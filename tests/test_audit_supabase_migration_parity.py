from pathlib import Path

from tools.audit_supabase_migration_parity import (
    CREATE_FUNCTION_RE,
    CREATE_EXTENSION_RE,
    extract_local_function_bodies,
    CREATE_INDEX_RE,
    CREATE_TRIGGER_RE,
    _extract_local_objects,
    _project_ref,
    extract_local_columns,
    extract_local_policies,
    extract_local_named_constraints,
    extract_local_check_constraint_definitions,
    extract_local_search_path_functions,
    extract_local_extension_schemas,
    extract_local_tables,
)


def test_extract_local_tables_reads_only_public_create_table_statements(tmp_path: Path):
    (tmp_path / "001_first.sql").write_text(
        "create table if not exists public.documents (id uuid);\n"
        "create table public.document_chunks (id uuid);\n"
        "create table private.internal (id uuid);\n",
        encoding="utf-8",
    )
    (tmp_path / "002_second.sql").write_text(
        "CREATE TABLE IF NOT EXISTS public.model_runs (id uuid);\n",
        encoding="utf-8",
    )

    assert extract_local_tables(tmp_path) == {
        "documents",
        "document_chunks",
        "model_runs",
    }


def test_project_ref_rejects_non_supabase_urls():
    assert _project_ref("https://eyumuxwabmsymytjbxoj.supabase.co") == "eyumuxwabmsymytjbxoj"


def test_extract_local_functions_indexes_and_triggers(tmp_path: Path):
    (tmp_path / "001_objects.sql").write_text(
        "create or replace function public.guard_write() returns trigger language plpgsql as $$ begin return new; end; $$;\n"
        "create unique index if not exists public.documents_owner_idx on public.documents(owner_id);\n"
        "create trigger guard_write_trg before update on public.documents for each row execute function public.guard_write();\n",
        encoding="utf-8",
    )

    assert _extract_local_objects(tmp_path, CREATE_FUNCTION_RE) == {"guard_write"}
    assert _extract_local_objects(tmp_path, CREATE_INDEX_RE) == {"documents_owner_idx"}
    assert _extract_local_objects(tmp_path, CREATE_TRIGGER_RE) == {"guard_write_trg"}


def test_extract_local_added_columns(tmp_path: Path):
    (tmp_path / "001_columns.sql").write_text(
        "alter table public.documents add column if not exists source_hash text;\n"
        "alter table public.documents add column processing_attempts integer;\n",
        encoding="utf-8",
    )

    assert extract_local_columns(tmp_path) == {
        ("documents", "source_hash"),
        ("documents", "processing_attempts"),
    }


def test_extract_local_policies_and_extensions(tmp_path: Path):
    (tmp_path / "001_security.sql").write_text(
        'create policy "Users read own profile" on public.profiles;\n'
        "create policy coverwise_documents_select on storage.objects;\n"
        "create extension if not exists vector;\n",
        encoding="utf-8",
    )

    assert extract_local_policies(tmp_path) == {
        "Users read own profile",
        "coverwise_documents_select",
    }
    assert _extract_local_objects(tmp_path, CREATE_EXTENSION_RE) == {"vector"}


def test_extract_local_named_constraints(tmp_path: Path):
    (tmp_path / "001_constraints.sql").write_text(
        "alter table public.document_chunks add constraint chunks_positive check (id is not null);\n"
        "alter table public.document_chunks drop constraint if exists old_constraint;\n",
        encoding="utf-8",
    )

    assert extract_local_named_constraints(tmp_path) == {"chunks_positive"}


def test_extract_latest_check_constraint_definition(tmp_path: Path):
    (tmp_path / "001_constraints.sql").write_text(
        "alter table public.consent_ledger add constraint consent_type_check "
        "check (consent_type in ('privacy_policy')) not valid;\n",
        encoding="utf-8",
    )
    (tmp_path / "002_constraints.sql").write_text(
        "alter table public.consent_ledger add constraint consent_type_check "
        "check (consent_type in ('privacy_policy', 'analytics')) not valid;\n",
        encoding="utf-8",
    )

    assert extract_local_check_constraint_definitions(tmp_path) == {
        "consent_type_check": "check(consent_type in('privacy_policy','analytics'))"
    }


def test_extract_local_search_path_functions(tmp_path: Path):
    (tmp_path / "001_hardening.sql").write_text(
        "alter function public.claim_job_outbox(integer) set search_path = public;\n"
        "alter function public.match_document_chunks(vector, text, integer, double precision) set search_path = public;\n"
        "alter function public.match_document_chunks(vector, text, integer, double precision) set search_path = extensions, public;\n",
        encoding="utf-8",
    )

    assert extract_local_search_path_functions(tmp_path) == {
        ("claim_job_outbox", "integer", "public"),
        (
            "match_document_chunks",
            "vector, text, integer, double precision",
            "extensions,public",
        ),
    }


def test_extract_latest_extension_schemas(tmp_path: Path):
    (tmp_path / "001_extensions.sql").write_text(
        "create extension if not exists vector;\n"
        "create extension if not exists pg_trgm;\n"
        "alter extension vector set schema extensions;\n",
        encoding="utf-8",
    )

    assert extract_local_extension_schemas(tmp_path) == {
        "vector": "extensions",
    }


def test_extract_latest_function_body(tmp_path: Path):
    (tmp_path / "001_function.sql").write_text(
        "create or replace function public.guard_write() returns trigger "
        "language plpgsql as $$ begin return new; end; $$;\n",
        encoding="utf-8",
    )
    (tmp_path / "002_function.sql").write_text(
        "create or replace function public.guard_write() returns trigger "
        "language plpgsql as $$ begin raise exception 'blocked'; end; $$;\n",
        encoding="utf-8",
    )

    assert extract_local_function_bodies(tmp_path) == {
        "guard_write": " begin raise exception 'blocked'; end; "
    }
