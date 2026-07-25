#!/usr/bin/env bash
# Run the reproducible local dependency and release-source secret checks.
set -euo pipefail

repo_root=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
pip_audit_bin=${PIP_AUDIT_BIN:-"$repo_root/.venv/bin/pip-audit"}

if [[ ! -x "$pip_audit_bin" ]]; then
  echo "pip-audit is required; install requirements-local.txt into .venv first" >&2
  exit 2
fi

cd "$repo_root"

# Production requirements are exact pins. --no-deps therefore audits the
# declared release graph directly without requiring pip-audit to create a
# second virtual environment (which is incompatible with some uv Python builds).
"$pip_audit_bin" -r requirements.txt --disable-pip --no-deps
"$repo_root/tools/run_tracked_source_secret_scan.sh"

echo "supply-chain audit passed."
