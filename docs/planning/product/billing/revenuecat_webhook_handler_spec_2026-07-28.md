# RevenueCat Webhook Handler Spec — Full Product Catalog

**Date:** 2026-07-28
**Status:** SPEC — ready to implement once RC catalog exists. Not yet started.
**Decision owner:** Pranay
**Doctrine:** `motto_v4.md` — §0 (whole-answer), §0.5 (evidence tiers — payments are high-risk, require Tier 3+), §0.6 (risk-based verification)
**Related:** `monetization_research_and_decision_2026-07-21.md`, `coverwise_india_billing_revenuecat_dodo_decision_2026-07-21.md`

---

## Why this exists

The current webhook (`src/api/subscription.py:295` `_webhook_plan` + `src/workers/revenuecat_webhook_handler.py`) only handles **subscription** products and **rejects consumable purchases**. The agreed product catalog has three product types: subscription, non-consumable (remove-ads), and consumable (Q&A packs). This spec defines the handlers for all three so the backend can process every product in the catalog.

---

## 0. P0 bug discovered during spec (must fix before any billing ships)

While reading the existing handler, a serious defect surfaced:

**`src/workers/revenuecat_webhook_handler.py:9-14`** — `_encrypt_sensitive_field()` SHA256-hashes `app_user_id` and `product_id` before passing them to `BillingLedger.process_revenuecat_webhook()`. Consequences:
- The billing ledger receives a **hash of the user ID**, not the user ID — it cannot match the event to a real user account.
- The ledger receives a **hash of the product ID** — `_webhook_plan()` cannot match `"plus"` or `"family"` substrings, so every event maps to `free`.
- Consumable purchases (which are already rejected at `subscription.py:378`) would silently fail even if the rejection were removed.
- The function's docstring claims "AES-256-GCM with principal-key DEK" but the implementation is a non-reversible hash — not encryption. This is security-theater, not protection.

**Why this is P0:** billing is a high-risk path (motto §0.5). A webhook that can't identify the user or the product cannot grant entitlements correctly. This must be fixed before any of the new handlers below are useful.

**Fix:** Remove the hashing entirely. The webhook operates server-side with the service-role Supabase key; `app_user_id` and `product_id` are operational identifiers, not secrets. The "encryption" stub was misguided. If PII minimization is desired in logs, redact at the log layer, not by corrupting the data passed to the ledger.

---

## 1. The product catalog (the contract)

All product IDs are prefixed `coverwise_` pending the rename (see `rename_strategy_and_inventory_2026-07-28.md`). When the rename lands, these change — but since there are no paying customers yet, the change is free.

| Product ID | Type | Entitlement | Grant semantics |
|---|---|---|---|
| `coverwise_plus_monthly` | Auto-renewing subscription | `pro` | Active while subscription is valid; revoked on expiry |
| `coverwise_plus_yearly` | Auto-renewing subscription | `pro` | Same |
| `coverwise_family_yearly` | Auto-renewing subscription | `family` | Same; includes family features |
| `coverwise_remove_ads` | Non-consumable (one-time) | `ad_free` | Permanent; granted once, never revoked (store restores it) |
| `coverwise_qa_pack_5` | Consumable | *(none — grants questions directly)* | +5 questions in `qa_pack_grants`; consumed by Q&A usage |

---

## 2. Event routing matrix

RevenueCat sends events; the webhook must route each `(event_type, product_class)` pair correctly. Product class is derived from product ID.

| RC event type | Subscription (plus/family) | Non-consumable (remove_ads) | Consumable (qa_pack) |
|---|---|---|---|
| `INITIAL_PURCHASE` | Grant entitlement | Grant `ad_free` | Grant +5 questions |
| `RENEWAL` | Reaffirm entitlement | n/a | n/a |
| `NON_RENEWING_PURCHASE` | n/a | n/a | Grant +5 questions |
| `UNCANCELLATION` | Reaffirm | n/a | n/a |
| `PRODUCT_CHANGE` | Swap entitlement tier | n/a | n/a |
| `SUBSCRIPTION_EXTENDED` | Reaffirm | n/a | n/a |
| `EXPIRATION` | **Revoke** entitlement | n/a | n/a |
| `CANCELLATION` | Keep until expiry | n/a | n/a |
| `BILLING_ISSUE` | Keep until expiry | n/a | n/a |
| `TRANSFER` | Re-map to new app_user_id | Re-map | Re-map (complex — see §6) |
| `REFUND_REVERSED` | Restore | Restore | Restore questions |
| `TEST` | Ignore | Ignore | Ignore |

**Critical rule (already in code, keep it):** a `CANCELLATION` does NOT immediately revoke — the user paid through the expiry date. Only `EXPIRATION` revokes.

---

## 3. Handler design

### 3.1 Product class resolver

Replace `_webhook_plan()` (which only knows subscriptions) with a resolver that returns `(product_class, entitlement_or_pack)`:

```python
def _resolve_product(product_id: str | None) -> tuple[str, str | None]:
    """Map a RevenueCat product_id to (class, identifier).

    Returns one of:
      ("subscription", "pro" | "family")
      ("non_consumable", "ad_free")
      ("consumable", "qa_pack_5")
      ("unknown", None)
    """
    p = (product_id or "").lower()
    if "family" in p:           return ("subscription", "family")
    if "plus" in p:             return ("subscription", "pro")
    if "remove_ads" in p:       return ("non_consumable", "ad_free")
    if "qa_pack" in p:          return ("consumable", p)  # full id; pack size derived
    return ("unknown", None)
```

### 3.2 Subscription handler (existing — keep, with P0 fix)

Already works via `billing_subscription_states` table. The P0 fix (remove hashing) is the only required change. Tier mapping stays.

### 3.3 Non-consumable handler (NEW — `ad_free`)

Non-consumable = bought once, owned forever, restorable across devices. Stored as a boolean entitlement on the user.

**Storage:** new table `ad_free_entitlements` (or extend existing entitlement table). Minimal schema:

```sql
create table if not exists public.ad_free_entitlements (
  owner_id text primary key,
  product_id text not null,
  purchased_at timestamptz not null default now(),
  provider_event_id text not null,   -- idempotency key
  source text not null default 'revenuecat',
  created_at timestamptz not null default now()
);
-- RLS: owner reads own; service_role full.
```

**Handler logic:**
- `INITIAL_PURCHASE` / `REFUND_REVERSED`: insert (upsert by owner_id). Idempotent on `provider_event_id`.
- Never revoked — non-consumables don't expire. The only revocation path is a manual refund (handled as a separate event type if RC reports it).

### 3.4 Consumable handler (NEW — `qa_pack_5`)

Consumable = bought, granted as a quantity, consumed by use. Maps directly to the existing `qa_pack_grants` table (verified schema: `owner_id`, `product_id`, `questions_granted`, `questions_remaining`, `provider_event_id`).

**Handler logic:**
- `INITIAL_PURCHASE` / `NON_RENEWING_PURCHASE`: insert into `qa_pack_grants` with `questions_granted = 5`, `questions_remaining = 5`. Idempotent on `provider_event_id`.
- Consumption is NOT triggered by the webhook — it's triggered by the existing `reserve_qa_question` / `finalize_qa_question` RPCs when the user asks a question.
- `REFUND_REVERSED` (rare for consumables): re-insert the grant.

**Pack size derivation:** the product ID encodes the size (`qa_pack_5` → 5). For a future `qa_pack_20`, parse the trailing integer. Single source of truth: a `PACK_SIZES` dict in code, mirrored in the RC product config.

---

## 4. Idempotency (critical for billing — motto §0.6)

Every handler must be idempotent on the RevenueCat event ID. RC retries failed deliveries (non-200 → retry), so the same event WILL arrive multiple times.

- `provider_event_id` (the RC event `id`) is the idempotency key.
- Every insert uses `INSERT ... ON CONFLICT (provider_event_id) DO NOTHING` (or equivalent upsert).
- A duplicate delivery returns 200 without re-granting.

**Existing coverage:** `processed_webhook_events` table + `revenuecat_webhook_events` (sqlite) already exist for this. The new handlers reuse the same dedup path. Verify the dedup table has a unique constraint on `provider_event_id`.

---

## 5. Mobile-side alignment (`billing_adapter.dart`)

The current `_productTierMap` and `_packProductMap` must match the new catalog:

```dart
static const Map<String, PlanTier> _productTierMap = {
  'coverwise_plus_monthly': PlanTier.plus,
  'coverwise_plus_yearly': PlanTier.plus,
  'coverwise_family_yearly': PlanTier.family,  // was _monthly + _yearly; yearly only now
};

static const Map<String, QaPackType> _packProductMap = {
  'coverwise_qa_pack_5': QaPackType.pack5,  // renamed from starter/value/pro
};

// NEW: non-consumable tracking
static const Set<String> _nonConsumableProducts = {
  'coverwise_remove_ads',
};
```

**Note:** The current `_packProductMap` uses `starter/value/pro` tiers that don't exist in the agreed catalog. Either repurpose them as pack sizes or collapse to a single pack. Decision: single `qa_pack_5` for MVP; expand later. This simplifies the model.

---

## 6. TRANSFER events (deferred — complex)

`TRANSFER` fires when a user reinstalls and RC merges identities (`from_app_user_id` → `to_app_user_id`). Handling this requires re-owning all entitlements and pack grants. For MVP, **log and acknowledge without re-owning** — the user can restore purchases via the RC SDK's `restorePurchases()`, which re-syncs their active entitlements. Full TRANSFER handling is a post-launch task.

---

## 7. Verification plan (Tier 3+ required before shipping — motto §0.5)

Billing is high-risk. Each handler needs integration verification, not unit-only:

| Test | Method | Gate |
|---|---|---|
| Subscription grant + expiry | RC sandbox → webhook → assert `billing_subscription_states` row | Must pass |
| Remove-ads purchase + restore | RC sandbox → webhook → assert `ad_free_entitlements` row; reinstall → restore → still present | Must pass |
| Q&A pack purchase + consumption | RC sandbox → webhook → assert `qa_pack_grants` row with `questions_remaining=5`; ask 5 questions → assert `=0`; 6th blocked | Must pass |
| Idempotency | Replay same event 3× → assert single grant | Must pass |
| P0 fix verification | Process event with real `app_user_id` → assert ledger row has real ID, not hash | Must pass |
| Refund reversal | RC sandbox refund → reversal event → assert entitlement/questions restored | Must pass |

**Sandbox requirement:** RC sandbox testing requires a Play Console license tester account (founder adds their Google account to the tester list). Without it, real purchases can't be tested without real money.

---

## 8. Build order (gated commits)

1. **P0 fix:** remove `_encrypt_sensitive_field` hashing; pass real IDs. Verify existing subscription path still works. (1 commit)
2. **Product resolver:** replace `_webhook_plan` with `_resolve_product`. (1 commit)
3. **Consumable handler** + `qa_pack_grants` insert + idempotency + tests. (1 commit)
4. **Non-consumable handler** + `ad_free_entitlements` migration + tests. (1 commit)
5. **Mobile alignment:** update `_productTierMap`/`_packProductMap`, add remove-ads tracking. (1 commit)
6. **Tier 3 sandbox verification** of all three flows (manual, founder + agent). (verification, not commit)

Total: ~5 commits + 1 verification gate. Not dependent on the rename (product IDs swap later for free).

---

## 9. Anything else? (motto §0.1.1)

**Yes:**

1. **Receipt verification.** The webhook trusts RC's event as authoritative. That's correct — RC has already verified the store receipt. Do NOT re-verify receipts server-side; that's RC's job and double-verifying creates divergence. This is the "server-authoritative via webhook" model the billing audit demanded.

2. **Webhook URL + authorization secret.** The handler at `/subscription/webhook` checks an Authorization header against `REVENUECAT_WEBHOOK_AUTHORIZATION` (already in `.env`). When the backend moves to Render, the RC webhook URL becomes `https://<render-url>/subscription/webhook`. Founder must register this URL in RC dashboard. The auth secret must match between `.env` and RC.

3. **Tax / invoicing.** Out of scope for this spec — Google Play handles tax collection and remittance in India. RC reports post-tax revenue. No server-side tax logic needed for MVP.

4. **Refund handling for consumables.** If a user refunds a `qa_pack_5` AFTER consuming some questions, the granted balance could go negative. Mitigation: on refund, clamp `questions_remaining` to `max(0, current - granted)` rather than going negative. Documented as edge case; handle in the refund reversal path.

5. **Free-tier enforcement is separate.** This spec is about *granting* entitlements. Enforcing the free-tier limit (1 policy, 5 questions/month) is app-side logic in `entitlement_service.dart`, not webhook work. Track separately.

---

## Update log

- 2026-07-28: created. Catalog contract + 3 handler designs + P0 bug discovery + Tier 3 verification plan. Blocked on RC catalog existing.
