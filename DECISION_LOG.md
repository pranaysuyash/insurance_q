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
