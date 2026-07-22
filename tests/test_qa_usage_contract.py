from pathlib import Path


MIGRATION = Path("supabase/migrations/20260721180000_qa_usage_ledger.sql")


def test_q_and_a_ledger_contract_has_idempotent_usage_and_pack_grants():
    sql = MIGRATION.read_text()

    assert "create table if not exists public.qa_pack_grants" in sql
    assert "create table if not exists public.qa_usage_events" in sql
    assert "provider_event_id text not null unique" in sql
    assert "request_id uuid primary key" in sql
    assert "process_revenuecat_webhook" in sql
    assert "NON_RENEWING_PURCHASE" in sql
    assert "reserve_qa_question" in sql
    assert "pg_advisory_xact_lock(hashtextextended(p_owner_id, 0))" in sql
    assert "source = 'revenuecat_webhook'" in sql
    assert "request id belongs to another owner" in sql
    assert "qa_budget_exhausted" in sql
    assert "alter table public.qa_pack_grants enable row level security" in sql
    assert "alter table public.qa_usage_events enable row level security" in sql
    assert "grant select, insert, update on public.qa_pack_grants, public.qa_usage_events to service_role" in sql
    lifecycle = Path(
        "supabase/migrations/20260721190000_qa_usage_reservation_lifecycle.sql"
    ).read_text()
    assert "status in ('reserved', 'consumed', 'released')" in lifecycle
    assert "finalize_qa_question" in lifecycle
    assert "release_qa_question" in lifecycle
    assert "reserved_at" in lifecycle
    assert "15 minutes" in lifecycle
    assert "language plpgsql" in lifecycle
    assert "security invoker" in lifecycle
    assert "grant execute on function public.finalize_qa_question(text, uuid) to service_role" in lifecycle
    assert "grant execute on function public.release_qa_question(text, uuid) to service_role" in lifecycle
