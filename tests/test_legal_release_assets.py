import pytest
from pathlib import Path

from src.frontend.app import app, lifespan
from tools.validate_legal_release_assets import validation_errors


def test_legal_release_preflight_has_all_placeholders_resolved():
    errors = validation_errors()

    assert (
        "unresolved legal placeholder in terms_of_service.md: [Jurisdiction]"
        not in errors
    ), "The [Jurisdiction] placeholder was resolved to 'India'"

    assert (
        "disallowed product-role wording in terms_of_service.md: information broker"
        not in errors
    ), "The 'information broker' wording was fixed to 'policy information assistant'"


def test_legal_release_preflight_checks_every_packaged_document():
    errors = validation_errors()

    assert not any("privacy_policy.md" in error for error in errors)


@pytest.mark.asyncio
async def test_public_frontend_starts_with_complete_legal_assets(
    monkeypatch,
):
    monkeypatch.setenv("ENVIRONMENT", "production")
    async with lifespan(app):
        pass


def test_mobile_release_gate_verifies_the_hosted_legal_documents():
    release_script = Path("tools/build_mobile_release.sh").read_text()

    assert 'python3 "$repo_root/tools/verify_hosted_legal_documents.py"' in release_script
    assert '--privacy-url "$COVERWISE_PRIVACY_POLICY_URL"' in release_script
    assert '--terms-url "$COVERWISE_TERMS_OF_SERVICE_URL"' in release_script
