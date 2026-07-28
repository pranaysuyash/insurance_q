#!/usr/bin/env bash
# ─── Run the CoverWise Flutter app on the iOS Simulator ─────────────────
#
# Usage:
#   tools/run_ios_simulator.sh                    # build + launch
#   tools/run_ios_simulator.sh --no-build          # launch only (skip flutter build)
#   tools/run_ios_simulator.sh --api-url http://host:port  # override API endpoint
#
# Requires:
#   - Xcode 15+ with iOS Simulator runtime installed
#   - Flutter SDK (stable) on PATH
#   - CocoaPods (pod install must have been run at least once)
#   - .env file at project root (for Supabase keys)

set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "$0")/..")"

# ── Prerequisites ─────────────────────────────────────────────────────────
xcode-select -p &>/dev/null || {
  echo "❌  Xcode not found. Install Xcode from the Mac App Store first."
  exit 1
}

if ! command -v flutter &>/dev/null; then
  echo "❌  Flutter SDK not found. Ensure 'flutter' is on your PATH."
  exit 1
fi

if [[ ! -f mobile/ios/Podfile.lock ]]; then
  echo "⚠️   Missing Podfile.lock — running pod install for the first time..."
  (cd mobile && flutter pub get && cd ios && pod install --repo-update) || {
    echo "❌  CocoaPods setup failed. Run manually: cd mobile/ios && pod install"
    exit 1
  }
fi

# ── Parse args ───────────────────────────────────────────────────────────
SKIP_BUILD=false
API_URL="http://127.0.0.1:8000"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)  SKIP_BUILD=true; shift ;;
    --api-url)   API_URL="$2"; shift 2 ;;
    *)           echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# ── Load env (for -dart-define values) ────────────────────────────────────
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

# ── Detect or boot simulator device ──────────────────────────────────────
BOOTED=$(xcrun simctl list devices available 2>/dev/null \
  | grep -E 'Booted' | head -1 || true)

if [[ -z "$BOOTED" ]]; then
  # Find the newest available iPhone simulator
  SIM=$(xcrun simctl list devices available 2>/dev/null \
    | grep -E 'iPhone [0-9]+' | grep -v -E 'Se|Plus|Mini' \
    | sort -t'(' -k2 -r | head -1 \
    | sed 's/.*(\([A-Z0-9-]*\)).*/\1/' || true)

  if [[ -z "$SIM" ]]; then
    echo "❌  No available iPhone simulator found."
    echo "   Create one: xcrun simctl create <name> 'iPhone 16' '$(xcrun simctl list runtimes 2>/dev/null | grep -E 'iOS' | tail -1 | sed 's/.* - //')'"
    exit 1
  fi

  echo "📱  Booting simulator: $SIM"
  xcrun simctl boot "$SIM"
  sleep 2

  # Poll until booted (up to ~20 seconds)
  for i in {1..10}; do
    STATE=$(xcrun simctl list devices 2>/dev/null \
      | grep "$SIM" | grep -o '(Booted)' || true)
    if [[ -n "$STATE" ]]; then
      echo "   Simulator booted (${i}s)"
      break
    fi
    sleep 2
  done

  BOOTED_ID="$SIM"
else
  BOOTED_ID=$(echo "$BOOTED" | sed 's/.*(\([A-Z0-9-]*\)).*/\1/')
  echo "📱  Using already-booted simulator: $BOOTED_ID"
fi

# Open Simulator.app so the window is visible
open -a Simulator 2>/dev/null || true

# ── Build (optional) ────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
  echo "🔨  Building Flutter app for iOS simulator..."

  # Collect dart-defines from .env
  DART_DEFINES=()
  for var in SUPABASE_URL SUPABASE_PUBLISHABLE_KEY; do
    val="${!var:-}"
    if [[ -n "$val" ]]; then
      DART_DEFINES+=(--dart-define="$var=$val")
    fi
  done
  DART_DEFINES+=(--dart-define=COVERWISE_API_URL="$API_URL")

  (cd mobile && flutter build ios --debug --no-codesign "${DART_DEFINES[@]}" 2>&1 \
    | tail -5) || {
    echo ""
    echo "⚠️   Build had warnings. Check above for details."
  }
  echo "✅  Build complete"
fi

# ── Install & launch ─────────────────────────────────────────────────────
echo "🚀  Installing app on simulator..."
cd mobile
flutter install 2>&1 | tail -3

echo "📱  Launching CoverWise..."
flutter run -d "$BOOTED_ID" &
FLUTTER_PID=$!

echo ""
echo "──────────────────────────────────────────────"
echo "  CoverWise running on iOS simulator"
echo "  API: $API_URL"
echo "  PID: $FLUTTER_PID"
echo "  Stop: kill $FLUTTER_PID"
echo "──────────────────────────────────────────────"
echo ""
echo "Test protocol: docs/planning/product/ground_truth_testing_protocol.md"
