from pathlib import Path


MIGRATION = Path(__file__).parents[1] / (
    "supabase/migrations/20260721150000_account_deletion_write_fence.sql"
)


def test_account_deletion_fences_document_inserts_and_owner_transfers():
    sql = MIGRATION.read_text().lower()

    assert "create or replace function public.reject_active_account_deletion_write()" in sql
    assert "adr.status in ('pending', 'running')" in sql
    assert "before insert or update of owner_id on public.documents" in sql
    assert "using errcode = 'check_violation'" in sql
