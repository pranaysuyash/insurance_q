"""Read-only audit of repository Supabase objects against a live project.

This intentionally uses the Supabase Management API's read-only SQL endpoint.
It never applies SQL, uses an application secret as a management credential, or
prints credentials. The audit exists because a remote database can contain the
right tables while its migration ledger no longer describes how it got there.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


CREATE_TABLE_RE = re.compile(
    r"create\s+table(?:\s+if\s+not\s+exists)?\s+public\.([a-zA-Z0-9_]+)",
    re.IGNORECASE,
)
CREATE_FUNCTION_RE = re.compile(
    r"create\s+or\s+replace\s+function\s+public\.([a-zA-Z0-9_]+)",
    re.IGNORECASE,
)
CREATE_INDEX_RE = re.compile(
    r"create\s+(?:unique\s+)?index(?:\s+if\s+not\s+exists)?\s+"
    r"(?:public\.)?([a-zA-Z0-9_]+)",
    re.IGNORECASE,
)
CREATE_TRIGGER_RE = re.compile(
    r"create\s+trigger\s+([a-zA-Z0-9_]+)",
    re.IGNORECASE,
)
ADD_COLUMN_RE = re.compile(
    r"alter\s+table\s+public\.([a-zA-Z0-9_]+)\s+"
    r"add\s+column(?:\s+if\s+not\s+exists)?\s+([a-zA-Z0-9_]+)",
    re.IGNORECASE,
)
CREATE_POLICY_RE = re.compile(
    r"create\s+policy\s+(?:if\s+not\s+exists\s+)?"
    r"(?:\"([^\"]+)\"|([a-zA-Z0-9_]+))",
    re.IGNORECASE,
)
CREATE_EXTENSION_RE = re.compile(
    r"create\s+extension\s+if\s+not\s+exists\s+([a-zA-Z0-9_]+)",
    re.IGNORECASE,
)
ALTER_EXTENSION_SCHEMA_RE = re.compile(
    r"alter\s+extension\s+([a-zA-Z0-9_]+)\s+set\s+schema\s+([a-zA-Z0-9_]+)",
    re.IGNORECASE,
)
ADD_CONSTRAINT_RE = re.compile(
    r"alter\s+table\s+public\.[a-zA-Z0-9_]+\s+"
    r"add\s+constraint\s+([a-zA-Z0-9_]+)",
    re.IGNORECASE,
)
ADD_CHECK_CONSTRAINT_RE = re.compile(
    r"alter\s+table\s+public\.([a-zA-Z0-9_]+)\s+"
    r"add\s+constraint\s+([a-zA-Z0-9_]+)\s+"
    r"(check\s*\(.*?\))(?:\s+not\s+valid)?\s*;",
    re.IGNORECASE | re.DOTALL,
)
ALTER_FUNCTION_SEARCH_PATH_RE = re.compile(
    r"alter\s+function\s+public\.([a-zA-Z0-9_]+)\(([^)]*)\)\s+"
    r"set\s+search_path\s*=\s*([a-zA-Z0-9_,\s]+)",
    re.IGNORECASE,
)
FUNCTION_BODY_RE = re.compile(
    r"create\s+or\s+replace\s+function\s+public\.([a-zA-Z0-9_]+)"
    r".*?\bas\s*(\$[A-Za-z0-9_]*\$)(.*?)\2\s*;",
    re.IGNORECASE | re.DOTALL,
)
SQL_COMMENT_RE = re.compile(r"--[^\n]*|/\*.*?\*/", re.DOTALL)

FUNCTIONS = (
    "finalize_policy_upload_slot",
    "finalize_qa_question",
    "release_policy_upload_slot",
    "release_qa_question",
    "reserve_policy_upload_slot",
    "reserve_qa_question",
)


def _migration_sql(path: Path) -> str:
    return SQL_COMMENT_RE.sub("", path.read_text(encoding="utf-8"))


def extract_local_tables(migrations_dir: Path) -> set[str]:
    tables: set[str] = set()
    for migration in sorted(migrations_dir.glob("*.sql")):
        tables.update(CREATE_TABLE_RE.findall(_migration_sql(migration)))
    return tables


def _extract_local_objects(migrations_dir: Path, pattern: re.Pattern[str]) -> set[str]:
    objects: set[str] = set()
    for migration in sorted(migrations_dir.glob("*.sql")):
        objects.update(pattern.findall(_migration_sql(migration)))
    return objects


def extract_local_columns(migrations_dir: Path) -> set[tuple[str, str]]:
    columns: set[tuple[str, str]] = set()
    for migration in sorted(migrations_dir.glob("*.sql")):
        columns.update(ADD_COLUMN_RE.findall(_migration_sql(migration)))
    return columns


def extract_local_policies(migrations_dir: Path) -> set[str]:
    policies: set[str] = set()
    for migration in sorted(migrations_dir.glob("*.sql")):
        for quoted, bare in CREATE_POLICY_RE.findall(_migration_sql(migration)):
            policies.add(quoted or bare)
    return policies


def extract_local_named_constraints(migrations_dir: Path) -> set[str]:
    """Return constraints explicitly named in ALTER TABLE ADD CONSTRAINT."""
    return _extract_local_objects(migrations_dir, ADD_CONSTRAINT_RE)


def extract_local_check_constraint_definitions(
    migrations_dir: Path,
) -> dict[str, str]:
    """Return the latest declared CHECK definition for each named constraint."""
    definitions: dict[str, str] = {}
    for migration in sorted(migrations_dir.glob("*.sql")):
        for _table, name, definition in ADD_CHECK_CONSTRAINT_RE.findall(
            _migration_sql(migration)
        ):
            definitions[name] = _canonical_constraint_definition(definition)
    return definitions


def extract_local_search_path_functions(
    migrations_dir: Path,
) -> set[tuple[str, str, str]]:
    """Return the latest search-path setting for each altered function."""
    functions: dict[tuple[str, str], str] = {}
    for migration in sorted(migrations_dir.glob("*.sql")):
        for name, args, search_path in ALTER_FUNCTION_SEARCH_PATH_RE.findall(
            _migration_sql(migration)
        ):
            key = (name, _normalize_identity_args(args))
            functions[key] = _normalize_search_path(search_path)
    return {(name, args, search_path) for (name, args), search_path in functions.items()}


def extract_local_extension_schemas(migrations_dir: Path) -> dict[str, str]:
    """Return the latest explicit schema declaration for each extension.

    CREATE EXTENSION without a schema is environment-dependent in Supabase:
    some extensions are preinstalled in the platform ``extensions`` schema.
    Only an explicit ALTER EXTENSION ... SET SCHEMA is therefore treated as a
    repository-owned placement contract.
    """
    schemas: dict[str, str] = {}
    for migration in sorted(migrations_dir.glob("*.sql")):
        sql = _migration_sql(migration)
        for name, schema in ALTER_EXTENSION_SCHEMA_RE.findall(sql):
            schemas[name] = schema.lower()
    return schemas


def _normalize_identity_args(value: str, *, named: bool = False) -> str:
    """Normalize type-only ALTER signatures against PostgreSQL's named args."""
    normalized: list[str] = []
    for argument in value.split(","):
        tokens = argument.strip().split()
        # pg_get_function_identity_arguments includes parameter names while
        # ALTER FUNCTION signatures use types only. The migration extractor
        # has the inverse shape. Current contracts use scalar/array types with
        # no comma-bearing type expressions.
        if named and len(tokens) >= 2:
            tokens = tokens[1:]
        normalized.append(" ".join(tokens))
    return ", ".join(normalized).lower().replace("extensions.vector", "vector")


def _normalize_search_path(value: str) -> str:
    return re.sub(r"\s+", "", value).strip().lower().rstrip(";")


def extract_local_function_bodies(migrations_dir: Path) -> dict[str, str]:
    """Return the latest migration-defined function body for each function."""
    bodies: dict[str, str] = {}
    for migration in sorted(migrations_dir.glob("*.sql")):
        for name, _dollar_tag, body in FUNCTION_BODY_RE.findall(_migration_sql(migration)):
            bodies[name] = body
    return bodies


def _normalize_sql_body(value: str) -> str:
    return re.sub(r"\s+", " ", SQL_COMMENT_RE.sub("", value)).strip().lower()


def _canonical_constraint_definition(value: str) -> str:
    """Normalize equivalent PostgreSQL CHECK renderings for comparison."""

    normalized = _normalize_sql_body(value)
    normalized = re.sub(r"check\s*\(\((.*?)\)\)", r"check (\1)", normalized)

    def _any_to_in(match: re.Match[str]) -> str:
        values = re.sub(r"::[a-z_][a-z0-9_ ]*", "", match.group(2))
        return f"{match.group(1)} in ({values})"

    normalized = re.sub(
        r"([a-z_][a-z0-9_]*)\s*=\s*any\s*\(\s*array\[(.*?)\]\s*\)",
        _any_to_in,
        normalized,
    )
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return re.sub(r"\s*([(),])\s*", r"\1", normalized)


def _project_ref(supabase_url: str) -> str:
    hostname = urllib.parse.urlparse(supabase_url).hostname or ""
    ref = hostname.split(".", 1)[0]
    if not ref or ref == hostname:
        raise ValueError("SUPABASE_URL must be a Supabase project URL")
    return ref


def _query(endpoint: str, token: str, query: str) -> list[dict[str, Any]]:
    request = urllib.request.Request(
        endpoint,
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "coverwise-read-only-migration-audit/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"management_api_http_{error.code}") from error
    if not isinstance(payload, list) or not all(isinstance(row, dict) for row in payload):
        raise RuntimeError("management_api_returned_unexpected_shape")
    return payload


def build_report(*, migrations_dir: Path, supabase_url: str, management_token: str) -> dict[str, Any]:
    ref = _project_ref(supabase_url)
    endpoint = f"https://api.supabase.com/v1/projects/{ref}/database/query/read-only"
    local_tables = extract_local_tables(migrations_dir)
    local_functions = _extract_local_objects(migrations_dir, CREATE_FUNCTION_RE)
    local_function_bodies = extract_local_function_bodies(migrations_dir)
    local_indexes = _extract_local_objects(migrations_dir, CREATE_INDEX_RE)
    local_triggers = _extract_local_objects(migrations_dir, CREATE_TRIGGER_RE)
    local_columns = extract_local_columns(migrations_dir)
    local_policies = extract_local_policies(migrations_dir)
    local_extension_schemas = extract_local_extension_schemas(migrations_dir)
    local_extensions = set(local_extension_schemas)
    local_search_path_functions = extract_local_search_path_functions(migrations_dir)
    remote_table_rows = _query(
        endpoint,
        management_token,
        "select table_name from information_schema.tables "
        "where table_schema='public' and table_type='BASE TABLE' order by table_name",
    )
    remote_tables = {str(row["table_name"]) for row in remote_table_rows}
    history = _query(
        endpoint,
        management_token,
        "select version,name from supabase_migrations.schema_migrations order by version",
    )
    # pg_proc is used instead of information_schema.routines because Supabase
    # may hide security-sensitive routine metadata from the management query
    # role even when the callable function exists.
    function_rows = _query(
        endpoint,
        management_token,
        "select p.proname, pg_get_function_identity_arguments(p.oid) as identity_args, "
        "p.proconfig, pg_get_functiondef(p.oid) as definition from pg_proc p "
        "join pg_namespace n on n.oid=p.pronamespace "
        "where n.nspname='public' and p.prokind='f' order by p.proname",
    )
    remote_functions = {str(row["proname"]) for row in function_rows}
    remote_function_bodies: dict[str, list[str]] = {}
    remote_search_path_functions: set[tuple[str, str, str]] = set()
    for row in function_rows:
        identity_args = _normalize_identity_args(
            str(row.get("identity_args", "")), named=True
        )
        proconfig = row.get("proconfig") or []
        if isinstance(proconfig, list):
            for setting in proconfig:
                setting_text = str(setting)
                if setting_text.lower().startswith("search_path="):
                    remote_search_path_functions.add(
                        (
                            str(row["proname"]),
                            identity_args,
                            _normalize_search_path(setting_text.split("=", 1)[1]),
                        )
                    )
                    break
        definition = str(row.get("definition", ""))
        match = re.search(
            r"\bas\s*(\$[A-Za-z0-9_]*\$)(.*?)\1\s*$",
            definition,
            re.IGNORECASE | re.DOTALL,
        )
        if match:
            remote_function_bodies.setdefault(str(row["proname"]), []).append(match.group(2))
    index_rows = _query(
        endpoint,
        management_token,
        "select indexname from pg_indexes where schemaname='public'",
    )
    remote_indexes = {str(row["indexname"]) for row in index_rows}
    trigger_rows = _query(
        endpoint,
        management_token,
        "select t.tgname from pg_trigger t "
        "join pg_class c on c.oid=t.tgrelid "
        "join pg_namespace n on n.oid=c.relnamespace "
        "where n.nspname='public' and not t.tgisinternal",
    )
    remote_triggers = {str(row["tgname"]) for row in trigger_rows}
    column_rows = _query(
        endpoint,
        management_token,
        "select table_name,column_name from information_schema.columns "
        "where table_schema='public'",
    )
    remote_columns = {
        (str(row["table_name"]), str(row["column_name"])) for row in column_rows
    }
    policy_rows = _query(
        endpoint,
        management_token,
        "select distinct policyname from pg_policies",
    )
    remote_policies = {str(row["policyname"]) for row in policy_rows}
    extension_rows = _query(
        endpoint,
        management_token,
        "select extname, extnamespace::regnamespace::text as schema_name "
        "from pg_extension",
    )
    remote_extensions = {str(row["extname"]) for row in extension_rows}
    remote_extension_schemas = {
        str(row["extname"]): str(row["schema_name"])
        for row in extension_rows
    }
    constraint_rows = _query(
        endpoint,
        management_token,
        "select conname, pg_get_constraintdef(c.oid) as definition from pg_constraint c "
        "join pg_namespace n on n.oid=c.connamespace "
        "where n.nspname='public'",
    )
    remote_constraints = {str(row["conname"]) for row in constraint_rows}
    remote_constraint_definitions = {
        str(row["conname"]): _canonical_constraint_definition(str(row["definition"]))
        for row in constraint_rows
        if row.get("definition") is not None
    }
    local_constraints = extract_local_named_constraints(migrations_dir)
    local_check_constraint_definitions = extract_local_check_constraint_definitions(
        migrations_dir
    )
    local_versions = {migration.name.split("_", 1)[0] for migration in migrations_dir.glob("*.sql")}
    history_versions = {str(row.get("version", "")) for row in history}
    return {
        "project_ref": ref,
        "local_migration_file_count": len(list(migrations_dir.glob("*.sql"))),
        "local_table_count": len(local_tables),
        "remote_table_count": len(remote_tables),
        "local_tables_missing_remotely": sorted(local_tables - remote_tables),
        "remote_tables_not_declared_locally": sorted(remote_tables - local_tables),
        "required_rpc_functions": list(FUNCTIONS),
        "required_rpc_functions_missing": sorted(set(FUNCTIONS) - remote_functions),
        "local_functions_missing_remotely": sorted(local_functions - remote_functions),
        "local_function_definitions_mismatched": sorted(
            name
            for name, body in local_function_bodies.items()
            if name in remote_function_bodies
            and not any(
                _normalize_sql_body(body) == _normalize_sql_body(remote_body)
                for remote_body in remote_function_bodies[name]
            )
        ),
        "local_indexes_missing_remotely": sorted(local_indexes - remote_indexes),
        "local_triggers_missing_remotely": sorted(local_triggers - remote_triggers),
        "local_columns_missing_remotely": [
            {"table": table, "column": column}
            for table, column in sorted(local_columns - remote_columns)
        ],
        "local_policies_missing_remotely": sorted(local_policies - remote_policies),
        "local_extensions_missing_remotely": sorted(local_extensions - remote_extensions),
        "local_extension_schemas_mismatched": [
            {"extension": name, "local": schema, "remote": remote_extension_schemas.get(name)}
            for name, schema in sorted(local_extension_schemas.items())
            if remote_extension_schemas.get(name) != schema
        ],
        "local_named_constraints_missing_remotely": sorted(
            local_constraints - remote_constraints
        ),
        "local_constraint_definitions_mismatched": [
            {
                "constraint": name,
                "local": definition,
                "remote": remote_constraint_definitions.get(name),
            }
            for name, definition in sorted(local_check_constraint_definitions.items())
            if remote_constraint_definitions.get(name) != definition
        ],
        "local_search_path_functions_missing_or_mismatched": [
            {"name": name, "identity_args": args, "search_path": search_path}
            for name, args, search_path in sorted(
                local_search_path_functions - remote_search_path_functions
            )
        ],
        "migration_history_count": len(history),
        "migration_history": history,
        "migration_history_versions_not_in_repository": sorted(history_versions - local_versions),
        "migration_history_parity_warning": bool(
            len(history) != len(list(migrations_dir.glob("*.sql")))
            or history_versions - local_versions
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--migrations-dir", type=Path, default=Path("supabase/migrations"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    url = os.environ.get("SUPABASE_URL", "").strip()
    token = (
        os.environ.get("SUPABASE_EXPERIMENTAL_API_KEY", "").strip()
        or os.environ.get("SUPABASE_MANAGEMENT_API_TOKEN", "").strip()
    )
    if not url or not token:
        raise SystemExit("SUPABASE_URL and SUPABASE_EXPERIMENTAL_API_KEY are required")
    report = build_report(
        migrations_dir=args.migrations_dir,
        supabase_url=url,
        management_token=token,
    )
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    missing_keys = (
        "local_tables_missing_remotely",
        "local_functions_missing_remotely",
        "local_function_definitions_mismatched",
        "local_indexes_missing_remotely",
        "local_triggers_missing_remotely",
        "local_columns_missing_remotely",
        "local_policies_missing_remotely",
        "local_extensions_missing_remotely",
        "local_extension_schemas_mismatched",
        "local_named_constraints_missing_remotely",
        "local_constraint_definitions_mismatched",
        "local_search_path_functions_missing_or_mismatched",
    )
    return 0 if not any(report[key] for key in missing_keys) else 2


if __name__ == "__main__":
    raise SystemExit(main())
