from pathlib import Path


def test_account_deletion_retry_index_preserves_history_and_allows_active_retry():
    sql = Path(
        "supabase/migrations/20260721210000_account_deletion_retry_index.sql"
    ).read_text()

    assert "drop index if exists public.job_outbox_account_deletion_request_idx" in sql
    assert "status in ('pending', 'running')" in sql
    assert "job_type = 'account_deletion'" in sql
