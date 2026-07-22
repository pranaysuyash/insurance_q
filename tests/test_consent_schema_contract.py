"""Static contract checks for the additive consent vocabulary migration."""

from pathlib import Path


MIGRATION = Path(__file__).parents[1] / "supabase/migrations/20260721130000_document_processing_consent.sql"


def test_document_processing_consent_is_added_without_rewriting_history():
    sql = MIGRATION.read_text().lower()

    assert "drop constraint if exists consent_ledger_consent_type_check" in sql
    assert "add constraint consent_ledger_consent_type_check" in sql
    assert "'document_processing'" in sql
    assert "'privacy_policy'" in sql
    assert "'analytics'" in sql


def test_secondary_use_consent_purposes_are_explicitly_versioned():
    sql = Path(
        Path(__file__).parents[1]
        / "supabase/migrations/20260721260000_dataset_consent_purposes.sql"
    ).read_text().lower()

    assert "'evaluation_dataset'" in sql
    assert "'model_improvement'" in sql
    assert "drop constraint if exists consent_ledger_consent_type_check" in sql
