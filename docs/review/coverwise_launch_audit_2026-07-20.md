# CoverWise iOS Launch Readiness — Runtime UI/UX Audit

**Date:** 2026-07-20  
**Device:** iPhone 17 Pro Simulator  
**UDID:** AD261A84-B563-4423-956D-45ED29FB89E0  
**Repo:** /Users/pranay/Projects/medpiper/insurance_app  
**App bundle:** com.coverwise.app  
**Auditor:** Kimi Code CLI runtime QA (read-only, no source changes)

---

## 1. Environment Status

| Component | Status | Notes |
|-----------|--------|-------|
| iOS Simulator | ✅ Booted | iPhone 17 Pro, UDID as above |
| Flutter build | ✅ Built | `mobile/build` exists; build completed in ~18s during `flutter run` |
| serve-sim | ⚠️ Intermittent | Started via `nohup` after multiple background-task timeouts/crashes; eventually stable on port 3200 |
| Backend (port 8000) | ⚠️ Unstable / degraded | Already running on audit start (PID 83605), then died mid-audit. Fresh start returned HTTP 503 on `/health` with RAG unavailable; `/docs` 200; `/user/anonymous` 200 |
| Hot-reload / debugger | ❌ Detached | `flutter run` background task timed out; app ran without active debugger |

**Backend observations:**
- Initial `/health` returned `{"status":"ok","rag_status":"available","embedding_probe":"ok","document_processing_status":"available","version":"2.0.0"}`.
- The backend process later disappeared from port 8000 (cause not captured).
- A fresh start logged:
  - `rag_initialization_failed error_type=TypeError`
  - `PolicyExtractionService init failed: AsyncClient.__init__() got an unexpected keyword argument 'proxies'`
  - Sample documents `sample_health_policy.txt` and `sample_auto_policy.txt` failed to fully process (`summary_partial`).
  - `/health` returned HTTP 503 with body `{"status":"unavailable","rag_status":"unavailable","document_processing_status":"available","version":"2.0.0","detail":"RAG pipeline not initialized"}`.
- `POST /user/anonymous` returned a valid JWT bearer token and anonymous user object.

---

## 2. Flow-by-Flow Results

Screenshots are in `docs/review/assets/launch_audit_2026-07-20/`.

### (a) Cold Launch → Onboarding

| Step | Screenshot | Result | Observations |
|------|------------|--------|--------------|
| iOS Home with CoverWise icon | `01_launch.png` | ✅ Pass | App icon renders correctly (shield with checkmark). |
| Tap app icon → splash | `02_app_opening.png` | ✅ Pass | Dark splash screen with blue shield logo. |
| Splash → onboarding page 1 | `03_launch_loaded.png` | ✅ Pass | Page 1 "UNDERSTAND — Turn policy pages into plain answers." renders cleanly. 3D illustration, pagination dots, Continue button. No overflow stripes or red screens. |
| Tap Continue → page 2 | `10_continue_success.png` | ✅ Pass | Page 2 "ASK — Ask your policy, not the internet." renders. |
| Tap Continue → page 3 | `11_onboarding_3.png` | ✅ Pass | Page 3 "STAY READY — Know what needs attention next." renders. |

**UX notes — onboarding:**
- Copy is clear and benefit-oriented.
- Pagination dots give progress feedback.
- The illustration on page 1 has a subtle rendering seam where the scroll/page overlaps the card (visible at the right edge of the document image); not a blocker but a polish item.

### (b) Dashboard / Home

| Step | Screenshot | Result | Observations |
|------|------------|--------|--------------|
| Check ToS → enable "Add my first policy" | `12_consent_checked.png` | ✅ Pass | Checkbox toggles on; button becomes enabled. |
| Tap "Add my first policy" → Home | `13_dashboard.png` / `17_dashboard.png` | ⚠️ Intermittent | Reached Home empty state once. On subsequent attempts the same button did not respond (see `26_dashboard_again.png`, `27_dashboard_after_policy_button.png`, `28_dashboard_attempt3.png`). |
| Home empty state | `17_dashboard.png` | ✅ Pass when reached | "Turn your first policy into clear answers" with "Choose policy file" CTA. Bottom tab bar: Home, Documents, Ask, Family, More. |

**UX notes — Home:**
- Empty state is clear and action-oriented.
- Tab bar icons are legible; labels are short.
- No sample policies or "see an example" shortcut, so first-time users cannot explore the app without uploading a real file.

### (c) Documents List

| Step | Screenshot | Result | Observations |
|------|------------|--------|--------------|
| Tap Documents tab | `18_documents.png` | ❌ Fail | App was sent to background / home screen. Screenshot shows iOS Home, not Documents. |
| Retry Documents after relaunch | `05b_documents_retry.png` | ❌ Fail | App hung on black screen after interaction. |

**Finding:** Tab-bar taps near the bottom edge (y ≈ 0.95) appear to conflict with the iOS Home indicator, causing the app to background or crash. The Documents screen was never successfully reached.

### (d) Upload Flow

| Step | Screenshot | Result | Observations |
|------|------------|--------|--------------|
| Open upload UI from Home | — | ❌ Not reached | App became unstable before a reliable tap on "Choose policy file" could be recorded. The CTA on the consent page was intermittently unresponsive, suggesting the same button-hit area issue. |

### (e) Q&A / Ask Screen

| Step | Screenshot | Result | Observations |
|------|------------|--------|--------------|
| Tap Ask tab | — | ❌ Not reached | App instability prevented navigation to Ask tab. |

### (f) Policy Detail

| Step | Screenshot | Result | Observations |
|------|------------|--------|--------------|
| Open any policy detail | — | ❌ Not reached | No documents uploaded; no sample data surfaced in UI. Backend sample documents exist in storage but are not exposed in the mobile UI. |

### (g) Family Screen

| Step | Screenshot | Result | Observations |
|------|------------|--------|--------------|
| Tap Family tab | — | ❌ Not reached | App instability prevented navigation. |

### (h) More / Settings + Notification Preferences

| Step | Screenshot | Result | Observations |
|------|------------|--------|--------------|
| Tap More tab | — | ❌ Not reached | App instability prevented navigation. |

### (i) Paywall / Upgrade Screen

| Step | Screenshot | Result | Observations |
|------|------------|--------|--------------|
| Reach paywall/upgrade | — | ❌ Not reached | No upgrade prompt surfaced during onboarding or Home empty state. Could not locate a paywall entry point. |

---

## 3. Severity-Ranked Issue List

### P0 — Crash / Blocker

1. **App crashes / hangs on lower-screen taps (Documents tab, primary CTAs)**
   - **Evidence:** `18_documents.png` (iOS Home after tapping Documents), `19_relaunch2.png`/`20_relaunch2_loaded.png` (black screen after terminating/relaunching), `29_dashboard_attempt4.png` (black screen after tapping "Add my first policy" at y≈0.84).
   - **Observation:** Taps in the lower portion of the screen (tab bar, bottom CTAs) frequently cause the app to either background itself or hang on a black screen. This makes core navigation unusable.
   - **Impact:** Users cannot open Documents, Ask, Family, or More; primary "Add my first policy" / "Choose policy file" flow is unreliable.

2. **Onboarding state is not persisted; app restarts from page 1 on relaunch**
   - **Evidence:** `14_current_state.png` shows onboarding page 1 after the app had already reached dashboard in `13_dashboard.png`; `22_relaunch3_loaded.png` shows onboarding page 1 again after terminate/relaunch.
   - **Observation:** Completing onboarding and reaching Home does not persist; a fresh launch sends the user back to the first onboarding screen.
   - **Impact:** Repeat users are trapped in onboarding every launch; consent checkbox must be re-accepted.

3. **Backend RAG pipeline fails to initialize; `/health` returns 503 on fresh start**
   - **Evidence:** `/tmp/backend_audit.log` shows `rag_initialization_failed error_type=TypeError` and `PolicyExtractionService init failed: AsyncClient.__init__() got an unexpected keyword argument 'proxies'`.
   - **Observation:** Fresh backend boot cannot initialize the RAG/embedding pipeline. The original long-running backend reported OK, but died during the audit.
   - **Impact:** Q&A feature (which depends on RAG) will be unavailable in a clean environment; health checks will fail.

4. **Backend process died during audit**
   - **Evidence:** Port 8000 became unresponsive mid-audit; original PID 83605 no longer present.
   - **Observation:** The backend that initially served OK terminated unexpectedly.
   - **Impact:** Any API-dependent UI flows would fail until the backend is restarted.

### P1 — Broken / Misleading

5. **"Add my first policy" button is intermittently unresponsive**
   - **Evidence:** Reached Home once (`17_dashboard.png`), but on at least three subsequent attempts (`26_dashboard_again.png`, `27_dashboard_after_policy_button.png`, `28_dashboard_attempt3.png`) the enabled blue button did not advance.
   - **Observation:** Button state updates correctly when the consent checkbox is toggled, but tap handling is unreliable. This may share root cause with the lower-screen crash issue.
   - **Impact:** Users cannot reliably enter the app after onboarding.

6. **Sample documents exist on backend but are not surfaced in mobile UI**
   - **Evidence:** Backend logs show `Found 52 existing documents to process` including `sample_health_policy.txt` and `sample_auto_policy.txt`; mobile Home shows only an empty-state "Choose policy file" CTA.
   - **Observation:** No sample/demo policy is offered, so users cannot explore policy detail or Q&A without uploading a real file.
   - **Impact:** First-run experience is a dead end if the user does not have a policy file handy.

7. **serve-sim preview server repeatedly crashed / timed out when run as a background task**
   - **Evidence:** Multiple `task:bash-*:timed_out` notifications; `serve-sim --list` showed `{"running":false}` several times.
   - **Observation:** The automation harness itself was unstable until detached with `nohup`.
   - **Impact:** Not a user-facing bug, but it indicates the dev/QA workflow is fragile.

### P2 — Polish

8. **Onboarding illustration seam on page 1**
   - **Evidence:** `03_launch_loaded.png` shows a thin overlap/clip at the right edge of the document illustration.
   - **Observation:** The hero image appears to extend beyond its rounded container or has a compositing edge.
   - **Impact:** Visual polish; does not block functionality.

9. **"Skip" button only advances one page at a time**
   - **Evidence:** Each tap on Skip moved from page 1 → page 2 → page 3 rather than jumping to Home.
   - **Observation:** Standard iOS onboarding "Skip" is expected to skip the entire carousel. Here it behaves like a next-page button.
   - **Impact:** Minor UX confusion; users still see all onboarding pages.

10. **No loading/progress feedback during backend-dependent transitions**
    - **Observation:** After onboarding consent, tapping the primary CTA sometimes gave no immediate feedback while the app presumably called the backend.
    - **Impact:** Users may tap multiple times or think the app is frozen.

---

## 4. What Could Not Be Tested

Due to the P0 instability, the following flows were **not successfully exercised**:
- Documents list empty and populated states
- Upload flow (file picker opening)
- Q&A / Ask screen and question submission
- Policy detail screen
- Family screen
- More / Settings screen
- Notification preferences
- Paywall / upgrade screen (no entry point found)
- Real document upload and backend processing end-to-end
- Deep links or push-notification entry points

---

## 5. Recommendations Before Launch

1. **Fix the lower-screen tap crash.** This is the highest-priority blocker. Verify safe-area handling, tab bar hit-testing, and that taps near the iOS Home indicator do not background the app or trigger a crash.
2. **Persist onboarding completion state** (e.g., SharedPreferences / secure local storage) so users only see onboarding once.
3. **Stabilize backend RAG initialization.** The `AsyncClient.__init__() got an unexpected keyword argument 'proxies'` error suggests an `httpx` / OpenAI client version mismatch; pin and upgrade dependencies.
4. **Add backend health/retry logic in the app** and a user-friendly offline/error state.
5. **Surface sample/demo policies** in the mobile UI so users can explore value before uploading.
6. **Make the primary CTA reliably tappable** and add a loading indicator during the anonymous-auth/onboarding-complete transition.
7. **Investigate why the backend process terminated mid-audit** (memory? unhandled exception?); add structured crash logging.

---

## 6. Screenshot Index (files created by this audit)

All files are in `docs/review/assets/launch_audit_2026-07-20/`.

- `01_launch.png` — iOS Home, CoverWise icon  
- `02_app_opening.png` — Splash screen  
- `03_launch_loaded.png` — Onboarding page 1  
- `04_onboarding_2.png` — Onboarding page 1, Continue tap attempt  
- `05_onboarding_2_retry.png` — Onboarding page 1, retry  
- `06_after_skip.png` — After Skip tap  
- `07_home_button_test.png` — iOS Home after hardware home button  
- `08_relaunch.png` — Onboarding page 1 after relaunch  
- `09_continue_tap.png` — Onboarding page 1, Continue tap  
- `10_continue_success.png` — Onboarding page 2  
- `11_onboarding_3.png` — Onboarding page 3 (consent)  
- `12_consent_checked.png` — Consent checkbox checked  
- `13_dashboard.png` / `17_dashboard.png` — Home empty state (reached intermittently)  
- `14_current_state.png` — App reset to onboarding page 1  
- `15_after_skip2.png` — Onboarding page 2 after second relaunch  
- `16_after_skip3.png` — Onboarding page 3 after third relaunch  
- `18_documents.png` — iOS Home after Documents tab tap (app backgrounded)  
- `19_relaunch2.png` / `20_relaunch2_loaded.png` — Black screen after relaunch attempt  
- `21_relaunch3.png` / `22_relaunch3_loaded.png` — Splash then onboarding after terminate/relaunch  
- `23_skip_to_consent.png` — Onboarding page 1 after Skip (did not advance)  
- `24_continue_after_relaunch.png` — Onboarding page 2  
- `25_onboarding_3_again.png` — Onboarding page 3  
- `26_dashboard_again.png` — Consent page, button enabled but unresponsive  
- `27_dashboard_after_policy_button.png` — Still on consent page after CTA tap  
- `28_dashboard_attempt3.png` — Still on consent page after CTA tap  
- `29_dashboard_attempt4.png` — Black screen after lower CTA tap  

(Other files in the directory with names such as `02_onboarding2.png`, `r_*.png`, etc. were not produced by this audit run and are ignored.)
