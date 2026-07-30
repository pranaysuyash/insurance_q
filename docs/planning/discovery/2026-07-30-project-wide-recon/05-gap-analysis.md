# 05 — Gap Analysis (Project-Wide)

**Bundle:** 2026-07-30-project-wide-recon
**Doc E (Part 0)** — project-wide gap matrix: intended product vs documented vs architected vs implemented vs tested vs deployed
**Author:** session-init agent
**Date:** 2026-07-30

---

## Reading guide

For each gap:

- **Type** — what kind
- **Evidence** — what proves the gap
- **Impact** — user / technical / operational
- **Severity** — Blocker / Critical / High / Medium / Low / Informational
- **Recommended response** — what to do (and where)
- **Affects current request?** — yes / no

## A. Project-wide gap matrix

### G-1 — Constitution / ADR-2026-07-29-02 sign-off still pending

- **Type:** Doctrine ↔ authority
- **Evidence:** Both docs read "Proposed, awaiting operator sign-off." Retrofit sign-off (recording "accepted at 2026-07-19" entries in retro-decisions) cannot proceed without explicit operator approval.
- **Impact:** Constitution binds project *directionally* only. Downstream pricing/comparison/demos/camera decisions are blocked or scoped-provisional. The 14 ADR-2026-07-19-XX substrate extensions are Accepted but their boundary with the wedge remains interpreter-dependent.
- **Severity:** High.
- **Recommended response:** Single operator ADR entry: "Constitution, Wedge, Commercial Boundary accepted at 2026-07-30. Update log appended." Triggers downstream decision making.
- **Affects current request?** Yes — affects every future project-wide decision.

### G-2 — Six test failures in `mobile/test/` dismissed without root-cause analysis

- **Type:** Test ↔ honesty
- **Evidence:** `docs/strategic_assessment_2026-07-17.md` §2.2 lists 6 dismissed failures with diagnoses: "gapId import", "Dart compiler crash", "Missing MaterialApp", and three "timeouts."
- **Impact:** Cited as launch-blocking (motto §6 violation). Likely at least one of these is real.
- **Severity:** High (per Buffy). **Re-evaluated 2026-07-30:** actually **Medium** — see "Re-evaluation" subsection.
- **Recommended response:** Each failure: read its test source, identify whether it broke `main` or whether it was pre-existing without root-cause investigation. Fix or remove with explicit reason. Per retro-Decision 2026-07-18-05's discipline: dismiss-test without investigation = "the system must explain its own state" violation.
- **Re-evaluation 2026-07-30 (in this bundle's session):** All 6 dismissed tests pass when run individually against production code with `--dart-define-from-file=.dartdefine.env` (the CI config already in `.github/workflows/ci.yml:74`). Specifically:
  - `coverage_gap_tracking_test.dart` — **23/23 pass** (was "gapId import issue" per Buffy; **not** an issue).
  - `confidence_badge_test.dart` — **10/10 pass** (was "Dart compiler crash"; not real).
  - `policy_type_test.dart` — **2/2 pass** (was "timeout"; not real).
  - `global_error_boundary_test.dart` — **3/3 pass** (was "timeout"; not real).
  - `service_test.dart` — **11/11 pass** (was "timeout"; not real).
  - `widget_test.dart` — **1/1 pass** when run with `--dart-define-from-file=.dartdefine.env` (was "Missing MaterialApp"; not real — the issue was `AppConfig.baseUri` throwing `StateError: API_BASE_URL is required`, fixed by the `--dart-define-from-file` flag).
  - **Conclusion:** zero source-code changes were needed. **The dismissals were wrong.** Buffy's P0 launch-blocker claim was based on local runs that lacked the env flag. CI is unaffected because CI uses the flag.
- **Updated recommended response:** Update `docs/strategic_assessment_2026-07-17.md` §2.2 with this re-evaluation; record as Decision 9 in `DECISION_LOG.md`. **Do not change test source code.**
- **Affects current request?** Yes — Decision 9 lands in this session.

### G-3 — Backend granularity mismatch (5 frontend stages vs 3 backend states)

- **Type:** Code ↔ honesty
- **Evidence:** ProcessingStatusScreen shows 5 sub-stages (OCR → Extraction → Classification → Indexing → Complete) but backend exposes only 3 states (`processing` → `completed` → `failed`). Frontend simulates progression.
- **Impact:** User sees stage 3/5 indefinitely when backend is slow; trust erosion.
- **Severity:** High (per Buffy P0).
- **Recommended response:** Either add real stage reporting to backend or simplify frontend to actual states.
- **Affects current request?** No.

### G-4 — On-disk What-If Calculator violates constitution Gate C

- **Type:** Code ↔ product-boundary
- **Evidence:** `mobile/lib/screens/what_if_calculator_screen.dart` exists; constitution Gate C rejects speculative adequacy/premium queries; ADR-2026-07-19-13 ("What-If Premium = refused as a product capability") is Accepted.
- **Impact:** Constitution says no; code says yes; on-disk contradiction.
- **Severity:** Medium.
- **Recommended response:** Either remove the screen and its route registration or refactor into "Coverage Adequacy" (cite-stated-only, per retro-Decision 2026-07-19-17). Per the wedge's surface table, adequacy is IN scope as "what the policy states for a user-selected scenario, plus unknowns" — but premium estimates, outcome prediction, purchase advice are OUT. The current implementation needs audit.
- **Affects current request?** No.

### G-5 — `_shareSummary` no analytics events

- **Type:** Observability
- **Evidence:** `CoverageDetailsSummaryScreen._shareSummary` does not call `AnalyticsService.track`. Free→Plus conversion via share-gate lacks telemetry.
- **Severity:** Medium.
- **Recommended response:** Add 2 events (`share_gate_displayed` per tier, `share_completed` per tier).
- **Affects current request?** No.

### G-6 — `CoverageDetailsSummaryScreen` is 935-line god-object

- **Type:** Code ↔ maintainability
- **Evidence:** Line count from `wc -l`. 6 type-specific builders inline. Audit 2026-07-23 §3.3 noted.
- **Impact:** Cost-of-add for new policy type / new section / new gate.
- **Severity:** Medium.
- **Recommended response:** Decompose into smaller widgets (`_HeaderCard`, `_BenefitsSection`, each type-specific section as its own widget).
- **Affects current request?** No.

### G-7 — 32 screens vs ~15 recommended for solo launch

- **Type:** Scope ↔ maintenance burden
- **Evidence:** Buffy §2.4 enumerates the 32 vs recommended ~15. Constitution P12 says long-term ≠ maximalism.
- **Impact:** Maintenance drag for solo founder.
- **Severity:** Medium.
- **Recommended response:** Apply the cut/keep/finish framework (retro-Decision 2026-07-19-08 / ADR-2026-07-19-08) to the 32 screens. Cut: Claims Assistant (narrowed), Claim Tracking, Insurance Literacy, Digital Insurance Card, What-If Calculator. Keep-finish: Coverage Summary, Q&A, Dashboard, Documents, Policy Detail, Emergency, Settings, Profile + main nav + core flow.
- **Affects current request?** No.

### G-8 — Legal-risk copy inventory: 83 files / 1,793 lines flagged

- **Type:** Compliance
- **Evidence:** `docs/legal_risk_copy_audit_2026-07-24.md`. Two remediation docs exist (`legal_risk_remediation_2026-07-25.md`, `legal_risk_remediation_priority_2026-07-25.md`).
- **Impact:** Customer trust + regulatory risk.
- **Severity:** High (likely launch-blocking).
- **Recommended response:** Track remediation ticket status; flag any Category C (billing/entitlement) gaps.
- **Affects current request?** No.

### G-9 — Content audit 2026-07-19: 14 of 44 strings need review

- **Type:** Copy / voice
- **Evidence:** `docs/CONTENT_AUDIT_2026-07-19.md`.
- **Impact:** Voice inconsistency, jargon leakage ("grounded", "substrate", "parser pipeline"), missing legal references.
- **Severity:** Medium.
- **Recommended response:** Voice remediation pass; replace jargon with user language; add Privacy Policy / ToS links near claim-assistance.
- **Affects current request?** No.

### G-10 — `AGENTS.md` absent at repo root

- **Type:** Discovery hygiene
- **Evidence:** No `AGENTS.md` / `CLAUDE.md` / `CODEX.md` / `GEMINI.md` / `QWEN.md` / `COPILOT.md` at root or nested.
- **Impact:** Agents that bypass `agent-start` miss the doctrine stack.
- **Severity:** Low.
- **Recommended response:** Create `AGENTS.md` referencing `motto_v4.md` + constitution + wedge + DECISION_LOG + DESIGN + ADR index.
- **Affects current request?** No.

### G-11 — Live deployment uncertain

- **Type:** Operational
- **Evidence:** README §"Launch status" — "CoverWise is **not yet deployed for customer use**." ADR-2026-07-21-06 ("deployed launch health gate") referenced; backend paths documented.
- **Impact:** Cannot claim release in this session.
- **Severity:** Informational.
- **Recommended response:** Track via deployment dashboard; not a project-scope blocker.
- **Affects current request?** No.

### G-12 — Legal source-of-truth duplication

- **Type:** Documentation bloat / Canonicity
- **Evidence:** `legal_risk_copy_audit_2026-07-24.md` flags: legal docs exist in both `docs/legal/` AND `mobile/assets/legal/`.
- **Impact:** Two copies of canonical policy text can drift.
- **Severity:** Medium.
- **Recommended response:** One canonical source; the other is a generated/symlinked copy. `motto_v4.md` §7 (supersession) + constitution P8 (one canonical path).
- **Affects current request?** No.

### G-13 — Launch-claim registry location not visible

- **Type:** Claim registry
- **Evidence:** `motto_v4.md` §0.11.1 requires the registry at `docs/launch_claims/`. README §0.11.1 references "launch-claim registry"; ADR-2026-07-19-09 establishes the evidence-backed contract. But registry content not surfaced in this session's reads.
- **Impact:** Each launch claim ("evidence-backed", "private", "verified", "offline-ready", "family-aware") must map to a registry entry with enforcing test.
- **Severity:** High if registry is incomplete; Medium otherwise.
- **Recommended response:** Read `docs/launch_claims/` and confirm it tracks every public claim with enforcing test + Tier 3+ evidence.
- **Affects current request?** No (this session did not surface).

### G-14 — Documentation bloat (Buffy §2.5)

- **Type:** Documentation bloat
- **Evidence:** ~20 stale planning docs; Buffy recommends consolidation.
- **Impact:** Operator cognitive load.
- **Severity:** Medium.
- **Recommended response:** Apply consolidation: keep decision index, constitution, wedge, commercial, 10 recent ADRs, audit cross-references. Move others to `docs/archive/`.
- **Affects current request?** No.

### G-15 — Hero copy "evidence-backed" terminology (legal risk)

- **Type:** Voice / legal
- **Evidence:** `legal_risk_copy_audit_2026-07-24.md` Category F (AI capability and accuracy signaling).
- **Impact:** Customer-facing messaging needs precise legal safety in every locale.
- **Severity:** High (per legal audit taxonomy).
- **Recommended response:** Pass of voice/copy + legal review; tracking tickets exist.
- **Affects current request?** No.

### G-16 — Hindi localization not deeply audited

- **Type:** Localization
- **Evidence:** `app_hi.arb` referenced in legal audit search scope; not deeply read in this session.
- **Impact:** Same legal-risks apply; needs Hindi-language voice/copy review.
- **Severity:** Medium.
- **Recommended response:** Future Hindi copy/voice session.
- **Affects current request?** No.

### G-17 — iOS deployment pending

- **Type:** Platform parity
- **Evidence:** APK ready per README; iOS sign-off per README roadmap.
- **Impact:** Half the mobile market unreachable.
- **Severity:** Medium.
- **Recommended response:** Track via deployment ticket.
- **Affects current request?** No.

### G-18 — Substrate-extension backlog (Coverage Check-in, Adequacy, Family Map, Claim Vault, Partnerships)

- **Type:** Roadmap / Wedge completion
- **Evidence:** 14 ADRs of 2026-07-19 define these. Implementation status varies.
- **Impact:** Long-term wedge completeness.
- **Severity:** Medium.
- **Recommended response:** Schedule in tracks per cut/keep/finish framework.
- **Affects current request?** No.

## B. Tier analysis (project-wide)

For the **Project → Product** lens:

| Layer | Says | Reality | Gap |
|---|---|---|---|
| Intended product | Constitution + wedge + commercial | Direction only (Proposed) | G-1 |
| Documented product | README, audit corpus, decision index | Mature; self-aware about gaps | Healthy |
| Architected product | Canonical architecture + doctrine stack | Sound; awaits sign-off | G-1 |
| Implemented product | Live mobile + backend | Substantial; pockets of debt (god-objects, on-disk constitution-violators) | G-3, G-4, G-6, G-7 |
| Tested product | 636 passing + 6 dismissed | 6 known failures uninvestigated | G-2 |
| Deployed product | Not yet | README §launch-status says "not deployed" | G-11 |

## C. Gap-rating summary

| Severity | Gaps |
|---|---|
| Blocker | (none — none are *this* session's blockers) |
| Critical | — |
| High | G-1 (doctrine sign-off), G-2 (6 test failures), G-3 (backend granularity), G-8 (legal inventory), G-13 (claim registry), G-15 (hero copy) |
| Medium | G-4 (What-If contradiction), G-5 (no share analytics), G-6 (god-object), G-7 (scope bloat), G-9 (content jargon), G-12 (legal doc duplication), G-14 (doc bloat), G-16 (Hindi), G-17 (iOS), G-18 (substrate extension backlog) |
| Low | G-10 (AGENTS.md) |
| Informational | G-11 (deployment status) |

## D. "Anything else?" (motto §0.1.1)

The pattern in this gap list is **"real implementation, honest documentation, deferred operational follow-through"**: most gaps are well-named in the corpus but not yet executed. The discovery bundle is the project-wide equivalent of what Buffy did one doc at a time. The biggest single delta an operator could make today is **G-1** (doctrine-stack sign-off): it would resolve the only "directional only" upper layer and re-enable a chain of downstream decision-making.
