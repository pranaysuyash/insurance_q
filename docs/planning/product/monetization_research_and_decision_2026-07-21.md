# CoverWise Monetization Research and Decision — 2026-07-21

## Status: DECISION PENDING (awaiting founder review)

This document supersedes `monetization_strategy_2026-07-20.md`. It incorporates
the founder's direct input, deep market research with sourced data, and a
first-principles analysis. Per motto_v4 §0.0.1 (whole-answer mandate) and §0.3
(documentation continuity), this is the canonical monetization artifact.

---

## Founder's directive (2026-07-21)

> "Lets not have 5 policies in free because most people dont even have more than
> 1, so 1 is free with maybe 5 questions, they can unlock more questions by
> watching ads or removing ads for a price or getting more policies+questions
> etc... dont just jump to making changes, document our discussions, your own
> analysis, maybe do a detailed research as well, document that as well first"

**Key elements the founder proposed:**
1. Free tier: 1 policy, ~5 questions
2. Unlock more questions by watching ads (rewarded ads)
3. "Remove ads" as a one-time purchase
4. More policies + questions as paid tiers
5. Research before implementation

---

## Research findings (sourced)

### Indian app market reality (Tier 1 evidence)

| Metric | India/SEA | Global | Source |
|---|---|---|---|
| Annual spend per user | <$5 (₹415) | — | Business of Apps 2026 |
| D35 download-to-paid conversion | 1.4% | 2.0% | RevenueCat 2026 |
| Year-1 RLTV per payer | $14 (₹1,160) | $23 | RevenueCat 2026 |
| Revenue per install (D60) | $0.11 | $0.55 | RevenueCat 2026 |
| 1st-year refund rate | 7.7% | 3.4% (NA) | RevenueCat 2026 |
| Median successful monthly price | ₹300-315 (~$3.75) | ₹830 (~$9.99) | RevenueCat 2026 |
| Median successful yearly price | ₹1,500 (~$18) | ₹3,300 ($39.99) | RevenueCat 2026 |

**Translation:** of every 1,000 Indian installs, expect 7-14 to ever pay, each
worth ~₹1,160 in year 1. At 10,000 installs: ~₹1.6L/year subscription revenue.

### Rewarded ads in India (Tier 2 — regional data, slightly dated)

| Format | India eCPM | US comparison | Source |
|---|---|---|---|
| Rewarded video | ~$1.50 | ~$13 | AdPumb/AdMob |
| Interstitial | ~$1.10 | ~$15 | AdPumb/AdMob |
| Banner | ~$0.10-0.34 | ~$0.61 | AdPumb/AdMob |

**Revenue math at 5,000 MAU:** if 30% watch 1 rewarded ad per session, 4
sessions/week → ~6,000 impressions/month → **₹750-1,500/month** from rewarded ads.

**Key insight (Adapty 2026):** rewarded ads are the ONLY ad format safe for
paying users because they're opt-in. Interstitials cause 6-7% churn. Banner ads
cause 20% abandonment. Rewarded ads can increase session length and retention
when the reward is meaningful.

### "Remove ads" one-time pricing (Tier 2)

- IN/SEA has the highest prevalence of lifetime/IAP tiers: 29.2% of apps
  (RevenueCat 2026). Indian users prefer one-time payments.
- Realistic "remove ads" one-time price for India: **₹199-499**.
- Above ₹699, conversion collapses.
- The pattern that works: **free (with ads) → ₹299-499 "remove ads" → ₹899/year
  Pro subscription**. One-time removes ads but NOT feature gates; subscription
  unlocks premium features.

### Insurance app monetization landscape (Tier 2)

| Player | Model | User-facing charge |
|---|---|---|
| PolicyBazaar | IRDAI broker (commission) | Free to user; ₹34B revenue from commission |
| Acko | Direct insurer | Premium (they ARE the insurer) |
| Star Health | Direct insurer | Premium |
| Ditto/Turtlemint | Advisory + broker | Free to user; commission backend |

**No major Indian insurance app charges users a subscription.** This is both a
gap (opportunity) and a warning (users expect insurance tools to be free).

**IRDAI commission rates (for future web-aggregator path):**
- Term insurance: 40% of Year-1 premium, 10% trail
- Health/motor: 15% of annual premium
- On a ₹15,000 health policy: commission = ₹2,250 (≈13 months of a ₹199/mo subscription)

### Free-tier design rules (Tier 2 — Rework/Adapty)

The quantitative rule: **what % of target customers can fully achieve their goal
on the free tier?**
- >50% → too generous (conversion stays <2%)
- <10% → too restrictive (aha moment never reached)
- Sweet spot: **20-40%**

**Is "1 policy, 5 questions" too restrictive?** The research says YES — but not
for the reason you'd think. The issue isn't the policy count (most Indians have
1-2 policies), it's the **5 questions being lifetime** rather than monthly.

- 1 policy is actually reasonable for the target user (most have 1 health or
  1 term policy)
- 5 questions LIFETIME is too restrictive — the user exhausts them in week 1
  and the app becomes useless
- 5 questions PER MONTH is the natural expansion trigger (the user runs out as
  their engagement grows, not immediately)

**The right limitation model:** capacity-based (like Dropbox's 2GB). Users
*grow into* the limit rather than hitting it on day 1.

---

## Analysis: the founder's model vs the research

### What the founder proposed vs what the data says

| Element | Founder's model | Research says | My assessment |
|---|---|---|---|
| Free: 1 policy | "most people don't have more than 1" | Correct — median Indian has 1-2 | ✅ **Agree: 1 policy is right** |
| Free: 5 questions | "maybe 5 questions" | 5 lifetime is too restrictive; 5/month works | ⚠️ **5/month, not lifetime** |
| Rewarded ads to unlock | "unlock more by watching ads" | ₹750-1,500/mo at 5K MAU; increases retention | ✅ **Good as secondary, not primary** |
| Remove ads for price | "removing ads for a price" | ₹199-499 one-time works in India | ✅ **Yes, as a tier between free and subscription** |
| More policies+questions | "getting more policies+questions etc" | Capacity-based limit — right model | ✅ **Agree** |

### What the research adds that the founder didn't mention

1. **Don't show ads to likely-subscribers** (30-day window rule). If a user
   might convert to subscription, don't pollute their experience with ads. Only
   monetize via ads after they've shown they won't pay.

2. **Subscription is ~8x more valuable than ads per user** in India. Don't
   optimize for ad revenue at the expense of subscription conversion.

3. **The IRDAI commission path** dwarfs everything. One policy sale
   (₹2,250 commission) = 13 months of subscription from one user. This is the
   long-term monetization — but requires IRDAI registration.

4. **Design for the 7.7% refund rate.** Indian users refund aggressively. No
   hard paywalls, generous free tier first.

5. **PPP pricing, not FX pricing.** ₹899/year, not ₹1,900 (which is what a
   $19.99 product auto-converts to).

---

## Recommended model (3-tier hybrid)

### Tier 1: Free (the aha moment)
- **1 policy** upload + full policy detail screen
- **5 questions/month** (resets monthly, NOT lifetime)
- **All tools**: emergency card, claims assistant, renewal tracking, family view
- **Rewarded ads**: watch a 30s ad to get +3 questions (max 2 times/month = 11 total)
- **No banner/interstitial ads** (they destroy trust in a financial product)

### Tier 2: Remove Ads (one-time)
- **₹299 one-time** (launch price; ₹499 after 100 users)
- Removes ALL ads including rewarded (if the user prefers ad-free)
- Does NOT unlock more policies or features
- This is for the user who says "I just want it clean, I don't need Pro"

### Tier 3: Pro (subscription)
- **₹899/year or ₹99/month** (PPP-priced for India)
- Unlimited policies
- Unlimited questions (priority Q&A — faster backend)
- Coverage gap alerts (push notifications)
- Export policy summary as PDF
- Family management (up to 6 members)
- Ad-free (included)

### Tier 4 (future): Commission (IRDAI web aggregator)
- When the app detects a coverage gap or renewal, offer to connect with insurers
- Earn 15-40% commission on policy sales
- Requires IRDAI registration (regulatory work, separate from the app)
- This is the real business — subscription is the bridge to get here

### Why this model works (first-principles)

1. **Free delivers real value**: 1 policy + 5 questions/month + all tools = the
   user understands their insurance. That's the core promise delivered free.
2. **The limit creates natural upgrade pressure**: users who want a 2nd policy
   (spouse, parent, vehicle) or more questions hit the wall naturally as their
   life expands — not artificially.
3. **Rewarded ads monetize the 95% who won't pay** without destroying trust
   (opt-in, value-exchange).
4. **"Remove ads" captures the price-sensitive but ad-averse user** — a segment
   that won't pay ₹899 but will pay ₹299 once.
5. **Subscription captures the power user** who wants unlimited everything.
6. **Commission is the long-term play** that makes the app a business, not a
   side project.

### Why NOT banner/interstitial ads

- A financial trust product showing random ads undermines the core value prop
  ("we honestly read your policy")
- Interstitials cause 6-7% churn (Adapty 2026)
- Banner ads cause 20% abandonment
- Rewarded ads only — opt-in, user gets something for their time

---

## Anything else? (motto_v4 §0.1.1)

**Q: What about the existing entitlement system?**
A: A parallel agent built `PlanTier` (free/plus/family), `EntitlementService`,
`QaPacksScreen`, `UpgradeScreen` with RevenueCat. This model is compatible:
- free = Tier 1
- plus = Tier 3 (Pro)
- family = Tier 3 with family features
- Q&A Packs = an alternative to rewarded ads (buy 5 questions without subscription)
- The "remove ads" tier is NEW and needs to be added
- The free tier limits need to change from "5 policies" to "1 policy, 5 questions/month"

**Q: What about users who already have 5 policies stored?**
A: Grandfather them — don't remove data. But prevent new uploads until they
upgrade. This respects existing users while enforcing the new limit.

**Q: How does the rewarded-ad "watch for +3 questions" work technically?**
A: Google Mobile Ads SDK (`google_mobile_ads` Flutter package). Show a rewarded
video, on completion call `EntitlementService.addRewardQuestions(3)`. Track via
analytics (`rewarded_ad_completed`). Limit to 2/month (6 extra questions max).

**Q: What about the ad SDK weight/privacy?**
A: `google_mobile_ads` adds ~2MB to the APK. It uses Google's advertising ID
(which users can reset). Privacy policy must disclose ad SDK data collection.
This is a manageable tradeoff for the revenue.

**Q: Does this conflict with the "private by design" onboarding promise?**
A: Yes, slightly. The onboarding says "Your data stays yours" — adding ad SDKs
means Google collects usage data for ad targeting. Mitigate: (1) only show
rewarded ads (opt-in, user chooses), (2) disclose in privacy policy, (3) offer
"remove ads" as a clear escape hatch. The user is in control.

**Q: When should ads appear?**
A: Only after the user has hit the 5-question monthly limit. NOT on first use,
NOT before the aha moment, NOT for likely-subscribers (30-day heuristic: if the
user has been active for 30 days without hitting the limit, they're a likely
subscriber — don't show them ads).

---

## Implementation plan (NOT starting yet — awaiting founder review)

When approved, the work is approximately:

1. **Change free tier limits** in `entitlement.dart`: 1 policy, 5 questions/month
2. **Add rewarded ads SDK** (`google_mobile_ads`) + rewarded ad flow
3. **Add "Remove Ads" tier** to `PlanTier` enum + entitlement system
4. **Update paywall screen** to show 3 options (watch ad / remove ads / go Pro)
5. **Update pricing** to PPP-adjusted INR (₹299 one-time, ₹899/year)
6. **Add monthly question counter** (resets each month, tracked in Hive)
7. **Update privacy policy** to disclose ad SDK data collection
8. **Analytics**: `rewarded_ad_shown`, `rewarded_ad_completed`, `remove_ads_purchased`

Estimated: 4-5 commits, gated. No external accounts needed except AdMob
(free to create, takes 24h for approval).

---

## Sources

- [Business of Apps — India App Market Statistics](https://www.businessofapps.com/data/india-app-market/)
- [RevenueCat — State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps)
- [Adapty — Hybrid Monetization for Subscription Apps](https://adapty.io/blog/hybrid-monetization-for-subscription-apps/)
- [AdPumb — AdMob Revenue Guide India](https://adpumb.com/blog/admob-revenue-guide/)
- [Rework — Freemium Model Design](https://resources.rework.com/libraries/saas-growth/freemium-model-design)
- [Cafemutual — IRDAI Web Aggregator Commission Rules](https://cafemutual.com/news/insurance/8364-irdai-allows-insurers-to-pay-commission-to-web-aggregators-on-policy-sales)
- [PricePush — Google Play IAP Pricing by Country](https://pricepush.app/blog/google-play-iap-pricing-by-country)
