"""Tests for the versioned document-capability benchmark."""

from pathlib import Path

from tools.evaluate_document_capabilities import evaluate_manifest


def test_capability_manifest_runs_without_persisting_source_text():
    repo_root = Path(__file__).resolve().parents[1]
    manifest = repo_root / "docs/eval/document_intelligence/capability_manifest_v1.json"

    report = evaluate_manifest(manifest, repo_root=repo_root)

    assert report["all_executed_cases_passed"] is True
    assert report["source_text_included"] is False
    assert report["not_run_cases"] == 2
    assert {case["status"] for case in report["case_results"]} == {"passed", "not_run"}
    mixed = next(case for case in report["case_results"] if case["id"] == "synthetic_mixed_native")
    assert mixed["node_counts"]["table"] == 1
    assert mixed["node_counts"]["table_cell"] == 4
    assert mixed["node_counts"]["figure"] == 1
    form = next(case for case in report["case_results"] if case["id"] == "synthetic_form_native")
    assert form["status"] == "passed"
    assert form["node_counts"]["form_field"] == 1
    mixed_scan = next(
        case for case in report["case_results"]
        if case["id"] == "synthetic_mixed_scan_pdf_doctr"
    )
    assert mixed_scan["status"] == "not_run"
