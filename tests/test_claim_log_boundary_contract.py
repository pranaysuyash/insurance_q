from pathlib import Path


MIGRATION = Path(__file__).parents[1] / (
    "supabase/migrations/20260724010000_claim_log_boundary.sql"
)


def test_claim_log_migration_fences_new_agent_provenance_without_erasing_history():
    sql = MIGRATION.read_text(encoding="utf-8").lower()

    assert "claims_initiated_by_user_only" in sql
    assert "check (initiated_by = 'user') not valid" in sql
    assert "alter column initiated_by set default 'user'" in sql
    assert "status. it is not insurer confirmation" in sql
