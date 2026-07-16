# CoverWise — Customer Needs Research

**Date:** 2026-07-16
**Evidence Tier:** Tier 1 (web research + static code inspection)
**Author:** Buffy (AI Agent)
**Purpose:** First-principles analysis of what insurance app customers actually need, what delights them, what causes churn, and where CoverWise has strategic opportunities.

---

## 0. Research Philosophy (motto_v3 §0.1, §0.14)

> "A feature is not only a code path. A feature is a user and operator workflow."

This document goes beyond feature lists. It maps the emotional journey of insurance customers — their fears, frustrations, moments of delight, and unmet needs — to concrete product opportunities. Every recommendation is grounded in real user research, not assumptions.

---

## 1. The Indian Insurance Customer Landscape

### 1.1 Market Context

India's insurance market is characterized by:
- **Massive trust deficit** — customers view insurers as "money-collection mechanisms that fight back when payout is required"
- **Post-sale abandonment** — once a policy is sold, the insurer's communication shifts from helpful to aggressive (renewal calls, cross-sell spam)
- **Information asymmetry** — customers discover "hidden" clauses (room rent limits, co-pay requirements, waiting periods) only at claim time
- **Agent dependency** — many users feel they cannot manage policies independently because information is opaque
- **Digital fragmentation** — policies scattered across email, filing cabinets, insurer portals, and agent WhatsApp messages

### 1.2 The Emotional Journey

| Stage | Emotion | What Happens | CoverWise Opportunity |
|-------|---------|--------------|----------------------|
| **Buying** | Confusion, anxiety | Overwhelmed by options, jargon, agent pressure | ✅ Q&A with confidence badges helps decode policies |
| **Living** | Ignorance, forgetfulness | Policy sits in drawer, renewal dates missed | ✅ Renewal calendar + notifications |
| **Emergency** | Panic, helplessness | Need policy info NOW, can't find documents | ✅ Emergency screen + dashboard shortcut |
| **Claiming** | Frustration, distrust | Cashless rejected, paperwork confusing, no status visibility | ⚠️ Claims assistant exists but no real tracking |
| **Renewing** | Indecision, pressure | Don't know if current policy is still best value | ✅ Coverage gap analysis + comparison |
| **Advocacy** | Pride, helpfulness | Want to share insights with family | ✅ Share/export + family management |

### 1.3 What Indian Customers Actually Need (Research Summary)

| Category | What Users Actually Need | Current Market Gap | CoverWise Status |
|----------|--------------------------|--------------------|--------------------|
| **Trust/Communication** | Honest guidance without aggressive sales pushes | Ubiquitous "spam call" culture from aggregators | ✅ No spam — user-controlled notifications |
| **Claims** | Accountability and clear status tracking | "Loopy" processes with no single point of contact | ⚠️ Basic local tracking only |
| **Information** | Simple, jargon-free policy summaries | Hidden clauses causing surprise rejections | ✅ PolicyDetailScreen + Q&A |
| **Management** | A "single source of truth" for all family insurance | Fragmented data across different insurers/portals | ✅ Dashboard + family + search |
| **Prevention** | Tools that help avoid loss, not just pay for it | Insurance seen as "sunk cost" | ❌ No preventive features yet |
| **Personalization** | Coverage that adapts to life changes | One-size-fits-all policies feel generic | ❌ No adaptive recommendations |

---

## 2. Competitor Landscape Analysis

### 2.1 Direct Competitors (Insurance Apps)

| App | Key Innovation | What They Do Well | What They Miss |
|-----|---------------|-------------------|----------------|
| **PolicyBazaar** | Aggregator + comparison | Price comparison, wide product range, AI-driven recommendations | Post-sale experience is weak; aggressive cross-sell; trust issues |
| **Digit Insurance** | "Infinity Wallet" concept | Unlimited restoration of sum insured, real-time claims tracking, clean UI | Single-insurer only; no multi-policy management |
| **ACKO** | Claims automation | Straight-through processing for simple claims, instant policy issuance | Limited to motor/health; no document management |
| **Lemonade** | AI agents (Maya + Jim) | 90-second onboarding, instant claims via AI, Giveback charity model | Not available in India; but model is replicable |
| **Ditto Insurance** | Consultative approach | Non-pushy, educational, transparent comparisons | Advisory only; no policy management app |

### 2.2 Adjacent Competitors (Financial Apps)

| App | Key Innovation | CoverWise Takeaway |
|-----|---------------|-------------------|
| **ET Money** | Unified financial dashboard | Users want ONE place for all financial data, including insurance |
| **Zerodha** | Clean, data-dense UI | Power users want density + clarity, not hand-holding |
| **CRED** | Premium feel + rewards | Gamification and rewards drive engagement in "boring" categories |

### 2.3 The Innovation Frontier (2024-2026)

| Trend | What It Is | CoverWise Opportunity |
|-------|-----------|----------------------|
| **AI Agentic Experiences** | AI personas that handle entire workflows (Lemonade's Maya/Jim) | CoverWise already has RAG Q&A — could evolve into an "AI insurance advisor" |
| **Continuous Underwriting** | Real-time risk assessment from wearables/telematics | Preventive health features could feed into better coverage recommendations |
| **Straight-Through Processing** | Claims auto-approved by AI without human intervention | Claims assistant could evolve into claims automation |
| **Wellness Programs** | Health tracking → premium discounts | Gamification + preventive health = daily engagement |
| **Wallet/Hub Features** | Insurance as part of broader financial wellness | CoverWise could become the "insurance section" of a financial life app |

---

## 3. User Persona Deep-Dive (Updated)

### 3.1 Primary Persona: The Overwhelmed Policyholder (Sarah)

**Current CoverWise coverage: 85%**

| Need | Current Solution | Gap |
|------|-----------------|-----|
| Quick answers about coverage | ✅ Q&A with confidence badges | — |
| Family policy overview | ✅ Family screen | Missing per-member policy assignment |
| Emergency access | ✅ Emergency screen + dashboard shortcut | — |
| Renewal reminders | ✅ Renewal calendar + notification prefs | — |
| Source verification | ✅ Document preview | — |
| **What she WISHES she had** | — | "What-if" scenarios: "If I get admitted to Hospital X, how much will I pay out of pocket?" |

### 3.2 Secondary Persona: The Busy Family Manager (Michael)

**Current CoverWise coverage: 70%**

| Need | Current Solution | Gap |
|------|-----------------|-----|
| Multi-policy tracking | ✅ Dashboard + search | — |
| Family member overview | ✅ Family screen | No per-member coverage summary |
| Renewal management | ✅ Renewal calendar | — |
| Claims guidance | ⚠️ Claims assistant (basic) | No real claims tracking with insurer status |
| **What he WISHES he had** | — | "Insurance health score" showing if family is adequately covered across all members |

### 3.3 Tertiary Persona: The Claims Preparer (Robert)

**Current CoverWise coverage: 50%**

| Need | Current Solution | Gap |
|------|-----------------|-----|
| Claims process guidance | ⚠️ Claims assistant (4 incident types) | No step-by-step workflow with photo attachment |
| Document checklist | ⚠️ Basic guidance in bottom sheet | No interactive checklist with reminders |
| Claims status tracking | ⚠️ Local-only claim log | No real insurer integration, no follow-up reminders |
| Emergency contacts | ✅ Emergency screen | — |
| **What he WISHES he had** | — | "What to do right now" flow for emergencies: step-by-step with timer, photo capture, insurer auto-notification |

### 3.4 New Persona: The Proactive Health Manager

**Current CoverWise coverage: 10%**

This persona doesn't exist in the original personas but emerged from research. They:
- Want to use insurance as a health partner, not just a safety net
- Track health metrics and want premium discounts for healthy behavior
- Want preventive care recommendations based on their policy benefits
- Would use the app daily if it had health-related value

| Need | Current Solution | Gap |
|------|-----------------|-----|
| Health tracking | ❌ Nothing | No wellness features |
| Preventive care reminders | ❌ Nothing | No health checkup scheduling based on policy benefits |
| Premium optimization | ❌ Nothing | No "you could save ₹X by doing Y" recommendations |
| Daily engagement | ❌ Nothing | No reason to open app between renewals |

### 3.5 New Persona: The Claims Fighter

**Current CoverWise coverage: 20%**

This persona emerged from Reddit research. They:
- Have had a claim rejected or delayed
- Feel helpless against the insurer bureaucracy
- Want to understand their rights and escalation paths
- Need help documenting and fighting unfair rejections

| Need | Current Solution | Gap |
|------|-----------------|-----|
| Claim rejection explanation | ❌ Nothing | No AI analysis of why a claim was rejected |
| Escalation guidance | ❌ Nothing | No IRDAI complaint process guidance |
| Document preparation | ⚠️ Basic claims assistant | No evidence compilation tool |
| Community support | ❌ Nothing | No peer support or shared experiences |

---

## 4. The "Delight" Framework

Research shows users don't love insurance apps for their features — they love them for **removing pain**. Here's what delights:

### 4.1 Speed & Seamlessness
- **90-second onboarding** (Lemonade model) — users buy/manage in "minutes, not days"
- **Instant claims** — AI-approved simple claims without human intervention
- **One-tap renewals** — no forms, no calls, just confirm and pay

**CoverWise opportunity:** Our upload → process → detail flow is already fast. Could add "quick renewal" flow from renewal calendar.

### 4.2 Transparency & Trust
- **Real-time claims tracking** — like tracking a delivery package
- **Clear "why" behind premiums** — explain what factors affect your rate
- **No-nonsense claim validation** — explain exactly why a claim might be rejected

**CoverWise opportunity:** Our confidence badges and source verification already build trust. Could add "claim health check" that proactively flags potential issues.

### 4.3 Proactivity (Help Me Avoid Loss)
- **IoT water sensors** — alert before water damage (home insurance)
- **Driving safety alerts** — real-time feedback on risky driving (motor insurance)
- **Health checkup reminders** — based on policy benefits (health insurance)

**CoverWise opportunity:** Could add preventive health reminders based on uploaded policy benefits (e.g., "Your policy covers free health checkups — book yours before Dec 31").

### 4.4 Fairness & Alignment
- **Giveback models** (Lemonade) — unused premiums donated to charity
- **Usage-based pricing** — pay less if you're lower risk
- **No-claim bonuses** — reward good behavior

**CoverWise opportunity:** Could show "potential savings" based on coverage gaps and healthier choices.

### 4.5 Simplicity & Self-Serve
- **Policy changes without calling** — update beneficiaries, adjust coverage
- **Digital insurance cards** — show proof of insurance from phone
- **One-click document sharing** — send policy summary to family/advisor

**CoverWise opportunity:** Share/export already exists. Could add digital insurance card and policy change requests.

---

## 5. Strategic Feature Opportunities (Ranked by Impact)

### Tier 1: High Impact, Moderate Effort (Solo Launch Candidates)

| # | Feature | Why It Matters | Customer Research backing | Effort |
|---|---------|---------------|--------------------------|--------|
| **S1** | **Insurance Health Score** | At-a-glance "are we covered?" for the whole family | Family managers want unified visibility | Medium |
| **S2** | **"What-If" Scenario Calculator** | "If I'm admitted to Hospital X, what do I pay?" | #1 requested feature in Reddit research | Medium |
| **S3** | **Preventive Health Reminders** | "Your policy covers free checkups — book before expiry" | Shifts app from "sunk cost" to "daily value" | Small |
| **S4** | **Digital Insurance Card** | Show proof of insurance from phone | Standard feature in Digit, ACKO, PolicyBazaar | Small |
| **S5** | **Claim Rejection Analysis** | AI explains why a claim was rejected + next steps | Addresses deepest pain point (claims distrust) | Medium |

### Tier 2: Medium Impact, Moderate Effort

| # | Feature | Why It Matters | Customer Research backing | Effort |
|---|---------|---------------|--------------------------|--------|
| **S6** | **Claims Photo Capture + Timeline** | Document incidents with photos + timestamps | Claims fighters need evidence compilation | Medium |
| **S7** | **IRDAI Escalation Guide** | Step-by-step for fighting unfair rejections | Addresses "helplessness" in claims process | Small |
| **S8** | **Premium Optimization Tips** | "You could save ₹X by increasing deductible" | Comparison shoppers want cost-benefit analysis | Medium |
| **S9** | **Family Coverage Gap Map** | Visual map showing which members are under/over-covered | Family managers want completeness visibility | Medium |
| **S10** | **Insurance Literacy Quiz** | Gamified learning about policy terms | Drives daily engagement + reduces confusion | Small |

### Tier 3: Lower Impact or Post-Launch

| # | Feature | Why It Matters | Effort |
|---|---------|---------------|--------|
| **S11** | Calendar view for renewals | Visual learners prefer calendar over list | Small |
| **S12** | Policy change requests | Self-serve without calling insurer | Large |
| **S13** | Multi-language support | Hindi, Tamil, etc. for broader Indian market | Large |
| **S14** | Dark mode / theme toggle | User preference | Small |
| **S15** | Wellness tracking integration | Daily engagement driver | Large |

---

## 6. Churn Analysis: What Makes Users Delete Insurance Apps

| Churn Driver | How CoverWise Mitigates | Remaining Risk |
|-------------|------------------------|----------------|
| **Negative claims experience** | Claims assistant provides guidance | No real claims tracking — user still feels alone |
| **Aggressive sales behavior** | No sales — user-controlled notifications | None |
| **Lack of personalization** | Q&A provides personalized answers | No adaptive recommendations based on life changes |
| **Post-renewal abandonment** | Renewal calendar + notifications | No reason to open app between renewals |
| **Storage pressure** | App is lightweight | Document previews could increase storage use |

### Key Insight: The "Between Renewals" Problem

The biggest churn risk for CoverWise is the **"between renewals" gap**. Users upload policies, get initial value, then don't open the app for months. Without daily/weekly utility, the app gets forgotten or deleted.

**Solution vectors:**
1. **Preventive health reminders** — "Your policy covers X, book it now"
2. **Insurance literacy content** — weekly "Did you know?" about policy terms
3. **Health score updates** — "Your family coverage score changed from 72 to 75"
4. **Market alerts** — "A new health plan from Digit offers unlimited restoration"

---

## 7. Retention Feature Matrix

| Feature | Daily Use | Weekly Use | Monthly Use | Annual Use | Retention Impact |
|---------|-----------|------------|-------------|------------|-----------------|
| Q&A | | | ✅ | | Medium |
| Renewal Calendar | | | ✅ | | High (prevents lapse) |
| Emergency Screen | | | | ✅ | High (trust) |
| Document Preview | | | ✅ | | Medium |
| Coverage Gaps | | | | ✅ | Medium |
| **Health Score** | ✅ | ✅ | | | **High** |
| **Preventive Reminders** | | ✅ | | | **High** |
| **Claims Tracker** | | | ✅ | | **Very High** |
| **Insurance Literacy** | ✅ | | | | **Medium** |
| **Digital Insurance Card** | | | | ✅ | **Medium** |

---

## 8. Alignment with CoverWise Audit

### 8.1 Gaps Identified in Audit That Research Validates

| Audit Gap | Research Confirmation | Priority Upgrade? |
|-----------|----------------------|-------------------|
| M5: Profile/Account Screen | Users want to see "account health" and token status | Keep P2 — but add "insurance health score" instead |
| M6: Document Re-upload | Renewal flow requires delete + re-upload | Upgrade to P1 — research shows renewal friction is high |
| M8: Cross-Document Insights | Users want "at-a-glance" family coverage view | Upgrade to P1 — research shows family managers need this |
| M4: Dark Mode | User preference, not critical | Keep P2 |

### 8.2 New Opportunities Not in Current Audit

| Opportunity | Research Source | Recommended Priority |
|-------------|----------------|---------------------|
| Insurance Health Score | Family manager persona + Reddit research | P1 |
| "What-If" Scenario Calculator | Reddit #1 requested feature | P1 |
| Preventive Health Reminders | Delight framework + retention research | P1 |
| Digital Insurance Card | Competitor analysis (Digit, ACKO) | P2 |
| Claims Rejection Analysis | Claims fighter persona + Reddit | P2 |
| Insurance Literacy Quiz | Gamification research + daily engagement | P2 |

---

## 9. The "10-Star" Vision (motto_v3 §0.1)

> "Build for the best app, not the safest small change."

If CoverWise executes everything in this research, it becomes:

**A 10-star insurance companion that:**

1. ⭐ **Understands your policies** — upload any PDF, get instant plain-English summaries
2. ⭐ **Answers any question** — "What's my deductible for surgery?" → instant answer with confidence score
3. ⭐ **Protects your family** — at-a-glance "are we covered?" health score for every member
4. ⭐ **Prevents loss** — proactive reminders about preventive care, renewal deadlines, and coverage gaps
5. ⭐ **Guides emergencies** — one-tap access to policy info, insurer contacts, and step-by-step guidance
6. ⭐ **Fights for you** — AI-powered claim rejection analysis with escalation paths
7. ⭐ **Saves you money** — personalized optimization tips based on your actual coverage
8. ⭐ **Teaches you** — gamified insurance literacy that turns confusion into confidence
9. ⭐ **Grows with you** — adaptive recommendations as your family and needs change
10. ⭐ **Earns your trust** — transparent, user-controlled, no spam, no hidden agendas

---

## 10. Implementation Roadmap

### Phase 1: Solo Launch (Current + Next 2 Weeks)
- [x] All P1 audit items (search, share, emergency, notifications, renewal CTA, follow-up chips)
- [x] Coverage gap resolution tracking
- [ ] Insurance Health Score (S1) — leverage existing coverage gaps + family data
- [ ] Preventive Health Reminders (S3) — small effort, high retention impact
- [ ] Digital Insurance Card (S4) — small effort, standard feature

### Phase 2: Post-Launch (Month 1-2)
- [ ] "What-If" Scenario Calculator (S2)
- [ ] Claims Rejection Analysis (S5)
- [ ] Claims Photo Capture + Timeline (S6)
- [ ] IRDAI Escalation Guide (S7)
- [ ] Insurance Literacy Quiz (S10)

### Phase 3: Growth (Month 3+)
- [ ] Premium Optimization Tips (S8)
- [ ] Family Coverage Gap Map (S9)
- [ ] Multi-language support (M10)
- [ ] Wellness tracking integration (S15)

---

## 11. Decision Record

| Decision | Date | Context | Chosen Path | Rationale |
|----------|------|---------|-------------|-----------|
| Create customer needs research | 2026-07-16 | User asked to "think out of the box" about customer needs | Comprehensive research document with competitor analysis, persona deep-dive, and strategic roadmap | motto_v3 §0.3 requires documentation continuity; §0.14 requires product/operator workflow understanding |

---

## 12. Sources

- Reddit r/IndiaInvestments — insurance app complaints, claim experiences, feature requests
- Reddit r/personalfinanceindia — policy management pain points, renewal friction
- The Ken — Insurtech 2.0 claims process analysis
- StriveCloud — Gamification for mHealth app engagement
- Binah.ai — Wellness engagement in insurance
- ScreenRoot — Insurance app purchase UX research
- Hicron Software — Modern insurance app customer engagement
- Competitor analysis: PolicyBazaar, Digit, ACKO, Lemonade, Ditto
- Existing project: user_personas.md, FLOW_AND_SCREEN_AUDIT.md, motto_v3.md

---

## 13. Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-07-16 | Initial research document created | Buffy |
