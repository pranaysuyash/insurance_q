# 03 — Vision, Constitution, and First Principles (Project-Wide)

**Bundle:** 2026-07-30-project-wide-recon
**Doc C (Part 0)** — vision, motto alignment, gates, project-derived principles at project scale
**Author:** session-init agent
**Date:** 2026-07-30

---

## A. Canonical product statement (constitution §1)

> CoverWise is a private, source-verifiable personal insurance knowledge workspace that helps people understand and organise policies they already own. It reports what the uploaded policy workspace establishes, what it does not establish, and where each material fact comes from. It does not recommend, quote, underwrite, broker, transact, or represent claims.

Important distinctions:

- The insurance policy is the **authoritative source**.
- CoverWise is the **interpretation and organisation workspace**, not the legal source of truth.
- CoverWise knows only what the user has uploaded, what was successfully processed, and what remains current and verifiable.
- **Missing information must remain missing or unknown.** It must not become a negative conclusion.

The durable user outcome is **comprehension** — understanding and organising policies a person already owns.

The name may change. This constitution survives the rename. CoverWise is the chosen name per the 2026-07-28 founder decision; not all episodes of the doctrine accepted the name.

## B. Canonical wedge (constitution §5)

```
owned policy
  -> secure import
  -> evidence-backed policy workspace
  -> source-verifiable explanation and Q&A
  -> neutral organisation across policies and household
  -> factual reminders and emergency retrieval
  -> personal notes and document lifecycle
```

## C. Motto_v4 alignment matrix (project-wide)

| Motto clause | Status | Evidence |
|---|---|---|
| §0 (whole answer) | Honored at project-scope (50+ decisions documented) | Decision Log + 40+ ADRs |
| §0.3 / §0.3.1 (docs continuity / everything is a doc candidate) | Honored | This bundle + MANIFEST + redirect transcripts |
| §0.4 / §0.4.1 / §0.4.2 (acceptance / multi-pass) | Honored in past decisions; some retro-ADRs lack acceptance contract | 6 retroactive decisions in `docs/decisions/README.md` track `fa02854` and earlier |
| §0.5 (evidence tiers) | Honored in most documents | "Evidence tier" sections in ADRs and assessments |
| §0.6 (risk-based verification) | Honored (deployment gates, audit phases) | ADR-2026-07-21-06 deployed launch health gate; buffy's risk-based P0/P1/P2 ordering |
| §0.7 (AI output boundary) | Partially honored | Doctrine stack reconciliation does; some earlier accepted decisions lack explicit verification log |
| §0.8 (data layer rule) | Honored | Prompts as production code (extraction prompts); config as data (the 13 structured fields) |
| §0.9 (prompt/model/routing rule) | Honored | gpt-5+/o1+/o3+ compatibility fix in `src/llm/client.py` (retro-Decision 2026-07-18-09) |
| §0.10 (observability) | Honored | 3 operator dashboard views, RevOps R1 events, Sentry client |
| §0.11 / §0.11.1 (claims / launch claim registry) | Mostly honored; one gap | ADR-2026-07-19-09 establishes evidence-backed contract; claim registry location not found in this session — see `07-open-questions-register.md` OQ-9 |
| §0.12 / §0.12.1-§0.12.4 (ADR schema + appends + ADR-first + pattern families + cut/keep/finish) | Honored | 40+ ADRs; append-only update logs present in ADR-2026-07-29-02 |
| §0.13 (scope expansion control) | Tension | Buffy's "ship 15 not 32" critique; constitution's P12 (long-term ≠ maximalism) applies — not yet cut |
| §0.14 (operator workflow) | Honored | RevOps R1 + operator trust model + reason-required access |
| §0.15 (third-layer rule) | Honored | RAG pipeline is the third layer; substrate is the third (data) layer |
| §3 (git safety) | Honored | Coverage gate; load-bearing for this session |
| §4 (local work preservation) | Honored | 15 dirty files + 6 untracked items classified at session start |
| §5 (stale state rule) | Honored | Re-read every file before editing; MANIFEST.md verified both before and after the parallel-agent's fix |
| §6 ("pre-existing" is not an excuse) | Honored at observation level; tension on 6 test failures | Strategic assessment flags the gap; not yet fixed in this session |
| §7 (supersession) | Honored | 2026-07-29 addenda apply supersession discipline to audit; doctrine-stack reconciliation does the same to earlier doctrine |
| §8 (group-by-group preservation) | Honored in past commits | Multi-AUDIT Phase 0 commit `fa02854` grouped docs/infra/tests |
| §9 (artifact handling) | Honored | `mobile/build/` outputs ignored after APK removal |
| §10 (pattern & related-issue search) | Honored | Pattern families established in ADR-2026-07-29-02 §0.12.3 |
| §11–§15 (engineering/product/analysis/validation/docs standards) | Honored across the corpus | Decision index + STRATEGIC_ASSESSMENT + DESIGN + motto |
| §16–§18 (branches/cleanup/communication) | Honored in past work | "main is canonical"; cleanup on legacy AWS scripts |
| §19 (primary goal — best long-term solution) | Honored | Constitution §1 statement; wedge; durable comprehension outcome |
| §20 (no AI co-author trailers) | Honored | Past commits and this session do not include AI trailers |
| §21 (code is evidence) | Honored at substrate level | Evidence substrate (4 tables) is the implementation of this rule |
| §22 (automated checks advisory) | Honored | CI lints; constitutional decisions prioritize long-term correctness over tool satisfaction |
| §23 / 2026-07-28 addendum (parallel-authored, contested runtime boundary) | **Honored load-bearing** | This bundle's pause-then-resolve pattern during the auth_service.dart compile block |

## D. Constitution gate verdict (project-wide)

| Gate | Verdict | Notes |
|---|---|---|
| A — Outcome | Pass project-wide | Wedge serves this; surfaces match |
| B — Truth | Pass for substrate-backed features; partial elsewhere | 4-face evidence contract enforces; backend granularity mismatch on ProcessingStatusScreen violates B (simulated truth) |
| C — Role | Pass for in-scope features; violation for on-disk What-If Calculator | Code-and-product disagreement needs resolution |
| D — Lifecycle | Pass | Principal-scoped encryption, consent ledger, deletion workflows, observability substrate, launch-claim registry |
| E — Commercial | Pass at boundary level; exact prices/limits are Proposed | Free vs paid boundary exists; commercial layer awaits operator approval on pricing |

## E. First principles (project-derived, binding project-wide)

These eight principles are derived from the doctrine stack. They are the project's standard for *any* future work.

### 1. Source-of-truth precedence (motto §1.1, constitution P1)

Code is current source of truth. Documents (including constitution) are time-stamped snapshots. When conflict arises, verify behaviour against current code/runtime before deciding.

### 2. One canonical path per truth (constitution P8)

| Concern | Canonical truth |
|---|---|
| Original policy document | Supabase Storage (private bucket, principal-owned) |
| Document lifecycle | Backend state machine + append-only processing events |
| Policy-specific claims | Evidence substrate (4 immutable tables) |
| Customer-visible citation | Immutable source text + resolvable page artifact |
| Durable async work | Outbox (per retro-Decision 2026-07-18-02, ADR-2026-07-19-10) |
| Identity | Canonical anonymous or account principal + explicit migration |
| Consent | Server-side append-only consent ledger (ADR-2026-07-19-07) |
| Entitlement | Server-side entitlement ledger reconciled with store provider |
| Local sensitive data | Principal-scoped encrypted Hive (ADR-2026-07-19-06) |
| Operator access | Role-scoped, reason-required, audited (ADR-2026-07-19-12) |
| Deletion | Durable deletion workflow + completion evidence |
| Public product claims | Launch-claim registry backed by tests and runtime evidence |

**Hard rule:** no parallel truths. No legacy routes. No shadow pipelines. No simulated frontend state. No client-side truth sources that disagree with these contracts.

### 3. Evidence-graded confidence (motto §0.4.1, §0.5)

Tier 0 (assumption) through Tier 5 (production). High-risk paths (auth, billing, payment, claim workflow, eligibility, customer-facing financial/regulatory copy) require Tier 3+ before release. The "evidence-backed" launch claim is gated by tests.

### 4. Risk-based verification (motto §0.6)

Verification depth scales with failure cost. Every migration, encryption boundary, billing event, claim entry, consent withdrawal requires targeted tests. A passing unit test is not enough.

### 5. Abstracted-responsibility boundaries (constitution P5, P7)

Each major feature defines: who triggers it; what input; what processing; what state changes; what user sees; what operator sees; what happens on failure; what happens on retry; what persists locally/remotely; audit trail; support/recovery. If any of these is undefined, the feature is incomplete.

### 6. Privacy by design, not by page (constitution P6, ADR-2026-07-19-15 through -25)

Consent is purpose-specific, explicit, versioned, principal-associated, server-authoritative where remote processing occurs, append-only, withdrawable, enforceable, auditable. Privacy copy is a launch claim ("private", "never shared", "deleted", "stays local", "backed up") — each must map to a registry entry with enforcing test. Medical-records expansion requires its own ADR.

### 7. Reliability at moment of need (constitution P9)

The app may be opened during hospital admission, an accident, a renewal deadline. Reliability is designed around that moment, not "does the screen load." Resumable imports, truthful processing stages, durable retries, dead-letter recovery, stale-timestamp visibility, no silent fallback.

### 8. Long-term thinking ≠ maximalism (constitution P12, motto §0.13)

If a capability belongs to the durable wedge, finish it properly. If it's an honest thin slice, scope to the honest part. If it belongs to a different product, cut or gate. Don't keep dead code; don't drop core features mid-flight.

## F. Long-term first-principles alignment (project-wide)

| Long-term question | Project-wide answer |
|---|---|
| Real user problem? | Comprehension of insurance policies the user already owns |
| Fundamental or only symptom? | Fundamental — policy comprehension is the durable value; upload and Q&A are interfaces |
| What must remain true in three years? | Source-verifiable comprehension; abstention as valid outcome; one canonical gate per cross-cutting concern (entitlement, consent, analytics, billing) |
| Critical assumptions | (1) Backend substrate is trusted source. (2) Operator dashboard correctness is required for launch. (3) Privacy policy is enforceable. (4) Test suite is honest — no dismissed failures. |
| Long-term options preserved/eliminated | Preserved: owned-policy comparison, family organisation, factual reminders, lifecycle. Eliminated (by constitution): purchase/ranking/underwriting |
| Reversal cost for current architecture | High — wires through every layer; intentional |
| New failure modes (recent) | Pause-and-resolve pattern (#23) and audit-supersession addenda (#29) are new in this period |
| Motto alignment | §0, §0.3, §0.12 — yes |
| Constitution alignment | Gates A–E — yes |

## G. Conditions under which the vision should change

- The constitution's *durable user outcome* could change only with operator sign-off on a new ADR that revises §1 — a major change requiring operator + co-founders + legal.
- The *long-term wedge* is bound by operator feedback during signature sessions (the constitutional sign-off is precisely this kind of session).
- *Anti-principles* are durable: "the model is probably right," "a disclaimer makes the activity safe," etc., are stable rejections.

## H. Anti-principles (constitution §7) — applied project-wide

The product must reject these twelve recurring failure modes:

1. "The model is probably right." — Reject via evidence substrate + LLM honesty check.
2. "A disclaimer makes the activity safe." — Reject via activity-is-the-boundary rule.
3. "Not found means not covered." — Reject via Constitution §1 + Gate B hard rule.
4. "The UI shows progress, so progress exists." — Reject via ProcessingStatusScreen backend-granularity fix (P0 per Buffy, open work).
5. "The client says the user is paid, so entitlement is paid." — Reject via server-side entitlement reconciliation.
6. "HTTP 200 means deletion completed." — Reject via durable deletion workflow + completion evidence.
7. "The partner handles it, so our responsibility ends." — Reject via value-add partnerships framework (ADR-2026-07-19-16).
8. "The feature already exists, so it belongs." — Reject via wedge scope discipline.
9. "The feature is expensive, so it does not belong." — Reject via finish-properly-when-in-wedge (cut/keep/finish framework).
10. "More engagement means more value." — Reject; comprehension is the outcome.
11. "The source is internal; the user does not need to see it." — Reject via substrate-as-primary-deliverable.
12. "A test passed, therefore the public claim is proven in production." — Reject via launch-claim registry with Tier 3+ enforcement.

---

## Anything else? (motto §0.1.1)

The doctrine stack is the strongest foundation in this project: layered, self-describing, append-only by design, with explicit provenance chains. The work to *operationalise* it (sign-off, registry maintenance, follow-through on cut/keep/finish cut items) is the biggest open category. Future sessions should treat doctrine-stack ratification as their highest-leverage available contribution.
