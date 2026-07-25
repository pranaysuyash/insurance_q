"""Keep the shipped legal assets and publishable document sources aligned."""

from pathlib import Path


ROOT = Path(__file__).parents[1]


def test_publishable_legal_documents_match_the_in_app_versions():
    """A reviewer must not see different terms in the app and deployment docs.

    The release process may render ``docs/legal`` to a hosted HTTPS page, while
    Flutter packages ``mobile/assets/legal``. Exact source parity is a local
    contract; it is not evidence that the hosted pages were deployed.
    """
    for filename in ("privacy_policy.md", "terms_of_service.md"):
        asset = ROOT / "mobile" / "assets" / "legal" / filename
        publishable = ROOT / "docs" / "legal" / filename
        assert asset.read_bytes() == publishable.read_bytes(), filename
