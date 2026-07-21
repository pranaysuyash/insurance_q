"""Fail-closed runtime configuration shared by the application entrypoint."""

from __future__ import annotations

from collections.abc import Mapping


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


def production_configuration_errors(environment: Mapping[str, str]) -> list[str]:
    """Return safe, field-level launch configuration errors without secrets."""
    if environment.get("ENVIRONMENT", "development").lower() != "production":
        return []

    errors: list[str] = []
    required = (
        "OPENAI_API_KEY",
        "SUPABASE_URL",
        "SUPABASE_SERVICE_ROLE_KEY",
        "ANONYMOUS_AUTH_SIGNING_KEY",
        "PUBLIC_SITE_URL",
        "ALLOWED_ORIGINS",
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

    key = environment.get("ANONYMOUS_AUTH_SIGNING_KEY", "")
    if key and len(key) < 32:
        errors.append("ANONYMOUS_AUTH_SIGNING_KEY must be at least 32 characters")

    public_site_url = environment.get("PUBLIC_SITE_URL", "").strip()
    if public_site_url and not public_site_url.startswith("https://"):
        errors.append("PUBLIC_SITE_URL must use https")
    try:
        origins = allowed_cors_origins("production", environment.get("ALLOWED_ORIGINS", ""))
        if public_site_url.rstrip("/") not in {origin.rstrip("/") for origin in origins}:
            errors.append("PUBLIC_SITE_URL must be included in ALLOWED_ORIGINS")
    except RuntimeError as error:
        errors.append(str(error))
    if environment.get("LOG_LEVEL", "INFO").upper() == "DEBUG":
        errors.append("LOG_LEVEL cannot be DEBUG in production")
    return errors
