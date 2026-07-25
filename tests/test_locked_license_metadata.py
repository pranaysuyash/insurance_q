"""Contracts for locked dependency licence-metadata evidence preparation."""

from email.message import Message

from tools import extract_locked_license_metadata as licence_tool


class FakeDistribution:
    """Small package-metadata stand-in; no interpreter packages are required."""

    def __init__(self, name: str, version: str, **metadata_values: str) -> None:
        self.version = version
        self.metadata = Message()
        self.metadata["Name"] = name
        for key, value in metadata_values.items():
            self.metadata[key] = value


def test_locked_packages_reads_unique_hash_locked_pins(tmp_path):
    lock = tmp_path / "requirements.lock"
    lock.write_text(
        "Alpha_Package==1.2.3 \\\n"
        "    --hash=sha256:abc\n"
        "alpha-package==1.2.3\n"
        "beta==4.5.6\n",
        encoding="utf-8",
    )

    assert licence_tool.locked_packages(lock) == [
        ("Alpha_Package", "1.2.3"),
        ("beta", "4.5.6"),
    ]


def test_component_record_keeps_missing_mismatch_and_approval_states_explicit():
    distributions = {
        "matched": FakeDistribution("matched", "1.0.0", **{"License-Expression": "MIT"}),
        "mismatch": FakeDistribution("mismatch", "2.0.0", License="BSD-3-Clause"),
    }

    matched = licence_tool.component_record("matched", "1.0.0", distributions)
    mismatch = licence_tool.component_record("mismatch", "1.0.0", distributions)
    missing = licence_tool.component_record("missing", "1.0.0", distributions)

    assert matched["match_status"] == "matched"
    assert matched["licence_metadata"]["license_expression"] == "MIT"
    assert matched["review_status"] == "legal-review-required"
    assert mismatch["match_status"] == "version-mismatch"
    assert mismatch["installed_version"] == "2.0.0"
    assert missing["match_status"] == "missing-from-interpreter"


def test_build_report_never_promotes_metadata_to_legal_approval(tmp_path, monkeypatch):
    lock = tmp_path / "requirements.lock"
    lock.write_text("matched==1.0.0\nmissing==1.0.0\n", encoding="utf-8")
    monkeypatch.setattr(
        licence_tool,
        "installed_distributions",
        lambda: {"matched": FakeDistribution("matched", "1.0.0", License="MIT")},
    )

    report = licence_tool.build_report(lock)

    assert report["summary"] == {
        "locked_components": 2,
        "matched_components": 1,
        "missing_from_interpreter": 1,
        "version_mismatches": 0,
        "components_with_declared_licence_metadata": 1,
        "components_without_declared_licence_metadata": 0,
        "legal_approval": "not-recorded",
    }
