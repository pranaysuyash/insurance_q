from pathlib import Path


MIGRATION = Path(
    "supabase/migrations/20260721170000_policy_slot_reservations.sql"
)


def test_policy_slot_migration_has_owner_locked_reservation_contract():
    sql = MIGRATION.read_text()

    assert "create table if not exists public.policy_slot_reservations" in sql
    assert "pg_advisory_xact_lock(hashtextextended(p_owner_id, 0))" in sql
    assert "reserve_policy_upload_slot" in sql
    assert "finalize_policy_upload_slot" in sql
    assert "release_policy_upload_slot" in sql
    assert "source = 'revenuecat_webhook'" in sql
    assert "active_documents + active_reservations >= max_policies" in sql
    assert "interval '30 minutes'" in sql
    assert "'upload_in_progress'" in sql
    assert "only one request may own the" in sql
