# 03 — Vision, Constitution, and First Principles

**Bundle:** 2026-07-30-coverage-details-summary-share-gating
**Doc C (Part 0)** — vision, motto alignment, constitution alignment, project-derived principles
**Author:** session-init agent
**Date:** 2026-07-30

---

## A. Canonical product statement (from proposed constitution §1)

> CoverWise is a private, source-verifiable personal insurance knowledge workspace that helps people understand and organise policies they already own. It reports what the uploaded policy workspace establishes, what it does not establish, and where each material fact comes from. It does not recommend, quote, underwrite, broker, transact, or represent claims.

The name may change. This constitution survives the rename.

Important distinctions:

- The insurance policy is the **authoritative source**.
- CoverWise is the **interpretation and organisation workspace**, not the legal source of truth.
- CoverWise knows only what the user has uploaded, what was successfully processed, and what remains current and verifiable.
- **Missing information must remain missing or unknown.** It must not become a negative conclusion.

The durable user outcome is **comprehension** — understanding and organising policies a person already owns.

## B. Canonical product wedge (from constitution §5)

```
owned policy
  -> secure import
  -> evidence-backed policy workspace
  -> source-verifiable explanation and Q&A
  -> neutral organisation across policies and household
  -> factual reminders and emergency retrieval
  -> personal notes and document lifecycle
```

Coverage Details Summary Screen is named in `FIRST_PRINCIPLES_WEDGE.md §3.3` as the screen "closest to the wedge of any screen" — making it a high-value surface for this workstream's verification focus.

## C. Motto_v4 alignment matrix (this workstream vs operating doctrine)

| Motto clause | Status | Evidence |
|---|---|---|
| §0 (whole answer) | Honored | Plan spans Part 0 → verification + delivery; not a sprint cut short |
| §0.3 (docs continuity) | Honored | This bundle + MANIFEST.md + plan file |
| §0.3.1 (everything is a doc candidate) | Honored | All findings moved to durable markdown, not chat |
| §0.4 (acceptance contract) | Honored | Final report will fill the contract |
| §0.4.2 (multi-pass review) | Honored | Plan §9 documents Pass 1/2/3 outcomes |
| §0.5 (evidence tiers) | Honored | Tier 1 (static) + Tier 2 (test) planned; final reports tier |
| §0.6 (risk-based verification) | Honored | Share gate = user-visible; high-stakes verification depth |
| §0.7 (AI output boundary) | Honored | Re-read every file before any edit; current state verified |
| §0.11.1 (launch-claim registry) | N/A | Gate-reason copy is user-visible but not a launch claim |
| §0.12 (decision record) | Honored | Will append only if a real code change is made |
| §0.13 (scope expansion) | Honored | 935-line screen not refactored; canonical locations preserved |
| §4 (local work preservation) | Honored | 10 dirty files + 5 doc files preserved untouched (auth_service tracked only via read) |
| §5 (stale state) | Honored | Re-read files between tool calls |
| §6 ("pre-existing" is not an excuse) | Honored at static level; paused on dynamic level due to §23 |
| §7 (supersession) | N/A | No superseding path here |
| §20 (no AI co-author trailers) | Honored | No commits at all |
| §21 (code is evidence) | Honored | Refactor-driven changes tracked separately; not in this bundle |
| §22 (automated checks advisory) | Honored | Plan to run `flutter analyze` on touched paths if any change is made |
| §23 / 2026-07-28 (parallel-editor hold) | **Honored — load-bearing for this session** | auth_service.dart line shifts observed; pause documented |

## D. Constitution gate verdict (this workstream)

| Gate | Verdict | Notes |
|---|---|---|
| A — Outcome | PASS | Improves audit trail of share-gate enforcement |
| B — Truth | PASS | Tests assert against production contract; no fabricated claims |
| C — Role | PASS | Mechanical alignment; no advisory surface added |
| D — Lifecycle | N/A | No principal, consent, deletion, storage change |
| E — Commercial | PASS | `planLimits` table is the single source of truth; we test against it but do not edit it |

## E. First principles (project-derived, binding for this work)

These are the four principles that anchor this workstream. They are **not** generic; they are derived from `motto_v4`, the proposed constitution, and verified evidence from the repo.

### 1. Source-of-truth precedence (motto §1.1, constitution P1)

Code is current source of truth. Documents (including `motto_v4` and the constitution) are time-stamped snapshots. Tests assert behaviour; if tests and docs diverge, tests are correct.

**Implication:** the share-gate test is the contract. If the production gate disagrees with the test, the production code is wrong or stale — *not* the test. Work either aligns production to the test (smallest-coherent-delta) or upgrades the test to reflect deliberate production changes (and only if production has a documented reason to drift).

### 2. One canonical path per truth (constitution P8)

The gate-reason message lives in exactly one place: `mobile/lib/providers/entitlement_provider.dart:checkAction`. The test asserts against that location via substring match. Multiple sources of gate-reason copy would be a regression.

**Implication:** any change to the gate-reason copy must occur at the source location, or it must add a *new* canonical location with its own supersession ADR. Spreading the copy across screens would violate P8.

### 3. Risk-based verification (motto §0.6)

A user-visible gate. Failure modes:

- Free user with paid feature unlocked = trust violation, possible regulatory issues.
- Paid user denied their feature = revenue-customer loss + trust violation.

Both are top-decile failure costs. Verification depth must match.

**Implication:** passing the test is necessary but not sufficient. A reviewer should also be able to read the screen and gate code end-to-end and confirm: (a) the snackbar surfaces with the right text, (b) the upgrade action routes correctly, (c) paid-tier users do *not* see the snackbar.

### 4. Evidence-graded confidence (motto §0.4.1, §0.5)

- Tier 1 (static inspection) — review only; not enough for "done".
- Tier 2 (targeted test passed) — acceptable for completion if no high-risk paths exist beyond the tested scope.
- Tier 3 (integration / end-to-end) — needed when adjacent contracts are involved (here: PlanLimits + checkAction + snackbar + Plans screen route).
- Tier 4 (visual / runtime manual) — would require debug-APK observation; not feasible in this session.

**Implication:** "Tests pass" alone is Tier 2. Tier 3 is reachable by additionally running `entitlement_test.dart` and `coverage_share_text_test.dart`. Both must pass before declaring done, given the screen + snackbar + gate interlock.

## F. Long-term first-principles alignment

| Long-term first-principles question | Answer (this workstream) |
|---|---|
| What real user problem are we solving? | Trust surface: a paid feature must not be silently denied or granted; a free user must see honest gate messaging |
| Is this the root problem or a symptom? | Symptom → root. Symptom: stale test assumptions. Root: gate + test contracts drifted; this workstream is alignment, not invention |
| What must remain true in three years? | The gate function remains the single source of truth; the test continues to assert all three tier scenarios + PlanLimits invariants |
| Which assumptions are being made? | PlanLimits table is canonical; checkAction is the single gate; substring match on the gate-reason is intentional test flexibility |
| What evidence supports those assumptions? | Live inspection of `mobile/lib/models/entitlement.dart`, `mobile/lib/providers/entitlement_provider.dart`, and the test file in this session |
| What existing contract does this affect? | The user-visible share button + snackbar + Plans navigation on the Coverage Details Summary screen |
| What future options does this preserve/eliminate? | Preserves: freedom to add new tier cases; freedom to harden substring match → exact match. Eliminates: nothing |
| Cost of reversal? | Low — all in test/screen/snackbar trio |
| New failure modes? | Only if WS-2 makes a code change: potential test brittleness if `find.text('Upgrade')` becomes too narrow |
| Aligns with motto_v4? | Yes |
| Aligns with constitution? | Yes (Gates A-E) |
| Aligns with durable user promise? | Yes: comprehension + honest gating |

## G. Conditions under which this vision should change

None for this workstream. The share gate is a steady-state feature within the wedge. Vision change would require an evidence-backed ADR modifying either the constitution or the wedge — none proposed here.

## H. Anti-principles (from constitution §7) — none violated

- ❌ "The model is probably right" — N/A (no LLM call).
- ❌ "A disclaimer makes the activity safe" — N/A (no advice in this scope).
- ❌ "Not found means not covered" — N/A (no absence-to-conclusion).
- ❌ "The UI shows progress, so progress exists" — N/A (no fabricated loading).
- ❌ "The client says the user is paid, so entitlement is paid" — N/A (server-side authoritative).
- ❌ "HTTP 200 means deletion completed" — N/A (no deletion).
- ❌ "The partner handles it, so our responsibility ends" — N/A (no partner integration).
- ❌ "The feature already exists, so it belongs" — N/A (existing feature accepted).
- ❌ "The feature is expensive, so it does not belong" — N/A (low cost).
- ❌ "More engagement means more value" — N/A (gate, not engagement).
- ❌ "The source is internal; the user does not need to see it" — N/A (gate-reason copy is user-visible).
- ❌ "Generic insurance knowledge is close enough to the contract" — N/A (no LLM in path).
- ❌ "A test passed, therefore the public claim is proven in production" — N/A (no public claim in this scope).

## Anything else? (motto §0.1.1)

Two deliberate clarifications:

1. The constitution is *Proposed*. Operators reading this bundle should treat the constitution as directional, not authoritative, until ADR-2026-07-29-02 has explicit sign-off recorded in its Update Log (§0.12.1 v4 rule).
2. WS-2 (smallest coherent delta) was scoped but paused per §23 hold. If a subsequent session resumes this workstream after the parallel-agent refactor lands, the Wedge §3.3 statement ("Coverage Summary Is Closer to the Wedge Than Q&A") argues for *expanding* test coverage on this surface in a future gate, not for *narrowing* scope further here.
