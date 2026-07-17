# CoverWise Monetization, Advertising, and Responsible Data Research

## Owner decision addendum (2026-07-16): permanently solo and non-regulated

The owner has made a permanent product decision:

- CoverWise will be operated as a solo software product.
- It will not become an insurer, broker, agent, web aggregator, marketplace, claims representative, or regulated insurance intermediary.
- It will not solicit, sell, procure, renew, recommend, or rank insurance products.
- It will not earn insurance commissions, sell insurance leads, or build insurer/broker distribution tooling.
- Its insurance purpose is limited to helping users understand, organize, search, factually compare, and remember information in policies they already have.
- A possible health lane must remain personal organization/wellness software: no diagnosis, treatment, disease prediction, clinical risk score, care recommendation, or sharing with insurers, advertisers, employers, or data buyers.

This supersedes the earlier exploration of regulated partnerships, commissions, paid insurance experts, claim-preparation services, and insurer/broker B2B products. Those paths are rejected, not deferred. It does not prohibit evidence-based comparisons of policies the user already owns.

### Boundary test

Ask: **Does this explain a conclusion from the user's own documents, or does it tell the user what insurance/medical action to take or act on their behalf?** Evidence-based conclusions about price and documented terms fit CoverWise; unsupported personal recommendations do not.

### What CoverWise may say

> Policy A costs ₹10,000 per year and Policy B costs ₹6,000. Based on the documents uploaded, Policy B is ₹4,000 cheaper (40% less) and we found no difference in the listed sum insured. Policy A lists a shorter waiting period for [benefit] and Policy B has [exclusion/sub-limit]. The documents do not establish which policy is better for your personal situation.

Scoped labels are acceptable: **lower premium**, **broader documented benefits**, **shorter documented waiting period**, **higher deductible**, or **more exclusions listed**. Each label should link to source clauses, show missing/uncertain fields, and state the comparison basis.

Avoid: "Policy B is better for you," "You should switch," "Policy A is overpriced," or "This is the best plan." Price alone does not establish equivalence; exclusions, deductibles, sub-limits, waiting periods, riders, taxes, claim conditions, underwriting, and missing pages can change the result.

### Comparison contract

Every comparison result must:

1. compare only policies the user supplied or explicitly selected;
2. normalize currency, payment frequency, taxes, riders, discounts, and period;
3. calculate differences with an explicit denominator: ₹6,000 is 40% cheaper than ₹10,000, while ₹10,000 is 66.7% more than ₹6,000;
4. compare fields independently rather than treating "same cover" as an assertion;
5. cite the source page or section for each material conclusion;
6. show missing, contradictory, or unextractable fields;
7. use scoped conclusions such as "lower premium" or "shorter listed waiting period";
8. avoid an overall winner, switch instruction, purchase instruction, or renewal instruction;
9. state that price and listed terms do not establish suitability, claim outcome, or equivalence;
10. preserve the original documents and let the user inspect the evidence.

This is a product behavior contract, not merely a copy preference. The pipeline must produce structured comparison evidence before the UI renders comparative language.

### Feature audit

| Feature | Decision | Required framing |
|---|---|---|
| Policy extraction, summary, citations, Q&A | Keep | Faithful explanation; document-grounded and uncertainty-aware |
| Renewal reminders | Keep | Calendar reminder, not renewal recommendation or transaction |
| Insurer contacts | Keep | Convenience only; no routed or paid lead |
| Owned-policy comparison | Keep | Dimension-specific judgments are allowed; no unsupported overall winner or buy/renew instruction |
| Personal claim log | Keep with limits | User-maintained record; no filing, negotiation, prediction, or representation |
| Family policy inventory | Keep with limits | Show documented membership; do not infer what anyone should buy |
| Coverage-gap detection | Reframe or remove | "Not found in uploaded documents," never "under-insured" or recommended amount |
| Renewal decision support | Remove | Show dates and existing terms only |
| Premium what-if calculator | Remove | Simulates pricing/underwriting without authoritative inputs |
| Product shopping, ranking, quotes, referrals | Remove | Outside permanent scope |
| Paid expert or claim-support service | Remove | Advice/representation ambiguity and solo burden |
| Commission, leads, insurer/broker tooling | Permanently reject | Conflicts with the product identity |
| General subscription | Keep | Charge for software capacity, storage, sync, organization, and convenience |
| Health tracking | Explore separately | Manual/private records and neutral trends; no medical conclusions |

### Health-tracking safe lane

Health tracking is not insurance intermediation, but it changes privacy, app-store, safety, and product scope. Google Play treats health tracking and health-record management as health-app features, requires an accurate Health Apps declaration and privacy disclosure, and requires non-medical-device apps to state that they do not diagnose, treat, cure, or prevent medical conditions.

The coherent lane is a **private personal health and benefits organizer**:

- user-entered measurements and notes;
- medication, appointment, vaccination, and preventive-check reminders;
- storage of records the user chooses to keep;
- neutral charts of user-entered values;
- benefits copied from the user's policy, clearly separated from medical guidance;
- export for the user to take to a clinician.

Exclude symptom checking, diagnosis, treatment/dosage recommendations, disease prediction, triage, clinical risk scoring, insurer eligibility/premium/claim predictions, third-party sensitive-data access, and default training use.

Recommendation: keep health tracking **local-first, manual, minimal, exportable, and optional**, and add it only after the policy-understanding product shows retention. A broad health platform would dilute the product and create a large solo-founder security and support burden.

**Date:** 2026-07-16  
**Status:** research-backed direction; legal, tax, and IRDAI review required before regulated revenue  
**Scope:** India-first, solo-operated consumer software  
**Evidence:** repository inspection and current primary sources. Regulatory interpretations are not legal advice.

## Executive decision

CoverWise should monetize trust, clarity, and ongoing policy management, not access to sensitive policy contents.

1. Launch a **freemium consumer subscription**: keep the first useful policy outcome free; charge for ongoing household management and costly AI features.
2. Add **clearly priced expert services** for policy review and claim-document preparation, with regulated work performed by an appropriately qualified partner.
3. Keep expansion focused on consumer software, not insurer/broker distribution.
4. Permanently exclude insurance commissions, compensated leads, solicitation, and procurement.
5. Reject **third-party behavioral ads** in the policy product. A later sponsorship test may use fixed, first-party, contextual placements only on public education surfaces.
6. Never train shared models on customer documents by default. Use a separate, optional, revocable contribution program with quarantine, provenance, de-identification, privacy review, and release gates.

Behavioral advertising and silent corpus reuse would exchange CoverWise's central asset, user trust, for weak near-term revenue.

## Product and market reality

Large Indian distributors already provide free comparison, purchase, policy management, renewal, and claims-assistance surfaces. Policybazaar describes comparison, purchase, policy storage, renewal, and claims support in one app. Ditto offers zero-cost advisor calls and lifetime claim support, monetized through the insurance purchase journey.

A paid generic policy vault is therefore weak. CoverWise's paid value must be recurring, neutral intelligence:

- explain an existing policy regardless of where it was purchased;
- maintain a household coverage inventory;
- provide sourced answers and expose ambiguity;
- support renewal and coverage reviews;
- prepare users for insurer and broker conversations;
- reduce claim-time document chaos;
- preserve user control without sales pressure.

The strongest position is **independent policy intelligence**, not another marketplace and not AI insurance advice.

## Monetization option matrix

| Model | Alignment | Regulatory load | Trust risk | Decision |
|---|---:|---:|---:|---|
| Consumer subscription | High | Low-medium | Low | **Build first** |
| Fixed-fee expert review | High | Medium | Low-medium | **Pilot with strict scope** |
| Claim preparation/support | Medium | Medium-high | Medium | **Reject; personal log only** |
| Employer/benefits workspace | Medium | Medium-high | Medium | **Reject for this product** |
| Broker/insurer API | Medium | High | High | **Reject for this product** |
| Insurance commission | Medium | High | High conflict risk | **Permanently reject** |
| Lead sale | Medium | High | High | **Reject as default** |
| Behavioral ads/AdMob | Low | High | Very high | **Reject in core app** |
| Fixed contextual sponsorship | Medium | Medium | Medium | **Narrow later experiment** |
| Aggregate benchmark product | Medium | High | High | **Only after privacy maturity** |
| Customer-derived training-data licensing | Low | Very high | Extreme | **Reject** |

## Ads vs Subscription: Deep Analysis (Updated 2026-07-17)

### The Core Tradeoff

| Dimension | Ads (AdMob/Contextual) | Subscription | Winner |
|-----------|----------------------|-------------|--------|
| **Revenue per user** | ₹0.10-0.30/month (Indian CPM ₹10-30) | ₹149-249/month | Subscription (20-50x) |
| **User trust** | Low — ads beside sensitive policy data feel exploitative | High — user pays for value, no data exploitation | Subscription |
| **Regulatory load** | High — DPDP consent, Google Play health-app rules, IRDAI ad rules | Low-medium — standard consumer software | Subscription |
| **Retention impact** | Negative — ads increase churn in utility apps | Positive — paid users have 2-3x higher retention | Subscription |
| **Solo founder burden** | High — ad mediation, fill rate optimization, creative management | Low — set pricing, ship product, measure conversion | Subscription |
| **Time to revenue** | Fast (1-2 weeks to integrate AdMob) | Medium (2-4 weeks for billing integration) | Ads (marginal) |
| **Scalability** | Linear with DAU | Exponential with conversion rate improvements | Subscription |
| **Data liability** | Very high — SDK telemetry, targeting, PII risk | Low — no third-party data sharing | Subscription |

### The Case FOR Ads (Devil's Advocate)

1. **Zero friction to monetize.** Every user who downloads and sees ads is monetized immediately. No conversion funnel, no billing integration, no payment failure recovery. With subscription, you need 5-10% of free users to pay ₹149/month to make meaningful revenue.

2. **Distribution advantage.** An ad-supported free tier removes all limits. Users get unlimited Q&A, unlimited documents, full comparison — and you monetize attention. This could accelerate user growth dramatically.

3. **Market reality.** Indian insurance app users are price-sensitive. ₹149/month sounds small, but for many Indian households it's non-trivial. PolicyBazaar's entire business model is "free for the user, monetized by insurer commissions." Users are already conditioned to expect free.

4. **Ad networks have matured.** Google's privacy sandbox, contextual targeting, and consent frameworks have improved. You can serve contextual insurance ads without reading document content — just the category (health, auto, life) and rough demographics.

### The Case AGAINST Ads (Why Subscription Wins)

1. **Trust is your only moat.** CoverWise's entire value proposition is: "We help you understand your own policy. We don't sell you anything. We don't sell your data." The moment you put an ad next to a detected coverage gap, that message is dead.
   - User sees "Your health policy has a coverage gap" → right below it: "Get a better health plan! Click here." Even if the ad is technically contextual, the user thinks: "They're using my gap to sell me something."
   - User uploads a policy with their name, address, health details → AdMob SDK loads. User Googles "what data does AdMob collect" → finds device IDs, location, usage patterns. User uninstalls.
   - User asks "What's excluded from my policy?" → answer includes an ad for an insurance broker. CoverWise becomes indistinguishable from PolicyBazaar.

2. **Indian insurance CPMs are terrible.** Indian insurance ad CPMs are ₹10-30 (USD $0.12-0.35).
   - You need ~100,000 monthly active users to earn ₹10,000-30,000/month from ads
   - That's roughly ₹0.10-0.30 per user per month from ads
   - Even if 5% of users pay ₹149/month for Plus, that's ₹7.45 per user per month — 25-75x more per paying user
   - And paying users are more engaged, less likely to churn, and more likely to refer

3. **Ad SDKs are a compliance minefield in India.** Google Play requires accurate Data Safety declarations. If you declare "share data with advertising partners" and your app handles health insurance documents, you trigger additional scrutiny:
   - Health app disclosure requirements
   - Sensitive-permission data restrictions
   - DPDP Act consent requirements for ad tracking
   - IRDAI advertising rules if ads are insurance-related
   - A solo founder managing all this is a significant burden.

4. **Ads kill the premium upsell.** If the free experience is ad-supported and fully featured (unlimited docs, unlimited Q&A), there's zero reason to upgrade to Plus. The only Plus benefit becomes "no ads" — which users will tolerate if the ads are contextual and not too aggressive. With subscription-only, the free tier is genuinely limited (1 policy, basic Q&A). Users who find value hit the wall and convert.

5. **The "ad-free" promise is fragile.** Once you introduce ads, removing them later (if you switch to subscription) is perceived as a regression. Users who downloaded because "free with ads" existed will churn when you remove the free tier. You've locked yourself into the ad model.

### Specific Trust-Destroying Scenarios

| Scenario | What Happens | Trust Impact |
|----------|-------------|-------------|
| Coverage gap + ad | "Your health policy has a gap" → ad for better plan | User thinks app is using their data to sell insurance |
| Policy upload + AdMob | User uploads health docs, AdMob SDK loads | User Googles data collection, uninstalls |
| Q&A + ad | Answer about exclusions includes broker ad | App becomes indistinguishable from PolicyBazaar |
| Emergency screen + ad | Insurance helpline number with ad above it | Life-safety context trivialized by commercial content |

### When Ads *Could* Make Sense (Stage 4+)

Only after subscription retention evidence, and only on **public education surfaces** (blog, glossary, landing page)—never inside the authenticated policy workspace:

- Fixed-price sponsorships (e.g., "Covered by ICICI Lombard") on the public insurance literacy section
- Display ads on the public blog/SEO content
- No SDK inside the app itself
- No targeting based on policy contents, health, or family data
- Removable for paid subscribers

### Decision: Subscription First, Pay-per-Q&A Packs as Alternative

**Primary model:** Subscription (Free → Plus → Family)
**Secondary model:** Pay-per-Q&A packs for occasional users who don't want a subscription

The hybrid approach captures both segments:
- Users who need ongoing household management → subscription
- Users who upload 1 policy and ask 20 questions once, then don't use the app for months → packs

This avoids the "ad-supported free tier" trap while still monetizing low-engagement users.

**Final decision: Ads rejected in core app. Subscription is primary. Packs are secondary. Contextual sponsorship only on public education surfaces, only after subscription evidence.**

---

## Final Pricing Hypotheses (Implemented in Code)

Prices are test hypotheses, not forecasts. All limits and prices are tunable via `mobile/lib/models/entitlement.dart`.

### Free: understand one policy

**Price:** Free forever

- 1 active policy;
- useful summary and key fields;
- 20 questions/month;
- basic renewal date;
- sourced answers, export, and deletion;
- insurance health score;
- emergency screen;
- preventive health tips.

The free tier must reach the real aha moment. Uploading without useful interpretation will not build conversion. The free tier is generous enough to demonstrate value but limited enough to motivate upgrade.

**Conversion trigger:** User hits the 1-policy limit or wants to compare two policies.

### Plus: household policy companion

**Price:** ₹149/month or ₹999/year (₹83/month equivalent — 44% savings)

- up to 10 active policies;
- family coverage view;
- 200 questions/month;
- renewal reminders and calendar actions;
- two-policy comparison;
- encrypted cloud sync and structured export;
- claim-ready document bundle;
- advanced cross-document search.

**Why ₹149/month:** Below Netflix (₹149-649), below any insurance premium, positioned as "insurance for your insurance." Indian mobile-first users are price-sensitive but willing to pay for clear utility. ₹149 is the psychological threshold where the value proposition is obvious.

**Why ₹999/year:** Annual discount drives commitment. ₹83/month equivalent feels like a steal. Annual subscribers have 2-3x higher retention.

**Conversion trigger:** User has 2+ policies or wants family view.

### Family: ongoing household management

**Price:** ₹249/month or ₹1,799/year (₹150/month equivalent — 40% savings)

- 50 active policies (fair-use);
- 500 questions/month;
- household sharing and emergency access;
- coverage-review prompts;
- richer comparison and renewal history;
- annual structured coverage review;
- advanced search;
- priority support.

**Why ₹249/month:** The family plan targets households with 3-5+ policies across multiple family members. ₹249 is still below any single insurance premium. The emergency access feature alone justifies the price for families.

**Why ₹1,799/year:** ₹150/month equivalent. Annual pricing locks in the household for a full renewal cycle.

**Conversion trigger:** User manages insurance for 3+ family members.

### Pricing Psychology Notes

- **No free trial** — the free tier IS the trial. Users experience real value before paying.

- **Annual discount is aggressive** — 40-44% off monthly. This is intentional: annual subscribers are stickier, have lower churn, and provide predictable revenue.

- **No per-feature pricing** — clean tiers avoid decision paralysis. Users upgrade when they hit limits, not when they want one feature.

- **No regional pricing** — ₹149/₹249 works across India. Regional pricing adds complexity without measurable benefit at current scale.

- **No family member limits** — the Family plan is per-household, not per-person. This avoids the complexity of tracking individual family members.

### Revenue Projections (Hypotheses)

| Scenario | MAU | Free→Plus | Free→Family | MRR | ARR |
|----------|-----|-----------|-------------|-----|-----|
| Conservative (Month 6) | 5,000 | 2% | 0.5% | ₹17,450 | ₹2,09,400 |
| Moderate (Month 12) | 20,000 | 3% | 1% | ₹1,39,600 | ₹16,75,200 |
| Optimistic (Month 18) | 50,000 | 5% | 2% | ₹7,45,000 | ₹89,40,000 |

**Break-even estimate:** ~500 paying subscribers covers a solo founder's basic infrastructure costs (Cloud Run, Supabase, OpenAI API).

### Unit Economics Target

| Metric | Target | Rationale |
|--------|--------|----------|
| Cost per successful policy processing | < ₹5 | OCR + LLM + storage |
| Cost per Q&A answer | < ₹1 | Embedding + retrieval + generation |
| Gross margin per Plus subscriber | > 85% | ₹149 revenue - ~₹20 COGS |
| Gross margin per Family subscriber | > 80% | ₹249 revenue - ~₹45 COGS |
| LTV/CAC ratio | > 3:1 | Sustainable growth |
| Payback period | < 3 months | Recover acquisition cost quickly |

---

## Fixed-fee services (Future)

- policy wording review and question list;
- pre-renewal coverage inventory;
- human review of low-confidence extraction.

The product and terms must distinguish software information, administrative assistance, regulated advice, solicitation, and claims representation.

## Rejected B2B and distribution paths

The following was evaluated and is now preserved only as rejected-path rationale. It is not part of the roadmap.

Potential customers include IRDAI-registered brokers and corporate agents, insurers and TPAs, employer-benefits platforms, and financial-wellness providers.

Sell outcomes, not raw data:

- policy intake and normalization API;
- white-label policy-understanding experience;
- renewal and document-completeness workflow;
- source-grounded agent assist;
- claim-packet completeness checks;
- aggregate operational analytics computed within a customer's tenant.

CoverWise will not sell these products. It also will not sell cross-customer corpora, individual scores, policyholder leads, or health/financial segments.

## Insurance distribution boundary

The Insurance Act restricts commission or other remuneration for soliciting or procuring insurance business to insurance agents or insurance intermediaries in the manner regulations permit. IRDAI separately regulates corporate agents, brokers, web aggregators, insurance marketing firms, advertisements, and remuneration.

Consequences:

- Do not disguise compensated insurance procurement as ordinary affiliate revenue.
- Do not rank products by commercial payout.
- Do not present a buy funnel as though CoverWise were a licensed intermediary.
- Commission revenue and compensated insurance referrals are permanently excluded.
- Preserve a non-regulated subscription path useful for policies bought anywhere.

The regulatory analysis is retained to explain the boundary, not to propose a future registration path.

## Advertising decision

### Why ad networks are a poor fit

Policy documents can reveal health, family, age, address, financial position, identifiers, nominees, premiums, and claims. Even without sending document text, an ad SDK adds identifiers, telemetry, sharing disclosures, consent, incident surface, and user suspicion.

Google Play makes the developer responsible for SDK practices, requires accurate Data Safety declarations, and applies health-app disclosure rules. Sensitive-permission data cannot be repurposed for advertising or marketing, and Google's ad products restrict personalized targeting based on health and sensitive financial interests.

An insurance or loan ad beside a detected coverage gap can look exploitative even when targeting is technically contextual.

### Prohibited practices

- No targeting based on policy type, insurer, premium, exclusions, health, family, claim, Q&A, renewal, or inferred gap.
- No ad SDK on upload, detail, Q&A, family, gap, claim, or emergency screens.
- No audience export, remarketing, lookalike seed, Customer Match, or conversion signal from sensitive workflows.
- No lead sale inferred from policy contents.
- No sponsored ranking disguised as recommendation.
- No creative implying knowledge of health, hardship, or claim state.

### Possible narrow sponsorship

If later tested, sponsorship must be directly sold, fixed to a broad public-education context, labeled with sponsor identity, independent of profile and documents, absent from trusted workflows, frequency-limited without cross-app identifiers, reviewed under IRDAI advertising rules when applicable, and removable for subscribers.

**Initial decision: no ads.** Revisit only after subscription retention evidence and only outside the authenticated policy workspace.

## Responsible model-improvement architecture

### Core rule

Customer uploads, extracted text, questions, answers, and feedback are used only to provide the product by default. Shared training is a separate purpose.

Removing names is insufficient. Insurance records contain direct identifiers, free text, metadata, exact dates, rare combinations, health details, employer data, family structure, and other quasi-identifiers. NIST treats de-identification as risk management in which transformation is only one control.

### Four data zones

**Zone A: operational customer data**

- Original, OCR text, embeddings, fields, questions, and answers.
- Owner-scoped; training jobs cannot read it directly.
- Subject to product deletion and retention.

**Zone B: contribution quarantine**

- Created only after separate opt-in.
- Holds consent version, purpose, source, allowed uses, expiry, and revocation token.
- Not training-eligible and accessible only to the privacy pipeline and authorized reviewers.

**Zone C: approved research corpus**

- Passed automated detection, transformation, human review where required, and re-identification-risk tests.
- Identity linkage removed from the research environment. A separately protected provenance service holds the minimum mapping needed for withdrawal.
- Dataset cards record composition, exclusions, provenance, purpose, transformations, bias, residual risk, and expiry.

**Zone D: model and evaluation artifacts**

- Trained adapters/models, approved synthetic fixtures, and aggregate metrics.
- No raw text in logs, trackers, prompts, checkpoints, filenames, or errors.
- Memorization and canary-extraction tests before release.

### Granular contribution choices

All controls default off except non-content operational analytics already disclosed:

1. Product analytics: bucketed, content-free events.
2. Answer quality: thumbs signal; optional comment remains support data unless separately contributed.
3. Corrected fields: show the exact redacted derivative and ask for confirmation.
4. Redacted policy sample: separate higher-friction consent, preview, and withdrawal.
5. Research study: distinct study-specific governance.

Consent must be free, specific, informed, unambiguous, purpose-limited, evidenced, and as easy to withdraw as to give. It must not be bundled with core use.

### De-identification and release pipeline

1. Validate source and consent receipt.
2. Strip metadata, hidden layers, annotations, signatures, images, barcodes, and attachments unless required.
3. Detect names, contacts, addresses, policy/member/claim/account IDs, government IDs, vehicle IDs, employer IDs, and signatures.
4. Detect quasi-identifiers: exact dates/ages, diagnoses, procedures, hospitals, rare occupations/locations, household links, amounts, and narratives.
5. Redact, generalize, tokenize, bucket, perturb, or synthetically replace according to task.
6. Preserve controlled consistency only where layout or relationships require it.
7. Reject artifacts whose utility depends on high-risk free text or rare combinations.
8. Run an independent detector and leakage scan.
9. Conduct sampled restricted human review with no local download.
10. Measure residual re-identification risk and record the release decision.
11. Store only the approved derivative with version lineage and expiry.
12. Re-run privacy and memorization tests for every dataset/model release.

### Task-specific source policy

| Task | Preferred sources | Customer-derived boundary |
|---|---|---|
| OCR/layout | Public/synthetic templates | Only consented pages after visual/metadata review |
| Field extraction | Synthetic policies and corrected structured fields | Prefer derivatives over raw text |
| Classification | Public wordings and synthetic labels | Private docs only for essential measured gaps |
| Retrieval/reranking | Public wordings, synthetic questions, expert judgments | No raw private questions by default |
| Answer generation | Public wordings, expert Q&A, red-team cases | Private Q&A needs separate consent/redaction |
| Evaluation | Public/synthetic plus separately consented edge cases | Isolate evaluation from training |

### Never eligible for shared training

- non-consenting uploads or Q&A;
- government IDs, policy/member/claim/account/payment data, signatures, or contacts;
- linked health/claim narratives;
- support messages or feedback silently repurposed;
- production logs, traces, or prompt payloads;
- child/dependent data without a validated pathway;
- data under deletion, uncertain consent/provenance, or contractual restriction.

### Prefer less invasive learning

- insurer-published wordings and Customer Information Sheets with provenance review;
- expert-authored schemas, rubrics, and edge cases;
- controlled synthetic documents with human/statistical validation;
- aggregate on-device success counters;
- active learning on a single redacted field, not a whole document;
- tenant-specific retrieval/evaluation for enterprise customers.

Federated learning or confidential compute may later reduce data movement, but neither removes consent, leakage, poisoning, or governance risk.

## DPDP-derived product requirements

The DPDP Act requires lawful purpose and consent that is free, specific, informed, unconditional, unambiguous, affirmative, and limited to necessary data. It provides withdrawal rights and cessation of consent-based processing, subject to lawful exceptions. The notified 2025 Rules add implementation detail and staged commencement.

Required capabilities:

- purpose registry for every data class and processor;
- versioned just-in-time notices and consent receipts;
- withdrawal history and processor propagation;
- deletion across object, metadata, vector, cache, analytics identity, quarantine, and approved corpus where applicable;
- automated retention expiry;
- rights/grievance workflow and breach runbook;
- child/dependent-data decision before family expansion;
- cross-border and subprocessor review;
- evidence-based determination of when transformed data is no longer personal data.

## Metrics and unit economics

### Trust and value

- households with one successfully understood policy;
- 30/90-day retained households completing renewal, Q&A, comparison, or family actions;
- answer helpfulness and correction rate;
- low-confidence review rate;
- deletion completion across stores;
- contribution opt-in, withdrawal, and rejection;
- support contacts caused by misleading answers.

### Commercial

- free-to-paid conversion after successful summary;
- annual-plan share and churn reason;
- gross margin per household after OCR/LLM/storage/support;
- service attach rate and fulfillment cost;
- **cost per successful policy processing:** target < ₹5 (OCR + LLM + storage);
- **cost per Q&A answer:** target < ₹1 (embedding + retrieval + generation);
- **gross margin per Plus subscriber:** target > 85% (₹149 revenue - ~₹20 COGS);
- **gross margin per Family subscriber:** target > 80% (₹249 revenue - ~₹45 COGS);
- **LTV/CAC ratio:** target > 3:1;
- **payback period:** target < 3 months.

Pricing must never vary using inferred health, claim urgency, insurer, policy premium, or financial status. Deletion, export, and safety features remain available without payment.

## Implementation status (2026-07-16)

The following architecture seams from the original research are now partially or fully implemented:

| Seam | Status | Evidence |
|------|--------|----------|
| **Entitlements service** | ✅ Implemented | `EntitlementService` (Hive-backed), `EntitlementProvider` (Riverpod), `PlanTier` enum with `PlanLimits` registry |
| **Billing adapter** | ✅ Skeleton | `BillingAdapter` with product ID mapping (`coverwise_plus_monthly`, etc.), purchase/restore/manage stubs, `handlePaymentConfirmation` webhook handler |
| **Consent ledger** | ✅ Implemented | `ConsentLedger` with purpose-specific grant/revoke/hasConsent, integrated into upload flow |
| **Analytics schema** | ✅ Implemented | `validateAnalyticsEvent` with event registry, required properties, type checking, PII detection |
| **Cost attribution** | 🔲 Not started | No per-operation cost tracking yet |
| **Commercial disclosure registry** | 🔲 Not started | No partner/compensation tracking |
| **Dataset registry** | 🔲 Not started | No model contribution governance |
| **Privacy pipeline** | 🔲 Not started | No quarantine/de-identification/release gates |

### What's built and working

- **Plan tier system:** Free (1 policy, 20 Q&A/month), Plus (10 policies, 200 Q&A/month, ₹149/₹999), Family (50 policies, 500 Q&A/month, ₹249/₹1,799)
- **Feature gating:** `checkAction()` returns reason strings for disabled features (comparison, family view, cloud sync, emergency access, annual review, advanced search)
- **Usage tracking:** Q&A usage counted per month with automatic reset
- **Upload limits:** Policy count checked against plan limits before upload
- **Settings display:** Current plan shown in settings with upgrade CTA
- **Consent recording:** Purpose-specific consent in ConsentLedger on first upload
- **Analytics validation:** Server-side event/property validation with PII detection
- **Pay-per-Q&A packs:** `QaPackType` enum (starter ₹49/5Q, value ₹119/15Q, pro ₹199/30Q), `QaPack` model with 90-day expiry, FIFO consumption (subscription first, then packs by earliest expiry), `QaPacksScreen` purchase UI with balance card, pack cards, active pack display, and FAQ. Pack-aware entitlement gating in QA screen with budget banner and analytics tracking.
- **Emergency shortcut:** One-tap `_EmergencyShortcutButton` on DashboardScreen for fastest emergency access
- **Processing status:** Real-time stage indicators (Received → Reading → Extracting → Classifying → Indexing) with Dio fallback to local storage, PopScope dismiss warning, and auto-navigate on completion
- **Notification preferences:** Master toggle, custom reminder days, quiet hours, per-policy switches with try/finally error recovery
- **Coverage gap resolution tracking:** Filter bar (All/Open/Addressed), mark-as-addressed with notes dialog, resolution badge, strikethrough styling, reopen button, Hive-persisted
- **Insurance health score:** At-a-glance 0–100 score on dashboard with animated gauge, 4-factor breakdown
- **Policy share/export:** Share button in app bar + Quick Actions formats policy summary as readable text
- **Cross-document search:** SearchScreen with auto-focused search bar, type/status filter chips, highlighted text matches, ranked results
- **Document preview:** DocumentPreviewScreen with PDF viewer, page navigation, pinch-to-zoom, error states
- **What-If Calculator:** Coverage/deductible sliders, maternity/daycare/hospitalization toggles, estimation formulas
- **Dark mode / theme toggle:** System/Light/Dark picker in Settings → Appearance
- **Profile screen:** Identity, auth token, version, appearance, storage, privacy info, scope disclaimer

### What's needed before subscription launch

1. **Real billing integration:** Replace `BillingAdapter` stubs with RevenueCat or Google Play Billing
2. **Backend subscription sync:** Endpoint to verify receipt and sync entitlement state
3. **Cost attribution:** Per-operation tracking for OCR, LLM, storage costs
4. **Grace periods:** Handle expired subscriptions without data loss
5. **Webhook reliability:** Idempotent payment confirmation processing

## Architecture seams required before implementation

1. **Entitlements service:** canonical plan, allowance, grace, and feature decision.
2. **Billing adapter:** provider-neutral state, idempotent webhooks, reconciliation, refunds, audit.
3. **Commercial disclosure registry:** partner, regulated role, compensation, placement, approval.
4. **Purpose/consent ledger:** notice, consent, withdrawal, provenance, propagation.
5. **Dataset registry:** cards, provenance, allowed use, transformation, expiry, lineage.
6. **Privacy pipeline:** quarantine, detection, transformation, review, release, deletion.
7. **Cost attribution:** safe per-operation OCR/model/storage cost buckets.

These must extend the canonical backend and validation stack, not introduce duplicate routes or pipelines.

### Current implementation gaps found during research

- `src/api/analytics.py` accepts arbitrary event names and property dictionaries. The safe-event specification is documentation, not a server-enforced allowlist. Before production analytics or monetization experiments, add shared event/property validation, reject unknown content, test malicious/free-text payloads, and apply retention/deletion rules.
- `mobile/lib/services/analytics_service.dart` relies on every caller to honor the non-PII contract. A typed event API or generated schema should prevent accidental content properties at compile time.
- Answer feedback is stored locally using the full question as part of a Hive key. It is not currently transmitted in the feedback event, but local deletion, encryption, backup behavior, and migration should be verified before describing it as low risk.
- Processing consent exists in `mobile/lib/widgets/lead_capture_dialog.dart`, but it is not a purpose/consent ledger for model contribution, advertising, or commercial sharing.
- The app has no canonical entitlement, billing, commercial disclosure, dataset registry, contribution quarantine, or privacy release service today.
- The privacy draft still contains operator and retention placeholders. It is not publication-ready and must be reconciled with runtime and provider contracts.

## Staged roadmap

### Stage 0: trust and measurement

- finalize retention/deletion behavior;
- reconcile privacy policy, Data Safety, providers, and runtime;
- establish cost per successful policy and answer;
- document purpose and processor inventory;
- interview 12-20 users about willingness to pay and trust boundaries.

**Exit:** the team can explain what data exists, why, where, for how long, who receives it, and what one active household costs.

### Stage 1: subscription pilot

- validate Free and Plus;
- implement canonical entitlements and sandboxed billing;
- keep ads absent;
- measure activation, retention, conversion, support, and gross margin.

### Stage 2: deepen the solo consumer product

- improve owned-policy organization, factual comparison, reminders, export, and privacy controls;
- test optional local-first health records without diagnostic or treatment claims;
- remove or reframe prescriptive insurance and health surfaces identified in the owner-decision audit.

### Stage 3: consented contribution

- launch corrected-field contribution before raw samples;
- build provenance, quarantine, withdrawal, redaction, and release gates;
- benchmark public/synthetic-only models against permissioned data;
- proceed only for a material measured gain.

### Stage 4: sustainable solo operation

- optimize subscription retention, cost controls, support load, and privacy operations;
- consider contextual sponsorship only on public education if subscriptions are insufficient, while preserving the permanent sensitive-workflow ban.

## Decisions and open questions

### Decisions

- Subscription software is the primary revenue model; commissions and regulated services are prohibited.
- **Ads vs Subscription: Subscription wins on every dimension** — revenue per user (20-50x), user trust, regulatory load, retention impact, solo founder burden, and data liability. Ads earn ₹0.10-0.30/month per active user (raw CPM ₹10-30); a single Plus subscriber earns ₹149/month. Ads are rejected in the core app.
- **Pay-per-Q&A packs** are the secondary monetization model for occasional users who don't want a subscription. Starter (₹49/5Q), Value (₹119/15Q), Pro (₹199/30Q), all 90-day expiry. Packs are implemented in code but billing is still a stub.
- The first paid promise is **household policy management** — the subscription's core value. Packs serve the occasional-use segment that doesn't justify a subscription.
- Behavioral ads are excluded from trusted policy workflows.
- Commission is deferred pending an explicit regulated operating model.
- Operational data is not shared-training data.
- Model improvement starts with public, synthetic, expert-authored, and corrected structured data.
- Raw sample contribution, if offered, is separate, optional, previewable, revocable, and gated.
- Analytics remains non-content and purpose-limited.

### Owner decisions needed

- Will CoverWise remain neutral software, become a regulated intermediary, or use separate entities/products?
- Which first paid promise is strongest: household management, higher usage, human review, or claim preparation?
- Will launch and processing remain India-only where feasible?
- Should CoverWise permanently prohibit raw customer documents from shared training?
- Which entity is the data fiduciary, merchant, contracting party, and support owner?

## Primary sources

- [Digital Personal Data Protection Act, 2023](https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf)
- [Digital Personal Data Protection Rules, 2025](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf)
- [Insurance Act, 1938, incorporating amendments through 2021](https://noc.irdai.gov.in/Content/docs/Insurance%20Act%2C1938%20-%20incorporating%20all%20amendments%20till%2020212021-08-12.pdf)
- [IRDAI updated regulations](https://irdai.gov.in/updated-regulations)
- [IRDAI corporate-agent registration requirements](https://irdai.gov.in/requirements-for-license-as-a-corporate-agent)
- [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Google Play Data Safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Google Play Health Content and Services](https://support.google.com/googleplay/android-developer/answer/16679511)
- [Google Play Ads policy](https://support.google.com/googleplay/android-developer/answer/9857753)
- [Google Play SDK safety](https://support.google.com/googleplay/android-developer/answer/13326895)
- [Google personalized advertising policy](https://support.google.com/adspolicy/answer/143465)
- [Google AdMob personalized/non-personalized ads](https://support.google.com/admob/answer/7676680)
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [NIST IR 8053: De-Identification of Personal Information](https://nvlpubs.nist.gov/nistpubs/ir/2015/NIST.IR.8053.pdf)
- [Policybazaar app](https://www.policybazaar.com/insurance-app/)
- [Ditto service model](https://joinditto.in/)

## Evidence and confidence

- **Tier 1:** current product, analytics, storage, training-plan, privacy, and exploration-map inspection.
- **Primary-source research:** cited regulator, government, app-store, standards, and competitor pages.
- **Inferred:** packaging, price, sequencing, trust impact, and health-organizer appeal; these require tests.
- **Not verified:** legal classification of an exact future flow, tax, provider economics, willingness to pay, production deletion, and all processor contract terms.

**Research confidence:** 0.88. The product direction is strong; regulated implementation remains intentionally unapproved until assessed against the exact entity, contracts, and journey.

## Three-pass review record

- **Pass 1, correctness/completeness:** compared the research against the current product, analytics, privacy draft, training plan, storage paths, and exploration map. Added the missing analytics-validation and local-feedback risks; corrected older feedback-training language.
- **Pass 2, architecture/long-term viability:** confirmed the proposal extends canonical services rather than introducing payment, consent, analytics, or training shadow paths. The owner addendum now permanently excludes regulated distribution and insurer/broker tooling.
- **Pass 3, compliance/handoff readiness:** separated primary-source facts, product inference, implementation gaps, owner decisions, and legal gates. No payment, ad, referral, or training behavior is represented as production-approved.
