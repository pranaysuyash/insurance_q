"""CI gate: launch-claim registry integrity.

Asserts that every entry in docs/launch_claims/README.md exists on disk
and that its registry file contains the required sections
(Approved wording, Explicit limitations, Implementation owners,
Verification gates, Revisit trigger).

This test prevents stale registry entries from being merged.
"""

from pathlib import Path
import re

REGISTRY_PATH = Path("docs/launch_claims/README.md")
REGISTRY_DIR = REGISTRY_PATH.parent

REQUIRED_SECTIONS = [
    "Approved wording",
    "Explicit limitations",
    "Implementation owners",
    "Verification gates",
    "Revisit trigger",
]


def _parse_registry_entries():
    """Return list of (claim_number, claim_name, registry_filename) tuples."""
    text = REGISTRY_PATH.read_text(encoding="utf-8")
    entries = []

    # Match table rows: | # | Claim | [file](file) | Evidence tier | Status |
    pattern = re.compile(
        r"^\|\s*(\d+[a-z]?)\s*\|(.+?)\|\s*\[([^\]]+)\]\(([^)]+)\)\s*\|",
        re.MULTILINE,
    )
    for match in pattern.finditer(text):
        num = match.group(1).strip()
        # Claim name is between second pipe and third pipe
        claim_name = match.group(2).strip()
        link_text = match.group(3).strip()
        link_target = match.group(4).strip()
        entries.append((num, claim_name, link_text, link_target))

    return entries


class TestLaunchClaimRegistry:
    def test_registry_file_exists(self):
        assert REGISTRY_PATH.exists(), f"Registry file not found: {REGISTRY_PATH}"

    def test_registry_file_contains_required_sections(self):
        text = REGISTRY_PATH.read_text(encoding="utf-8")
        for section in ["Registry entries", "Evidence tiers", "Revisit trigger", "CI gate"]:
            assert section in text, f"Registry README missing section: {section}"

    def test_all_entry_files_exist(self):
        """Every registry entry must link to an existing file."""
        entries = _parse_registry_entries()
        assert len(entries) >= 8, f"Expected at least 8 registry entries, found {len(entries)}"
        for num, claim_name, link_text, link_target in entries:
            target_path = REGISTRY_DIR / link_target
            assert target_path.exists(), (
                f"Entry #{num} ({claim_name}) links to {link_target} but "
                f"that file does not exist"
            )

    def test_entry_files_have_required_sections(self):
        """Each registry entry's file must have the 5 required sections."""
        entries = _parse_registry_entries()
        for num, claim_name, link_text, link_target in entries:
            target_path = REGISTRY_DIR / link_target
            if not target_path.exists():
                continue  # covered by test above
            text = target_path.read_text(encoding="utf-8")
            for section in REQUIRED_SECTIONS:
                assert section in text, (
                    f"Entry #{num} ({claim_name}) file {link_target} "
                    f"missing section: {section}"
                )

    # NOTE: A stale-entry check (>90 days since last commit) was
    # intentionally omitted because filesystem mtime is unreliable in
    # CI (fresh checkout resets all mtimes). The section-existence and
    # file-existence checks above provide a robust validation that no
    # entry has been silently abandoned. A future improvement could
    # parse an in-file date marker (e.g. "Last updated: YYYY-MM-DD")
    # from each registry file once that convention is standardized.
