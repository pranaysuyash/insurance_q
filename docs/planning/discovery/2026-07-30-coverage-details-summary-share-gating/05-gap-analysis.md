# 05 — Gap Analysis

**Bundle:** 2026-07-30-coverage-details-summary-share-gating
**Doc E (Part 0)** — gap matrix between intended product, documented product, architected product, implemented product, tested product, deployed product
**Author:** session-init agent
**Date:** 2026-07-30

---

## A. Reading guide

For each gap, the matrix records:

- **Type** — what kind of gap (test ↔ code, doc ↔ code, scaffold missing, etc.)
- **Evidence** — concretely what proves the gap
- **Impact** — user / technical / operational
- **Severity** — Blocker / Critical / High / Medium / Low / Informational
- **Recommended response** — what to do (and whether in this session)
- **Affects current request?** — yes / no

## B. Gap matrix

### G-1 — `coverage_details_summary_screen_test.dart` cannot load: compile-blocked by `auth_service.dart`

- **Type:** Test ↔ code (transitive).
- **Evidence:** `flutter test test/coverage_details_summary_screen_test.dart` reports compile error `lib/services/auth_service.dart:303:37: The argument type 'String' can't be assigned to the parameter type 'DateTime'.` Line number shifted from 302 to 303 between two runs minutes apart, confirming live editing.
- **Impact:** Test cannot verify ANY assertion in the share gate, blocking this workstream's WS-1 evidence path.
- **Severity:** **Blocker** for this workstream's WS-1; **not a blocker** for the broader product (the gate itself is functional at runtime — only the test harness is blocked).
- **Recommended response:** Wait for parallel-agent refactor to land their defensive `createdAt` parse. After it lands, re-run WS-1. Do not patch the contested line directly (motto §23 hold).
- **Affects current request?** Yes — blocks WS-1 tier verification.

### G-2 — `principal_key_service.dart` had transient `bytes.length` compile error that self-resolved

- **Type:** Stale-state (no longer present).
- **Evidence:** First `flutter test` run flagged `principal_key_service.dart:184:13: Error: The getter 'bytes' isn't defined`; second run minutes later — error gone, file shows `decoded` consistently. The parallel agent was editing through that bug while I was looking at it.
- **Impact:** None (cleared).
- **Severity:** Informational.
- **Recommended response:** None. Documented for audit continuity.
- **Affects current request?** No.

### G-3 — `CoverageDetailsSummaryScreen` is a god-object at 935 lines

- **Type:** Code ↔ maintainability debt.
- **Evidence:** Line count from `wc -l`. 2026-07-23 UX audit noted 1,439 lines (per their count, before today's partial refactor); current is 935 (already partially decomposed). 10 sections including 6 type-specific builders, executive summary, dates, benefits, sharing.
- **Impact:** Future evolution cost — adding new policy type, new section, or new entitlement gate becomes harder.
- **Severity:** Medium (not in immediate path; will become a drag once new policy types are added).
- **Recommended response:** Out of scope. If the operator chooses, a follow-up workstream could split into smaller composable widgets — but *not* in this session, where §0.13 controls.
- **Affects current request?** No — direct scope.

### G-4 — Substring `find.textContaining('Export is available on Plus')` weakens the test contract

- **Type:** Test ↔ canonical copy.
- **Evidence:** Test asserts substring match against `'Export is available on Plus and Family plans.'`. The assertion would pass against any gate-reason containing the substring, including drift cases like `'Export is back; available on Plus and Family plans.'`.
- **Impact:** If the canonical gate-reason drifts in copy that still contains the substring, the test still passes silently. The user-visible messaging could subtly change without test signal.
- **Severity:** Low (matches current contract by design; not breaking anything).
- **Recommended response:** If desired, a future workstream could add a second assertion on the full gate-reason string or a sentinel `Key`. **Not in this workstream scope.** Mentioned in `04-current-state-architecture.md` §D.
- **Affects current request?** No — it's a borderline-future-brittleness note, not a current defect.

### G-5 — `EntitlementNotifier.checkAction` intermixes "expired" and per-action branches

- **Type:** Code ↔ design wart.
- **Evidence:** Lines 130–171 mix `if (ent.isExpired && action != 'ask_question')` returning a generic message with the per-action switch that returns action-specific messages.
- **Impact:** Latent. For an expired Plus user who hits the share button, they'd see "Your Plus plan has expired..." instead of the export-reason. Slightly less informative.
- **Severity:** Low (test 1 does not exercise expiry; user impact is textual only).
- **Recommended response:** Out of scope for this session.
- **Affects current request?** No.

### G-6 — `CoverageDetailsSummaryScreen` is not registered in `main.dart` `routes:` map

- **Type:** Architecture vs surface.
- **Evidence:** Grep shows `coverage_details_summary` referenced from `dashboard_screen.dart` (import) and `policy_detail_screen.dart` (import), but the screen is reached via direct `MaterialPageRoute` pushes, not `Navigator.pushNamed`. No `'/coverage-details-summary'` route exists.
- **Impact:** Cannot be reached via deep links. Acceptable for an MVP.
- **Severity:** Low.
- **Recommended response:** Out of scope. Adding a deep-link route would require an argument contract decision (e.g., documentId → fetch summary) that bleeds beyond mechanical alignment.
- **Affects current request?** No.

### G-7 — No analytics event on share attempt

- **Type:** Observability ↔ coverage.
- **Evidence:** `_shareSummary` does not call `AnalyticsService.track(...)`. No `share_attempted` or `share_gated` event exists in the codebase.
- **Impact:** Operators cannot count share-gate displays vs. share-completions. Tier conversion measurement (free → plus on upgrade-tap) lacks a data path.
- **Severity:** Medium (telemetry gap, not a product-correctness gap).
- **Recommended response:** Out of scope for this session. Possible follow-up: `AnalyticsService.track('share_gate_displayed', {'tier': 'free'})` in `_shareSummary` when gated; `track('share_completed', {'tier': tier})` on successful share. Both are Tier-3 evidence once added (event captured in analytics_events box).
- **Affects current request?** No.

### G-8 — Constitution + ADR-2026-07-29-02 still *Proposed*, awaiting operator sign-off

- **Type:** Doctrine ↔ authority gap.
- **Evidence:** Both docs read *"Proposed, awaiting operator sign-off."*
- **Impact:** Doctrine hierarchy is directional, not enforceable.
- **Severity:** Medium (cross-cutting; affects every future workstream, not just this one).
- **Recommended response:** Out of scope. Sign-off is its own ADR.
- **Affects current request?** No.

### G-9 — `AGENTS.md` (or equivalent scoped instruction file) absent at the repo root

- **Type:** Instruction ↔ discoverability gap.
- **Evidence:** Grep for AGENTS.md, CLAUDE.md, CODEX.md, COPILOT.md, GEMINI.md, QWEN.md finds nothing in `~/Projects/medpiper/insurance_app/`.
- **Impact:** Future agents may not know to read `motto_v4.md` without an `agent-start` invocation.
- **Severity:** Low (`agent-start` does the discovery anyway; motto_v4 loads via that path).
- **Recommended response:** Out of scope. Hygiene improvement: create root `AGENTS.md` referencing `motto_v4.md`.
- **Affects current request?** No.

### G-10 — `analyze`-style static check not yet run (Tier-1 tooling baseline)

- **Type:** Verification ↔ evidence tier.
- **Evidence:** `flutter analyze` was not run in this session because the codebase does not compile (G-1).
- **Impact:** No static-analyzer baseline captured for the share-gate trio.
- **Severity:** Informational.
- **Recommended response:** Run after G-1 clears, on touched paths only.
- **Affects current request?** Yes — required for acceptance contract per motto §0.4 once WS-2 lands.

## C. "Tier analysis": how tested is tested, today?

- **Intended product** says: free user sees upgrade snackbar; paid user gets OS share.
- **Documented product** (DECISION_LOG.md, wedge) says: Coverage Details Summary is the high-leverage surface; gate is exact.
- **Architected product** (canonical entities) says: `checkAction('export')` is the single gate; `planLimits[PlanTier]` is the boundary; one copy of the gate-reason text.
- **Implemented product** (code on disk) says: all three pieces exist, wired correctly.
- **Tested product** (current state) says: cannot run — compile-blocked by parallel-agent refactor on auth_service.dart:303.
- **Deployed product** (last commit on main) says: commit `f941f13 feat: land CoverWise product and analytics foundation` — this commit predates the in-flight refactor; deployment is not in scope here.

The single line that prevents movement from "tested" to "verified" is `auth_service.dart:303` — and that file is owned by a parallel session. Crossing the line requires their work to land or operator escalation.

## D. Gap-rating summary

| Severity | Gaps |
|---|---|
| Blocker | G-1 |
| Critical | — |
| High | — |
| Medium | G-3, G-7, G-8 |
| Low | G-4, G-5, G-6, G-9 |
| Informational | G-2, G-10 |

## Anything else? (motto §0.1.1)

The most actionable gap (G-1) is *not* something the operator can fix unilaterally by ordering me to keep going — it is contingent on a parallel session's deliverable landing, or on a coordinated handoff (operator takes ownership of the contested files). Either way, the right next action is documented in `MANIFEST.md` "Pause decision" + "Anything else?" sections. The other gaps (G-3 through G-10) are explicit non-goals for this workstream — they are surfaced so future sessions don't rediscover them with surprise.
