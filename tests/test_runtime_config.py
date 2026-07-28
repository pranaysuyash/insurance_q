import os
import subprocess
import sys
from pathlib import Path

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.middleware.trustedhost import TrustedHostMiddleware

from src.utils.runtime_config import (
    allowed_cors_origins,
    allowed_hostnames,
    production_configuration_errors,
    supabase_server_key,
)
from tools.validate_production_config import _load_runtime_env_file


def test_env_example_matches_the_canonical_embedding_and_launch_contract():
    example = (Path(__file__).parents[1] / ".env.example").read_text()

    assert "OPENAI_EMBEDDING_MODEL=text-embedding-3-small" in example
    assert "text-embedding-ada-002" not in example
    for name in (
        "ENVIRONMENT",
        "SUPABASE_SECRET_KEY",
        "SUPABASE_STORAGE_BUCKET",
        "DOCUMENT_REPOSITORY_BACKEND",
        "DOCUMENT_OBJECT_STORE_BACKEND",
        "RAG_VECTOR_BACKEND",
        "ANONYMOUS_AUTH_SIGNING_KEY",
        "PROCESSING_PAYLOAD_ENCRYPTION_KEY",
        "PUBLIC_SITE_URL",
        "ALLOWED_ORIGINS",
        "ALLOWED_HOSTS",
    ):
        assert f"{name}=" in example


def test_production_validator_loads_gcloud_yaml_env_files(tmp_path, monkeypatch):
    env_file = tmp_path / "coverwise-runtime.env.yaml"
    env_file.write_text(
        "ENVIRONMENT: production\n"
        "SUPABASE_URL: https://project.supabase.co\n"
        "ALLOWED_ORIGINS: https://app.example.com\n"
        "ALLOWED_HOSTS: api.example.com\n"
        "PUBLIC_SITE_URL: https://app.example.com\n",
        encoding="utf-8",
    )
    for name in (
        "ENVIRONMENT",
        "SUPABASE_URL",
        "ALLOWED_ORIGINS",
        "ALLOWED_HOSTS",
        "PUBLIC_SITE_URL",
    ):
        monkeypatch.delenv(name, raising=False)

    values = _load_runtime_env_file(env_file)

    assert values["ENVIRONMENT"] == "production"
    assert values["PUBLIC_SITE_URL"] == "https://app.example.com"
    assert "ENVIRONMENT" not in os.environ


def test_production_validator_rejects_secret_bound_values_in_runtime_file(
    tmp_path, monkeypatch, capsys
):
    env_file = tmp_path / "coverwise-runtime.env.yaml"
    env_file.write_text(
        "ENVIRONMENT: production\n"
        "OPENAI_API_KEY: accidentally-embedded-secret\n",
        encoding="utf-8",
    )
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)

    from tools.validate_production_config import main

    monkeypatch.setattr(
        "sys.argv",
        [
            "validate_production_config.py",
            "--env-file",
            str(env_file),
            "--secret-bound",
            "OPENAI_API_KEY",
        ],
    )
    assert main() == 2
    assert "must not contain secret-bound" in capsys.readouterr().err


def test_production_validator_prioritizes_explicit_runtime_file(
    tmp_path, monkeypatch
):
    env_file = tmp_path / "coverwise-runtime.env.yaml"
    env_file.write_text(
        "ENVIRONMENT: production\n"
        "SUPABASE_URL: https://project.supabase.co\n"
        "PUBLIC_SITE_URL: https://app.coverwise.example\n"
        "ALLOWED_ORIGINS: https://app.coverwise.example\n"
        "ALLOWED_HOSTS: api.coverwise.example\n"
        "DOCUMENT_REPOSITORY_BACKEND: supabase\n"
        "DOCUMENT_OBJECT_STORE_BACKEND: supabase\n"
        "RAG_VECTOR_BACKEND: supabase\n"
        "BILLING_LEDGER_BACKEND: supabase\n"
        "LOG_LEVEL: INFO\n",
        encoding="utf-8",
    )
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("OPENAI_API_KEY", "process-value")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "process-value")
    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "a" * 32)
    monkeypatch.setenv("REVENUECAT_WEBHOOK_AUTHORIZATION", "Bearer process-value")

    from tools.validate_production_config import main

    monkeypatch.setattr(
        "sys.argv",
        [
            "validate_production_config.py",
            "--env-file",
            str(env_file),
            "--secret-bound",
            "OPENAI_API_KEY",
            "--secret-bound",
            "SUPABASE_SERVICE_ROLE_KEY",
            "--secret-bound",
            "ANONYMOUS_AUTH_SIGNING_KEY",
            "--secret-bound",
            "REVENUECAT_WEBHOOK_AUTHORIZATION",
            "--secret-bound",
            "PROCESSING_PAYLOAD_ENCRYPTION_KEY",
        ],
    )
    assert main() == 0


def test_development_allows_local_browser_origins():
    assert allowed_cors_origins("development", "") == ["*"]


def test_supabase_server_key_accepts_current_secret_name(monkeypatch):
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "modern-server-key")
    assert supabase_server_key() == "modern-server-key"


def test_supabase_server_key_prefers_internal_compatibility_name(monkeypatch):
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "internal-key")
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "modern-server-key")
    assert supabase_server_key() == "internal-key"


def test_production_requires_explicit_origins():
    with pytest.raises(RuntimeError, match="ALLOWED_ORIGINS"):
        allowed_cors_origins("production", "")


def test_production_rejects_wildcard_origin():
    with pytest.raises(RuntimeError, match="cannot contain"):
        allowed_cors_origins("production", "*")


def test_production_requires_explicit_allowed_hosts():
    with pytest.raises(RuntimeError, match="ALLOWED_HOSTS"):
        allowed_hostnames("production", "")


def test_production_rejects_wildcard_or_url_allowed_hosts():
    with pytest.raises(RuntimeError, match="cannot contain"):
        allowed_hostnames("production", "*")
    with pytest.raises(RuntimeError, match="hostnames only"):
        allowed_hostnames("production", "https://api.example.com")


def test_production_parses_explicit_allowed_hosts():
    assert allowed_hostnames("production", " api.example.com,*.coverwise.example ") == [
        "api.example.com",
        "*.coverwise.example",
    ]


def test_trusted_host_middleware_rejects_unconfigured_host():
    app = FastAPI()
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=["api.example.com"])

    @app.get("/health")
    def health():
        return {"status": "ok"}

    client = TestClient(app)

    assert client.get("/health", headers={"Host": "api.example.com"}).status_code == 200
    assert client.get("/health", headers={"Host": "api.example.com/forged"}).status_code == 400


def test_canonical_api_enforces_the_production_host_allowlist():
    environment = os.environ.copy()
    environment.update(
        {
            "ENVIRONMENT": "production",
            "OPENAI_API_KEY": "sk-test",
            "SUPABASE_URL": "https://project.supabase.co",
            "SUPABASE_SERVICE_ROLE_KEY": "service-role-secret",
            "ANONYMOUS_AUTH_SIGNING_KEY": "a" * 32,
            "PROCESSING_PAYLOAD_ENCRYPTION_KEY": "p" * 32,
            "PUBLIC_SITE_URL": "https://app.coverwise.example",
            "ALLOWED_ORIGINS": "https://app.coverwise.example",
            "ALLOWED_HOSTS": "api.coverwise.example",
            "REVENUECAT_WEBHOOK_AUTHORIZATION": "Bearer rc-test",
            "DOCUMENT_REPOSITORY_BACKEND": "supabase",
            "DOCUMENT_OBJECT_STORE_BACKEND": "supabase",
            "RAG_VECTOR_BACKEND": "supabase",
            "BILLING_LEDGER_BACKEND": "supabase",
            "LOG_LEVEL": "INFO",
        }
    )
    script = """
from fastapi.testclient import TestClient
from src.app.main import app
client = TestClient(app)
print(client.get('/healthz', headers={'Host': 'api.coverwise.example'}).status_code)
print(client.get('/healthz', headers={'Host': 'api.coverwise.example/forged'}).status_code)
"""

    result = subprocess.run(
        [sys.executable, "-c", script],
        cwd=Path(__file__).parents[1],
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    # Filter out JSON log lines emitted by structlog/Sentry init during startup
    lines = [
        line
        for line in result.stdout.splitlines()
        if not line.startswith("{")
    ]
    assert lines == ["200", "400"]


def test_production_parses_explicit_origins():
    assert allowed_cors_origins("production", " https://app.example.com,https://www.example.com ") == [
        "https://app.example.com",
        "https://www.example.com",
    ]


def test_production_preflight_requires_the_canonical_contract():
    errors = production_configuration_errors({"ENVIRONMENT": "production"})

    assert "OPENAI_API_KEY is required" in errors
    assert "REVENUECAT_WEBHOOK_AUTHORIZATION is required" in errors
    assert errors.count("ALLOWED_ORIGINS is required when ENVIRONMENT=production") == 1
    assert errors.count("ALLOWED_HOSTS is required when ENVIRONMENT=production") == 1
    assert "DOCUMENT_REPOSITORY_BACKEND must be supabase" in errors
    assert "BILLING_LEDGER_BACKEND must be supabase" in errors


def test_production_preflight_accepts_complete_configuration():
    errors = production_configuration_errors(
        {
            "ENVIRONMENT": "production",
            "OPENAI_API_KEY": "sk-test",
            "SUPABASE_URL": "https://project.supabase.co",
            "SUPABASE_SERVICE_ROLE_KEY": "service-role-secret",
            "ANONYMOUS_AUTH_SIGNING_KEY": "a" * 32,
            "PUBLIC_SITE_URL": "https://app.coverwise.example",
            "ALLOWED_ORIGINS": "https://app.coverwise.example",
            "ALLOWED_HOSTS": "api.coverwise.example",
            "REVENUECAT_WEBHOOK_AUTHORIZATION": "Bearer rc-test",
            "PROCESSING_PAYLOAD_ENCRYPTION_KEY": "p" * 32,
            "DOCUMENT_REPOSITORY_BACKEND": "supabase",
            "DOCUMENT_OBJECT_STORE_BACKEND": "supabase",
            "RAG_VECTOR_BACKEND": "supabase",
            "BILLING_LEDGER_BACKEND": "supabase",
            "LOG_LEVEL": "INFO",
        }
    )

    assert errors == []


def test_production_preflight_measures_encryption_keys_in_utf8_bytes():
    errors = production_configuration_errors(
        {
            "ENVIRONMENT": "production",
            "OPENAI_API_KEY": "sk-test",
            "SUPABASE_URL": "https://project.supabase.co",
            "SUPABASE_SERVICE_ROLE_KEY": "service-role-secret",
            "ANONYMOUS_AUTH_SIGNING_KEY": "🔐" * 8,
            "PUBLIC_SITE_URL": "https://app.coverwise.example",
            "ALLOWED_ORIGINS": "https://app.coverwise.example",
            "ALLOWED_HOSTS": "api.coverwise.example",
            "REVENUECAT_WEBHOOK_AUTHORIZATION": "Bearer rc-test",
            "PROCESSING_PAYLOAD_ENCRYPTION_KEY": "🔐" * 8,
            "DOCUMENT_REPOSITORY_BACKEND": "supabase",
            "DOCUMENT_OBJECT_STORE_BACKEND": "supabase",
            "RAG_VECTOR_BACKEND": "supabase",
            "BILLING_LEDGER_BACKEND": "supabase",
            "LOG_LEVEL": "INFO",
        }
    )

    assert errors == []


def test_worker_profile_requires_only_worker_runtime_contract():
    errors = production_configuration_errors(
        {
            "ENVIRONMENT": "production",
            "OPENAI_API_KEY": "sk-test",
            "SUPABASE_URL": "https://project.supabase.co",
            "SUPABASE_SERVICE_ROLE_KEY": "service-role-secret",
            "DOCUMENT_REPOSITORY_BACKEND": "supabase",
            "DOCUMENT_OBJECT_STORE_BACKEND": "supabase",
            "RAG_VECTOR_BACKEND": "supabase",
            "BILLING_LEDGER_BACKEND": "supabase",
            "PROCESSING_PAYLOAD_ENCRYPTION_KEY": "p" * 32,
            "LOG_LEVEL": "INFO",
        },
        profile="worker",
    )

    assert errors == []
