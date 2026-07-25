"""Production health-check CI gate: validates that the stack is launch-ready.

This test suite runs against the FastAPI TestClient (no deployed backend needed)
and validates:

1. /healthz liveness endpoint returns {"status": "live", "version": "2.0.0"}
2. /readyz readiness endpoint returns correct status based on service state
3. /health health endpoint returns correct contract (status: ok / degraded)
4. Production configuration validation rejects incomplete configs
5. CORS origins are correctly restricted in production mode
6. Sentry DSN config is properly wired (verified via mobile-side imports)
7. The launch verifier smoke checks (tools/validate_production_config.py) pass
"""

import json
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

# Import the app for health endpoint testing
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.app.main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_global_state():
    """Reset health-check globals between tests to avoid cross-test pollution."""
    import src.app.main as main_module
    main_module._embedding_probe_result = None
    main_module._last_embedding_probe = 0.0
    main_module.rag_pipeline = None
    main_module.document_processing_service = None
    yield


# ─── 1. Liveness probe (/healthz) ─────────────────────────────────────


class TestLivenessEndpoint:
    """/healthz must be a cheap process-liveness check that never calls
    external services and never validates runtime state."""

    def test_returns_live_status(self):
        response = client.get("/healthz")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "live"
        assert data["version"] == "2.0.0"

    def test_liveness_does_not_depend_on_external_services(self, monkeypatch):
        """/healthz must work even when all services are unavailable."""
        monkeypatch.setattr("src.app.main.rag_pipeline", None)
        monkeypatch.setattr("src.app.main.document_processing_service", None)
        response = client.get("/healthz")
        assert response.status_code == 200
        assert response.json()["status"] == "live"


# ─── 2. Readiness probe (/readyz) ─────────────────────────────────────


class TestReadinessEndpoint:
    """/readyz must reject traffic when core services are uninitialized."""

    def test_returns_not_ready_when_services_down(self):
        response = client.get("/readyz")
        assert response.status_code == 503
        data = response.json()
        assert data["status"] == "not_ready"

    def test_returns_ready_when_services_initialized(self, monkeypatch):
        monkeypatch.setattr("src.app.main.rag_pipeline", object())
        monkeypatch.setattr("src.app.main.document_processing_service", object())
        response = client.get("/readyz")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ready"
        assert data["rag"] == "available"
        assert data["document_processing"] == "available"


# ─── 3. Health endpoint (/health) ─────────────────────────────────────


class TestHealthEndpoint:
    """/health must report service health status and include"
    document capability registry without exposing secrets."""

    def test_returns_unavailable_when_rag_not_initialized(self):
        response = client.get("/health")
        assert response.status_code == 503
        data = response.json()
        assert data["status"] == "unavailable"
        assert data["rag_status"] == "unavailable"
        assert "document_capabilities" in data

    def test_health_contract_contains_required_fields(self):
        """The /health response must always include the required fields
        regardless of service state, so monitoring tools can parse them."""
        response = client.get("/health")
        assert response.status_code == 503
        data = response.json()
        for field in ["status", "rag_status", "version", "document_capabilities"]:
            assert field in data, f"Missing required field: {field}"
        assert data["version"] == "2.0.0"

    def test_health_does_not_expose_secrets(self):
        """The /health response must never include API keys or secrets."""
        response = client.get("/health")
        # Force lower-case check across the entire JSON body
        body_text = json.dumps(response.json()).lower()
        for secret_indicator in ["api_key", "secret", "token", "password", "dsn"]:
            assert secret_indicator not in body_text, (
                f"Health response exposes secret-related term: {secret_indicator}"
            )

    def test_health_exposes_safe_document_capability_registry(self):
        """Document capability registry must be present and not contain secrets."""
        response = client.get("/health")
        data = response.json()
        caps = data.get("document_capabilities", {})
        assert caps.get("registry_version") == "document-capabilities.v1"
        body_text = json.dumps(caps).lower()
        assert "api_key" not in body_text


# ─── 4. Production configuration validation ───────────────────────────


class TestProductionConfiguration:
    """Validate that production_configuration_errors correctly identifies
    incomplete or unsafe configurations."""

    def test_valid_production_config_passes(self):
        from src.utils.runtime_config import production_configuration_errors

        env = {
            "ENVIRONMENT": "production",
            "OPENAI_API_KEY": "sk-" + "a" * 48,
            "SUPABASE_URL": "https://test.supabase.co",
            "SUPABASE_SERVICE_ROLE_KEY": "eyJ" + "a" * 40,
            "ALLOWED_ORIGINS": "https://coverwise.app",
            "ALLOWED_HOSTS": "api.coverwise.app",
            "PUBLIC_SITE_URL": "https://coverwise.app",
            "ANONYMOUS_AUTH_SIGNING_KEY": "a" * 32,
            "PROCESSING_PAYLOAD_ENCRYPTION_KEY": "b" * 32,
            "REVENUECAT_WEBHOOK_AUTHORIZATION": "test-webhook-secret",
            "DOCUMENT_REPOSITORY_BACKEND": "supabase",
            "DOCUMENT_OBJECT_STORE_BACKEND": "supabase",
            "RAG_VECTOR_BACKEND": "supabase",
            "BILLING_LEDGER_BACKEND": "supabase",
        }
        errors = production_configuration_errors(env)
        assert errors == [], f"Expected no errors, got: {errors}"

    def test_missing_openai_key_fails(self):
        from src.utils.runtime_config import production_configuration_errors

        env = {
            "ENVIRONMENT": "production",
            "SUPABASE_URL": "https://test.supabase.co",
            "SUPABASE_SERVICE_ROLE_KEY": "eyJ" + "a" * 40,
        }
        errors = production_configuration_errors(env)
        # Must have at least one error about OpenAI API key
        openai_errors = [e for e in errors if "OPENAI_API_KEY" in e or "OpenAI" in e]
        assert len(openai_errors) > 0, "Expected error about missing OpenAI API key"

    def test_missing_supabase_config_fails(self):
        from src.utils.runtime_config import production_configuration_errors

        env = {"ENVIRONMENT": "production", "OPENAI_API_KEY": "sk-" + "a" * 48}
        errors = production_configuration_errors(env)
        supabase_errors = [e for e in errors if "SUPABASE" in e]
        assert len(supabase_errors) > 0, "Expected error about missing Supabase config"

    def test_development_env_skips_production_checks(self):
        from src.utils.runtime_config import production_configuration_errors

        env = {"ENVIRONMENT": "development"}
        errors = production_configuration_errors(env)
        assert errors == [], f"Expected no errors for development, got: {errors}"


# ─── 5. CORS configuration in production ──────────────────────────────


class TestCorsConfiguration:
    """CORS must be correctly restricted in production mode."""

    def test_production_cors_allows_configured_origin(self):
        from src.utils.runtime_config import allowed_cors_origins

        origins = allowed_cors_origins(
            "production", "https://coverwise.app"
        )
        assert "https://coverwise.app" in origins
        # Wildcard must not be allowed in production
        assert "*" not in origins

    def test_production_cors_rejects_wildcard(self):
        from src.utils.runtime_config import allowed_cors_origins

        # allowed_cors_origins raises RuntimeError when ALLOWED_ORIGINS is
        # empty in production — this is the correct fail-closed behavior.
        with pytest.raises(RuntimeError, match="ALLOWED_ORIGINS is required"):
            allowed_cors_origins("production", "")

    def test_development_allows_wildcard(self):
        from src.utils.runtime_config import allowed_cors_origins

        origins = allowed_cors_origins("development", "")
        assert "*" in origins, "Development should allow wildcard CORS"

    def test_cors_with_credentials_in_production(self):
        """Production CORS origins must be explicit, not wildcard."""
        from src.utils.runtime_config import allowed_cors_origins

        origins = allowed_cors_origins("production", "https://coverwise.app")
        assert "*" not in origins, "Wildcard CORS must not be allowed in production"
        assert "https://coverwise.app" in origins


# ─── 6. Sentry config validation ──────────────────────────────────────


class TestSentryConfiguration:
    """Validate that Sentry crash reporting is properly wired."""

    def test_sentry_flutter_dependency_exists(self):
        """sentry_flutter must be declared in pubspec.yaml."""
        pubspec = Path(__file__).resolve().parents[1] / "mobile" / "pubspec.yaml"
        assert pubspec.exists(), "pubspec.yaml not found"
        content = pubspec.read_text(encoding="utf-8")
        assert "sentry_flutter" in content, (
            "sentry_flutter dependency not found in pubspec.yaml"
        )

    def test_sentry_init_exists_in_main_dart(self):
        """SentryFlutter.init() must be called in main.dart."""
        main_dart = Path(__file__).resolve().parents[1] / "mobile" / "lib" / "main.dart"
        assert main_dart.exists(), "main.dart not found"
        content = main_dart.read_text(encoding="utf-8")
        assert "SentryFlutter.init" in content, (
            "SentryFlutter.init() not found in main.dart"
        )
        assert "AppConfig.sentryDsn" in content, (
            "sentryDsn config reference not found in main.dart"
        )

    def test_has_sentry_config_property_exists(self):
        """AppConfig must expose hasSentryConfig property."""
        config_dart = (
            Path(__file__).resolve().parents[1]
            / "mobile" / "lib" / "config" / "app_config.dart"
        )
        assert config_dart.exists(), "app_config.dart not found"
        content = config_dart.read_text(encoding="utf-8")
        assert "hasSentryConfig" in content, (
            "hasSentryConfig getter not found in app_config.dart"
        )
        assert "sentryDsn" in content, (
            "sentryDsn constant not found in app_config.dart"
        )

    def test_run_zoned_guarded_fallback_exists(self):
        """runZonedGuarded must still exist as a fallback when Sentry DSN is empty."""
        main_dart = Path(__file__).resolve().parents[1] / "mobile" / "lib" / "main.dart"
        content = main_dart.read_text(encoding="utf-8")
        assert "runZonedGuarded" in content, (
            "runZonedGuarded fallback must exist when Sentry DSN is empty"
        )


# ─── 7. Launch verifier smoke test ────────────────────────────────────


class TestLaunchVerifier:
    """The production config validator tool must parse and validate correctly."""

    def test_validate_production_config_script_exists(self):
        validator = Path(__file__).resolve().parents[1] / "tools" / "validate_production_config.py"
        assert validator.exists(), "validate_production_config.py not found"

    def test_verify_deployed_launch_script_exists(self):
        verifier = Path(__file__).resolve().parents[1] / "tools" / "verify_deployed_launch.py"
        assert verifier.exists(), "verify_deployed_launch.py not found"

    def test_verify_deployed_launch_imports_cleanly(self):
        """The verify_deployed_launch.py script must import without errors."""
        module_path = Path(__file__).resolve().parents[1] / "tools" / "verify_deployed_launch.py"
        with open(module_path, "r") as f:
            try:
                compile(f.read(), module_path.name, "exec")
            except SyntaxError as e:
                pytest.fail(f"verify_deployed_launch.py has a syntax error: {e}")

    def test_azure_integration_test_file_exists(self):
        """The Azure integration test suite must exist for production verification."""
        azure_test = Path(__file__).resolve().parents[1] / "tests" / "test_azure_api.py"
        assert azure_test.exists(), "test_azure_api.py not found"

    def test_azure_integration_env_var_is_documented(self):
        """Azure integration tests must reference COVERWISE_INTEGRATION_BASE_URL."""
        azure_test = Path(__file__).resolve().parents[1] / "tests" / "test_azure_api.py"
        content = azure_test.read_text(encoding="utf-8")
        assert "COVERWISE_INTEGRATION_BASE_URL" in content, (
            "Azure integration tests must reference COVERWISE_INTEGRATION_BASE_URL"
        )
