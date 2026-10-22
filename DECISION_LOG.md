# Decision Log — CoverWise Mobile UX Transformation

**Started:** 2026-07-23  
**Context:** First-principles audit → P0 execution

---

## Decision 1: P0-1 Direct-to-Camera Onboarding

**Date:** 2026-07-23
**Proposal (Agent):** Direct-to-camera onboarding — bypass DocumentsScreen for first policy. Camera opens immediately after onboarding completion, snap → instant local preview → background upload.

**Pushback (User):** Two points:
1. "I did not say that, you proposed" — correct. The user asked for audit first, not prescriptions.
2. **Technical reason:** Camera capture would need an additional OCR step (image → text → extraction pipeline), whereas the current backend pipeline handles PDF text extraction directly. Adding camera-first means: image_picker → on-device OCR (ML Kit) → upload → server extraction. That's an extra failure mode and latency hop for no gain if user has PDF.

**Current Reality:**
- `FeatureFlags.onboardingV2` exists but default `false` (camera-first UX)
- `ConsentPurpose.cameraAccess` exists in consent ledger but not requested during onboarding
- DocumentsScreen supports PDF/JPEG/PNG via file picker (20MB limit)
- Camera would need `image_picker` + runtime permission handling + on-device OCR integration

**Decision:** **Defer P0-1**. Not a P0. The file picker flow works; camera adds complexity (permissions, crop, multi-page PDF not supported natively, extra OCR hop). Revisit when activation data shows drop-off at file picker.

**Rationale:** First-principles = reduce friction to first value. But camera ≠ less friction for PDF policies (most common). File picker handles PDF + images. Camera only helps for photo-of-document. Keep simple.

**Next Trigger:** If analytics show >40% drop at DocumentsScreen, reconsider.

---

## Decision 2: P0-2 Executive Summary Card on PolicyDetail

**Date:** 2026-07-23
**Status:** Under discussion — see detailed analysis below

---

### P0-2 Executive Summary Card — Full Analysis

#### What Exists Today
| Layer | Current State |
|-------|---------------|
| **Backend extraction** (`PolicySummaryExtraction` in `src/models/extraction.py`) | 13 structured fields — NO executive_summary field |
| **LLM prompt** (`policy_extraction_service.py:166-173`) | Asks for 13 specific fields, no "TL;DR" instruction |
| **Mobile model** (`PolicySummary` in `models/policy_summary.dart`) | Mirrors backend 13 fields exactly |
| **PolicyDetailScreen** (1,439 lines) | Renders raw fields in sections: HeaderCard → MoneyRow → DatesCard → Benefits → Exclusions → WaitingPeriods → CoverageItems → QuickActions |
| **Trust gate** (lines 166-178) | Blocks entire screen if critical fields missing — shows "Not yet verified" + Ask button |

#### What "Executive Summary Card" Requires
| Component | Change Required | Effort |
|-----------|-----------------|--------|
| **Backend model** | Add `executive_summary: List[str]` (3 bullets) to `PolicySummaryExtraction` | Low |
| **LLM prompt** | Add instruction: "Generate a 3-bullet executive summary in plain language" | Low |
| **Mobile model** | Add `executiveSummary: List<String>` to `PolicySummary` + `fromJson`/`toJson`/`copyWith` | Medium |
| **API response** | Backend already returns full extraction dict — new field flows automatically | None |
| **UI** | New `_ExecutiveSummaryCard` widget inserted at line 207 (after PageHeader, before HeaderCard) | Medium |
| **Trust gate** | Summary card should show even if trust gate fails (it's derived, not extracted) | Low |

#### First-Principles Assessment

**Why this is high-leverage (P0):**
1. **The "aha moment" is currently broken** — user lands on PolicyDetail and sees 10+ raw fields. Cognitive load = high. Answer to "What am I covered for?" requires scanning 3 sections.
2. **Trust gate makes it worse** — if extraction incomplete, user sees "Not yet verified" + Ask button. They get *zero* value from the upload.
3. **Executive summary is derived, not extracted** — LLM already has full context. Adding 3 bullets is near-zero marginal cost.
4. **Mobile-first** — 3 bullets fit on one screen without scroll. Raw fields require 3-4 scrolls.

**What the card should show (3 bullets max):**
```
┌─────────────────────────────────────┐
│  📋 Your Health Policy at a Glance  │
├─────────────────────────────────────┤
│  • ₹5L coverage for hospitalization │
│  • Room rent capped at 1% of sum    │
│  • 2-year wait for pre-existing     │
└─────────────────────────────────────┘
```

**Placement:** After `CoverWisePageHeader` (line 207), before `_PolicyActionsRow` (line 250) and `_CitedFieldsSection` (line 255). This is the *first thing* user sees after the title.

**When trust gate triggers** (`!hasMinimumViableEvidence`): Still show executive summary if we have *any* extracted fields (it's a derived synthesis, not a critical field). Current gate blocks entire screen — that's the bug to fix alongside this.

#### Risk Assessment
| Risk | Likelihood | Mitigation |
|------|------------|------------|
| LLM hallucinates in summary | Low (temp=0.1, structured output) | Validate: each bullet must reference an extracted field |
| Extra backend field breaks old mobile builds | None (additive field, optional in JSON) | Mobile `fromJson` handles missing keys gracefully |
| Summary duplicates raw fields below | Medium | Card labeled "At a glance" — raw sections below for detail |
| Trust gate still blocks if critical fields missing | High | **Fix trust gate:** show summary card even in unverified state, gate only raw sections |

#### Implementation Sequence (if approved)
1. **Backend** (30 min): Add `executive_summary` to `PolicySummaryExtraction` + prompt instruction
2. **Mobile model** (20 min): Add field to `PolicySummary` + serialization
3. **UI widget** (45 min): `_ExecutiveSummaryCard` using `CoverWiseSurface` + `CoverWiseIconBadge` + 3 bullet texts
4. **Integration** (15 min): Insert at line 207 in `PolicyDetailScreen.build`
5. **Trust gate fix** (30 min): Modify `_buildUnverifiedSummaryScaffold` to show summary card + Ask button

**Total: ~2 hours end-to-end**

---

**Decision:** ✅ Approved — implementation started 2026-07-23

---

## Decision 3: P0-3 Streaming QA Answers

**Date:** 2026-07-23
**Status:** ✅ Approved — implementation completed 2026-07-23

### Implementation Summary:
- Added `generate_stream()` method to `LLMClient` in `src/llm/client.py` with SSE-compatible token streaming
- Added `query_rag_stream()` method to `RAGPipeline` in `src/rag/pipeline.py` that streams LLM tokens
- Added `/query/stream` endpoint in `src/app/main.py` with SSE response
- Added `queryDocumentStream()` to `QueryService` in `mobile/lib/services/query_service.dart` with SSE parsing
- Added `_askQuestionStream()` to `QaScreen` in `mobile/lib/screens/qa_screen.dart` that updates UI token-by-token
- Modified `_StandardQuestionsTab` and `_CustomQuestionTab` to use streaming version

**Total effort:** ~3 hours end-to-end

---

## Decision 4: P0-4 Dynamic More Screen

**Date:** 2026-07-23
**Status:** ✅ Approved — implementation completed 2026-07-23

### Implementation Summary:
- Converted `MoreScreen` to `ConsumerWidget` that watches `documentsProvider`, `policySummariesProvider`, `mergedFamilyMembersProvider`
- Created `_DynamicMoreContent` that builds sections dynamically based on user state:
  - "Find and carry" (Search, Emergency, Insurance cards) — only if has documents
  - "Plan your cover" (Family, Renewals, Coverage gaps, Compare, What-if) — only if has policies
  - "Claims and learning" (Insurance basics) — only if has policies
  - "Account and support" (Profile, Advisor requests, Settings, Notifications, Help, Privacy, About) — always
  - "Get started" — only if no documents
- Removed all "Coming soon" items (Claims info guide, My claims log)
- Family section moved to ProfileScreen with `_FamilySection` widget
- Added localization string `profileFamilySection`

**Total effort:** ~2 hours

---

## Decision 5: Nav Restructure (5 tabs → 4 tabs + FAB)

**Date:** 2026-07-23
**Status:** ✅ Approved — implementation completed 2026-07-23

### Implementation Summary:
- Changed `MainNavigation` from 5 tabs to 4 tabs + centered FAB:
  - Tab 0: Home (Dashboard)
  - Tab 1: Policies (was Documents)
  - Tab 2: Insights (new — Renewals, Coverage gaps, Compare, What-if, Claims, Literacy)
  - Tab 3: Profile (was Family + More + Account combined)
- Added `FloatingActionButton.extended` for "Ask" (QA) — cross-cutting action
- Created `InsightsScreen` combining all planning/analysis tools
- Added Family section to ProfileScreen
- Moved demo navigation from Ask tab (index 2) to Policies tab (index 1)
- FAB positioned at `centerDocked` for thumb reachability

**Total effort:** ~2 hours

---

## Decision 6: P0-2 Executive Summary Card on PolicyDetail

**Date:** 2026-07-23
**Status:** ✅ Approved — implementation completed 2026-07-23

### Implementation Summary:
- Added `executive_summary: List[str]` to `PolicySummaryExtraction` in `src/models/extraction.py`
- Updated LLM prompt in `src/services/policy_extraction_service.py` to generate 3-bullet summary
- Added `executiveSummary` field to `PolicySummary` model in `mobile/lib/models/policy_summary.dart` with serialization
- Created `_ExecutiveSummaryCard` widget at line 207 in `mobile/lib/screens/policy_detail_screen.dart` using `CoverWiseSurface` + bullet list
- Modified trust gate in `policy_detail_screen.dart` to show executive summary even when `!hasMinimumViableEvidence` (derived data, not extracted)

**Total effort:** ~2 hours

---

## Decision 7: Coverage Details Summary Share-Gate Verification — Verified, No Code Change Required

**Date:** 2026-07-30
**Status:** ✅ Verified — Tier 1 + Tier 2 + Tier 3 evidence obtained; no production code changed

### Context

The IDE surfaced `mobile/test/coverage_details_summary_screen_test.dart` for a verification workstream. The user explicitly framed the work as "the full thing, not just Part 0," which the agent interpreted as verification-first execution of the approved plan. The plan's preferred outcome was "Default — no change. Run the test. If it passes, document. If it fails, apply the smallest coherent delta."

### Update log (per motto §0.12.1 — append, do not edit)

- **2026-07-30 (initial pause):** WS-1 verification surfaced a `createdAt` type-mismatch compile error inside an in-flight parallel-agent refactor on `mobile/lib/services/auth_service.dart` (lines 302→303, comment shifted between polls — confirming live editing). Per motto §23 addendum (2026-07-28 — Parallel-editor hold and resync protocol), the agent paused rather than patching the contested file. Operator chose "Wait + poll for compile to clear" as the resolution path.
- **2026-07-30 (resolution):** During the time the discovery bundle was being authored, the parallel agent landed the defensive `DateTime.tryParse` form on `auth_service.dart:303`. Final WS-1 run: 6/6 share-gate tests pass in 27 seconds. Regression run: 32/32 tests pass (`entitlement_test` + `coverage_share_text_test`) in 7 seconds. `flutter analyze` on the trio (`CoverageDetailsSummaryScreen`, `EntitlementNotifier`, `Entitlement` model, the test file, `HiveTestHelper`): No issues found. Status flipped from "paused" to "verified, no code change required."

### Decision

**No code change.** The 6 share-gate test contracts were already correct; the production wiring was already correct; the gate-reason copy at `mobile/lib/providers/entitlement_provider.dart:checkAction('export')` is the single canonical source of truth. Tier 2 + Tier 3 evidence confirms both ends match.

### Evidence tier achieved

| Tier | Source | Outcome |
|---|---|---|
| 1 — static inspection | `04-current-state-architecture.md` §G (state flow analysis) | Aligned by manual trace |
| 1 — static analyzer | `flutter analyze <trio>` | No issues found |
| 2 — targeted test | `flutter test test/coverage_details_summary_screen_test.dart` | 6/6 pass in 27s |
| 3 — regression | `flutter test test/entitlement_test.dart test/coverage_share_text_test.dart` | 32/32 pass in 7s |
| 4 — runtime/manual | (debug APK) | Out of scope (no APK device available) |
| 5 — production | (deployment) | Out of scope (not deployed) |

### Rationale

1. **motto §23 / 2026-07-28 Addendum** — contested files were paused, not patched; that discipline held.
2. **motto §13 (Scope Expansion Control)** — patching `auth_service.dart` would have been unapproved scope expansion into the parallel-agent's auth refactor.
3. **Constitution §8 (One canonical path per truth)** — the gate-reason copy has exactly one source location; fragmenting it would be a regression.
4. **Verification-first discipline** — better to document evidence than invent unjustified code changes.

### Files / artefacts produced (this workstream)

- `docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/MANIFEST.md` (outcome + WS-1 evidence + re-resolution)
- `docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/01-instruction-applicability-map.md` through `09-anything-else.md` (Documents A–I per the system-prompt Part 0 template; motto §0.3.1 "Everything Is a Documentation Candidate" honored)
- This Decision 7 entry (canonical append)
- Plan file: `~/.commandcode/plans/coverwise-coverage-details-summary-share-gating.md` (pre-approval contract, distinct role)

### Files NOT touched (out of scope, blast-radius-clean)

- `mobile/lib/main.dart`, `mobile/lib/services/auth_service.dart`, `mobile/lib/services/principal_key_service.dart`, `mobile/lib/services/hive_workspace_service.dart`, `mobile/lib/providers/auth_provider.dart`, `mobile/lib/config/app_config.dart`, `mobile/lib/screens/coverage_gap_screen.dart`, `mobile/test/widget_test.dart`, `mobile/pubspec.yaml`, `mobile/pubspec.lock` — all 10 modified files in `mobile/` were pre-existing parallel-agent work. Verified via `git status -s` and `git diff --stat docs/` (no diff outside the new bundle directory).
- `mobile/lib/screens/coverage_details_summary_screen.dart`, `mobile/lib/providers/entitlement_provider.dart`, `mobile/lib/models/entitlement.dart`, `mobile/test/coverage_details_summary_screen_test.dart`, `mobile/test/helpers/hive_test_helper.dart` — all canonical and unchanged.

### Trade-offs accepted

- The 935-line god-object status of `CoverageDetailsSummaryScreen` is acknowledged and out of scope (motto §0.13).
- The substring assertion in test 1 is by-design flexibility (allows copy tweaks without test churn) but undocumented; flagged for follow-up at G-4 in `05-gap-analysis.md`.
- The `_shareSummary` analytics gap (no `share_gate_displayed` or `share_completed` events) is flagged for follow-up at G-7.
- No `AGENTS.md` exists at the repo root; flagged for hygiene follow-up.

### Anything else? (motto §0.1.1)

The discovery bundle under `docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/` carries Documents A–I, the WS-1 evidence (compile-error traces and the parallel-refactor resolution), and the gap/open-question/risk registers for future sessions. The pause-then-resolve execution pattern is documented inline so future operators can adopt or refine it. The constitution's doctrine hierarchy was treated as *Proposed* throughout; if `ADR-2026-07-29-02-doctrine-stack-reconciliation.md` later flips to Accepted, downstream workstreams should re-classify this bundle's gate verdicts.

### Total effort (this workstream)

Verification + 10-file discovery bundle + canonical DECISION_LOG append + plan file. ~2 hours of agent time, no human-time blocking.

---

## Decision 8: Project-Wide Part 0 + Part 1 Discovery Bundle Authored (No Code Change)

**Date:** 2026-07-30
**Status:** ✅ Bundle authored (`docs/planning/discovery/2026-07-30-project-wide-recon/`); no production code changed

### Context

Operator requested "the full thing" — full system prompt Part 0–16 execution at project scope. After workstream-scope Decision 7, the operator clarified project scope. This Decision 8 records the project-wide Part 0 + Part 1 effort.

### Implementation summary

- Authored 12 files (MANIFEST + 11 numbered docs) under `docs/planning/discovery/2026-07-30-project-wide-recon/`.
- Coverage: doctrine stack (motto_v4, constitution, wedge, commercial, ADR-2026-07-29-02), audit corpus (Buffy's strategic assessment, content audit, legal-risk audit, doctrinal decisions), project reconstruction A–I categories, gap matrix (18 project-scope gaps), open questions (16), risks (20), "Anything else?" standing prompt (12 items), mission restatement, Parts 2-16 planning skeleton.
- No production code changed. No commit performed (operator handles commits separately per session-end direction).

### Rationale

1. **motto §0.13 (scope expansion control)** — project-wide Part 0 was complete-able in a single session; Parts 8-16 require operator-authorised implementation work which is multi-session scope.
2. **Documentation-first (constitution §8, motto §0.3.1)** — durable documents belong before speculative execution.
3. **Authority discipline (motto §3 + ADR-2026-07-29-02)** — operator sign-off required for project-wide directives; this Decision is positioned for that review.

### Total effort

12 files, 2,075 lines, single session of agent time.

---

## Decision 9: Six "Dismissed" Tests Are Actually Passing — Retract Buffy §2.2

**Date:** 2026-07-30
**Status:** ✅ Re-evaluation complete; no source code change required; `docs/strategic_assessment_2026-07-17.md` §2.2 superseded

### Context

`docs/strategic_assessment_2026-07-17.md` (Buffy's strategic assessment) §2.2 listed six Flutter test failures as "dismissed" with diagnoses ("gapId import issue", "Dart compiler crash", "Missing MaterialApp", three "timeouts"), and §3 P0 #1 named them as a launch blocker. The 2026-07-30 project-wide Part 0 re-validation of G-2 in the discovery bundle (`docs/planning/discovery/2026-07-30-project-wide-recon/05-gap-analysis.md`) actually ran each test and revealed the diagnoses were wrong.

### Implementation summary

Ran each of the 6 dismissed tests in isolation:

| Test | Per-file outcome (no source change) | Buffy's stated diagnosis |
|---|---|---|
| `coverage_gap_tracking_test.dart` | **23/23 pass** | "gapId import issue" — **not real** |
| `confidence_badge_test.dart` | **10/10 pass** | "Dart compiler crash" — **not real** |
| `policy_type_test.dart` | **2/2 pass** | "timeout" — **not real** |
| `global_error_boundary_test.dart` | **3/3 pass** | "timeout" — **not real** |
| `service_test.dart` | **11/11 pass** | "timeout" — **not real** |
| `widget_test.dart` | **1/1 pass** when run with `--dart-define-from-file=.dartdefine.env` | "Missing MaterialApp" — **not real** (the actual cause was `AppConfig.baseUri` throwing `StateError: API_BASE_URL is required`; the env flag in `.github/workflows/ci.yml:74` provides it) |

Then ran all 6 together with the same CI flags (`flutter test --concurrency=1 --dart-define-from-file=.dartdefine.env`): **50 cases, 0 failures, ~4 seconds**.

### Real cause of the local-machine dismissals

Local `flutter test test/foo.dart` runs without `--dart-define-from-file=.dartdefine.env`. In that mode:
- `widget_test.dart` calls `InsuranceApp()` → `_startup()` → `AppConfig.isProduction` returns true (default) → `baseUri` throws `StateError`. The test never reaches the assertions.
- Running many tests in parallel causes a Flutter test-runner `stream_channel` cascade that masks the actual signal.

CI runs without these problems because CI has the flag and `--concurrency=1`.

### Decision

Retract Buffy §2.2's "dismissed failures" diagnoses. The six tests are not failures. **No source-code change is required.**

### Update log (per motto §0.12.1)

- **2026-07-30:** Original §2.2 assessments retracted; this entry supersedes.

### Files affected

- `docs/strategic_assessment_2026-07-17.md` §2.2 — appended dated supersession note (see Decision 9 appendix below).
- `docs/planning/discovery/2026-07-30-project-wide-recon/05-gap-analysis.md` G-2 — re-evaluated with this evidence.
- `DECISION_LOG.md` — Decision 9 entry (this file).

### Rationale

1. **motto §0.7 (AI Output Boundary)** — re-verifying diagnoses against current state is required before accepting any claim.
2. **motto §5 (Stale State)** — the dismissal predates the `--dart-define-from-file` flag being added to CI.
3. **motto §0.3 (Documentation Continuity)** — durable knowledge survives in this entry; the §2.2 addendum preserves original text + records the supersession.

### Trade-offs

- **Cost:** ~5 minutes of test runs.
- **Net:** launch-blocker claim "all 6 tests must be fixed" is retracted. CI is unaffected. Future agents reading §2.2 will see the dated addendum and not re-derive the wrong diagnosis.

### Total effort

5 minutes of verification + 3 file edits (Decision 9 entry, §2.2 addendum, G-2 re-evaluation).

---

### Decision 9 Appendix — supersession text to add to `docs/strategic_assessment_2026-07-17.md` §2.2

> **Addendum (2026-07-30):** §2.2's six "dismissed failures" diagnoses are **superseded** per `DECISION_LOG.md` Decision 9. Re-running each of the six tests in isolation against current `main` (commit `f941f13`) with the same flags as CI (`flutter test --concurrency=1 --dart-define-from-file=.dartdefine.env`) shows all 50 individual test cases pass, in ~4 seconds. The original diagnoses were based on local `flutter test` runs that lacked `--dart-define-from-file=.dartdefine.env`; in that mode `widget_test.dart` fails because `AppConfig.baseUri` throws `StateError: API_BASE_URL is required`. CI includes the env flag (`mobile/.github/workflows/ci.yml`), so CI does not exhibit the failure. **No source-code change was required.** Per motto §0.12.1, this supersession is recorded as Decision 9 in `DECISION_LOG.md`. Original §2.2 text preserved as historical record.

---

## Decision 10: Multi-Policy Upgrades: Family Workspace Sync, SSE Streaming Grounding, Umbrella Deductible Analysis & Detail Modularization

**Date:** 2026-08-24
**Status:** ✅ Implemented and Verified across Backend, Mobile, and Benchmark Suites

### Context

Following the Persona audit and doctrine-aligned improvement mandate, the system had four critical architectural gaps:
1. **Isolated Family Workspace**: Family member profiles and coverage dependencies were trapped in device-local `SharedPreferences` without cross-device synchronization or backend auditability.
2. **Streaming Grounding Gap**: SSE streaming responses emitted answer tokens but omitted structured citation verification status, causing citations and confidence badges to render only on non-streaming paths.
3. **Umbrella & Deductible Coordination Deficit**: Multi-policy holders (e.g. Base Health + Super Top-up) had no automatic aggregate sum insured calculations or deductible gap detection.
4. **God-Widget in Policy Detail Screen**: `mobile/lib/screens/policy_detail_screen.dart` had grown to over 3,500 lines with 6 domain-specific cards bundled in a monolithic file.

### Implementation Summary

1. **Family Workspace Sync (Component 1)**:
   - Created `src/api/family.py` mounted at `/api/v1/family` with full CRUD and offline reconciliation.
   - Authored migration `supabase/migrations/20260824000000_family_workspace.sql` with strict RLS policies.
   - Built `mobile/lib/services/family_sync_service.dart` providing offline-first sync, conflict resolution, and background sync triggers on mutations.
   - Documented in `docs/technical/family_workspace_architecture.md`.
2. **Streaming Grounding & Citations (Component 2)**:
   - Enhanced `src/rag/pipeline.py:query_rag_stream()` to verify citations against retrieved sources upon stream completion and emit a structured completion packet: `{"done": true, "verification_status": ..., "citations": [...], "confidence": ..., "sources": [...]}`.
   - Updated `mobile/lib/services/query_service.dart` and `mobile/lib/screens/qa_screen.dart` to parse this packet and render live verification badges and citations during streaming.
3. **Multi-Policy Umbrella & Deductible Coordination (Component 4)**:
   - Implemented `src/rag/umbrella_analyzer.py` (`UmbrellaCoverageAnalyzer`) calculating aggregate sum insured across policies, base vs. top-up coordination, and deductible coverage gaps.
   - Added `mobile/lib/providers/aggregate_coverage_provider.dart` to display unified coverage metrics in the mobile client.
4. **Verified Insurer Directory & Claims Hotlines (Component 6)**:
   - Added `mobile/lib/data/insurer_directory.dart` with verified 24x7 toll-free contacts for top Indian insurers (Star Health, HDFC ERGO, ICICI Lombard, Care, Niva Bupa, etc.).
   - Integrated into `mobile/lib/screens/emergency_screen.dart` as fallback when extracted policies lack insurer contact metadata.
5. **Visual Bounding-Box Overlay in PDF Viewer (Component 5)**:
   - Enhanced `mobile/lib/screens/document_preview_screen.dart` to accept citation highlights and display high-contrast amber bounding-box overlays and floating quote banners.
6. **Policy Detail Screen Modularization (Component 7)**:
   - Extracted 6 domain-specific card widgets into `mobile/lib/widgets/policy_detail/`: `health_details_card.dart`, `life_details_card.dart`, `vehicle_details_card.dart`, `home_details_card.dart`, `travel_details_card.dart`, and `marine_details_card.dart`.
   - Reduced `policy_detail_screen.dart` size by over 54% (from 3566 lines to 1625 lines), improving readability, compile times, and unit testability.

### Verification & Evidence
- Backend unit & API tests:
  - `pytest tests/test_family_api.py` (4/4 passed).
  - `pytest tests/test_streaming_citations.py` (1/1 passed).
  - `pytest tests/test_umbrella_analyzer.py` (3/3 passed).
- Mobile unit & widget tests:
  - `flutter test test/family_sync_service_test.dart` (2/2 passed).
  - `flutter test test/aggregate_coverage_test.dart` (all passed).
  - `flutter test test/document_preview_test.dart` (11/11 passed).
  - `flutter test test/insurer_directory_test.dart` (3/3 passed).
  - `flutter test test/query_scope_test.dart test/query_service_verification_contract_test.dart` (7/7 passed).
- Global Offline Sweep (`pws-v4`):
  - 16 datasets, 90 examples, 0 schema errors, 0 grounding failures across AU, CA, EU, IN, UK, US corpora (`docs/eval/2026-08-24-pws-v4-global-sweep.md`).

---

## Decision 11: Full Open-Debt Remediation Batch — Revenue Integrity, Play Store Compliance, Dead-Code Sweep, Architecture Hardening

**Date:** 2026-09-07  
**Status:** In Progress / Implementing  
**Authorized by:** User directive — "do all aligned with doctrines, long term 1st principles"

### Context

Following the completion of the 8-component multi-policy architecture overhaul (Decision 10), a comprehensive "missed-anything" sweep surfaced 20+ open debt items across revenue integrity, Play Store compliance, dead/orphan code, documentation drift, and mobile reliability. This decision records the complete remediation batch executed 2026-09-07.

### Sub-decision 11.1: Server-Side Q&A Entitlement Enforcement (C-01)

**Problem:** The `/query` endpoint had no server-side budget check. Any API caller could bypass the Q&A plan limit entirely — it was enforced only in the Flutter UI.

**Decision:** Add a `qa_usage` Supabase table (date-scoped per-user call counter) and enforce the limit at the API boundary. Free tier: `FREE_TIER_QA_LIMIT` env var (default 10/day). Paid tier: unlimited. On Supabase unavailability: fail open (log warning, allow call — never block a user due to DB unreachability). Return HTTP 429 with `{"code": "qa_budget_exhausted"}` when limit is reached.

### Sub-decision 11.2: Durable QA Content Reports (M-11)

**Problem:** `src/api/report_router.py` stored user content reports in `_REPORTS_STORE = []` — lost on every process restart. Google Play's Generative AI Content Policy requires a durable moderation record.

**Decision:** Replace in-memory store with Supabase `qa_reports` table. Report acceptance never fails (fallback to logging if Supabase is unreachable — user must always be able to report). Add admin-only `GET /qa/reports` for moderation.

### Sub-decision 11.3: Dead-Code Sweep and Archive (H-04, M-13, M-14, L-11)

**Decision:**
- Archive `src/rag/service.py` and dead modules to `src/archive/` with dated headers.
- Remove `CLAIM_VERIFICATION` and `RENEWAL_DIFF` from `JobType` enum.
- Wire `QA_RESPONSE` outbox handler: create `src/workers/qa_report_handler.py` and register in `outbox_worker.py`.

### Sub-decision 11.4: Cost Ledger Plumbing (M-12)

**Decision:** Thread `CostTracker` through the LLM extractor path in `EvidencePipeline._run_extractors()`. Deterministic extractors remain zero-cost by design. LLM extractor calls accumulate token counts into the evidence record's `total_cost_usd` field.

### Sub-decision 11.5: Deployment Platform Single-Source (D1, M-15)

**Decision:** `render.yaml` is the canonical deployment spec. README updated with "Canonical deployment platform — Render" section dated 2026-09-07. All Cloud Run / App Runner references marked historical. Root `AGENTS.md` created as the authoritative onboarding document (closes P13/D7 gap).

### Sub-decision 11.6: Full Hive AppStateRepository Migration (M-01)

**Decision:** Full migration — not constants-only. All direct `Hive.box()` call sites updated to use `AppStateRepository` getter/setter methods or `HiveWorkspaceService` lifecycle methods. `hive_box_names.dart` created as a constants layer.

### Sub-decision 11.7: Offline Upload Retry Worker (H-03)

**Decision:** Create `mobile/lib/services/upload_retry_service.dart` — a connectivity listener that detects offline→online transitions and retries pending uploads with exponential backoff.

### Sub-decision 11.8: Route Error Boundaries (L-09)

**Decision:** All named-route builders in `mobile/lib/main.dart` wrapped in `ScreenErrorBoundary`.

---

## Decision 12: ARTEMIS Android Automation Evaluation & On-Device Testing Integration

**Date:** 2026-09-14  
**Status:** Evaluated & Documented in AGENTS.md Section 4  
**Context:** Evaluation of Google's open-source `google/artemis` repository for CoverWise mobile testing.

### Problem
CoverWise mobile testing currently relies exclusively on 128 headless Flutter unit/widget tests in `mobile/test/`. While effective for logic, widget rendering, and contract testing, headless execution cannot verify:
1. Native Android plugins (`camera`, `image_picker`, `file_selector`, `google_mlkit_text_recognition`, `flutter_local_notifications`).
2. Real device UI rendering (text clipping, overflow on specific screen densities, gesture navigation).
3. System permission sheets and file chooser interactions during policy PDF/image upload.
4. Android runtime crashes, ANRs, and Logcat diagnostics.

### Evaluation of ARTEMIS
- **Source:** `https://github.com/google/artemis` (Google Pixel-Test-Engineering Fusion team).
- **Core capabilities:** Dual execution model (Flash reactive observe-think-act 3–5s/step; Pro multi-agent LangGraph planner-operator-safety-checker loop), native MCP server (`mobile_run_task`, `mobile_manage_task`, `mobile_get_device_state`, `mobile_inspect_trace`), 99%+ on AndroidWorld benchmark.
- **Fit for CoverWise:** High utility for Tier 2 on-device autonomous regression and exploratory testing. Solves the native plugin verification gap.

### Operational Constraints & Host Readiness
- **Disk headroom:** Host root filesystem `/` has only 2.4 GB free. A full Artemis installation (`uv` venv with `opencv`, `scipy`, `langchain`, etc.) plus building an Android debug APK and launching an Android emulator snapshot requires >= 10 GB free disk space.
- **Action taken:** Evaluated repository architecture, integrated operational guidance and commands into canonical `AGENTS.md` Section 4, and documented execution prerequisites for deployment once disk headroom is established.

---

## Evidence reconciliation — Supabase FTS (2026-09-30)

**Status:** Checked-in source path present; hosted migration status unknown. This entry reconciles the historical July 20 plan and does not authorize a production/provider query or schema change.

The July 20 RAG map and ADR correctly recorded that the Supabase FTS route was absent at that inspection point. Current source now contains `SupabaseVectorStore.search_fts`, owner-scoped dispatch from both standard and streaming RAG query paths, and the `20260720020000_rag_fts.sql` migration. Focused coverage exists in `tests/test_supabase_fts.py` and the synthetic adapter fixture `tests/test_supabase_pgvector_integration.py`. `./venv/bin/pytest -q tests/test_supabase_fts.py tests/test_supabase_pgvector_integration.py` could not start (exit 127: the prescribed executable is absent); the available fallback `python3 -m pytest -q tests/test_supabase_fts.py tests/test_supabase_pgvector_integration.py` passed 19 tests in 0.06s (T2/S1). No hosted database was contacted.

The map entry is retained as historical evidence and has a dated status note in `docs/review/rag_pipeline_exploration_map_2026-07-20.md`. The deployment boundary remains unresolved: `docs/debt_register.md` tracks the migration-ledger mismatch as open, and no authorized migration receipt was inspected. The next verification is an owner-authorized migration-ledger check that uses no customer policy records. Until then, report implementation in source as present and hosted application as unknown.


---

## 2026-10-09 Operational record — canonical doctrine provenance correction

**Status:** Applied to project instructions and generated context; no product-code or runtime change.

The project `AGENTS.md` incorrectly named local Operating Doctrine v6.1 as canonical, while its local generated copy was v8.0 (SHA-256 `ff848618a7431a3b…`) and the shared canonical source is Operating Doctrine v8.2 at `/Users/pranay/Projects/agent-start/doctrines/OPERATING_DOCTRINE.md` (SHA-256 `e14bab7b1964d8b755c9e6c7f5b1c2b44e1d726033fa23aeaee6ce921e271a75`). The global control plane makes the shared source authoritative and project copies generated. The evidence showed the old project doctrine added no unique substantive guidance beyond its generated header; no project content was retired.

**Action:** Correct the `AGENTS.md` provenance line and regenerate the doctrine/context pack from the canonical source using `agent-start` in offline/local-provider mode. Preserve the displaced generated v8.0 copy in `.agent/archives/`. Avoid `.env`, local policy documents, database contents, customer/real policy data, services, providers, and Git.

**Verification:** Compare source hash and generated version/provenance; verify generated prompt/session context point to the canonical doctrine root and current version. No app tests are warranted because no code or runtime behavior changed.

## 2026-10-09 Follow-up — generated doctrine header remains ambiguous

A later verification showed the provenance correction was partial. The project's `AGENTS.md` now correctly identifies the shared v8.2 doctrine as canonical, and the agent-start refresh regenerated current context. However, the project-local generated `OPERATING_DOCTRINE.md` still begins **“Status: canonical, editable source”** because the shared canonical source contains that same header and the generator copies it verbatim. The document later states that generated copies are not authoritative, so this is a contradictory header/body signal rather than evidence of two distinct doctrine contents. The generated file's SHA-256 exactly matches the canonical source (`e14bab7b1964d8b755c9e6c7f5b1c2b44e1d726033fa23aeaee6ce921e271a75`).

**Correction to the prior record:** regenerating refreshed context and fixed the project onboarding line, but did not remove the generated doctrine's misleading status header. No generated copy was hand-edited. Resolve the correct wording at the canonical doctrine/generator boundary with its owner, test on a safe fixture, and preserve the canonical source's editable-authority meaning. The agent-start family integrity check passed (10 doctrines; manifest current); this does not resolve the wording ambiguity. No app tests or runtime checks were warranted or run.

## 2026-10-14 Audit record — App Store / Play launch readiness

**Status:** Documentation only; no product code changed.

Multi-lane static audit (Claude Haiku swarm for store compliance + 42-screen UI/UX; Codex gpt-6-luna xhigh for user flows, bugs/tests, backend security/privacy). Reports and consolidated verdict: `docs/audits/app_store_readiness_2026-10-12/00_SUMMARY.md`. **Verdict: not ready.** Nine orchestrator-verified blockers, including a committed DB credential (SEC-02, rotate immediately), unauthenticated email-only account deletion (SEC-01), Q&A pack purchases that grant no credits (FLOW-12), missing Sign in with Apple / Restore Purchases / app privacy manifest, no AI not-advice disclaimer, and emergency-hotline insurer mismatch. `flutter analyze` clean and `flutter test` 1390/1390 green (2026-10-14) — tests did not detect the blockers. Backend pytest not run: `./venv` absent. Evidence tier 1 (static) + tier 2 (Flutter suite). Owner decisions listed in summary §5.
