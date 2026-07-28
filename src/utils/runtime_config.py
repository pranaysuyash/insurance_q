"""Fail-closed runtime configuration shared by the application entrypoint."""

from __future__ import annotations

from collections.abc import Mapping
import re


_ALLOWED_HOST_PATTERN = re.compile(r"^(?:\*\.)?[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*$")


def supabase_server_key() -> str:
    """Return the server-only Supabase key under either supported name.

    Supabase renamed the server key over time: older projects expose it as the
    ``service_role`` secret (read via ``SUPABASE_SERVICE_ROLE_KEY``), while
    current projects expose the same capability as the ``secret`` key (read via
    ``SUPABASE_SECRET_KEY``, value starts with ``sb_secret_``). Both names refer
    to the SAME key — operators should set only one. This helper prefers
    ``SUPABASE_SERVICE_ROLE_KEY`` and falls back to ``SUPABASE_SECRET_KEY`` so
    the application starts under either convention without code changes.
    """
    import os

    return (
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        or os.environ.get("SUPABASE_SECRET_KEY", "").strip()
    )


def normalize_supabase_environment() -> None:
    """Accept Supabase's modern secret-key name at the server boundary.

    The application keeps ``SUPABASE_SERVICE_ROLE_KEY`` as its canonical
    internal contract, while current Supabase projects expose the server key
    as ``SUPABASE_SECRET_KEY``. This alias is server-only and is never exposed
    to Flutter or returned in diagnostics.
    """
    import os

    if not os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip():
        secret = os.environ.get("SUPABASE_SECRET_KEY", "").strip()
        if secret:
            os.environ["SUPABASE_SERVICE_ROLE_KEY"] = secret


def allowed_cors_origins(environment: str, configured_origins: str) -> list[str]:
    """Return explicit browser origins; production never inherits a stale host."""
    origins = [origin.strip() for origin in configured_origins.split(",") if origin.strip()]
    if environment.lower() == "production":
        if not origins:
            raise RuntimeError("ALLOWED_ORIGINS is required when ENVIRONMENT=production")
        if "*" in origins:
            raise RuntimeError("ALLOWED_ORIGINS cannot contain '*' in production")
        return origins
    return ["*"]


def allowed_hostnames(environment: str, configured_hosts: str) -> list[str]:
    """Return explicit Host-header values for the canonical API entrypoint."""
    hosts = [host.strip().lower() for host in configured_hosts.split(",") if host.strip()]
    if environment.lower() != "production":
        return ["*"]
    if not hosts:
        raise RuntimeError("ALLOWED_HOSTS is required when ENVIRONMENT=production")
    if "*" in hosts:
        raise RuntimeError("ALLOWED_HOSTS cannot contain '*' in production")
    invalid = [host for host in hosts if not _ALLOWED_HOST_PATTERN.fullmatch(host)]
    if invalid:
        raise RuntimeError("ALLOWED_HOSTS must contain hostnames only")
    return list(dict.fromkeys(hosts))


def production_configuration_errors(
    environment: Mapping[str, str],
    *,
    profile: str = "api",
) -> list[str]:
    """Return safe, field-level launch configuration errors without secrets."""
    if environment.get("ENVIRONMENT", "development").lower() != "production":
        return []
    if profile not in {"api", "worker"}:
        return [f"unsupported production configuration profile: {profile}"]

    errors: list[str] = []
    required = (
        "SUPABASE_URL",
        "OPENAI_API_KEY",
        "SUPABASE_SERVICE_ROLE_KEY",
        "PROCESSING_PAYLOAD_ENCRYPTION_KEY",
    )
    if profile == "api":
        required += (
            "ANONYMOUS_AUTH_SIGNING_KEY",
            "PUBLIC_SITE_URL",
            "REVENUECAT_WEBHOOK_AUTHORIZATION",
        )
    for name in required:
        value = environment.get(name, "").strip()
        if name == "SUPABASE_SERVICE_ROLE_KEY" and not value:
            value = environment.get("SUPABASE_SECRET_KEY", "").strip()
        if not value or value.lower().startswith(("change-me", "placeholder", "your_", "set_")):
            errors.append(f"{name} is required")

    expected = {
        "DOCUMENT_REPOSITORY_BACKEND": "supabase",
        "DOCUMENT_OBJECT_STORE_BACKEND": "supabase",
        "RAG_VECTOR_BACKEND": "supabase",
        "BILLING_LEDGER_BACKEND": "supabase",
    }
    for name, value in expected.items():
        if environment.get(name, "").strip().lower() != value:
            errors.append(f"{name} must be {value}")

    if profile == "api":
        key = environment.get("ANONYMOUS_AUTH_SIGNING_KEY", "")
        if key and len(key.encode("utf-8")) < 32:
            errors.append("ANONYMOUS_AUTH_SIGNING_KEY must be at least 32 bytes")

        public_site_url = environment.get("PUBLIC_SITE_URL", "").strip()
        if public_site_url and not public_site_url.startswith("https://"):
            errors.append("PUBLIC_SITE_URL must use https")
        try:
            origins = allowed_cors_origins("production", environment.get("ALLOWED_ORIGINS", ""))
            if public_site_url.rstrip("/") not in {origin.rstrip("/") for origin in origins}:
                errors.append("PUBLIC_SITE_URL must be included in ALLOWED_ORIGINS")
        except RuntimeError as error:
            errors.append(str(error))
        try:
            allowed_hostnames("production", environment.get("ALLOWED_HOSTS", ""))
        except RuntimeError as error:
            errors.append(str(error))
    processing_key = environment.get("PROCESSING_PAYLOAD_ENCRYPTION_KEY", "")
    if processing_key and len(processing_key.encode("utf-8")) < 32:
        errors.append("PROCESSING_PAYLOAD_ENCRYPTION_KEY must be at least 32 bytes")
    if environment.get("LOG_LEVEL", "INFO").upper() == "DEBUG":
        errors.append("LOG_LEVEL cannot be DEBUG in production")
    dsn = environment.get("SENTRY_DSN", "").strip()
    if dsn and not dsn.startswith("https://"):
        errors.append("SENTRY_DSN must start with https://")
    return errors
