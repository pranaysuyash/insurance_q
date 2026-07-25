"""Static contract for private, owner-scoped Supabase Storage access.

The API currently writes source documents with the service role, which bypasses
RLS. These policies are still a required defense-in-depth boundary for any
direct authenticated Storage operation. A deployed two-principal denial test
remains the Tier 3 acceptance gate.
"""

from pathlib import Path


MIGRATION = Path(__file__).parents[1] / (
    "supabase/migrations/20260721072000_storage_owner_policies.sql"
)
OBJECT_STORE = Path(__file__).parents[1] / "src/services/document_object_store.py"


def test_private_document_storage_has_owner_checked_crud_policies():
    sql = MIGRATION.read_text(encoding="utf-8").lower()

    for operation in ("select", "insert", "update", "delete"):
        assert f"create policy coverwise_documents_{operation}" in sql
        assert f"on storage.objects for {operation}" in sql

    assert sql.count("to authenticated") == 4
    assert sql.count("bucket_id = 'coverwise-documents'") == 5
    assert sql.count("d.owner_id = (select auth.uid())::text") == 5
    assert "with check" in sql


def test_storage_policy_matches_the_canonical_document_object_path():
    store_source = OBJECT_STORE.read_text(encoding="utf-8")
    policy_source = MIGRATION.read_text(encoding="utf-8")

    assert 'return f"documents/{document_id}/{_safe_filename(filename)}"' in store_source
    assert "(storage.foldername(name))[2]" in policy_source
    assert "d.id::text" in policy_source
