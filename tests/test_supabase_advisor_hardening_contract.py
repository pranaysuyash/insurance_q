from pathlib import Path


MIGRATION = Path(
    "supabase/migrations/20260721230000_supabase_advisor_hardening.sql"
)
FOLLOW_UP = Path(
    "supabase/migrations/20260721240000_supabase_advisor_followup.sql"
)
EXTENSION_MOVE = Path(
    "supabase/migrations/20260721250000_move_extensions_to_private_schema.sql"
)


def test_advisor_hardening_pins_server_function_search_paths():
    sql = MIGRATION.read_text(encoding="utf-8")
    for signature in (
        "public.claim_job_outbox(integer)",
        "public.reclaim_job_outbox(integer)",
        "public.consent_ledger_append_only()",
        "public.job_outbox_set_updated_at()",
        "public.match_document_chunks(vector, text, integer, double precision, uuid[], text, text)",
        "public.match_document_chunks_fts(text, text, integer, double precision, uuid[])",
    ):
        assert f"alter function {signature}" in sql
    assert sql.count("set search_path = public") == 6


def test_advisor_hardening_uses_initplan_safe_profile_policy():
    sql = FOLLOW_UP.read_text(encoding="utf-8")
    assert "using (user_uid = (select auth.uid())::text)" in sql
    assert "match_document_chunks(vector, text, integer, double precision)" in sql


def test_extension_move_preserves_typed_retrieval_search_path():
    sql = EXTENSION_MOVE.read_text(encoding="utf-8")
    assert "alter extension vector set schema extensions" in sql
    assert "alter extension pg_trgm set schema extensions" in sql
    assert sql.count("set search_path = extensions, public") == 3
    assert "extensions.vector" in sql
