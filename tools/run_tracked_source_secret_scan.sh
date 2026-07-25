#!/usr/bin/env bash
# Scan release-relevant tracked and untracked source without traversing ignored
# local secrets, generated artifacts, documentation examples, or vendor tests.
set -euo pipefail

repo_root=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
gitleaks_bin=${GITLEAKS_BIN:-gitleaks}
command -v "$gitleaks_bin" >/dev/null 2>&1 || {
  echo "gitleaks is required; install it before running the tracked-source secret scan" >&2
  exit 2
}

scan_root=$(mktemp -d)
trap 'rm -rf "$scan_root"' EXIT

cd "$repo_root"

# `git ls-files` includes source currently under review while respecting
# .gitignore, so local .env files and Flutter/Pods build products cannot
# influence release evidence. Documentation and test fixtures frequently carry
# intentionally fake keys; they are audited separately from shippable source.
git ls-files -z --cached --others --exclude-standard -- \
  ':!docs/**' \
  ':!mobile/test/**' \
  ':!tests/**' \
  ':!mobile/ios/Podfile.lock' \
  ':!.env.example' \
  | while IFS= read -r -d '' source_path; do
      # Deleted index entries are useful to git but cannot be scanned from the
      # current working tree. Keep only regular files that will ship.
      [[ -f "$source_path" ]] && printf '%s\0' "$source_path"
    done \
  | tar --null --files-from=- -cf - \
  | tar -xf - -C "$scan_root"

"$gitleaks_bin" detect \
  --source "$scan_root" \
  --no-git \
  --redact \
  --no-banner

echo "tracked release-source secret scan passed."
