# CoverWise App Store and Google Play Readiness Audit

## 04. Bugs, Static Analysis, and Tests

**Audit date:** 2026-10-12  
**User:** Pranay  
**Business/team:** CoverWise  
**Internal value:** identify mobile and backend defects that can lose user data, crash workflows, expose sensitive information, or weaken the release gate.  
**Lane:** bugs, static analysis, tests.  
**Scope:** `mobile/lib`, `src`, Flutter test/build configuration, and the requested command runs.  
**Evidence level:** Tier 1 static inspection only. Flutter analysis and test execution did not reach project code, and pytest did not start.  
**Sensitivity:** no test sensitivity level achieved; no tests were collected or executed.

## Command results

Commands were issued from the repository root. No package installs, Git commands, production service calls, or external writes were made.

| Exact command | Exit | Counts and failing names | Result and error snippet |
|---|---:|---|---|
| `cd mobile && PATH=/Users/pranay/Projects/adhoc_resources/flutter/bin:$PATH flutter analyze` | 1 | Analyzer diagnostics: 0 emitted because analysis did not start. Source files analyzed: none. | Flutter SDK bootstrap could not update its local engine cache: `update_engine_version.sh: line 71: .../engine.stamp.tmp.41021: Operation not permitted`; `line 78: .../engine.realm: Operation not permitted`. This is a tool-cache permission failure, not a clean analysis result. |
| `cd mobile && PATH=/Users/pranay/Projects/adhoc_resources/flutter/bin:$PATH flutter test --dart-define-from-file=.dartdefine.env --concurrency=1` | 1 | 0 passed, 0 failed, 0 skipped, 0 collected. No failing test names because test discovery did not start. | Same Flutter SDK bootstrap failure before test startup: `update_engine_version.sh: line 71: .../engine.stamp.tmp.42011: Operation not permitted`; `line 78: .../engine.realm: Operation not permitted`. |
| `./venv/bin/pytest -q .` | 127 | 0 passed, 0 failed, 0 skipped, 0 collected. No failing test names because pytest did not start. | The requested executable is absent: `zsh:1: no such file or directory: ./venv/bin/pytest`. No alternate interpreter or runner was used. |

The Flutter commands stopped while trying to write under the configured Flutter SDK cache at `/Users/pranay/Projects/adhoc_resources/flutter/bin/cache`. The pytest command stopped because `./venv/bin/pytest` is missing. These results do not establish whether either codebase passes analysis or tests.

## Findings

All code behavior below is labeled **STATIC INSPECTION**. No runtime reproduction was possible in this lane.

| ID | Severity | Status | Evidence, behavior, and concrete fix |
|---|---|---|---|
| **BUG-01** | MED | **STATIC INSPECTION** | [mobile/lib/screens/family_member_detail_screen.dart:93](/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/screens/family_member_detail_screen.dart:93) removes the existing manual family member at lines 96-99, then writes the replacement at line 100. If the second Hive write fails or the process stops between these operations, the original record is already gone and there is no rollback. The code comment also acknowledges the crash window. **Fix:** add a repository operation that replaces the record in one serialized read-modify-write, or persist the new record successfully before removing the old one and roll back on failure. Acceptance: inject a failure on the replacement write and verify the original member remains present. |
| **BUG-02** | MED | **STATIC INSPECTION** | [mobile/lib/screens/family_member_detail_screen.dart:96](/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/screens/family_member_detail_screen.dart:96) awaits two persistence operations, then calls `refreshManualFamilyMembers(ref)` and `setState` at lines 101-105. The `mounted` check is only at line 106, after both operations. Navigating away while either await is pending can use a disposed `ref` or call `setState` after disposal. **Fix:** check `mounted` after the awaited persistence and before accessing `ref` or calling `setState`; keep storage completion separate from UI completion. Acceptance: dispose the route while either write is pending and verify there is no disposed-ref or setState exception. |
| **BUG-03** | MED | **STATIC INSPECTION** | [mobile/lib/screens/documents_screen.dart:811](/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/screens/documents_screen.dart:811) awaits `_ensureConsent`, then `_syncProcessingConsent` at lines 812-815, and calls `setState` at lines 817-821 without checking `mounted`. A later check at line 828 occurs only after this state update. Leaving the screen during consent sync can trigger `setState() called after dispose()`. **Fix:** return when `!mounted` immediately after `_syncProcessingConsent()` and before the state update. Acceptance: close the upload screen while consent sync is pending and verify no framework exception is emitted. |
| **BUG-04** | MED | **STATIC INSPECTION** | [mobile/lib/services/field_overrides_store.dart:69](/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/services/field_overrides_store.dart:69) logs the corrected policy field value and document ID at line 72. [mobile/lib/services/relationship_extraction_service.dart:226](/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/services/relationship_extraction_service.dart:226) logs the raw user question at line 234. The canonical API also logs the full account UID and raw provider exception in [src/api/family.py:67](/Users/pranay/Projects/medpiper/insurance_app/src/api/family.py:67), with similar logging at lines 102-104 and 144-170. Policy fields and questions can contain personal or health-related details, and account UIDs are persistent identifiers. Whether the Flutter `debugPrint` calls are emitted in a particular release build was not verified; the backend logger calls are unconditional. **Fix:** remove raw values, questions, full identifiers, and exception payloads from logs; record bounded error types and a non-reversible correlation value instead. |
| **BUG-05** | MED | **STATIC INSPECTION; runtime impact UNVERIFIED** | The project test command requires `--dart-define-from-file=.dartdefine.env --concurrency=1` in [AGENTS.md:75](/Users/pranay/Projects/medpiper/insurance_app/AGENTS.md:75). The canonical mobile release script runs only `flutter test` at [tools/build_mobile_release.sh:89](/Users/pranay/Projects/medpiper/insurance_app/tools/build_mobile_release.sh:89) and [tools/build_mobile_release.sh:91](/Users/pranay/Projects/medpiper/insurance_app/tools/build_mobile_release.sh:91). Without the test define, [mobile/lib/config/app_config.dart:213](/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/config/app_config.dart:213) can select the localhost development fallback instead of the configured test endpoint. The suite could not run here, so the affected tests and observed impact are unknown. **Fix:** have the release script invoke the prescribed test command, using an explicitly isolated test define file if the local one is unsuitable. Acceptance: the release script's test step is equivalent to the project command and stops the release on a test failure. |
| **BUG-06** | HIGH | **UNVERIFIED release-path risk** | [mobile/android/app/build.gradle.kts:18](/Users/pranay/Projects/medpiper/insurance_app/mobile/android/app/build.gradle.kts:18) enables the production signing check only when `COVERWISE_RELEASE_BUILD=true`; otherwise lines 69-79 allow a release variant to use the debug keystore when no key alias is configured. The canonical wrapper does set the guard and requires `key.properties` at [tools/build_mobile_release.sh:73](/Users/pranay/Projects/medpiper/insurance_app/tools/build_mobile_release.sh:73) and [tools/build_mobile_release.sh:85](/Users/pranay/Projects/medpiper/insurance_app/tools/build_mobile_release.sh:85). Static inspection confirms direct Gradle/Flutter release builds can bypass that guard. Whether any Play submission path bypasses the canonical wrapper is unknown. A debug-signed bundle cannot serve as a Play upload artifact. **Fix:** make release signing fail closed in the Gradle release variant itself, or enforce the canonical wrapper for every store build and verify the produced artifact's signer before submission. |

## Additional checks and limits

- **Null assertions and API casts:** inspected representative mobile API and persisted-data paths, including `qa_screen.dart`, `processing_status_screen.dart`, and `family_sync_service.dart`. No specific unguarded API-data null assertion or cast with a demonstrated failing input was confirmed. Several reviewed paths type-check responses or catch parse failures and fall back. The Flutter analyzer did not run, and malformed-response behavior remains unverified.
- **Swallowed exceptions:** found best-effort cache, telemetry, and fallback catches. The reviewed identity-link recovery catch in `src/api/user.py:184-196` still returns a failed request rather than reporting success after recovery failure. No additional production-critical false-success path was confirmed in this pass.
- **Unawaited work:** `src/services/job_dispatcher.py:119-163` creates a handler task but observes it through the lease-heartbeat loop and gathers cancellation. `mobile/lib/services/analytics_service.dart:171-191` explicitly marks session telemetry as unawaited and catches its failure. `src/api/document.py:945-966` has a legacy `ensure_future` reprocess path; deployment use of that fallback was not runtime verified.
- **Secrets and TODO markers:** no hard-coded production credential literal was confirmed in the inspected `mobile/lib` and `src` code. `.env` and `.dartdefine.env` values were not copied into this report. No actionable `TODO`, `FIXME`, or `XXX` markers were found in `mobile/lib` or `src` by the static search.
- **Android signing:** the canonical production build wrapper gates signing, but no release artifact was built or signer-verified. Apple signing, store-console state, device behavior, hosted behavior, and the complete Render/Supabase release configuration are outside this lane's verified evidence.
- **Side effects:** no production network calls, package installs, source edits, Git commands, or device runs occurred. The Flutter bootstrap attempts to write its local SDK engine cache were rejected before analysis or tests started.

## Review completeness

**Reviewed:** requested test commands and their startup results; static bug patterns in `mobile/lib` and `src`; the Flutter test guidance; the canonical mobile release script; Android release signing configuration; representative Flutter API parsing, lifecycle, and logging paths.

**Not reviewed:** Apple or Play consoles, signed store artifacts, physical-device or emulator workflows, hosted service behavior, production Supabase state, broad legal/policy readiness, and a full migration-by-migration correctness review.

**Remaining uncertainties:** analyzer diagnostics and Flutter test results; backend pytest results; whether the production Android artifact path always uses the canonical release wrapper; release-mode visibility of Flutter `debugPrint`; runtime frequency of the lifecycle and family-member persistence failures.

**Evidence needed next:** rerun the exact Flutter commands with a writable Flutter SDK cache; restore the documented project pytest executable; then add focused regressions for BUG-01 through BUG-03 and verify Android artifact signing from the actual release pipeline.

**Evidence tier achieved:** Tier 1 static inspection. No Tier 2 or higher behavior was verified. No test sensitivity result was achieved.

**Files changed:** this report only. Git state was not inspected because Git commands were prohibited.
