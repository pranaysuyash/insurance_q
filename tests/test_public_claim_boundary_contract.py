from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FRONTEND_APP = REPO_ROOT / "src/frontend/app.py"
PUBLIC_TEMPLATE = REPO_ROOT / "src/frontend/templates/index.html"
LEGACY_LANDING_TEMPLATE = REPO_ROOT / "src/frontend/templates/landing.html"


def test_public_root_uses_the_evidence_limited_template() -> None:
    source = FRONTEND_APP.read_text(encoding="utf-8")

    assert 'name="index.html"' in source
    assert 'name="landing.html"' not in source
    assert "launch-ready marketing" not in source.lower()


def test_public_template_does_not_promise_coverage_gap_finding_or_claim_filing() -> None:
    source = PUBLIC_TEMPLATE.read_text(encoding="utf-8").lower()

    assert "coverage gaps" not in source
    assert "how do i file a claim?" not in source
    assert "what claim steps does this policy describe?" in source
    assert "available coverage details" in source
    assert 'href="/privacy"' in source
    assert 'href="/terms"' in source
    assert "launch-ready" not in source


def test_legacy_landing_template_is_not_a_public_route() -> None:
    """Keep historical marketing copy out of the served public route contract."""
    assert LEGACY_LANDING_TEMPLATE.exists()
