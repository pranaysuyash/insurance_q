# CoverWise — India Payment Landscape Research (2026-07-28)

**Author:** agent (research), at Pranay's request
**Status:** Research document — **not** a decision. Ready for founder review.
**Scope:** Indian payment infrastructure for a **consumer document-understanding app** (RAG on the user's *own* insurance policy documents). CoverWise is **not** an insurance product, not an intermediary, not a broker, and does not collect insurance premium. See ADR-2026-07-19-13 and the 2026-07-28 regulatory-scope audit for the firm scope boundary. This document inherits that boundary.
**Today:** 2026-07-28.

> **Note on research method.** A planned parallel research subagent hit an upstream usage limit and returned nothing; web-search tooling was also rate-limited at the time of writing. This document is therefore written from established (training-time) knowledge of the Indian payments landscape and the project's own existing artifacts. Every external fact below should be re-verified against primary sources (RBI / NPCI / gateway pricing pages) before any contract or integration decision is made. Items marked **[VERIFY]** are the ones I most want a fresh primary-source check on.

---

## 0. TL;DR — what to take away

1. **CoverWise is safe on native mobile for now.** RevenueCat's mobile SDK is a store-abstraction layer over **Apple In-App Purchase** and **Google Play Billing**. Neither of those uses Stripe, and neither is affected by "Stripe is unavailable in India." The Stripe dependency only exists inside **RevenueCat Billing for Web**, which your own 2026-07-21 decision already ruled out for India. There is no fire here.
2. **The real question is forward-looking:** if/when you add a **web checkout** (or ever need Indian-card/UPI direct billing outside the app stores), RevenueCat will not be that rail. At that point you need an **India-authorized Payment Aggregator (PA)** — Razorpay, Cashfree, PhonePe PG, PayU — with **UPI Autopay / e-mandate** support for subscriptions, because RBI's recurring-payment rules make ad-hoc card recurring billing painful.
3. **No "RevenueCat vs Razorpay" choice is required today.** The two serve different surfaces. RevenueCat = in-app digital subscription. Indian PA = web/UPI/Indian-card direct billing. Most Indian consumer apps run **both**, gated by surface (in-app vs web) and product type.
4. **For an Indian consumer app in 2026, the leading shortlist is Razorpay and Cashfree** for the web/PG layer, with PhonePe PG as a strong third. All three are RBI-authorized PAs [VERIFY current status], all support UPI Autopay, and all have Flutter SDKs / hosted checkouts.
5. **Subscription billing on an Indian PG is *not* "set up a plan and forget."** RBI's e-mandate framework requires explicit customer mandate, has an ₹1 → ₹5,000 auto-debit band and a ₹5,000–₹15,000 pre-notification band, mandates Additional Factor of Authentication (AFA) for the first debit, and requires customer approval for any amount/tenure change. This is real, ongoing operational work — not a flag you flip.
6. **One concrete recommendation (defensible, not decided):** keep RevenueCat for in-app; if you add web checkout within the next 6–12 months, evaluate **Razorpay** first (mature Flutter SDK, strong subscription/mandate product, broad bank coverage) and **Cashfree** second (competitive pricing, very good developer experience). Do **not** try to replace Apple IAP / Google Play Billing with an Indian PG inside the native app — that is both against store policy for digital goods and operationally self-defeating.

---

## 1. Why this document exists (the actual trigger)

Pranay's words: *"RevenueCat accepts through Stripe which isn't enabled in India, so explore, deeply, for the Indian market and document."*

The accurate version of the trigger, after verification against RevenueCat's own docs (already cited in `coverwise_india_billing_revenuecat_dodo_decision_2026-07-21.md`):

- RevenueCat has **two products**: (a) the **mobile SDK** that abstracts Apple IAP + Google Play Billing, and (b) **RevenueCat Billing for Web**, a Stripe-backed hosted web-checkout product.
- **Stripe's India availability is irrelevant to (a)**, because in (a) the processor is Apple or Google, not Stripe. Stripe is the *backend of (b) only*.
- RevenueCat itself documents that **(b) is unsuitable for India today** — not because Stripe is unavailable, but because RevenueCat's web-checkout flow does not collect the full billing address that Indian RBI rules require for domestic cards / mandate registration. (See existing decision doc §2, citing `https://www.revenuecat.com/docs/web/web-billing/configuring-overview`.) [VERIFY still current.]
- "Stripe unavailable in India" is itself a partial truth worth getting right: **Stripe does support India-based businesses** for cross-border / international card charging via Stripe Atlas-style or direct India entity routes [VERIFY current 2026 status], but it is **not** a domestic-rupee payment aggregator and is not on the RBI authorized-PA list. So for *Indian-rupee, Indian-instrument* charging (UPI, RuPay, Indian netbanking, domestic cards with mandate support), Stripe is effectively not a path. RevenueCat's web product inherits that limit.

**Net:** the original trigger, slightly reframed, is: *"If we ever need to bill Indian customers directly (outside Apple/Google), RevenueCat's web product won't do it, and Stripe won't either. What does?"* Answer: an RBI-authorized Indian PA with UPI Autopay + e-mandate support. The rest of this document develops that.

---

## 2. Product scope guardrail (read before acting on this doc)

CoverWise's scope is locked by the founder and by existing ADRs:

- **CoverWise is a document-understanding tool.** It RAGs over the user's *own* insurance policy PDFs and answers questions about them. See `docs/audits/coverwise_regulatory_scope_risk_audit_2026-07-28.md`.
- **It is not an insurer, broker, corporate agent, web aggregator, claims consultant, or advisor.** It does not collect insurance premium, does not earn IRDAI commission, does not quote premium, and does not facilitate insurance transactions. See ADR-2026-07-19-13 (refused to fabricate premium; deep-links to insurer calculators instead) and ADR-2026-07-19-16 (value-add partnerships framework, strictly opt-in, intermediary-only).
- Therefore: **the only things CoverWise charges for are digital-utility features** — unlimited policy slots, Q&A packs / monthly question capacity, "remove ads", family management. These are pure **digital goods** under Apple and Google policy, and they are squarely within IAP / Play Billing scope. There is **no** insurance-premium payment rail on the product roadmap.

This matters because a chunk of the older planning docs (`monetization_strategy_2026-07-20.md`, `monetization_research_and_decision_2026-07-21.md`, `coverwise_product_strategy_monetization_scope_compliance_marketing_audit_2026-07-18.md`, parts of the 2026-07-28 naming brainstorm raw notes) still float an "IRDAI web-aggregator commission" or "sell insurance" path as a long-term monetization option. **That path is superseded by the scope audit and ADR-13/16.** Those docs should be marked superseded, not acted on. Section 9 lists the specific cleanup.

Implication for *this* document: everything below about insurance-specific payment rules (IRDAI premium routing, KYC for insurance purchases, GST/TDS on premium) is **out of scope for CoverWise** and is included only so we can explicitly say "this does not apply to us" and so the doc is complete for any future reader. Do not treat those subsections as a to-do list.

---

## 3. The current billing stack (what's actually in the repo)

Confirmed by codebase exploration on 2026-07-28:

- **Mobile (Flutter):** `mobile/pubspec.yaml` depends on `purchases_flutter: ^10.4.2` (RevenueCat's Flutter SDK). `mobile/lib/services/billing_adapter.dart` wraps `Purchases.configure / getCustomerInfo / getOfferings / purchase / restorePurchases / logIn / logOut`. Entitlements are mirrored locally in `entitlement_service.dart` (Hive) with the backend authoritative.
- **Backend (FastAPI):** `src/api/subscription.py` exposes `/subscription/{sync,webhook,status,qa-balance}`. `src/services/billing_ledger_service.py` + `src/workers/revenuecat_webhook_handler.py` + `src/workers/subscription_writeback_handler.py` do the durable reconciliation.
- **Database (Supabase Postgres):** migrations `20260721084800_billing_ledger.sql` and friends define `billing_subscription_states`, `revenuecat_webhook_events`, the `process_revenuecat_webhook(...)` RPC, the Q&A-usage ledger, and the consumable-pack fence.
- **Products:** `coverwise_plus_monthly`, `coverwise_plus_yearly`, `coverwise_family_monthly`, `coverwise_family_yearly`, `coverwise_qa_starter`, `coverwise_qa_value`, `coverwise_qa_pro`.
- **What is NOT in the repo:** any Stripe, Razorpay, Cashfree, PhonePe, UPI, or Dodo code. The only occurrences of those strings are (a) inside RevenueCat's vendored iOS Pods (an internal `Store` enum, not real Stripe), and (b) as placeholder enum values in `analytics_schema.dart`. No Indian PG integration exists.

So: **the only provider surface in the codebase is RevenueCat**, and it is doing exactly what it should for native in-app digital-goods billing. There is nothing to rip out today.

---

## 4. Stripe in India — the one-paragraph explanation

> Stripe supports India-domiciled merchants for **international/cross-border** card charging (e.g., an Indian SaaS company billing US customers in USD), but Stripe is **not** an RBI-authorized Payment Aggregator for **domestic INR** payments. It cannot acquire UPI, RuPay, Indian netbanking, or domestic-card transactions with recurring-mandate support at scale, and it is not on the RBI authorized-PA list. For an Indian consumer app charging Indian users in INR — especially for subscriptions, where RBI's e-mandate framework applies — you need an RBI-authorized Indian PA. RevenueCat's web-checkout product is built on Stripe and inherits Stripe's domestic-India gap; that is the real reason RevenueCat Web isn't a fit, more than "Stripe isn't in India" simpliciter.

[VERIFY all of §4 against Stripe's current India page and the RBI PA list before any external statement.]

---

## 5. RBI recurring-payment / e-mandate framework (the part that actually bites)

This is the single most important section if you ever do subscriptions on an Indian PG. [VERIFY thresholds and circular numbers against current RBI notifications.]

### 5.1 The framework

RBI's "Framework for processing of e-mandates on recurring online transactions" (originally notified 2019, operationalized 2021, tightened repeatedly since) governs **all** recurring card / UPI / wallet debits to a customer. The headline rules:

- **Additional Factor of Authentication (AFA) on mandate registration.** The first debit must go through an explicit AFA step (OTP / UPI PIN). The customer is approving a *mandate*, not a single payment.
- **Auto-debit band ≤ ₹5,000.** Recurring debits up to ₹5,000 can be auto-debited on schedule without per-debit AFA, *after* the mandate is registered.
- **Pre-notification band ₹5,000–₹15,000 (and above).** Each debit in this band requires the merchant to send a pre-notification (typically ≥ 24h ahead), and the customer gets a one-click cancel window. Auto-debit only fires if the customer does not cancel. [VERIFY exact threshold; RBI raised the UPI Autopay auto-debit limit in 2023–2024 — confirm the current figure, last seen at ₹1 lakh for UPI Autopay specifically.]
- **No amount / tenure / cycle change without fresh mandate.** Changing the subscription price, billing cycle, or term requires a new mandate with fresh AFA. This is operationally significant for SaaS pricing experiments.
- **Card-on-file tokenization (CoFT)** mandate (2021–2022): merchants cannot store raw card numbers; they must tokenize via networks (Visa/MC/RuPay) or use issuer-token-on-file. All major PAs handle this; you don't roll your own.

### 5.2 UPI Autopay (the recommended rail for consumer subscriptions)

- Launched by NPCI, built on UPI 2.x mandates. Customer registers a one-time mandate via any UPI app (PhonePe, GPay, Paytm, BHIM, etc.).
- **Limit:** up to ₹5,000 auto-renew without per-renewal AFA; above ₹5,000 the pre-notification window applies. [VERIFY current cap; NPCI has periodically raised this.]
- **UX:** one-time UPI PIN entry at mandate creation; renewals happen in the background; customer sees them in their UPI app's "mandate" / "autopay" list and can cancel anytime.
- **Coverage:** essentially every UPI-enabled customer in India, which is essentially every smartphone owner.
- **Failure modes:** insufficient balance, mandate revoked by user in their UPI app (silent until you poll / get a webhook), UPI app uninstalled, bank-side downtime. PGs expose these as webhooks; your backend must treat `payment.failed` / mandate-revoked as a downgraded entitlement.

### 5.3 e-NACH / Standing Instructions

- e-NACH is the bank-account-level debit mandate (NPCI's NACH infrastructure). Heavier to register (netbanking authentication), supports larger amounts, slower to settle. Useful for high-ticket annual subscriptions but overkill for a ₹99–₹899 consumer-app subscription.
- Card Standing Instructions (SI) predate the e-mandate framework and are being folded into it. Don't greenfield on SI; use the e-mandate flow.

### 5.4 What this means for CoverWise operationally

If you go down the Indian-PG-for-subscriptions path, the engineering is not "POST to `/subscribe`." It is:

1. **Mandate registration flow** with AFA — UI for first payment, handling the OTP / UPI PIN / bank redirect.
2. **Webhook ingestion** for `mandate.registered`, `mandate.revoked`, `payment.succeeded`, `payment.failed`, `subscription.cancelled` — idempotent (PGs retry), signed (verify HMAC), raw-body preserved (JSON middleware breaks signatures — see `payment-integration` skill).
3. **Entitlement downgrade on mandate failure** — the user keeps access until the grace period ends, then drops. This is exactly the model your RevenueCat webhook handler already implements; the pattern transfers.
4. **Pre-notification compliance** if any plan is priced > ₹5,000/renewal (none of the current CoverWise plans are; the annual Family plan at ₹899 is well under).
5. **Price-change re-mandate** — if you ever change subscription prices, every existing subscriber needs a new mandate. This is a real constraint on pricing experiments and a reason to price carefully up front.

This is doable — every Indian consumer SaaS does it — but it is a real subsystem, not a feature flag.

---

## 6. Indian Payment Aggregators — shortlist for CoverWise (2026)

All four below are (as of last verification) on the RBI authorized-PA list. [VERIFY each against the current RBI "List of Payment Aggregators" before contracting.] Pricing is indicative; real numbers come from your negotiated MDR and are volume- and instrument-dependent.

### 6.1 Razorpay (Razorpay Software Pvt. Ltd.)

- **Status:** In-principle + final PA authorization had a multi-year regulatory delay; was widely reported as fully authorized in late 2024. [VERIFY current status specifically — this one has been in flux.]
- **Instruments:** UPI (incl. UPI Autopay / recurring), Credit/Debit cards (incl. international), Netbanking (50+ banks), Wallets, EMI.
- **Subscriptions:** First-class `Subscriptions` product built on e-mandate + UPI Autopay. Webhook events, mandate management dashboard, customer-facing short links.
- **SDKs:** Android (Java/Kotlin), iOS (Swift), **Flutter** (`razorpay_flutter`), React Native, web checkout. Hosted Checkout + native drop-in.
- **Pricing (indicative):** ~2% MDR domestic cards + ₹3; UPI often ~0%–0.5% depending on scheme (MDR on UPI has been intermittently regulated to zero for merchants up to certain ticket sizes — [VERIFY current MDR rules]). International cards ~3%+. Settlement T+2 typically.
- **Strengths:** Best-in-class developer experience in India, mature Flutter SDK, broad bank coverage, strong dashboard, large community.
- **Weaknesses:** Past regulatory uncertainty (now mostly resolved [VERIFY]); KYC/onboarding can take 1–3 weeks for a Private Limited; support quality varies at scale.

### 6.2 Cashfree (Cashfree Payments India Pvt. Ltd.)

- **Status:** RBI-authorized PA. [VERIFY]
- **Instruments:** UPI (incl. Autopay), cards, Netbanking, wallets. Strong on payouts / vendor payments too.
- **Subscriptions:** `Subscriptions` product on e-mandate + UPI Autopay; good API for mandate lifecycle.
- **SDKs:** Android, iOS, **Flutter**, React Native, web. Hosted + drop-in.
- **Pricing (indicative):** Aggressive — ~1.75% domestic cards + ₹3, UPI low/zero. Often cheaper than Razorpay on negotiated deals.
- **Strengths:** Pricing, fast onboarding, good dev experience, strong payout product if you ever need to disburse (refunds, partner payouts).
- **Weaknesses:** Smaller market share / community than Razorpay; some edge cases in international-card acceptance reported.

### 6.3 PhonePe (PhonePe Pvt. Ltd.) — PhonePe PG

- **Status:** RBI-authorized PA (and dominant UPI app). [VERIFY]
- **Instruments:** UPI native (obviously best-in-class), cards, Netbanking, wallets, EMI on cards.
- **Subscriptions:** UPI Autopay first-class; recurring on cards via mandates.
- **SDKs:** Android, iOS, Flutter (third-party / wrapper), React Native, web. The native PhonePe switch is seamless for UPI.
- **Pricing (indicative):** UPI often at zero/near-zero merchant MDR; cards ~2% + ₹3.
- **Strengths:** Deepest UPI integration in India — if your users skew PhonePe (they do; PhonePe has ~50% UPI market share), the conversion is excellent.
- **Weaknesses:** PG product historically a bit behind Razorpay/Cashfree on dev experience and edge-case features; dashboard less polished.

### 6.4 PayU India (PayU Payments Pvt. Ltd.)

- **Status:** RBI-authorized PA. [VERIFY]
- **Instruments:** Full stack — UPI, cards, netbanking, wallets, EMI, pay-later.
- **Subscriptions:** `Recurring Payments` / mandate product mature.
- **SDKs:** All major platforms including Flutter.
- **Pricing (indicative):** ~2% + ₹3 cards; competitive on UPI.
- **Strengths:** Large enterprise book, good for higher-volume / higher-ticket; solid international-card acceptance.
- **Weaknesses:** More enterprise-flavored; onboarding heavier; less indie-friendly than Razorpay/Cashfree.

### 6.5 Others considered, not shortlisted

- **Billdesk,** **CCAvenue,** **Pine Labs / Plural** — large, mature, authorized PAs but more enterprise-tilted; weaker Flutter DX; not the right fit for a consumer mobile-first product.
- **Juspay** — orchestration / checkout layer (Hyper), excellent tech, but typically sits *in front of* a PA rather than being your sole PA. Worth reconsidering at higher volume.
- **Setu** — API-first, good for mandates / data products; often used in combination with a PA.
- **Open Money** — neobank + payments bundle; useful if you want banking + payments together.
- **Dodo Payments** — already evaluated in your 2026-07-21 decision doc. Good for Merchant-of-Record / international / web; not the obvious first pick for an India-domestic consumer-app subscription, because the big-4 Indian PAs above are cheaper, more locally tuned, and have better UPI Autopay DX.

### 6.6 Head-to-head for CoverWise (consumer mobile-first, India)

| Dimension | Razorpay | Cashfree | PhonePe PG | PayU |
|---|---|---|---|---|
| Flutter SDK quality | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| UPI Autopay DX | Strong | Strong | Best (native) | Strong |
| Subscription / mandate product | Mature, documented | Good | Good | Mature |
| Pricing (indicative) | ~2% + ₹3 cards | ~1.75% + ₹3 cards | UPI ≈ 0; cards ~2% | ~2% + ₹3 cards |
| Onboarding speed (Pvt Ltd) | 1–3 wks | Faster (~1 wk) | Medium | Heavier |
| Community / docs | Largest | Good | Medium | Good |
| Refunds / disputes tooling | Strong | Strong | Medium | Strong |

**My recommendation (defensible, not decided):** if you add a web checkout in the next 6–12 months, evaluate **Razorpay first** for DX and breadth, and **Cashfree as the live alternative** for price competition. Both integrate cleanly with the existing CoverWise entitlement ledger (section 8). Keep PhonePe PG in mind as the UPI-conversion play if you see UPI dominating your payments mix.

---

## 7. Store / IAP rules — the other half of the picture

### 7.1 Apple App Store

- **Digital goods = must use Apple IAP.** CoverWise's digital-utility features (unlimited policies, Q&A packs, remove-ads, family tier) are unambiguously digital goods → Apple IAP applies. RevenueCat wrapping IAP is the standard path. No change.
- **Apple does not take insurance premium.** Insurance is explicitly out of IAP scope. Irrelevant to CoverWise because CoverWise doesn't sell insurance (section 2) — but worth noting for completeness.
- **India-specific:** Apple supports Indian storefront, INR pricing, Indian dev payouts to Indian bank accounts. No India-specific carve-out that affects you.

### 7.2 Google Play Billing (India)

- **Digital goods = must use Play Billing**, with the India-specific history: Google announced mandatory Play Billing for India in 2021 (effective 2022), faced CCI litigation, and the current state (as of last verification) is "User Choice Billing" available in India alongside Play Billing. [VERIFY current 2026 status — this has been litigated and updated multiple times.]
- **User Choice Billing (UCB):** where available, lets you offer an alternative billing system *alongside* Play Billing. Google's service fee still applies (with a ~4-point reduction for the alternative-billing leg). Introduces a multi-rail reconciliation burden. Your 2026-07-21 decision correctly deferred this for v1.
- **Insurance is out of Play Billing scope** — same as Apple. Again irrelevant to CoverWise given scope.
- **Practical stance for CoverWise v1:** ship Play Billing + RevenueCat (current plan), do not add UCB or alternative billing in v1. The operational cost of multi-rail reconciliation is not justified by hypothetical UPI-conversion uplift before you have conversion data.

### 7.3 The hybrid model (common in India)

For a consumer app that has *both* digital-goods subscriptions and real-world services, the standard Indian pattern is:

- **In-app:** Apple IAP / Play Billing via RevenueCat, for all digital-goods subscriptions and consumables.
- **Web (only):** Indian PG (Razorpay / Cashfree / PhonePe), for any checkout that is (a) initiated outside the app, or (b) for a non-digital good or a good Apple/Google exclude.

CoverWise currently has no web checkout and no non-digital goods. So the hybrid model is a future option, not a current requirement.

---

## 8. Architecture — how an Indian PG would slot into the existing stack

The existing RevenueCat integration is well-factored: `BillingAdapter` (Flutter) ↔ RevenueCat ↔ webhook → `/subscription/webhook` → durable outbox → `process_revenuecat_webhook` RPC → `billing_subscription_states`. The entitlement / usage ledger is **provider-agnostic in shape** (`plan_tier`, `qa_packs`, `source` enum). Adding an Indian PG later would mean:

1. **New Flutter adapter** alongside `BillingAdapter` (e.g., `WebBillingAdapter`) for the web-checkout / PG flow — no need to touch the in-app RevenueCat path.
2. **New webhook receiver** (e.g., `/subscription/razorpay-webhook`) with signature verification, idempotency-by-event-id, raw-body preservation, and the same 2xx-before-expensive-work pattern as the RevenueCat receiver. Reuse the outbox.
3. **Generalize the RPC** (or add a sibling) so the entitlement writeback logic is shared. The `source` enum in `billing_subscription_states` already anticipates multiple sources (`'client_sync'`, `'revenuecat_webhook'`) — extend with `'razorpay_webhook'` / `'cashfree_webhook'` etc.
4. **Mandate lifecycle handling** specific to the PG (mandate registration, revocation, pre-notification for >₹5,000 — though no current plan hits that).
5. **Price-change re-mandate workflow** — operationally significant; build tooling before you need it.

Key: this is **additive**, not a rewrite. Per the global rule against duplicate/parallel payment rails, this would be *one* new route per provider, using the *existing* shared validation/outbox/ledger pipeline, not a forked system.

---

## 9. Stale-framing cleanup (from the 2026-07-28 verification sweep)

While verifying scope, the following files were found to still contain "sell insurance / IRDAI web aggregator / corporate agent / collect premium / commission" framing that is **superseded** by the 2026-07-28 regulatory-scope audit and ADR-2026-07-19-13/16. None of these affect code; they are documentation drift. Recommended action: add a **superseded** banner at the top of each, pointing to the scope audit, rather than deleting (history preservation per motto_v4 §0.3 and the global Documentation Management rule).

| File | Stale content (indicative) |
|---|---|
| `docs/planning/product/monetization_strategy_2026-07-20.md` | "IRDAI commission path" / long-term insurance-monetization language |
| `docs/planning/product/monetization_research_and_decision_2026-07-21.md` | "Tier 4 (future): Commission (IRDAI web aggregator)" — superseded |
| `docs/audits/coverwise_product_strategy_monetization_scope_compliance_marketing_audit_2026-07-18.md` | Pre-scope-lock framing; should reference 2026-07-28 audit |
| `docs/decisions/ADR-2026-07-19-16-value-add-partnerships-framework.md` | OK in principle (opt-in, intermediary-only) but should cross-link the scope audit explicitly |
| `docs/planning/naming/brainstorm_2026-07-28/raw/*.md` (01_strategist, 07_skeptic, 08_future_self, 10_executioner) | Brainstorm raw notes; fine to leave but should not be cited as decisions |
| `docs/planning/launch_strategy_2026-07-12.md` | Pre-scope; verify current |
| `docs/marketing/newsletter_*.md`, `docs/launch_claims/policy-readiness-and-coverage-overview.md` | Copy should match "document-understanding only" — verify wording |

**Recommended next step (separate small task):** add `> **Superseded.** See \`docs/audits/coverwise_regulatory_scope_risk_audit_2026-07-28.md\` and ADR-2026-07-19-13. Insurance-intermediation monetization is out of scope.` banner to the first three files above. Not in scope for *this* document; flagged for follow-up.

---

## 10. Open questions for founder

1. **Timeline on web checkout:** Is there any concrete plan to add a web purchase surface in the next 6 / 12 / 24 months? If no, this entire doc is contingency research and we ship nothing. If yes inside 6 months, we should start PA onboarding now (KYC + mandate registration takes weeks).
2. **Pricing strategy with respect to the ₹5,000 auto-debit band:** None of the current CoverWise plans (₹99/mo, ₹899/yr, ₹299 one-time remove-ads, Q&A packs) breach ₹5,000/renewal, so the pre-notification band is moot. If you ever introduce an annual family plan > ₹5,000, re-confirm the operational impact.
3. **Single-PA vs. multi-PA from day one:** I recommend single-PA (Razorpay or Cashfree) at launch and adding a second only if conversion data justifies it. Agree?
4. **Do you want a formal ADR** for "no Indian PG today; RevenueCat + IAP remains the v1 billing stack; Indian PG is a deferred contingency for web checkout," so the decision is locked and not re-litigated?

---

## 11. Items I could not fully verify at time of writing (re-check before any contract)

Marked inline with **[VERIFY]**. Collected here for the follow-up pass once web-search quota resets:

- Current RBI authorized-PA list (2026) for Razorpay, Cashfree, PhonePe, PayU — confirm each.
- Razorpay's exact final-authorization status (it had a long in-principle period).
- Current UPI Autopay auto-debit ceiling (was raised multiple times; confirm the live number).
- Current MDR rules for UPI (the zero-MDR-on-small-ticket policy has been intermittently in force).
- Current state of Google Play "User Choice Billing" in India (2026).
- Whether RevenueCat's India billing-address limitation for web billing has been resolved.
- Stripe's current India-domestic offering.

Primary sources to check directly (don't rely on aggregators):
- RBI: `rbi.org.in` → Notifications → Payment Systems → "List of Payment Aggregators"
- NPCI: `npci.org.in` → UPI / Autopay / NACH documentation
- Apple Developer: In-App Purchase + India storefront docs
- Google Play: developer docs on billing requirements for India
- Each gateway's own pricing page and status page

---

## 12. Decision recommendation (non-binding)

For founder review. Suggested as the basis of a short ADR:

> **ADR (proposed): CoverWise v1 keeps RevenueCat + Apple IAP + Google Play Billing as the sole billing stack. No Indian PG is integrated at this time. RevenueCat Billing for Web remains ruled out for India (unchanged from the 2026-07-21 decision). If and when a web-checkout surface is added, the default plan is to integrate a single RBI-authorized Indian PA — Razorpay or Cashfree, decided at the time — with UPI Autopay + e-mandate support, as an additive rail alongside the existing in-app RevenueCat path, reusing the existing entitlement ledger and outbox. The older "IRDAI commission / sell insurance" language in 2026-07-18 – 2026-07-21 planning docs is superseded by the 2026-07-28 regulatory-scope audit and is not a forward plan.**

This locks the current state, documents the contingency, and unblocks all current engineering without forcing a premature provider selection.
