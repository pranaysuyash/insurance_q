#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
venv_python="$repo_root/.venv/bin/python"

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required; install it before running backend checks" >&2
  exit 1
fi

if [[ ! -x "$venv_python" ]]; then
  echo "Project venv is missing: $venv_python" >&2
  echo "Create it with: uv venv --python 3.11 $repo_root/.venv" >&2
  exit 1
fi

if [[ "$(uname -s)" == "Darwin" && -d /opt/homebrew/lib ]]; then
  native_library_path="/opt/homebrew/lib:/opt/homebrew/opt/glib/lib:/opt/homebrew/opt/pango/lib:/opt/homebrew/opt/cairo/lib:/opt/homebrew/opt/gdk-pixbuf/lib"
  export DYLD_FALLBACK_LIBRARY_PATH="${DYLD_FALLBACK_LIBRARY_PATH:-$native_library_path}"
fi

exec uv run --python "$venv_python" python -m pytest "$@"
