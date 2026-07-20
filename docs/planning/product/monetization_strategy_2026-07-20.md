# CoverWise Monetization Strategy — 2026-07-20

## Context

The founder explicitly said: "I don't want to burn." The app has zero
monetization today — no payment integration, no paywall, no ads, no
subscription. The free tier has limits (5 documents, rate-limited queries) but
there's no way to pay for more.

This document analyzes monetization options for an Indian B2C insurance
companion app, from first principles, and recommends a path.

## The product's value

CoverWise saves the user from reading and misunderstanding their insurance
policy. The value moments are:
1. **Understanding** — seeing coverage, exclusions, benefits at a glance
2. **Answers** — asking questions and getting sourced responses
3. **Emergencies** — claim process, helpline, coverage at the moment of need
4. **Proactive** — renewal reminders, coverage gap analysis

The user is most willing to pay when they understand how much money CoverWise
is protecting or saving them. Insurance policies involve lakhs of rupees; the
app helps them not lose that coverage through ignorance.

## Who pays for insurance apps in India?

Indian consumers are price-sensitive and free-app-trained. But they WILL pay for:
- **Financial peace of mind** (CRED: ₹1000+ subscription; ET Money: premium tiers)
- **Tax saving** (ClearTax, myITreturn: freemium with paid CA assistance)
- **Health management** (Practo, Tata 1mg: consultations + medicine delivery)
- **Document management** (DigiLocker: free, government-backed)

The precedent is: **free to start, pay for expert help or premium features.**

## Options analyzed

### Option 1: Ads (Google AdMob)

**Revenue model:** CPM/CPC display ads in the app.

- **Expected revenue:** Indian insurance CPM is ~₹50-150 ($0.60-1.80). At 1000
  DAU with 2 ad impressions each, that's ~₹100-300/day = ₹3,000-9,000/month
  ($36-108). Barely covers server costs.
- **Pros:** Zero friction, no payment integration needed, works immediately
- **Cons:** 
  - **Terrible UX for a trust product.** Insurance users are in a serious
    mindset — showing them ads undermines the trust that makes the app valuable.
  - Low revenue at solo scale (need 10K+ DAU to make real money)
  - Google may show competitor insurance ads (Star Health ad in a Star Health
    policy reader = confusing)
  - AdMob SDK adds weight, privacy concerns, store review friction
- **Verdict:** ❌ **NO.** Ads destroy trust in a financial product. The revenue
  doesn't justify the UX cost at solo scale.

### Option 2: Subscription (monthly/annual)

**Revenue model:** Free tier with limits, paid tier removes limits + adds premium features.

**Pricing (India):**
- ₹99/month or ₹499/year — comparable to a Zomato Gold or a Spotify India
- ₹999/year "Pro" — comparable to CRED, includes family management, unlimited
  documents, priority Q&A

**Free tier (current):**
- 5 documents
- 10 queries/day per device
- Basic policy summary + detail screen
- Q&A with sourced answers
- Emergency card, claims assistant, renewal tracking

**Paid tier unlocks:**
- Unlimited documents
- Priority Q&A (faster backend, no rate limits)
- Family coverage management (per-member coverage tracking)
- Coverage gap alerts (push notifications when a gap is detected)
- Policy comparison (compare 2-3 policies side-by-side)
- Export policy summary as PDF (share with family/CA)
- Ad-free (if we ever add ads — but we won't)

**Payment integration for India:**
- **Razorpay** — supports UPI, cards, netbanking, wallets. Industry standard
  for Indian SaaS. 2% transaction fee. Setup: 2-3 days (KYC).
- **Google Play Billing** — required for digital subscriptions on Android
  (Google's 15-30% cut). Simpler setup but higher fees.
- **Cashfree / PhonePe / PayU** — alternatives, similar pricing.

**Expected revenue (conservative, solo launch):**
- 100 installs/month → 30 active users → 3-5 convert (10-15%) → ₹1,500-2,500/mo
- After 6 months: 500 active → 50-75 convert → ₹25,000-37,500/mo ($300-450)
- Break-even (server cost ~₹500/mo) at: 1 subscriber

**Pros:**
- Aligns with the product's value (pay for more policies = more value)
- Recurring revenue
- Razorpay/UPI is seamless for Indian users
- Doesn't compromise trust (unlike ads)
- Data shows Indian users DO pay for financial tools (CRED, Groww Pro, etc.)

**Cons:**
- Payment integration adds code + KYC setup time
- Subscription fatigue (users already have 5+ subscriptions)
- App store billing rules (Google takes 15-30% if using Play Billing)
- Churn management needed

**Verdict:** ✅ **YES — this is the right model.** Subscription aligns revenue
with value delivered, works for India (UPI/Razorpay), and doesn't destroy trust.

### Option 3: One-time unlock

**Revenue model:** Free basic, pay once for lifetime "Pro."

**Pricing:** ₹499 one-time (or ₹299 launch price).

**Pros:**
- Simpler than subscription (no recurring billing, no churn)
- Indian users prefer one-time payments over subscriptions
- No payment gateway recurring mandate complexity
- Good for "buy once, use forever" financial tools

**Cons:**
- No recurring revenue (harder to sustain)
- Users expect lifetime updates for ₹499 — unsustainable if API costs grow
- Can't offer server-side premium features forever without recurring revenue
- Less common in mobile apps (stores push subscriptions)

**Verdict:** ⚠️ **Maybe as a launch promotion** — offer ₹299 lifetime for the
first 100 users, then switch to subscription. Creates urgency + early revenue.

### Option 4: Freemium with affiliate revenue

**Revenue model:** Free app, earn commission when users buy/renew insurance
through partner links.

**Partners:** PolicyBazaar, Acko, Digit, Star Health affiliate programs
(commission: 0.5-2% of premium, or flat ₹50-500 per lead).

**Pros:**
- Zero payment friction (user never pays CoverWise)
- Aligns with the product (if the app detects a coverage gap, suggest a policy)
- Potentially high LTV per user (insurance premiums are ₹10K-50K/year)

**Cons:**
- **Conflict of interest.** If CoverWise earns commission on insurance sales,
    can the user trust its coverage gap analysis? Is it recommending a policy
    because it's best, or because it pays commission? This is the same problem
    PolicyBazaar has — and it erodes trust.
- Affiliate approval takes time (insurers vet partners)
- Commission tracking and reconciliation is complex
- Need a "we may earn commission" disclosure (which reduces trust further)

**Verdict:** ❌ **NO for launch.** The trust conflict kills it. CoverWise's
positioning is "we read your policy honestly" — affiliate revenue corrupts that.
MAYBE revisit as an opt-in "find better coverage" feature later, clearly
separated from the analysis tools.

### Option 5: Lead generation (sell leads to insurance agents)

**Revenue model:** Free for users. When a user wants to buy/renew/upgrade,
connect them with a licensed insurance agent. Charge the agent per lead.

**Pros:**
- No consumer-facing payment
- Higher intent than affiliate links (user explicitly asks to connect)
- Agents pay ₹100-500 per qualified lead

**Cons:**
- Need a network of licensed agents (regulatory complexity, IRDAI licensing)
- Agent quality control (bad agent = bad user experience)
- PII handling (sharing user contact with agents requires explicit consent)
- Takes time to build the agent network

**Verdict:** ❌ **NO for solo launch.** Too much operational and regulatory
overhead. Could work at scale with a dedicated team.

## Decision

**Subscription via Razorpay (UPI/cards), with a one-time launch offer.**

### Phase 1: Launch (free) — now
- Free tier with current limits (5 docs, rate-limited queries)
- All core features: policy detail, Q&A, emergency, claims, renewal, family
- Goal: user acquisition, feedback, proof of value

### Phase 2: Monetization (after 100+ active users)
- Razorpay integration (UPI + cards + netbanking)
- Free tier stays (3 documents, 10 queries/day)
- Paid tier: ₹99/month or ₹499/year
  - Unlimited documents
  - Priority Q&A (higher rate limits)
  - Export to PDF
  - Coverage gap alerts
- Launch promotion: first 100 paid users get ₹299 lifetime "Founding Member"
  badge

### Phase 3: Growth (after 500+ subscribers)
- Family plans (₹999/year for up to 6 family members)
- Add-on: expert consultation (connect with licensed advisor, revenue share)
- Consider Play Billing for international users

## Implementation path

### What to build now (Phase 1 — no payment code)
1. **Paywall screen** — shown when user hits a free-tier limit ("You've reached
   5 policies. Upgrade to add unlimited."). Buttons: "Upgrade" (coming soon) /
   "Not now."
2. **Usage tracking** — analytics events for `free_tier_limit_hit` so we can
   measure demand for paid features
3. **Settings: plan display** — shows "Free Plan" with usage stats (3/5 policies,
   7/10 queries today)

### What to build in Phase 2 (after traction)
1. **Razorpay integration** — checkout flow in-app (Razorpay Flutter SDK)
2. **Backend: subscription state** — store plan + expiry in Supabase, validate
   on each request
3. **Backend: dynamic rate limits** — paid users get higher limits
4. **Paywall: real checkout** — replace "coming soon" with actual Razorpay flow

### What NOT to build now
- No payment gateway integration (waste before there are users)
- No ad SDK (destroys trust)
- No affiliate links (trust conflict)
- No agent network (operational overhead)

## Razorpay notes

- Razorpay Flutter SDK: `razorpay_flutter` package
- KYC takes 2-3 business days (PAN, bank account, business proof)
- Transaction fee: 2% for UPI/cards, ~3% for international
- Subscriptions: Razorpay supports recurring via UPI AutoPay mandates
- Test mode available (no real money) for development
- Webhook for payment verification (backend confirms payment before unlocking)

## What this means for the codebase now

- Add a `paywall_screen.dart` that shows when limits are hit (no payment, just
  the wall + "coming soon" + analytics)
- Add `free_tier_limit_hit` analytics events
- Add plan display in Settings
- Do NOT add payment SDK yet — that's Phase 2
