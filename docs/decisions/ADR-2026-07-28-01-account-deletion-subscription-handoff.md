# ADR-2026-07-28-01: Account deletion hands off the store subscription; the product is an intermediary, not a canceller

**Format:** Per `motto_v4.md` §0.12 (Decision Record Requirement) and §0.12.1 (Update Log rule). Decisions-first per §0.12.2 — ADR lands before implementation. Pattern-family reuse per §0.12.3 (extends the ADR-2026-07-19-13 "intermediary, not answerer" family).

- **Decision:** When a user with an active store subscription deletes their CoverWise account, **CoverWise does not claim to cancel the subscription, and does not silently leave it running.** CoverWise acts as an **intermediary**: it (a) refuses to mark deletion `completed` while a live store entitlement exists, (b) hands the user to the authoritative source — the Google Play subscription-management deep-link — with an explicit, acknowledged "your Play subscription is separate; cancel it here" contract, and (c) defunds the CoverWise-side entitlement server-side so that no "deleted user with active entitlement" state can persist. The product never claims `complete` for something it did not do.
- **Date:** 2026-07-28
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Proposed.** Awaiting operator sign-off per §0.12.2 before any implementation. The analysis (`docs/audits/coverwise_g2_deletion_subscription_analysis_2026-07-28.md`) and the round-2 audit finding G-2 are the inputs; this ADR is the decision.
- **Pattern family:** extends [ADR-2026-07-19-13](./ADR-2026-07-19-13-what-if-premium-refused-as-product-capability.md) — the "intermediary, not answerer" family. Where ADR-13 refused to fabricate a premium number and pointed the user at the real source, this ADR refuses to falsely claim cancellation and points the user at the real canceller. Same first principle: **when the product lacks the authority/data to do a thing honestly, it does not pretend; it bridges to the actor who can.**
- **Related artifacts:** `docs/audits/coverwise_overlooked_risks_round2_2026-07-28.md` (G-2, G-9), `docs/audits/coverwise_g2_deletion_subscription_analysis_2026-07-28.md` (the 3-option analysis this ADR supersedes), `docs/legal/account_deletion.html` (copy to align), `mobile/lib/screens/profile_screen.dart` (deletion entry), `mobile/lib/services/billing_adapter.dart:347` (deep-link primitive already exists), `src/services/account_lifecycle_service.py` (deletion orchestrator), `docs/launch_claims/` (registry entry required per §0.11.1).

---

## Update log

- **2026-07-28 (original):** Initial proposal. Reasoned from motto_v4 against the 3-option analysis doc. The earlier pragmatic recommendation ("Option A + copy fixes") is **superseded** — it was scoped to "smallest honest code," which §0 and §0.12.4 reject as the framing. The motto_v4-aligned answer is the full intermediary contract below (gate + deep-link + defund + copy alignment + launch-claim), landed as one coherent decision, not a minimal patch. Status: Proposed.

---

## Context

### The gap, restated (from the analysis doc)

`account_lifecycle_service.process_deletion` deletes the Supabase auth user and writes `status: completed`, but never touches RevenueCat, Google Play Billing, or any entitlement table. A paying user who deletes sees a green "complete" snackbar and keeps getting charged by Play. The web copy (`account_deletion.html:128`) admits this in a buried `<em>` line; the bold "what will be deleted" list above it claims "entitlement records" are deleted, which they are not. Three risks follow: chargebacks (R1), copy-vs-behavior lie (R2), and `completed` as a semantic lie (R3).

### The platform constraint that makes this a decision, not a ticket

Google Play has **no server-side "cancel this user's subscription" API** for standard subscriptions, and Apple is the same. The subscription belongs to the *user's* Google account; only the user (via Play Store) or Google's own systems can end it. RevenueCat can *defund* an entitlement server-side (the app stops granting access), but the underlying store charge cannot be killed by CoverWise's backend. **No amount of code in `process_deletion` can make the Play charge stop on its own.** This is a platform reality, not a code-completeness gap.

### The precedent that governs this decision

ADR-2026-07-19-13 ("What-If Premium refused as a product capability") established a reusable first principle for this exact class of problem: **when the product lacks the data/authority to do something honestly, it refuses to fabricate the outcome and instead acts as an intermediary to the real source.** For premium numbers, the real source was the insurer's calculator (deep-link), a vetted partner, or "ask your insurer." ADR-13 explicitly named this a reusable pattern family (§0.12.3).

Account-deletion-vs-subscription is the same shape of problem, one layer up:
- The product lacks the **authority** to cancel a Play subscription (platform constraint).
- The current code **fabricates an outcome** — it writes `completed` and shows a success snackbar — which is the deletion-flow analogue of fabricating a premium number. It claims a result the product did not produce.
- The honest path is the **intermediary** path: hand the user to the actor who *can* cancel (Play Store), with an explicit "this is your action, not ours" contract, and do not claim completeness for something only the user's store account can complete.

ADR-13 is therefore the governing precedent. This ADR applies its pattern to the deletion flow.

### Why the earlier "Option A + copy fixes" recommendation is superseded

The analysis doc recommended "Option A + copy fixes" as the smallest honest code. motto_v4 §0 (Boldness and Long-Term Build Mandate) and §0.12.4 (Cut/Keep/Finish Anchored to Long-Term Product Shape) reject "smallest honest patch" as the framing when the right long-term shape is affordable:

> "Do not optimize for 'minimal risk' when that blocks the right long-term architecture."
> "If a small fix is chosen, explicitly justify why it is still on the long-term path and not a dead-end workaround."

The minimal patch (deep-link gate + copy) closes R1 (chargebacks) but leaves R3 (`completed` while still subscribed) only papered over, and leaves the entitlement ledger in the "deleted user with active entitlement" state that G-9 flags. The long-term-correct shape is the full intermediary contract: gate + deep-link **+ server-side defund + copy alignment + launch-claim registry entry**, landed as one coherent decision. That is what this ADR specifies. It is more commits than the minimal patch, but it is the answer that does not have to be redone (§0.0.1 Whole-Answer Mandate).

---

## Options considered

### Option A: Pure intermediary — gate + deep-link, no server-side defund. (The minimal patch.)

- **How:** Block deletion behind a gate that forces the Play subscription deep-link when an active entitlement exists. Re-check entitlement on return. Align copy. Do not touch the backend entitlement ledger on deletion.
- **Why considered:** smallest code; closes R1 at the source.
- **Why rejected:** leaves R3 (`completed` while still subscribed) only warned-about, not resolved; leaves "deleted user with active entitlement" ledger state (G-9); contradicts §0.0.1 (whole-answer mandate) by shipping a known-incomplete shape. It is honest *warning*, not honest *state*.

### Option B: Full intermediary contract — gate + deep-link + server-side entitlement defund + copy + launch-claim. CHOSEN.

- **How:** (full spec in "The contract" below). The deletion orchestrator gains a stage that defunds the CoverWise-side entitlement via RevenueCat (so no "deleted user with active entitlement" state persists). The mobile gate forces the Play deep-link (because the *charge* can only end at Play). Copy is aligned to match behavior exactly. A launch-claim registry entry makes the contract test-enforced.
- **Why chosen:** the only option that resolves all three risks (R1, R2, R3) and the G-9 ledger state, by reusing the ADR-13 intermediary pattern. It is the long-term-correct shape. It does require building the outbound RevenueCat REST capability that does not exist today — that is a real cost, paid once, on the long-term path.

### Option C: Status-quo + copy honesty only.

- **How:** change nothing in the flow; only fix the legal copy (drop "entitlement records" from the deleted list; promote the Play note).
- **Why rejected:** leaves R1 (chargebacks) entirely open; a prominent "you will still be charged" warning that nonetheless lets the user finish "deleting" is arguably worse UX than the gate. Violates §0.11 (customer-facing claims) by shipping a known-broken contract with a louder label.

### Option D: Fabricate cancellation — claim `complete` and rely on the disclaimer. (Status quo, essentially.)

- **Why rejected:** this is the current bug. A success message for an action not taken is the deletion-flow equivalent of the fabricated premium number ADR-13 refused. Rejected on the same first principle.

### Option E: Refuse server-side defund entirely; "the store owns cancellation, we own nothing."

- **Why rejected:** abdicates the entitlement ledger. Even though the store owns the *charge*, CoverWise owns the *entitlement record*. A defunded ledger is honest state; an ignored ledger is the G-9 orphan-rows problem. Refusing defund leaves "deleted user with active entitlement" as a real, queryable, misleading state.

---

## The contract (Option B, in detail)

The contract has four parts. All four land together as one decision; none is a follow-up.

### Part 1 — The deletion gate (mobile, pre-deletion)

- **Trigger:** user taps "Delete account" in `profile_screen.dart`.
- **Check:** the app reads the current entitlement state (`entitlement_service.dart`). If the plan tier is anything above `free` **and** the entitlement is active (not expired), the gate engages.
- **Gate behavior:** instead of proceeding straight to the deletion confirmation dialog, the app shows a dedicated screen: "You have an active CoverWise subscription through Google Play. Deleting your CoverWise account does **not** cancel your Play subscription. To stop being charged, cancel in Google Play first." The screen offers a single primary action: **"Open Google Play subscriptions"** → `billing_adapter.manageSubscription()` (already implemented at `billing_adapter.dart:347`, which opens `https://play.google.com/store/account/subscriptions`).
- **Return behavior:** when the user returns to the app, the app **re-checks** the entitlement via RevenueCat customer info (not the local cache). Two branches:
  - **Entitlement still active** (user did not cancel): the gate re-engages. The user may retry. This is the §0.14 "user workflow" honesty: the product does not let the user reach `complete` while the source still reports active.
  - **Entitlement no longer active** (user cancelled in Play): the gate releases; deletion proceeds normally.
- **Free-tier users:** no gate; deletion proceeds as today.
- **Dark-pattern guard (§0.11):** the gate copy must make clear the user *can* still delete without cancelling — the gate informs, it does not trap. The wording is a customer-facing claim and goes through §0.11 review. Specifically: the gate offers a secondary "Delete my CoverWise account anyway (I understand I'll keep being billed until I cancel in Play)" path that proceeds after an explicit ack. This avoids the anti-pattern of obstructing deletion, while never letting the user reach an unqualified `complete`.

### Part 2 — Server-side entitlement defund (backend, inside `process_deletion`)

- **New stage** in `account_lifecycle_service.process_deletion`, inserted **before** the auth-user deletion (so a defund failure can still fail the whole deletion loudly, per the existing fail-loud pattern at lines 173–174, 189–198).
- **Action:** call RevenueCat to **forfeit/revoke** the active entitlement for `account_uid` (RevenueCat REST: `POST /v1/subscribers/{app_user_id}/entitlements/{entitlement_id}/revoke`, or the product's equivalent). This is best-effort: if RC returns an error, the stage records it in `stage_state["entitlement_defund"] = {"ok": bool, "error": ...}` and the deletion proceeds but the `completed` status carries an honest `entitlement_defund_failed` flag.
- **What this does NOT claim:** defunding the entitlement is not cancelling the Play charge. The store may still charge the user until *they* cancel in Play. The defund only ensures CoverWise's own ledger no longer reports an active entitlement for a deleted user — closing G-9 and the "deleted user with active entitlement" state.
- **Capability required:** an outbound RevenueCat REST client (`src/services/revenuecat_client.py`, new) reading `REVENUECAT_SECRET_API_KEY` from env (currently only `REVENUECAT_WEBHOOK_AUTHORIZATION` exists in `.env.example`). Secret management + idempotency (RC revoke is idempotent on `app_user_id`+`entitlement_id`; safe to retry) per §0.6 (risk-based verification — payments is a high-risk path).

### Part 3 — Copy alignment (legal + in-app)

Three concrete edits, all required so the copy matches behavior (§0.11):

1. **`docs/legal/account_deletion.html`** — the "What will be deleted" list currently claims "entitlement records." Either (a) make it true by reference to Part 2 (entitlement is defunded on deletion), or (b) remove the bullet. Recommended: (a) — reword to "Your CoverWise entitlement is revoked server-side. Your Google Play subscription is separate and must be cancelled in Google Play." which is now accurate.
2. **`account_deletion.html` buried note (line 128)** — promote from `<em>` to a bold, ack-required element. This text also moves into the **in-app** deletion flow (Part 1's gate screen), because most users delete from the app and never see the web page.
3. **The success snackbar** (`profile_screen.dart` → `profileDeleteComplete`) — must no longer say an unqualified "complete." It must scope: "Your account and documents were deleted. Your Play subscription is separate — manage it in Play Store." The unqualified `complete` is the R3 bug; the scoped message is the fix.

### Part 4 — Launch-claim registry entry (§0.11.1)

New file `docs/launch_claims/account-deletion-subscription-handoff.md` recording:
- **Claim:** "CoverWise does not claim to cancel your store subscription. It hands you to Google Play and revokes your CoverWise entitlement."
- **Implementation path:** the gate (`profile_screen.dart`), the defund stage (`account_lifecycle_service.py`), the deep-link (`billing_adapter.dart:347`).
- **Gating test:** (a) a widget test asserting the gate engages for an active entitlement and releases only after entitlement is no longer active; (b) a backend test asserting `process_deletion` calls the RC revoke stage and records `stage_state["entitlement_defund"]`; (c) a copy-lint test asserting the success snackbar and the deletion HTML do not contain the unqualified word "complete" / do not list "entitlement records" as deleted without the defund context.
- **Evidence tier required:** Tier 3 (integration) per §0.5 — payments + data deletion are both explicitly named high-risk paths.
- **Release state:** gated; CI fails if any of the three tests regress.

---

## Chosen path

**Option B — the full intermediary contract (Parts 1–4), landed as one decision.**

This is not "Option A now, Option B later." The whole-answer mandate (§0.0.1) and the cut/keep/finish rule (§0.12.4) require that the long-term-correct shape be the one shipped, because the minimal patch (Option A) is a dead-end workaround that leaves R3 and G-9 open and would have to be redone. The defund stage is the part that makes `completed` honest; without it, the gate is just a louder warning.

**Commit-units estimate (per §0.2.1, not wall-clock):**

1. `src/services/revenuecat_client.py` — outbound RC REST client + env wiring + idempotency. (~1 commit)
2. `account_lifecycle_service.process_deletion` — add the defund stage before auth deletion; extend `stage_state`; add `entitlement_defund_failed` to the honest completion payload. (~1 commit, with backend test)
3. `profile_screen.dart` — the gate screen + entitlement re-check + secondary "delete anyway" path. (~1 commit, with widget test)
4. Copy alignment — `account_deletion.html` + the success snackbar scoping + in-app gate copy. (~1 commit, with copy-lint test)
5. Launch-claim registry entry + canonical doc note. (~1 commit)

Dependency order: 1 → 2 → (3 ‖ 4) → 5. Each commit gated.

**Operator decision still required before implementation** (per §0.12.2, ADR-first): sign-off on (a) the full-contract scope vs. a deliberate deferral of Part 2 with explicit rationale, and (b) the gate's "delete anyway" secondary path (the dark-pattern guard). If the operator chooses to defer Part 2, that deferral must be recorded as a dated Update Log entry with owner + closure criteria — it cannot be a silent "later."

---

## Why this path

### First-principle argument (ADR-13 pattern family, §0.12.3)

The product lacks the **authority** to cancel a Play subscription (platform constraint). Writing `completed` for a cancellation that did not happen is fabricating an outcome — the deletion-flow analogue of fabricating a premium number. The honest answer is the intermediary answer: hand the user to the actor who can cancel (Play deep-link), do not claim completeness for the store side, and do the part the product *does* own (its own entitlement ledger) correctly. This is the ADR-13 pattern, one layer up.

### Anti-fabricated-outcome argument (§0.7, §0.11)

A success snackbar for an action not taken is a lying UI. The acceptance contract (§0.4) for "deletion complete" is "the user who reads 'complete' is not deceived about what was completed." The current unqualified `complete` fails that contract. The scoped message + the defund stage restore it.

### Whole-answer argument (§0.0.1, §0.12.4)

The deletion-vs-subscription problem is one problem with three symptoms (R1, R2, R3) plus a ledger cousin (G-9). The minimal patch addresses R1 and half of R2; it leaves R3 and G-9. A correct plan executed once is smaller than a small plan redone (§0.0.1). The full contract resolves all four in one coherent decision.

### Customer-facing-claims argument (§0.11, §0.11.1)

"Entitlement records deleted" is a customer-facing claim that the code does not back. §0.11 forbids copy that implies a stronger guarantee than the system provides. The launch-claim registry (§0.11.1) makes this mechanical: the claim ships only with its gating test.

### Risk-based-verification argument (§0.5, §0.6)

Payments and data deletion are both named high-risk paths. §0.5 requires Tier 3 (integration) evidence before "done." The launch-claim registry's gating tests are the mechanism that holds that bar.

---

## Tradeoffs

- **More commits than the minimal patch.** The defund client (Part 2) is the incremental cost over Option A. Paid once; on the long-term path; not a dead-end. Justified per §0.0.1.
- **RevenueCat REST secret management.** Part 2 introduces a new outbound secret (`REVENUECAT_SECRET_API_KEY`). Mitigation: env-only, never in app code (matches the existing `privacy_policy.md:84` posture); added to `.env.example` as a placeholder; the G-1 lesson (verify it's a real secret before panicking; verify it's *not* committable before shipping) applies.
- **The gate adds friction to deletion.** The "delete anyway" secondary path is the dark-pattern guard. Mitigation: the path exists and is worded so the user is informed, not trapped (§0.11). The friction is the *honest* friction of confronting the user with the subscription they would otherwise be silently charged for.
- **Play deep-link is generic, not per-subscription.** `billing_adapter.dart:354` opens the subscriptions *list*, not a specific subscription. The user may have to pick the right one. Mitigation: acceptable; the product does not know the user's other Play subscriptions and should not pretend to.
- **Defund is best-effort; the store may still charge.** Even with Part 2, the user is charged until *they* cancel in Play. This is the platform constraint, not a defect. The copy (Part 3) states it. The defund only guarantees CoverWise's own ledger is honest.
- **Re-check on return depends on RevenueCat customer-info freshness.** If RC's cache lags, the gate may re-engage even after the user cancelled. Mitigation: the "delete anyway" path exists; the gate is advisory-to-state, not a hard lock.

---

## Assumptions

- **RevenueCat supports server-side entitlement revoke** for the CoverWise product/entitlement configuration. To verify at implementation time against the actual RC project (operator credential needed — links to the Supabase-creds gating question). If RC's free tier or the entitlement type does not support server-side revoke, Part 2 degrades to "mark entitlement inactive in CoverWise's own ledger" (still closes G-9; the RC REST call is the stronger form).
- **The Play deep-link** (`https://play.google.com/store/account/subscriptions`) is the correct authoritative surface for Android-first. iOS is out of scope per the operator's Android-first decision; an iOS-equivalent deep-link (`itms-apps://apps.apple.com/account/subscriptions`) is a future Update Log entry when iOS work begins.
- **Entitlement state is reliably readable pre-deletion** via `entitlement_service.dart` + RevenueCat customer info. To verify at implementation time.
- **The operator wants the full contract, not the minimal patch.** This is the §0.12.2 sign-off question. If the operator prefers Option A with a recorded deferral of Part 2, that is a valid decision — but it must be recorded, not implicit.

---

## Risks

- **RC revoke capability differs from assumption.** Mitigation: degrade to ledger-only defund (still closes G-9); record in Update Log.
- **Operator prefers minimal patch.** Feature of decisions-first process (§0.12.2); the ADR makes the choice explicit.
- **Gate is perceived as obstruction.** Mitigation: the "delete anyway" secondary path + §0.11 copy review.
- **Chargebacks from historical cases** (users who already deleted while still subscribed) are not addressed by this ADR — they are a remediation question, not a going-forward contract. Flagged for operator decision separately.
- **Race between deletion and an in-flight RC webhook.** Mitigation: the defund stage is inside the existing durable, idempotent `process_deletion`; RC revoke is idempotent on app_user_id+entitlement_id. The outbox retry semantics already handle transient RC errors.

---

## Validation plan

Per §0.5/§0.6, payments + deletion are high-risk → Tier 3 (integration) required before "done."

- **Part 1 (gate):** widget test — gate engages for active entitlement; releases after entitlement cleared; "delete anyway" path proceeds with ack. (Tier 2)
- **Part 2 (defund):** backend test — `process_deletion` calls RC revoke; `stage_state["entitlement_defund"]` recorded; failure recorded as `entitlement_defund_failed` without aborting the auth deletion. (Tier 2)
- **End-to-end (Tier 3):** a sandbox account with an active subscription goes through deletion: gate appears → user opens Play → returns → entitlement re-checked → proceeds → backend defund stage runs → success snackbar scoped correctly. This is the launch playbook's deletion-with-subscription path and must be run against RC sandbox + Play test track.
- **Part 3 (copy):** copy-lint test — snackbar and HTML do not contain unqualified "complete"; HTML does not list "entitlement records" as deleted without defund context. (Tier 2)
- **Part 4 (launch-claim):** CI gate fails if any of the above regress. (Tier 2, enforced)

---

## Rollback or migration path

- **Part 1 (gate):** revertible by removing the gate check; deletion proceeds directly. Local change.
- **Part 2 (defund):** revertible by removing the stage; the RC client is additive and unused elsewhere. No data migration needed.
- **Part 3 (copy):** copy edits are forward-only; rollback is re-editing.
- **Part 4 (launch-claim):** registry entry is removable.

No schema migration. No data backfill. All parts are additive and independently revertible.

---

## What would cause this decision to be revisited

- **Google Play or Apple introduce a true server-side cancel API.** Then a future ADR can add a real cancellation stage; the intermediary contract becomes the fallback rather than the default.
- **RevenueCat does not support server-side revoke** for this product configuration. Part 2 degrades to ledger-only; Update Log records it.
- **The operator chooses to never accept paid subscriptions** (free-only product). Then the entire contract is moot — there is no subscription to hand off. This would be a larger monetization decision and would supersede this ADR.
- **The regulator (DPDP / consumer protection) requires automatic cancellation on deletion.** Then the platform constraint collides with the legal duty and the resolution is a regulator-facing policy decision, recorded as a new ADR.
- **iOS work begins.** An Update Log entry adds the iOS deep-link and any Apple-specific entitlement handling.

---

## Anything else? (standing review prompt, §0.1.1)

The deletion-vs-subscription gap is one instance of a wider question: **what else does `process_deletion` claim to complete that it does not actually complete?** The round-2 audit already found two siblings:

- **G-3 — Qdrant vectors are not purged.** Same shape: `completed` claims erasure, but derived personal data (embeddings) persists. The first-principle fix is the same family — either purge the vectors (do the part the product owns) or make `completed` scope honestly to what was purged. **This ADR's defund-stage pattern is directly reusable: insert a "purge vectors" stage before auth deletion, record it in `stage_state`, fail loud or scope honestly.** Recommend a sibling ADR (ADR-2026-07-28-02) that reuses this exact staging pattern.
- **G-9 — orphaned ledger rows** (`qa_usage_ledger`, `consent_ledger`, `billing_ledger`). Same shape again: `completed` implies full erasure, ledgers retain rows. The resolution is a per-ledger retention decision (some ledgers are legitimately retained as audit trail), but the *mechanism* — explicit staging in `process_deletion` with honest `stage_state` — is identical.

**The reusable product of this ADR is not the subscription handoff; it is the "honest staging" pattern for `process_deletion`: every external obligation the deletion touches gets a named stage, recorded in `stage_state`, that either succeeds, fails loud, or is explicitly scoped out of `completed`.** G-2, G-3, and G-9 are three applications of that pattern. This ADR should be read as establishing the pattern for the deletion orchestrator, with the subscription handoff as its first instance.

A second cross-cutting note: the "delete anyway" secondary path in Part 1 is itself a small instance of the **honest-choice** pattern (give the user the real options, label them honestly, let them choose) — the same pattern as ADR-13's three-option contract. Worth naming as a pattern family if it recurs a third time.

---

## Links

- **Affected files (after operator sign-off):**
  - `src/services/revenuecat_client.py` (new — outbound RC REST client)
  - `src/services/account_lifecycle_service.py` (add defund stage; extend `stage_state`)
  - `mobile/lib/screens/profile_screen.dart` (deletion gate + re-check + "delete anyway")
  - `mobile/lib/services/billing_adapter.dart` (already has the deep-link at line 347; reused, not changed)
  - `mobile/lib/services/entitlement_service.dart` (read active-entitlement for the gate)
  - `docs/legal/account_deletion.html` (copy alignment)
  - `mobile/lib/l10n/app_en.arb` + `app_hi.arb` (scoped success message, both locales)
  - `docs/launch_claims/account-deletion-subscription-handoff.md` (new — registry entry)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-13](./ADR-2026-07-19-13-what-if-premium-refused-as-product-capability.md) — the "intermediary, not answerer" pattern family this ADR extends.
  - `docs/audits/coverwise_overlooked_risks_round2_2026-07-28.md` — G-2, G-3, G-9 (this ADR's inputs and siblings).
  - `docs/audits/coverwise_g2_deletion_subscription_analysis_2026-07-28.md` — the 3-option analysis; superseded by this ADR's decision.
- **Motto v4 alignment:** §0 (boldness/long-term), §0.0.1 (whole-answer mandate), §0.1.1 (anything-else prompt — answered above), §0.4 (acceptance contract — `complete` must mean complete), §0.5/§0.6 (Tier-3 verification for payments+deletion high-risk paths), §0.11/§0.11.1 (customer-facing claims + launch-claim registry), §0.12.1 (update-log rule), §0.12.2 (ADR-first), §0.12.3 (pattern-family reuse of ADR-13), §0.12.4 (cut/keep/finish anchored to long-term shape), §0.14 (user+operator workflow), §21 (the deletion-orchestrator refactor is part of this decision's deliverable).
