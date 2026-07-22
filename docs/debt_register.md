# Tech Debt Register

**Last updated:** 2026-07-22

Register of known technical debt with remediation plans. Prioritised by revenue/security risk first, then developer velocity.

---

## Critical

### C-01 Client-side entitlement enforcement
Upload policy limits and Q&A budget gating are enforced client-side only. The server accepts any `/query` call and charges after the response; `/upload` has no server-side budget reservation. Billing sync accepts client-declared RevenueCat state.

**Impact:** Revenue integrity risk — a compromised client or API caller can bypass plan limits entirely.

**Remediation:** Implement server-enforced entitlement ledger: check entitlements on every Q&A call and upload, remove client-only plan gates.

**Estimate:** ~2 days

---

## High

### H-01 Outbox shipped but not adopted by 5 async paths
The Supabase outbox table + service + dispatcher + worker is shipped and tested, but 5 existing in-process async paths (document processing, evidence substrate extraction, Q&A, webhook reconciliation, subscription writeback) are NOT migrated. The outbox is dormant in production.

**Impact:** Lost work on crash/restart; no idempotency or retry guarantees for critical async paths.

**Remediation:** Migrate each path to use the outbox.

**Estimate:** ~5 hours

### H-02 Remote Supabase migration ledger mismatch
51 local migration files vs 16 rows in the remote `_supabase_migrations` table. Object parity is confirmed, but rollback and replay are compromised.

**Impact:** Cannot reliably rollback or replay migrations on the remote project.

**Remediation:** Reconcilation: either a checked-in baseline/squash or a fully replayable migration ledger with proven idempotence.

**Estimate:** ~1 day

### H-03 Offline upload has no reconciliation worker
`pending_upload` persists locally but has no mobile retry consumer, no connectivity trigger, and no explicit retry/cancel UI.

**Impact:** Documents uploaded while offline are silently lost if the app is killed before connectivity returns.

**Remediation:** Implement durable retry worker with idempotency, backoff, auth transitions, and operator visibility.

**Estimate:** ~1 day

### H-04 10 half-built features not actioned
ADR-2026-07-19-08 documents cut/keep/finish decisions for Health Score, What-If Calculator, Lead Capture, Literacy Quiz, Billing, Q&A packs, Family, Claim Tracker, Insurance Cards, and Upgrade screen. Decisions have not been executed.

**Impact:** Code entropy; dead features in the live app confuse users and increase maintenance surface.

**Remediation:** Execute cut (remove Health Score, What-If, Literacy Quiz), redesign (Lead Capture), finish (Billing, Q&A packs, Family, Claim Tracker, Insurance Cards).

**Estimate:** ~3 days

---

## Medium

### M-01 53 scattered `Hive.box()` calls
Hive boxes accessed directly from screens, providers, and services across 20+ files. No single repository pattern.

**Impact:** Brittle — changing box names or migration logic requires touching many files.

**Remediation:** Consolidate behind `HiveWorkspaceService` and `AppStateRepository`; remove direct `Hive.box()` calls from screens and providers.

### M-02 Deprecated OCR microservice still live
`src/ocr/service.py` is marked `@deprecated` — a standalone FastAPI OCR microservice superseded by in-process `/process-and-ingest`. Still present and importable.

**Impact:** Confusing for new developers; could be accidentally deployed.

**Remediation:** Remove after confirming no external consumers exist. Target: next major release.

### M-03 Deprecated `/documents/query` route still active
Old route logs a warning but returns success payloads. No deprecation deadline set.

**Impact:** Maintains a compatibility surface indefinitely.

**Remediation:** Set a deprecation deadline, add `Sunset` header, remove after window expires.

### M-04 Completer-based file picker fragile
`WebFilePickerHtml` uses static `Completer` fields — a second pick before the first completes would share state.

**Impact:** Bug surface for multi-file upload flows.

**Remediation:** Use proper async pattern or dedicated state machine.

### M-05 Principal key migration deferred
Per-box migration from device-key to principal-key has known gaps: two-principal authenticated restart/replay not proven.

**Impact:** Local data could become inaccessible on principal transition.

**Remediation:** Complete per-box migration verification, prove two-principal restart, close Tier 3/4 gates.

### M-06 Consent ledger cache-first pattern
Local Hive box is primary read path for consent decisions. Cache can drift from server.

**Impact:** Stale consent decisions could be presented to the user or enforced locally after server-side revocation.

**Remediation:** Implement server-first read path with cache fallback, add "last verified at" indicator and pull-to-refresh.

### M-07 Performance budgets not enforced in CI
60 MB APK budget and <3s cold start adopted but not enforced in CI; startup benchmark gated on manual device run.

**Impact:** Budgets are aspirational — no regression gate.

**Remediation:** Wire APK size step to fail CI on budget breach; integrate startup benchmark into CI pipeline.

### M-08 16 `as dynamic` / `.cast<>()` patterns
Weak typing at JSON deserialization boundaries across main.dart, services, and screens.

**Impact:** Runtime cast failures; hides type errors from the compiler.

**Remediation:** Introduce typed `fromJson` factories with `json_serializable`; eliminate raw `cast<>()` calls.

### M-09 Localization migration incomplete
Localization catalog adopted by Q&A only; most screens still hold direct literals. Shared snackbar helper is incremental; legacy flows render raw snackbars.

**Impact:** Inconsistent user experience across the app.

**Remediation:** Complete extraction across all screens, add locale/placeholder tests, consolidate raw snackbar callers.

### M-10 Analytics schema not enforced
Backend accepts arbitrary event properties — safety is caller-enforced rather than schema-enforced.

**Impact:** Analytics data quality degrades over time; no validation at the API boundary.

**Remediation:** Implement schema enforcement for analytics events with validation at the API boundary.

---

## Low

### L-01 50+ `debugPrint()` calls in production code
No structured logging framework in place.

### L-02 5 `Future.delayed` timing hacks
Artificial delays in production code paths (splash, QA screen, document preview).

### L-03 2 `.then()` chains instead of async/await
In main.dart — potential unhandled-rejection paths.

### L-04 Resolve "Restore tests" TODO in `global_error_boundary_test.dart:6`
TODO to restore recovery/error-persist tests with mocked AnalyticsService.

### L-05 5 debug test files checked in
`debug_tos*.dart` and `debug_hive_clear.dart` in the test directory.

### L-06 Hardcoded Hive box names in `hive_workspace_service.dart`
7 box names hardcoded — extract to constants file.

### L-07 `PROCESSING_TEMP_DIR` defaults to relative `"temp"`
Could resolve to unexpected path.

### L-08 `SPOOFING_ATTEMPT` log includes user-controlled data
User-controlled `claimed_plan` in plain-text log message.

### L-09 Route screen content not wrapped in `ScreenErrorBoundary`
Named routes (settings, help, documents, etc.) accessed via `Navigator.pushNamed` are not wrapped in per-screen error boundaries. Only the 5 main tabs are covered.

**Remediation:** Wrap each route builder in `main.dart` with `ScreenErrorBoundary`.

---

## Tracking

| Item | Status | Target | Owner |
|------|--------|--------|-------|
| C-01 | open | — | — |
| H-01 | open | — | — |
| H-02 | open | — | — |
| H-03 | open | — | — |
| H-04 | open | — | — |
| M-01 | open | — | — |
| M-02 | open | next major | — |
| M-03 | open | — | — |
| M-04 | open | — | — |
| M-05 | open | — | — |
| M-06 | open | — | — |
| M-07 | open | — | — |
| M-08 | open | — | — |
| M-09 | open | — | — |
| M-10 | open | — | — |
| L-09 | open | — | — |
