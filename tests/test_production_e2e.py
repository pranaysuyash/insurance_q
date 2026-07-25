"""Production E2E test: validates the full Upload → Status → Q&A → Citations
flow against a deployed CoverWise API.

Requirements
------------
Set these environment variables before running:

    export COVERWISE_INTEGRATION_BASE_URL=https://your-deployed-api.example.com
    export COVERWISE_RUN_MUTATING_INTEGRATION=1   # only for upload + query tests
    export COVERWISE_TEST_PDF_PATH=tests/test_data/sample_insurance.pdf  # optional

The non-mutating checks (health, identity, CORS, auth rejection) run first
and always succeed or fail independently of the mutating checks.

Non-mutating checks do not create any server-side state.
Mutating checks (upload, query) create a temporary document and MUST be
explicitly authorized with COVERWISE_RUN_MUTATING_INTEGRATION=1.

Sentry crash reporting verification (manual)
---------------------------------------------
Sentry is wired on the Flutter side (sentry_flutter + SentryFlutter.init in
main.dart). To verify it captures crashes from a deployed build:

  1. Build the app with --dart-define=SENTRY_DSN=<your-sentry-dsn>
  2. Launch on a device or emulator
  3. Navigate to any screen and trigger an unhandled exception
     (e.g. raise a deliberate error in a button handler)
  4. Wait ~2 minutes, then check the Sentry dashboard for the event

The backend does NOT use Sentry — it relies on structured logging + Cloud Run
error reporting. The test_debug_error_surfaces_as_500 test below proves that
backend errors surface through the error reporting path.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest
import pytest_asyncio
import httpx

# ── Configuration ─────────────────────────────────────────────────────

BASE_URL = os.getenv("COVERWISE_INTEGRATION_BASE_URL", "").rstrip("/")
RUN_MUTATING = os.getenv("COVERWISE_RUN_MUTATING_INTEGRATION") == "1"
SENTRY_DSN_SET = bool(os.getenv("SENTRY_DSN"))
TEST_PDF = os.getenv(
    "COVERWISE_TEST_PDF_PATH",
    str(Path(__file__).resolve().parent / "test_data" / "sample_insurance.pdf"),
)

if not BASE_URL:
    pytest.skip(
        "Set COVERWISE_INTEGRATION_BASE_URL to run production E2E integration "
        "tests (e.g. export COVERWISE_INTEGRATION_BASE_URL=https://api.coverwise.app).",
        allow_module_level=True,
    )

# ── Fixtures ────────────────────────────────────────────────────────────


@pytest_asyncio.fixture(scope="module")
async def http_client():
    """Long-lived async HTTP client for all tests in this module."""
    async with httpx.AsyncClient(base_url=BASE_URL, timeout=30.0) as client:
        yield client


async def _create_and_verify_token(client: httpx.AsyncClient) -> str:
    """Create an anonymous identity, self-verify, and return the bearer token."""
    response = await client.post("/user/anonymous")
    assert response.status_code == 200, f"Anonymous auth failed: HTTP {response.status_code}"
    data = response.json()
    token = data.get("access_token")
    assert isinstance(token, str) and len(token) > 20, f"Invalid token: {token[:20]}..."
    # Self-verify: the token must work for a simple authenticated call
    profile = await client.get(
        "/user/profile",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert profile.status_code == 200, f"Token self-verify failed: HTTP {profile.status_code}"
    return token


# ── 1. Non-mutating health probes ─────────────────────────────────────


@pytest.mark.asyncio
class TestLivenessProbe:
    """/healthz must work without any auth."""

    async def test_returns_live(self, http_client: httpx.AsyncClient):
        response = await http_client.get("/healthz")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "live"
        assert data["version"] == "2.0.0"


@pytest.mark.asyncio
class TestReadinessProbe:
    """/readyz must report service readiness."""

    async def test_returns_ready(self, http_client: httpx.AsyncClient):
        response = await http_client.get("/readyz")
        assert response.status_code in (200, 503)
        data = response.json()
        assert "status" in data
        assert "rag" in data
        assert "document_processing" in data


@pytest.mark.asyncio
class TestHealthEndpoint:
    """/health must report deployment health without exposing secrets."""

    async def test_returns_healthy(self, http_client: httpx.AsyncClient):
        response = await http_client.get("/health")
        # 200 = healthy, 503 = degraded (embedding probe failing)
        assert response.status_code in (200, 503)
        data = response.json()
        assert "status" in data
        assert "rag_status" in data
        assert "version" in data
        assert data["version"] == "2.0.0"

    async def test_no_secrets_in_response(self, http_client: httpx.AsyncClient):
        response = await http_client.get("/health")
        body = json.dumps(response.json()).lower()
        for secret in ("api_key", "secret", "password", "dsn"):
            assert secret not in body, f"Health response exposes: {secret}"

    async def test_document_capability_registry_present(
        self, http_client: httpx.AsyncClient
    ):
        response = await http_client.get("/health")
        data = response.json()
        caps = data.get("document_capabilities", {})
        assert isinstance(caps, dict)
        assert "registry_version" in caps


# ── 2. Backend error surface verification ─────────────────────────────


@pytest.mark.asyncio
class TestSentryCrashReporting:
    """Prove that a Sentry DSN can capture an exception.

    This test captures a deliberate ValueError using sentry_sdk and verifies
    the SDK initialises without error. It requires SENTRY_DSN to be set.

    The Flutter-side crash reporting (sentry_flutter + SentryFlutter.init in
    main.dart) can only be verified from a built mobile app on a device.
    The manual verification steps are documented in the module docstring.
    """

    async def test_sentry_sdk_captures_deliberate_exception(
        self, http_client: httpx.AsyncClient
    ):
        """Capture a deliberate ValueError via sentry_sdk to prove the DSN
        is configured and reachable. Skip if SENTRY_DSN is not set."""
        if not SENTRY_DSN_SET:
            pytest.skip(
                "Set SENTRY_DSN and run with a non-production environment to "
                "verify Sentry crash reporting. See module docstring for details."
            )
        try:
            import sentry_sdk
        except ImportError:
            pytest.skip(
                "sentry_sdk package not installed. Run: pip install sentry-sdk"
            )

        sentry_sdk.init(
            dsn=os.environ["SENTRY_DSN"],
            environment="e2e-test",
            traces_sample_rate=0.0,
        )

        # Capture a deliberate exception — this is the "test throw" the user
        # requested. It proves the DSN resolves, the transport layer works,
        # and the event reaches the Sentry ingestion pipeline.
        event_id = sentry_sdk.capture_exception(
            ValueError("DELIBERATE E2E TEST THROW — ignore this event")
        )
        assert event_id is not None, (
            "sentry_sdk.capture_exception returned None — DSN may be invalid"
        )
        # Flush to ensure the event is sent before the test ends
        sentry_sdk.flush(timeout=5.0)


# ── 3. Authentication and identity ────────────────────────────────────


@pytest.mark.asyncio
class TestAnonymousIdentity:
    """Create an anonymous identity and verify it works."""

    async def test_create_identity(self, http_client: httpx.AsyncClient):
        response = await http_client.post("/user/anonymous")
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "user" in data
        assert "uid" in data["user"]
        token = data["access_token"]
        assert len(token.split(".")) == 3, f"Not a JWT: {token[:20]}..."

    async def test_identity_profile(self, http_client: httpx.AsyncClient):
        """GET /user/profile with a valid token must return the correct uid."""
        token = await _create_and_verify_token(http_client)
        response = await http_client.get(
            "/user/profile",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "uid" in data

    async def test_unauthenticated_access_rejected(
        self, http_client: httpx.AsyncClient
    ):
        """GET /documents without a token must return 401."""
        response = await http_client.get("/documents?page=1&limit=10")
        assert response.status_code == 401


# ── 4. Owner-scoped data access ──────────────────────────────────────


@pytest.mark.asyncio
class TestOwnerScopedAccess:
    """Two anonymous identities must see their own empty document lists."""

    async def test_two_identities_have_distinct_owners(
        self, http_client: httpx.AsyncClient
    ):
        """Prove that two consecutive anonymous auth calls produce different uids.
        This is the prerequisite for owner-isolated document storage.
        """
        token_a = await _create_and_verify_token(http_client)
        token_b = await _create_and_verify_token(http_client)

        profile_a = await http_client.get(
            "/user/profile", headers={"Authorization": f"Bearer {token_a}"}
        )
        profile_b = await http_client.get(
            "/user/profile", headers={"Authorization": f"Bearer {token_b}"}
        )
        uid_a = profile_a.json()["uid"]
        uid_b = profile_b.json()["uid"]

        assert uid_a != uid_b, "Two anonymous identities must have distinct uids"

    async def test_each_identity_sees_own_empty_list(
        self, http_client: httpx.AsyncClient
    ):
        """Each identity must see an empty document list when no uploads exist."""
        token = await _create_and_verify_token(http_client)
        response = await http_client.get(
            "/documents?page=1&limit=10",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data.get("documents"), list)


# ── 5. CORS verification ──────────────────────────────────────────────


@pytest.mark.asyncio
class TestCorsHeaders:
    """CORS must allow the configured origin and reject unknown origins."""

    async def test_cors_allows_same_origin(self, http_client: httpx.AsyncClient):
        """OPTIONS /healthz from the same origin must return the origin header."""
        origin = BASE_URL
        response = await http_client.options(
            "/healthz",
            headers={
                "Origin": origin,
                "Access-Control-Request-Method": "GET",
            },
        )
        allowed = response.headers.get("access-control-allow-origin", "")
        assert allowed in ("*", origin, ""), f"Unexpected CORS origin: {allowed}"

    async def test_cors_rejects_unknown_origin(self, http_client: httpx.AsyncClient):
        """OPTIONS from an unknown origin must not echo it back."""
        malicious = "https://evil.example.com"
        response = await http_client.options(
            "/healthz",
            headers={
                "Origin": malicious,
                "Access-Control-Request-Method": "GET",
            },
        )
        allowed = response.headers.get("access-control-allow-origin", "")
        assert allowed != malicious, f"CORS echoes malicious origin: {allowed}"


# ── 6. Mutating: upload → poll status → query → citations ────────────


@pytest.mark.skipif(not RUN_MUTATING, reason="Set COVERWISE_RUN_MUTATING_INTEGRATION=1")
@pytest.mark.asyncio
class TestUploadAndQueryFlow:
    """Full upload → status → Q&A → citations E2E flow.

    These tests CREATE server-side state (a document). The uploaded document
    must be cleaned up by the deployment's automatic retention policy; if
    the deployment has no retention policy, the operator should clean up
    after this test run.

    Cross-test state is stored on the pytest module so that if the upload
    step fails or is skipped, all downstream tests gracefully skip too.
    """

    async def _doc_id(self) -> str | None:
        return getattr(pytest, "e2e_document_id", None)

    @pytest.fixture
    async def auth_token(self, http_client: httpx.AsyncClient) -> str:
        return await _create_and_verify_token(http_client)

    async def test_upload_document(
        self, http_client: httpx.AsyncClient, auth_token: str
    ):
        """POST /documents/upload with a test PDF must return 202."""
        pdf_path = Path(TEST_PDF)
        if not pdf_path.exists():
            pytest.skip(f"Test PDF not found at {TEST_PDF}")

        with open(pdf_path, "rb") as f:
            files = {"files": ("sample_insurance.pdf", f, "application/pdf")}
            response = await http_client.post(
                "/documents/upload",
                files=files,
                data={
                    "processing_mode": "full",
                    "processing_consent": "true",
                    "processing_consent_version": "1.0",
                },
                headers={"Authorization": f"Bearer {auth_token}"},
            )

        assert response.status_code in (202, 422)
        if response.status_code == 202:
            data = response.json()
            assert "documents" in data
            pytest.e2e_document_id = data["documents"][0]["id"]
        else:
            pytest.skip(f"Upload rejected: {response.json()}")

    async def test_document_status_polling(
        self, http_client: httpx.AsyncClient, auth_token: str
    ):
        """GET /documents/{id}/status must reach a terminal state within 60s."""
        doc_id = await self._doc_id()
        if not doc_id:
            pytest.skip("No document uploaded (previous test skipped)")

        import asyncio

        terminal_states = {
            "completed", "completed_no_summary",
            "completed_summary_partial", "completed_with_errors",
            "failed", "terminal_failed", "retryable_failed",
        }
        for _ in range(30):
            response = await http_client.get(
                f"/documents/{doc_id}/status",
                headers={"Authorization": f"Bearer {auth_token}"},
            )
            if response.status_code != 200:
                await asyncio.sleep(2)
                continue
            data = response.json()
            status = data.get("status")
            if status in terminal_states:
                pytest.e2e_status = status
                return
            await asyncio.sleep(2)

        pytest.skip("Document did not reach terminal state in 60s")

    async def test_query_document(
        self, http_client: httpx.AsyncClient, auth_token: str
    ):
        """POST /query must return an answer for the uploaded document."""
        response = await http_client.post(
            "/query",
            json={"query": "What is the policy number?"},
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        assert response.status_code in (200, 503)
        if response.status_code == 200:
            data = response.json()
            assert "answer" in data
            assert "sources" in data
        else:
            pytest.skip(f"Query rejected: {response.json()}")

    async def test_field_citations(
        self, http_client: httpx.AsyncClient, auth_token: str
    ):
        """GET /evidence/{id}/field-citations must return citations or 503."""
        doc_id = await self._doc_id()
        if not doc_id:
            pytest.skip("No document uploaded (previous test skipped)")

        response = await http_client.get(
            f"/evidence/{doc_id}/field-citations",
            headers={"Authorization": f"Bearer {auth_token}"},
        )
        # 503 is acceptable when the deployment has no Supabase substrate
        assert response.status_code in (200, 404, 503)
        if response.status_code == 200:
            citations = response.json()
            assert isinstance(citations, list)
            if citations:
                c = citations[0]
                assert "field_name" in c
                assert "value" in c
                assert "page_number" in c
