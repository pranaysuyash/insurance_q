# G-2 Deep Dive — Account Deletion vs. Store Subscription

**Date:** 2026-07-28
**Status:** Discussion / decision document. **No code changes.** Companion to `coverwise_overlooked_risks_round2_2026-07-28.md` finding G-2. Read this before deciding what to build.
**Verification basis:** `src/services/account_lifecycle_service.py` (full read), `src/api/subscription.py`, `src/workers/revenuecat_webhook_handler.py`, `mobile/lib/services/auth_service.dart`, `mobile/lib/screens/profile_screen.dart`, `mobile/lib/screens/upgrade_screen.dart`, `docs/legal/account_deletion.html`.

---

## The finding, restated precisely

`account_lifecycle_service.process_deletion` (lines 100–198) is the durable, staged, idempotent erasure routine. It performs these stages, in order:

1. Mark `dataset_items` withdrawn (156–160)
2. List the user's `documents` (161)
3. Delete each document's object in the store (163–172)
4. Delete `document_chunks` rows (179)
5. Delete `documents` rows (180)
6. Delete the Supabase auth user (183) ← the finish line; `status: completed` is only written *after* this succeeds (185–188)

**What it does not do — anywhere in this function or its call graph:**
- It does not call RevenueCat.
- It does not call Google Play Billing.
- It does not revoke or cancel any entitlement in `subscription_sync` / `revenuecat_webhook_events`.
- It does not deep-link the user to Play subscription management.

A grep across the entire backend for any outbound RevenueCat REST capability (`api.revenuecat.com`, `/v1/subscribers`, `revoke`, `grant`, `delete_subscriber`) returns **nothing**. The backend only *ingests* RevenueCat state via the webhook (`/subscription/webhook`, `subscription.py:325`) and reflects it server-side. It has no way to *push* a cancellation back to the store.

**The concrete consequence.** A paying user who deletes their account:
- loses their CoverWise identity, documents, chunks, and auth user ✅
- **continues to be billed by Google Play** for the CoverWise subscription ❌, because the Play subscription is bound to the Google account, not to the CoverWise auth user, and nothing in the deletion flow tells the store to stop charging.

The app is *honest* about this in `docs/legal/account_deletion.html:128`:
> "Deleting your account does not automatically cancel active Google Play or Apple App Store subscriptions. Please cancel any active trial or subscription via your device store settings before submitting your request."

Honesty is necessary but not sufficient. This document is about what the gap actually costs and what the options are.

---

## Why this is a real problem (the risk surface)

### R1 — User harm and chargebacks (the immediate financial risk)

The dominant real-world failure mode: a user decides to leave, taps "Delete account," sees a success snackbar (`profile_screen.dart:236` — `profileDeleteComplete`), and assumes the relationship is fully over. Their card keeps getting charged by Play on the next billing date. They notice a month later, feel deceived, and file a **Play Store chargeback** citing "I deleted my account and was still charged." Play's automated systems frequently side with the user on that fact pattern, which:
- refunds the user (revenue loss), and
- counts as a chargeback against your Play merchant record (reputation/risk-surface loss).

At solo-founder scale, even a low frequency of these is disproportionately painful — there is no support team to absorb the dispute handling.

### R2 — Legal-copy vs. behavior drift (the compliance risk)

The deletion copy (`account_deletion.html:118-126`) explicitly lists what gets deleted:
> "Your CoverWise account identity and authentication credentials / All uploaded policy documents / Extracted policy summaries, field citations, and Q&A history / Associated family member profiles and **entitlement records**."

It claims **entitlement records** are deleted. But:
- `process_deletion` does **not** delete from `subscription_sync`, `revenuecat_webhook_events`, or any billing table (verified — see G-9 in the round-2 audit).
- The active billing relationship (Play → RevenueCat → CoverWise) is not an "entitlement record" in a table; it's a live store subscription that the copy is silent about except in the buried note at line 128.

So the copy says "entitlement records deleted" while the live subscription continues. A regulator or a Play reviewer reading the bold list and the buried note together sees an internal inconsistency. DPDP's erasure-right framing makes this worse, not better: the user exercised a right and was told it was complete, but a billing relationship that processes their payment data persists.

### R3 — The deletion returns `completed` while the financial relationship is live

`process_deletion` writes `status: completed` only after the auth user is deleted (line 183 → 185). The mobile app translates that into a green success snackbar (`profileDeleteComplete`). From the user's perspective the operation is *done*. From the store's perspective nothing changed. That semantic gap — "CoverWise says done, Google Play says still subscribed" — is the entire hazard. It's the same "confident incompleteness" pattern flagged in the round-2 synthesis: the function does what it knows about, declares success, and is blind to the rest.

### R4 — The backend has no *capability* to fix this today, even if you wanted to

This is the most important architectural fact in this doc: **RevenueCat + Google Play Billing cannot be cancelled purely server-side by the app in the general case.** Specifically:

- **Google Play** does **not** allow a developer to programmatically cancel a user's subscription via an API on demand. The Google Play Developer API has no "cancel this user's subscription" call for standard (non-DDA) subscriptions. The subscription belongs to the *user's* Google account; only the user (via Play Store) or Google's own systems (via refund/non-renewal) can end it.
- **RevenueCat** can *defund* an entitlement server-side (so the app stops granting access), but cancelling the underlying store billing still ultimately routes back to the user acting in the Play Store. RevenueCat's "cancel" is an entitlement-state action, not a billing-cancellation action.

So no amount of backend code in `process_deletion` can make the Play charge stop on its own. **This is not a code-completeness gap you can simply close by adding a stage.** It is a platform constraint that forces a product-design decision. That distinction matters a lot and is the reason this is a discussion doc, not a ticket.

---

## The options

There are three realistic options. They differ in who does the cancellation and how honest/UX-friendly the result is. None is free.

### Option A — User-driven cancellation, with a forced deep-link before deletion (recommended)

**Behavior:** Before the deletion request is accepted, the app checks whether the user has an active store entitlement. If yes, it **blocks the deletion** behind a screen that (1) explains the subscription must be cancelled separately, and (2) offers a one-tap deep-link to the correct Play subscription-management page. Once the user returns (or if they had no active entitlement), deletion proceeds as today.

**Deep-link:** Android supports a direct per-app subscription deep-link: `https://play.google.com/store/account/subscriptions?sku=<product_id>&package=<app_id>` (or the newer `DEEPLINK_SUBSCRIPTIONS` flow via Google Play Billing). RevenueCat's SDK / `BillingClient` exposes `launchBillingFlow`-adjacent management intents. The app already has a `manageSubscription()` call (`upgrade_screen.dart:158`) that could be reused.

**Pros:**
- Fully honest. No claim of "cancelled" that the platform won't back up.
- Closes the chargeback root cause: the user cannot reach "deleted" without having been forced to look at the subscription.
- Low backend risk — no new RevenueCat REST integration, no platform-policy edge cases.
- Matches the existing copy at `account_deletion.html:128` (just promotes the buried note to a forced gate).

**Cons:**
- Adds friction to deletion. Some users will abandon deletion because of the extra step — which, depending on your view, is either a feature (they actually wanted to stay) or a dark-pattern risk (must be worded very carefully to avoid "obstructing deletion").
- User could deep-link to Play, *not* cancel, and come back. You must decide whether the gate re-opens (re-check entitlement) or stays closed until the webhook reports cancellation. Re-checking via RevenueCat customer info is the robust pattern.

### Option B — Server-side entitlement defund + proactive refund-where-possible, plus Option A's gate

**Behavior:** Option A, *plus* the backend calls RevenueCat on deletion to (a) defund/forfeit the active entitlement immediately and (b) where RevenueCat supports it, request a cancellation/prorated refund. Continue to *also* gate the user through the Play deep-link because the store charge itself can't be killed server-side.

**Pros:**
- Maximally correct against the entitlement ledger: the moment the account is gone, the entitlement is gone too, so no "deleted user with active entitlement" state can exist.
- Signals good faith to the user and to any reviewer.

**Cons:**
- Requires building the **outbound RevenueCat REST client** that does not exist today (R4). Real integration work: secret management, error handling, idempotency inside `process_deletion`.
- "Defund entitlement but Play still charges" can itself feel inconsistent to the user ("I have no access but I'm still paying") — though this is strictly more honest than today, and the deep-link gate mitigates it.
- RevenueCat's ability to push a refund/cancellation is store- and plan-dependent; you cannot promise it in copy. Must be best-effort with honest failure.

### Option C — Status quo, but make the copy strictly accurate and prominent

**Behavior:** Change nothing in the deletion flow. Only fix the legal copy: remove "entitlement records" from the "what will be deleted" list (R2), and promote the Play-subscription note from a buried `<em>` line to a bold, ack-required element of the deletion dialog (not just the web page).

**Pros:**
- Zero code, zero platform risk. Shippable today.
- Removes the R2 legal-copy-vs-behavior lie.

**Cons:**
- Does **not** close R1 (chargebacks) or R3 (`completed` while still subscribed). Users still get surprised by the charge a month later; the friction just moves to the dispute.
- A prominent "you will still be charged" warning that nonetheless lets the user finish "deleting" is arguably worse UX than Option A — it tells the user the product is knowingly leaving them billed.

### Rejected: "just call the Play API to cancel"

Not listed as a real option because Google Play does not offer it for standard subscriptions. Mentioning it here so it's pre-empted: any plan that assumes a server-side `POST /cancel` to Play is built on a false premise. Apple is similarly restrictive. This platform reality is what makes the decision a *product* decision, not a *coding* decision.

---

## Recommendation

**Option A, with the copy fixes from Option C folded in.**

Reasoning:
1. It's the only option that closes R1 (the chargeback root cause) at its source — the user cannot finish deleting without confronting the subscription.
2. It respects the platform constraint (R4) instead of fighting it.
3. It is the smallest amount of code that produces an honest result. Option B's server-side defund is a *good* addition later, but it is not launch-blocking and should not be on the critical path.
4. It aligns the product with the founder's own "ship narrow / honest surfaces" posture from the 07-22 launch review.

**Specific copy changes required regardless of option** (these are the R2 fix and are non-negotiable):
- In `account_deletion.html`, the "What will be deleted" list must not claim "entitlement records" are deleted unless/until they actually are. Either remove that bullet or make it conditional and accurate.
- The Play-subscription note must move from the web page only into the **in-app deletion confirmation dialog** (`_DeleteConfirmationDialog` in `profile_screen.dart`), because most users delete from the app, not the web page. If they never see the web page, the note effectively doesn't exist for them.

---

## What "done" looks like for G-2 (acceptance criteria)

Whichever option is chosen, the closing state must satisfy all of:

1. **No silent billing.** A user who completes in-app deletion has either (a) been forced through a Play subscription deep-link gate (Option A/B), or (b) seen an unavoidable, acknowledged "you will still be charged unless you cancel in Play" message (Option C). "Did not see any notice" is not an acceptable outcome.
2. **Copy matches behavior.** The "what will be deleted" list contains only things `process_deletion` actually deletes. If the active store subscription is not cancelled, the copy does not imply it is.
3. **`completed` means what it says.** Either `process_deletion` only returns `completed` when the entitlement is also defunded (Option B), or the user-facing "complete" snackbar explicitly scopes what "complete" covers (Option A/C) — e.g. "Your account and documents were deleted. Your Play subscription is separate — manage it in Play Store." The current unqualified "complete" message is the bug.
4. **Tested path.** A real (sandbox) account with an active subscription goes through deletion and the expected handoff occurs. This is the kind of gap that survived precisely because the deletion path was never tested *with* an active subscription.

---

## Open questions for the founder (these decide the option)

1. **Are you willing to add a forced gate before deletion?** (Decides A/B vs C.) This is the single decision that determines whether R1 is closed or merely papered over. My recommendation is yes.
2. **Do you want server-side entitlement defund (Option B) at launch, or later?** (Decides A vs B.) My recommendation: later. It's real integration work and not on the critical path; Option A gets you honest first.
3. **For the in-app gate: if the user opens Play and comes back *without* cancelling, do you re-block, or let them through with a final ack?** Re-block (re-check entitlement via RevenueCat) is more robust; let-through-with-ack is less frustrating. This is a UX call only you can make.
4. **Refund posture:** when a user *does* get charged after deleting (the historical cases, or Option C stragglers), do you proactively refund via Play Console, or only on complaint? A written posture here prevents ad-hoc decisions under stress.

---

## What I have NOT done

- No code changes.
- No decision made on the option — that's the founder's call via the four questions above.
- No estimate of the historical exposure (how many users have already deleted while still subscribed) — that would require querying `account_deletion_requests` joined against `subscription_sync` / RevenueCat, which needs your creds and a decision on whether it's worth the query.

Answer the four questions (or just say "go with your recommendation: Option A + copy fixes") and I'll write the implementation plan. I will not write code until you pick.
