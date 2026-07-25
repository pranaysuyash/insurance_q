#!/usr/bin/env bash
# Generate a CycloneDX SBOM from the canonical Linux production dependency lock.
set -euo pipefail

repo_root=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
pip_audit_bin=${PIP_AUDIT_BIN:-"$repo_root/.venv/bin/pip-audit"}
lock_file="$repo_root/requirements-production-ocr-linux-x86_64.lock"

if [[ $# -ne 1 ]]; then
  echo "usage: $0 OUTPUT.json" >&2
  exit 2
fi

output_file=$1
if [[ -e "$output_file" ]]; then
  echo "refusing to overwrite existing output: $output_file" >&2
  exit 2
fi
if [[ ! -x "$pip_audit_bin" ]]; then
  echo "pip-audit is required; install requirements-local.txt into .venv first" >&2
  exit 2
fi
if [[ ! -f "$lock_file" ]]; then
  echo "missing canonical production lock: $lock_file" >&2
  exit 2
fi

output_dir=$(dirname "$output_file")
mkdir -p "$output_dir"
temp_file=$(mktemp "$output_dir/.production-sbom.XXXXXX")
trap 'rm -f "$temp_file"' EXIT

set +e
"$pip_audit_bin" -r "$lock_file" --require-hashes --disable-pip \
  --format cyclonedx-json --output "$temp_file"
audit_status=$?
set -e

"$repo_root/.venv/bin/python" -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    document = json.load(handle)
if document.get("bomFormat") != "CycloneDX" or not isinstance(document.get("components"), list):
    raise SystemExit("output is not a CycloneDX component inventory")
' "$temp_file"

mv "$temp_file" "$output_file"
trap - EXIT

if [[ $audit_status -ne 0 ]]; then
  echo "SBOM generated at $output_file; vulnerability findings remain and are not treated as a passing audit." >&2
else
  echo "SBOM generated at $output_file; locked-graph audit found no known vulnerabilities."
fi
