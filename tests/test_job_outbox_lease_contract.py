"""Static contract checks for durable outbox lease fencing."""

from pathlib import Path


MIGRATION = Path(__file__).parents[1] / "supabase/migrations/20260721140000_job_outbox_lease_fencing.sql"


def test_claim_replaces_lease_token_and_reclaim_rotates_it():
    sql = MIGRATION.read_text().lower()

    assert "add column if not exists lease_token uuid" in sql
    assert "alter column lease_token set not null" in sql
    assert sql.count("lease_token = gen_random_uuid()") >= 2
    assert "create or replace function public.claim_job_outbox" in sql
    assert "create or replace function public.reclaim_job_outbox" in sql


def test_claim_migration_keeps_database_owned_atomic_selection():
    sql = MIGRATION.read_text().lower()

    assert "for update skip locked" in sql
    assert "where status = 'pending'" in sql
    assert "returning j.*" in sql
