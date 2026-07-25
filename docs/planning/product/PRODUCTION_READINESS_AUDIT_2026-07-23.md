# Production Readiness & Resilience Audit — 2026-07-23

## Scope

Audit of the CoverWise mobile app's resilience layer: how the app behaves when things go wrong. A solo-founder app must degrade gracefully without paging the founder at 2am. Every gap below has a clear owner (the app code, not the founder) and a recovery path the user can follow.

---

## Rating Summary

| Area | Score | Verdict |
|------|-------|---------|
| Offline retry queue (uploads) | 🟢 8/10 | Works. One gap: no user-visible status of queued items |
| Connectivity monitoring | 🟡 6/10 | Monitored internally but **NOT surfaced in UI** |
| Emergency screen offline caching | 🟢 9/10 | Hive-backed, offline-first. Minor: no loading state during background refresh |
| Backend health detection | 🔴 2/10 | **No startup health check.** App hangs on splash until timeout |
| Crash reporting | 🔴 0/10 | **No crash reporter wired.** runZonedGuarded logs to debugPrint only |
| Error surface handling | 🟢 8/10 | AppError.userMessage is thorough. Some screens bypass it with raw SnackBars |
| Auth resilience | 🟡 5/10 | Token expiry handled. No email-verification reminder on startup |
| **Composite score** | **🟡 5.0/10** | Notable: 6 audits, 3 green ≥8, 2 red ≤2 |

---

## P0 — Must fix before launch

### P0-01: No crash reporting SDK (Severity: CRITICAL)

**Current state:** `runZonedGuarded` catches zone errors and logs to `debugPrint` (release mode disables `debugPrint`). `GlobalErrorBoundary._trackError()` sends `error_type` + `error_code` to `AnalyticsService.track()`, which requires analytics consent and buffers in Hive — but it's a single custom implementation, not a production crash reporter. There's **no Sentry, Crashlytics, or Firebase Analytics** wired.

**Why it matters:** A solo founder cannot watch the Firebase/App Store console 24/7. Without a crash reporter, every crash is invisible until a user emails support — by which time they've likely uninstalled.

**Fix:** Add `sentry_flutter` (or `firebase_crashlytics`) and wire it into `main()`:

```dart
// In main(), before runApp():
await SentryFlutter.init(
  (options) {
    options.dsn = AppConfig.sentryDsn;
    options.environment = AppConfig.environment;
    options.tracesSampleRate = 0.2;
  },
  appRunner: () => runApp(...),
);
```

**Files to modify:**
- `mobile/lib/main.dart` — add Sentry init before `runApp()`
- `mobile/lib/config/app_config.dart` — add `sentryDsn` from environment
- `mobile/pubspec.yaml` — add `sentry_flutter` dependency

**Effort:** Small (30 min with pubspec + init + DSN env var). `sentry_flutter` handles both native (Dart/iOS/Android) and Flutter errors, eliminating the need for custom `runZonedGuarded` + `GlobalErrorBoundary._trackError()` for crash monitoring.

**Acceptance:** A deliberate `throw Exception('test')` in a Flutter test appears in Sentry dashboard within 5 minutes (non-production env).

---

### P0-02: No backend health check on startup (Severity: HIGH)

**Current state:** `main()` initializes Hive, Supabase, PrincipalKeyService, analytics, then calls `_warmAnonymousSession()` (which hits the backend `POST /user/anonymous`) — but this is unawaited and fire-and-forget. The splash screen auto-dismisses after `~1100ms` regardless of backend reachability. If the backend is down, the user sees the splash → onboarding → dashboard → all features fail with generic errors.

**Why it matters:** The first user experience after a deploy failure is a broken app with no explanation. Users don't try again — they uninstall.

**Fix:** Add a backend health probe during splash:

```dart
// In SplashScreen, before calling onComplete:
Future<bool> _checkBackendHealth() async {
  try {
    final response = await Dio().get(
      AppConfig.healthEndpoint,
      options: Options(connectTimeout: const Duration(seconds: 5)),
    );
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}
```

If health check fails:
- **Show a "Service temporarily unavailable" banner** (not a full error screen — the app still works offline for viewing cached documents)
- **Do NOT block splash** — let the user through with a banner at the top
- **Retry health check every 30 seconds** in the background; dismiss banner on success

**Files to modify:**
- `mobile/lib/screens/splash_screen.dart` — add health probe
- `mobile/lib/widgets/shared/coverwise_components.dart` — add `ConnectivityBanner` widget (shared with P0-03)

**Effort:** Medium (1 hour — health probe + banner + retry logic + existing banner widget)

**Acceptance:** When backend is down, app loads to a functional offline state with a red "Service unavailable" banner. Banner auto-dismisses when backend recovers.

---

### P0-03: No offline/connectivity banner in UI (Severity: HIGH)

**Current state:** `connectivityProvider` and `isOnlineProvider` exist in `connectivity_provider.dart` and are used in `main.dart` to trigger `retryPendingUploads()` on connectivity restore. But **no screen subscribes to `isOnlineProvider` to show a visual indicator**. Users tapping "Ask" while offline get a cryptic Dio timeout after 90 seconds.

**Why it matters:** Users don't know they're offline. They wait 90 seconds for a timeout, then see a generic error. ~40% of insurance app usage happens in areas with poor connectivity.

**Fix:** Create a shared `ConnectivityBanner` widget and add it to the app shell:

```dart
// New widget: ConnectivityBanner
class ConnectivityBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) return const SizedBox.shrink();
    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const Icon(Icons.wifi_off_rounded, color: Colors.white),
      backgroundColor: Theme.of(context).colorScheme.error,
      content: const Text(
        'You are offline. Some features may be unavailable.',
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        TextButton(
          onPressed: () {}, // dismiss
          child: const Text('Got it', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
```

Place it in `MainNavigation.build()` as a `Column` wrapping the `IndexedStack` + `MaterialBanner`, so it appears consistently across all tabs.

**Files to modify:**
- `mobile/lib/widgets/shared/coverwise_components.dart` — add `ConnectivityBanner` widget
- `mobile/lib/screens/main_navigation.dart` — wrap body in `Column` with banner

**Effort:** Small (30 min — new widget + placement + MaterialBanner)

**Acceptance:** Disabling the network on the simulator shows a red "You are offline" banner within 2 seconds. Banner disappears when network is restored. Tapping Q&A while offline shows the banner + instant offline error (not a 90s timeout).

---

## P1 — High impact, post-launch visible

### P1-01: No retry on Q&A screen after network failure (Severity: HIGH)

**Current state:** `QaScreen` calls `askQuestion()` which hits `POST /query`. If the Dio request fails (network error, 503), the error is caught and shown as a `CoverWiseSnackBar.error`. The user must manually retype their question and tap "Ask" again. There's no retry button.

**Fix:** Add a "Retry" action to the error state that re-sends the last question with the same context. Track the last question text + document ID.

**Acceptance:** After a Q&A network failure, a "Retry" button appears. Tapping it resends the question without the user retyping it.

---

### P1-02: No grace period or retry for auth token expiry (Severity: HIGH)

**Current state:** `AuthInterceptor` in `auth_service.dart` handles 401 responses by attempting a token refresh. If the refresh fails (e.g., refresh token expired), the user gets a generic error. In offline situations, this happens frequently.

**Fix:** Add a buffer period after token expiry detection where:
1. The app serves cached data from Hive (already works for documents)
2. A "Session expired — Sign in again" banner appears (not a blocking dialog)
3. The user can continue viewing their cached policies while being prompted to re-auth

**Acceptance:** Token expiry while offline does NOT block document viewing. A non-blocking banner tells the user to re-auth when online.

---

### P1-03: Processing status screen no-retry for terminal failures (Severity: MEDIUM)

**Current state:** The `ProcessingStatusScreen` has retry logic (handles `failed` status → retry button). But **terminal failures** (e.g., "file too corrupted to process") don't show a clear terminal indicator — the screen eventually shows "failed" but with no guidance on what to do next.

**Fix:** Differentiate retryable vs terminal failures in the error state:
- Retryable: "Processing failed — Tap Retry to try again (X of 3)"
- Terminal: "This file cannot be processed. Choose a different file." + "Replace file" button

**Acceptance:** A corrupted file shows a terminal error with guidance on next steps, not a generic "failed" state.

---

## P2 — Important, but can wait for post-launch

### P2-01: Analytics flush failures don't surface (Severity: MEDIUM)

**Current state:** `AnalyticsNotifier._flush()` catches Dio errors silently with `debugPrint`. If the analytics endpoint is down for days, the Hive buffer grows unbounded. There's no backpressure.

**Fix:** Cap the analytics buffer at 10,000 events. After that, start dropping oldest events with a `debugPrint` warning.

**Acceptance:** Buffer never exceeds 10,000 events regardless of backend availability.

---

### P2-02: No upload progress indicator for batch uploads (Severity: LOW)

**Current state:** Batch upload (`documents_screen.dart`) selects multiple files and uploads them sequentially. There's no progress indicator showing "Uploading file 2 of 5".

**Fix:** Add a `LinearProgressIndicator` below the file type hint during batch upload, showing current file index and overall progress.

**Acceptance:** Uploading 5 files shows "Uploading 2/5 — health_policy.pdf" with a progress bar.

---

### P2-03: No email verification reminder on startup (Severity: LOW)

**Current state:** If the user signs up with email but never verifies, the app silently proceeds. The user hits the doc limit, tries to upload, and gets "email not confirmed" error.

**Fix:** On startup, if `Supabase.instance.client.auth.currentUser?.email_confirmed_at` is null, show a subtle "Verify your email — resend" card on the dashboard (dismissible).

**Acceptance:** Unverified users see a dismissible "Verify your email" banner on the dashboard until they verify.

---

### P2-04: No connectivity-aware actions gating (Severity: LOW)

**Current state:** Upload, Q&A, and document type inference all try the network, fail, and show errors. It would be better to check connectivity first and show an immediate offline message instead of waiting for a timeout.

**Fix:** In `QaScreen._askQuestion()`, `documents_screen._uploadFile()`, etc., check `ref.read(isOnlineProvider)` before making the Dio call. If offline, show the `ConnectivityBanner` immediately + instant feedback.

**Acceptance:** Tapping "Ask" while offline shows "You're offline — connect to the internet to ask questions" in <100ms (no network timeout).

---

## P3 — Nice-to-have, post-launch polish

### P3-01: Uptime monitoring for backend (Severity: LOW)

**Current state:** No external monitoring. The solo founder learns the backend is down when users email.

**Fix:** Set up a free UptimeRobot or BetterStack monitor on `GET /health`. Configure email/SMS alerts.

**Effort:** 10 minutes of configuration.

---

### P3-02: Graceful degradation matrix for each feature (Severity: LOW)

**Current state:** No documented degradation behavior per feature. When the backend is down, it's unclear which features work offline and which don't.

**Fix:** Document the below matrix in the runbook:

| Feature | Backend down | No network | Both down |
|---------|-------------|------------|-----------|
| View cached documents | ✅ Works | ✅ Works | ✅ Works |
| Upload document | ❌ Fails | ✅ Queue locally | ✅ Queue locally |
| Q&A | ❌ Fails | ❌ Fails | ❌ Fails |
| Emergency info | ✅ Works | ✅ Works | ✅ Works |
| Family management | ✅ Works (local) | ✅ Works (local) | ✅ Works (local) |
| Coverage gaps | ❌ Fails | ❌ Fails | ❌ Fails |
| Agent requests | ❌ Fails | ❌ Fails | ❌ Fails |

---

## Implementation Plan

### Phase 1 (Before launch — 1-2 days)

| Priority | Item | Effort | Dependencies |
|----------|------|--------|-------------|
| P0-01 | Wire crash reporting (Sentry) | 30 min | Sentry DSN |
| P0-02 | Backend health check on startup | 1 hour | SplashScreen |
| P0-03 | Offline connectivity banner | 30 min | MainNavigation |
| P1-01 | Q&A retry on network failure | 1 hour | QaScreen |

### Phase 2 (Launch week — 1 day)

| Priority | Item | Effort | Dependencies |
|----------|------|--------|-------------|
| P1-02 | Auth token grace period | 1 hour | AuthInterceptor |
| P1-03 | Terminal failure state in processing | 30 min | ProcessingStatusScreen |
| P2-01 | Analytics buffer cap | 15 min | AnalyticsNotifier |

### Phase 3 (Post-launch — ad-hoc)

| Priority | Item | Effort | Dependencies |
|----------|------|--------|-------------|
| P2-02 | Batch upload progress | 1 hour | DocumentsScreen |
| P2-03 | Email verification reminder | 30 min | Dashboard |
| P2-04 | Connectivity-aware gating | 1 hour | QaScreen + DocumentsScreen |
| P3-01 | Uptime monitoring | 10 min | External service |
| P3-02 | Degradation matrix | 15 min | Runbook |

---

## Change Log

| Date | Change |
|------|--------|
| 2026-07-23 | Initial audit. 6 audits, composite score 5.0/10. 5 P0/P1 items for Phase 1. |

## Addendum (2026-07-23) — implementation reconciliation

The initial resilience findings were written before the latest mobile changes
were committed. Current code now includes Sentry startup wiring, a backend
health provider/banner, and the offline banner. Those items still require
runtime/device evidence before they can be treated as launch proof.

The renewal-reminder path was not complete: `NotificationService` displayed
notifications immediately with `show()` and did not initialize the device
timezone. The implementation now builds a testable reminder plan and uses
timezone-aware `zonedSchedule()` with inexact Android scheduling. Reminder
delivery remains a device-runtime check, not a unit-test claim.

**Anything else?** Yes: the audit and TODO remain stale for several broader
launch claims. The next reconciliation pass must distinguish code existence
from integration/runtime/production evidence and must address unsupported
customer-facing coverage claims before public release.

## Addendum (2026-07-24) — Regression gate closure for current tranche

The current worktree was re-verified after parallel auth, QA, claims, More
screen, RAG, and answer-verification changes:

- Flutter full suite: **1,028 passed**.
- Python full suite: **532 passed, 1 skipped, 47 warnings**.
- Answer verifier and RAG pipeline focused checks: passed.
- `flutter analyze`: no compile errors; 12 existing warnings/info remain in
  test utilities and benchmarks.
- `git diff --check`: passed.

The earlier full-mobile failure was a real syntax error in the in-flight More
screen and is now fixed; the repaired screen smoke test passes. Parallel work
was preserved. These results establish Tier 2 regression evidence, not Tier 3
authenticated-flow or Tier 4 device evidence. Deployed provider health,
representative-document extraction, authenticated provenance flow, and actual
device notification delivery remain launch gates.

### Anything else?

The next implementation pass should close the highest-risk runtime gates in
this order: authenticated upload-to-citation flow, notification delivery and
quiet-hours behavior on a supported device, deployed service/provider health,
then representative-corpus evidence for the answer and policy-extraction
contracts.

## Addendum (2026-07-24) — Test skip and warning classification

The full Python run was repeated with `-ra`:

- **Skipped:** `tests/test_azure_api.py:20` — deployed-service integration is
  opt-in and requires `COVERWISE_INTEGRATION_BASE_URL`. It is a missing Tier 3
  environment gate, not a product test failure. The related mutating upload
  test also requires `COVERWISE_RUN_MUTATING_INTEGRATION=1` when that suite is
  enabled.
- **47 warnings:** all are dependency deprecation warnings:
  - 36 from `httpx`'s deprecated `app` shortcut;
  - 4 from Supabase client's deprecated `timeout`/`verify` parameters;
  - 6 from `httpx`'s deprecated `content=` upload path;
  - 1 from `defusedxml.cElementTree`.

No warning is an assertion failure or a swallowed application exception. The
cleanup path is dependency/API migration with regression checks, not warning
suppression. The Azure skip remains an explicit deployed integration gate.

### Anything else?

The next runtime execution should supply `COVERWISE_INTEGRATION_BASE_URL` and
run the non-mutating deployed checks first. Mutating Azure upload coverage
requires explicit environment authorization and representative test data.

## Addendum (2026-07-24) — Deprecation closure pass

The first deprecation-closure slice is now implemented and verified:

- FastAPI/Starlette and HTTPX moved to the supported TestClient boundary.
- Supabase client construction now injects the supported HTTPX client through
  one canonical helper instead of forwarding deprecated PostgREST keywords.
- Qdrant Client moved to `1.18.0`, removing the deprecated raw `data=` request
  path observed in the RAG health test.
- The native-text OCR path no longer initializes docTR; docTR `1.0.1` is
  loaded only for scanned-image OCR. Its upstream `defusedxml` warning is
  isolated to that optional import because no maintained upstream fix exists
  in the current release.
- The remaining Azure skip is unchanged and still requires deployed-service
  credentials; it is not a deprecation warning.

Verification after the pass: 506 non-slow Python tests passed with one Azure
integration skip; the focused Supabase/frontend/OCR boundary checks passed 15
tests with deprecations treated as errors; and the RAG pipeline passed 9 tests
with no deprecation warning. One Qdrant `UserWarning` remains when a local
server is unreachable during a health check and is intentionally visible as
operational status.

## Addendum (2026-07-24) — Fresh authenticated upload probe

A fresh local process on `127.0.0.1:8011` was exercised with a temporary
anonymous bearer identity and a repacked synthetic policy fixture:

- upload accepted with HTTP 202;
- owner-scoped status transitioned from `processing` to
  `completed_summary_partial` with HTTP 200;
- the status payload exposed stage metadata without raw text or page-image
  bytes after the status-contract fix;
- summary returned 404 because the tiny fixture did not meet the policy
  summary extraction threshold;
- field citations returned 503 because the local process had no configured
  Supabase evidence substrate;
- page readback returned 404 because no page artifact was persisted without
  the evidence substrate path.

This closes the local status serialization failure at Tier 4, but does not
close the authenticated evidence gate. The next required execution is a
configured Supabase run with a representative policy corpus, followed by
two-owner citation/page isolation and replay checks. No local in-memory
evidence substitute should be added; the substrate contract intentionally
fails closed when its durable backing service is absent.

## Addendum (2026-07-24) — Mobile dependency gate restored

The notification-delivery gate initially could not start because the mobile
package contract declared `intl ^0.17.0`, while the installed Flutter SDK's
`flutter_localizations` package requires `intl 0.20.2`. The dependency was
updated to `^0.20.2` and the lockfile was regenerated through `flutter pub
get`.

Verification after the change:

- renewal reminder and quiet-hours tests passed;
- `flutter analyze` passed with no analyzer findings;
- the full Flutter suite passed: **1,038 tests**.

This restores Tier 2 mobile regression evidence. It does not replace the
remaining Tier 4 supported-device notification test: permission grant,
timezone resolution, scheduled delivery, quiet-hours behavior, and tap
payload navigation still require a real supported device or emulator.

## Addendum (2026-07-24) — Device runtime gate blocked by host storage

An iPhone 16e simulator was booted and the app launch reached the native iOS
build. Xcode then failed while extracting the Sentry binary package with I/O
error code 28. The host filesystem had only **300 MB available** at the time
of the attempt; CoreSimulator used approximately **5.6 GB**, Xcode
DerivedData **1.9 GB**, and the Flutter SDK cache **3.4 GB**.

This is an environment blocker, not evidence of an application compile or
notification implementation failure. Device notification evidence remains
open until storage is safely reclaimed or expanded, followed by a simulator
or physical-device run that observes permission, scheduling, quiet-hours, and
tap-payload behavior. No cache or user data was deleted during this pass.
