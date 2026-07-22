"""Static contract tests for the canonical evidence citation view."""

from pathlib import Path


MIGRATION = Path(__file__).parents[1] / "supabase/migrations/20260721110000_latest_field_citations.sql"
LINEAGE_MIGRATION = Path(__file__).parents[1] / "supabase/migrations/20260721120000_evidence_lineage_constraints.sql"


def test_latest_field_citations_selects_latest_field_before_evidence():
    sql = MIGRATION.read_text()

    assert "with latest_fields as" in sql.lower()
    assert "distinct on (ef.document_id, ef.field_name)" in sql.lower()
    assert "order by ef.document_id, ef.field_name, ef.created_at desc, ef.id desc" in sql.lower()
    assert "strongest_evidence as" in sql.lower()
    assert "distinct on (fe.extracted_field_id)" in sql.lower()
    assert "from latest_fields ef" in sql.lower()
    assert "join strongest_evidence fe" in sql.lower()


def test_evidence_view_preserves_service_role_read_boundary():
    sql = MIGRATION.read_text().lower()

    assert "security_invoker = true" in sql
    assert "grant select on public.v_field_citations to service_role" in sql


def test_field_evidence_enforces_document_and_page_lineage():
    sql = LINEAGE_MIGRATION.read_text().lower()

    assert "existing field_evidence contains cross-document links" in sql
    assert "existing field_evidence contains cross-page span links" in sql
    assert "create or replace function public.validate_field_evidence_lineage()" in sql
    assert "field_evidence lineage mismatch: field and page belong to different documents" in sql
    assert "field_evidence lineage mismatch: span belongs to a different page" in sql
    assert "before insert or update of extracted_field_id, page_artifact_id, source_span_id" in sql


def test_source_span_capability_migration_preserves_visual_truth_boundary():
    migration = (
        Path(__file__).parents[1]
        / "supabase/migrations/20260721160000_source_span_capability_types.sql"
    ).read_text().lower()

    assert "drop constraint if exists source_spans_span_type_check" in migration
    assert "'sentence'" in migration
    assert "'table_cell'" in migration
    assert "'formula'" in migration
    assert "'form_field'" in migration
    assert "image-only figures remain page-artifact evidence" in migration
