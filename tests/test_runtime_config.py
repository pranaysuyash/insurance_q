import pytest

from src.utils.runtime_config import allowed_cors_origins, production_configuration_errors


def test_development_allows_local_browser_origins():
    assert allowed_cors_origins("development", "") == ["*"]


def test_production_requires_explicit_origins():
    with pytest.raises(RuntimeError, match="ALLOWED_ORIGINS"):
        allowed_cors_origins("production", "")


def test_production_rejects_wildcard_origin():
    with pytest.raises(RuntimeError, match="cannot contain"):
        allowed_cors_origins("production", "*")


def test_production_parses_explicit_origins():
    assert allowed_cors_origins("production", " https://app.example.com,https://www.example.com ") == [
        "https://app.example.com",
        "https://www.example.com",
    ]


def test_production_preflight_requires_the_canonical_contract():
    errors = production_configuration_errors({"ENVIRONMENT": "production"})

    assert "OPENAI_API_KEY is required" in errors
    assert "DOCUMENT_REPOSITORY_BACKEND must be supabase" in errors


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
            "DOCUMENT_REPOSITORY_BACKEND": "supabase",
            "DOCUMENT_OBJECT_STORE_BACKEND": "supabase",
            "RAG_VECTOR_BACKEND": "supabase",
            "LOG_LEVEL": "INFO",
        }
    )

    assert errors == []
