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
