#!/usr/bin/env bash
#
# check_apk_size.sh — CI gate that enforces the release APK size budget.
#
# Usage:
#   check_apk_size.sh [budget_mb]
#
# Default budget is 60 MB. Run after `flutter build apk --release`.
# Exits 0 if APK is within budget, 1 otherwise.
#
set -euo pipefail

budget_mb="${1:-60}"
budget_bytes=$(( budget_mb * 1024 * 1024 ))

apk_path="build/app/outputs/flutter-apk/app-release.apk"

if [ ! -f "$apk_path" ]; then
  echo "ERROR: APK not found at $apk_path"
  echo "Run 'flutter build apk --release' first."
  exit 1
fi

apk_size=$(stat -f%z "$apk_path" 2>/dev/null || stat --format=%s "$apk_path" 2>/dev/null)
apk_size_mb=$(echo "scale=1; $apk_size / 1048576" | bc)

echo "APK size: ${apk_size_mb} MB (budget: ${budget_mb} MB)"

if [ "$apk_size" -gt "$budget_bytes" ]; then
  echo "FAIL: APK exceeds budget. Run 'flutter build apk --analyze-size' to inspect."
  exit 1
fi

echo "PASS"
