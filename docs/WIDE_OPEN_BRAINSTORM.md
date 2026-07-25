# CoverWise — Wide-Open Brainstorm: Info Broker Scope

**Date:** 2026-07-16
**Skill:** wide-open-brainstorm (v1.0.0)
**Scope:** CoverWise as a **policy information assistant** — NOT an operational insurance platform
**Evidence Tier:** Tier 1 (static inspection + web research)
**Author:** Buffy (AI Agent)

---

## 0. The Core Question

> "CoverWise is an info broker. We help users understand, access, and manage their insurance information. We do NOT file claims, sell policies, or handle operations."

**What does this mean for product direction?** Which features align with info broking? Which are operational scope creep? Where are the highest-leverage info-broker opportunities we're missing?

---

## 1. Capture Reality: What Exists Today

### 1.1 Feature Inventory Through Info Broker Lens

| Feature | Info Broker? | Why | Verdict |
|---------|-------------|-----|---------|
| **Upload & OCR** | ✅ Core | Document ingestion is the foundation of info broking | KEEP |
| **Policy Detail Screen** | ✅ Core | Turns 40-page PDF into scannable summary — pure info broking | KEEP |
| **Q&A (RAG)** | ✅ Core | "What's my deductible?" — asking questions about your info | KEEP |
| **Search** | ✅ Core | Finding specific info across documents | KEEP |
| **Document Preview** | ✅ Core | Verifying extracted info against source — trust building | KEEP |
| **Share/Export** | ✅ Core | Sharing info with family/advisors | KEEP |
| **Emergency Screen** | ✅ Core | Quick access to critical info in emergencies | KEEP |
| **Renewal Calendar** | ✅ Core | Tracking when info needs updating (renewal dates) | KEEP |
| **Notification Prefs** | ✅ Core | Controlling when you're reminded about info | KEEP |
| **Coverage Gap Detection** | ✅ Core | Identifying what info is missing from your coverage picture | KEEP |
| **Gap Resolution Tracking** | ✅ Core | Tracking what you've done about missing info | KEEP |
| **Family Management** | ✅ Core | Organizing info by family member | KEEP |
| **Policy Comparison** | ✅ Core | Comparing info side-by-side | KEEP |
| **Terminology Glossary** | ✅ Core | Explaining insurance jargon — pure info broking | KEEP |
| **Onboarding** | ✅ Core | First-time info upload flow | KEEP |
| **Dark Mode** | ✅ UX | User preference, low effort | KEEP |
| | | | |
| **Claims Assistant** | ⚠️ Grey area | Informational guidance about claims process — but not filing claims | REFRAME as "Claims Info Guide" |
| **Claim Tracking** | ⚠️ Grey area | Local logging of claim status — but no insurer integration | REFRAME as "My Claims Log" (info only) |
| **Renew Now CTA** | ⚠️ Grey area | Links to insurer contact — informational, not operational | KEEP as info bridge |
| | | | |
| **Claims Filing** | ❌ Operational | We don't file claims | DON'T BUILD |
| **Policy Purchase** | ❌ Operational | We don't sell policies | DON'T BUILD |
| **Insurer API Integration** | ❌ Operational | We don't communicate with insurers on behalf of users | DON'T BUILD |
| **Payment Processing** | ❌ Operational | We don't handle premium payments | DON'T BUILD |
| **Underwriting** | ❌ Operational | We don't assess risk or set premiums | DON'T BUILD |

### 1.2 What's Trustworthy vs Not-Trustworthy Today

| Component | Trustworthy? | Evidence | Risk |
|-----------|-------------|----------|------|
| Policy Detail extraction | ✅ Yes | 9/10 rating, document preview for verification | Low |
| Q&A answers | ✅ Mostly | Confidence badges, source citations, follow-up chips | Medium — depends on RAG quality |
| Coverage gap detection | ✅ Yes | Derived from extracted summaries, user can verify | Low |
| Family auto-detection | ⚠️ Partial | Auto-detect from docs is clever but may miss/misspecify | Medium |
| Claims guidance | ⚠️ Partial | Informational only — user must verify accuracy | Medium |
| Renewal dates | ✅ Yes | Extracted from policy end dates, notifications work | Low |

---

## 1.3 What's Already Solid (Info Broker Core)

Before proposing changes, let's acknowledge what's genuinely excellent:

| Feature | Rating | Why It's Solid |
|---------|--------|---------------|
| PolicyDetailScreen | 9/10 | Turns 40-page PDF into one scannable page — core value prop |
| Q&A with Confidence | 9/10 | Trust-building through transparency, source citations, follow-up chips |
| Emergency Screen | 9/10 | One-tap access to critical info — exactly what an info broker needs |
| Renewal Calendar | 9/10 | Sorted by expiry, notification opt-in, Renew Now CTA |
| Search Screen | 9/10 | Cross-document search with filters, highlights, ranking |
| Coverage Gap Tracking | 9/10 | Filter bar, resolution tracking, notes dialog |
| Document Processing | 8/10 | Durable lease recovery, idempotent upload, anti-abuse |
| Document Preview | 8/10 | Trust-building through source verification |
| Notification Preferences | 8/10 | Full user control with master toggle, quiet hours |
| Onboarding Flow | 9/10 | Clean upload → process → detail → aha moment |

**The info broker foundation is strong.** 10 of 29 screens rated 8/10 or higher. The core loop (upload → understand → access → share) works end-to-end.

---

## 1.4 Top 3 Blockers to Next Live Call

Per the wide-open-brainstorm skill contract:

1. **"Between Renewals" Retention Risk** — Users upload policies, get initial value, then don't open the app for months. Without daily/weekly utility, the app gets forgotten. **Fix:** Preventive health reminders + insurance literacy content.

2. **Scope Ambiguity** — Claims Assistant and Claim Tracking feel operational ("file a claim" language, status chips like "Filed → In Review"). Users may not understand CoverWise is an info broker, not an insurer. **Fix:** Scope disclaimer + potential feature reframing.

3. **No At-a-Glance Coverage View** — Users can't quickly answer "am I covered?" across all family members and policies. The Coverage Gap Screen exists but requires navigation. **Fix:** Insurance Health Score on dashboard.

---

## 2. Cross-Role Analysis

### 2.1 OPERATOR MODE: What is blocked?

**Nothing is technically blocked.** The app works end-to-end:
- Upload → Process → Detail → Q&A → Search → Emergency → Share

**But the "between renewals" problem is a retention blocker:**
- User uploads policy → gets value → doesn't open app for months
- Without daily/weekly utility, app gets forgotten
- This is the #1 risk for an info broker — users only need info periodically

**What would unblock daily engagement?**
- Preventive reminders ("Your policy covers free checkups")
- Insurance literacy content ("Did you know?")
- Health score updates ("Your family coverage score changed")

### 2.2 PRODUCT MODE: What weakens purchase confidence?

**For an info broker, "purchase" = user deciding to upload their policies.**

| Trust Builder | Status | Impact |
|--------------|--------|--------|
| Can I verify the extracted info is accurate? | ✅ Document preview | High |
| Will my data be safe? | ✅ Anonymous auth, no PII required | High |
| Is the AI making things up? | ✅ Confidence badges, source citations | High |
| What if I need help understanding something? | ✅ Q&A + glossary | Medium |
| Can I share this with my family advisor? | ✅ Share/export | Medium |

**What weakens confidence:**
- No visible "insurance expert" backing — users may distrust AI-only advice
- No clear disclaimer about info broker scope (we're not giving insurance advice)
- Coverage gaps shown without context about what "should" be covered

### 2.3 ENGINEERING MODE: What needs low-risk high-leverage changes?

| Change | Risk | Leverage | Files to Touch |
|--------|------|----------|---------------|
| **Insurance Health Score** | Low | High | `policy_providers.dart`, new `health_score_screen.dart` |
| **Preventive Health Reminders** | Low | High | `notification_service.dart`, `policy_providers.dart` |
| **Digital Insurance Card** | Low | Medium | New `insurance_card_screen.dart` |
| **Cross-document Q&A** | Medium | High | `qa_screen.dart`, `rag/pipeline.py` |
| **Streaming answers** | Medium | Medium | `qa_screen.dart`, backend SSE |
| **Insurance Literacy Quiz** | Low | Medium | New `literacy_screen.dart` |

### 2.4 STRATEGY MODE: What protects long-term product direction?

**The info broker moat is:**
1. **Trust** — Users trust us because we're transparent, not pushy, and let them verify everything
2. **Simplicity** — We make complex info simple, not more complex
3. **Independence** — We work for the user, not the insurer
4. **Completeness** — We're the single source of truth for ALL their insurance info

**What protects this moat:**
- Never sell policies or take commissions (conflict of interest)
- Never communicate with insurers on behalf of users (operational scope creep)
- Always show sources and let users verify (transparency)
- Keep the app lightweight and fast (utility, not bloat)

**What threatens this moat:**
- Adding operational features (claims filing, policy purchase) dilutes the info broker identity
- Becoming an "everything app" loses focus
- Over-reliance on AI without human verification options

---

## 3. Defects Mapped to Info Broker Contract

| # | Defect | Type | Severity | Fix |
|---|--------|------|----------|-----|
| D1 | No "what is CoverWise?" landing that explains info broker scope | Trust | High | Add scope disclaimer to onboarding |
| D2 | Claims assistant feels operational (has "file a claim" language) | Scope creep | Medium | Reframe as "Claims Info Guide" |
| D3 | Claim tracking feels operational (status chips like "Filed → In Review") | Scope creep | Medium | Reframe as "My Claims Log" (info only) |
| D4 | No way to see "insurance health" at a glance | Info gap | High | Build Insurance Health Score |
| D5 | No preventive info reminders | Retention | High | Build Preventive Health Reminders |
| D6 | Cross-document Q&A not supported | Info gap | Medium | Extend RAG to multi-doc |
| D7 | No digital insurance card | Info gap | Medium | Build Insurance Card screen |
| D8 | Coverage gaps shown without "what should be covered" context | Trust | Medium | Add context disclaimers |

---

## 4. What to Build Next (Ranked by Risk-Adjusted Value)

> **Note:** These are brainstorm findings, not final decisions. The user will decide what to implement.

### Tier 1: Highest Leverage for Info Broker

| # | Feature | Why | Effort | Impact |
|---|---------|-----|--------|--------|
| **B1** | **Insurance Health Score** | At-a-glance "are we covered?" — pure info broking | Medium | 🔴 High |
| **B2** | **Preventive Health Reminders** | "Your policy covers X, use it" — info that drives action | Small | 🔴 High |
| **B3** | **Scope Disclaimer** | "CoverWise is an info broker. We don't sell policies or file claims." — trust | Small | 🟡 Medium |
| **B4** | **Digital Insurance Card** | Show proof of insurance from phone — info access | Small | 🟡 Medium |

### Tier 2: Info Broker Enhancements

| # | Feature | Why | Effort | Impact |
|---|---------|-----|--------|--------|
| **B5** | **Cross-document Q&A** | "Compare my health and motor policy coverage" — info synthesis | Medium | 🟡 Medium |
| **B6** | **Insurance Literacy Quiz** | Gamified learning about policy terms — info empowerment | Small | 🟡 Medium |
| **B7** | **Claims feature reframing** | Consider renaming to emphasize info-only scope | Small | 🟡 Medium |
| **B8** | **What-If Calculator** | "If I'm admitted to Hospital X, what do I pay?" — info simulation | Medium | 🟡 Medium |

### Tier 3: Post-Launch

| # | Feature | Why | Effort | Impact |
|---|---------|-----|--------|--------|
| **B9** | Multi-language support | Hindi, Tamil, etc. for broader market | Large | 🟢 Medium |
| **B10** | Premium optimization tips | "You could save ₹X" — info that saves money | Medium | 🟢 Medium |
| **B11** | Family coverage gap map | Visual map of coverage by member | Medium | 🟢 Medium |

---

## 5. What Currently Falls Outside Info Broker Scope (DECIDED)

> **Decisions finalized 2026-07-16.** See §8 Decision Record for rationale.

| Feature | Current State | Info Broker? | Decision |
|---------|--------------|-------------|----------|
| Claims filing | Not built | ❌ Operational | **DON'T BUILD** — liability, compliance overhead |
| Policy purchase | Not built | ❌ Operational | **DON'T BUILD** — conflict of interest with info broker identity |
| Claims Assistant | Exists (4 incident types) | ⚠️ Grey area | **REFRAMED** → "Claims Info Guide" (menu label updated) |
| Claim Tracking | Exists (local log) | ⚠️ Grey area | **REFRAMED** → "My Claims Log" (menu label updated) |
| Renew Now CTA | Exists (call/email) | ⚠️ Grey area | **KEEP** as info bridge — user initiates contact |
| Insurer API integration | Not built | ❌ Operational | **DON'T BUILD** — operational scope creep |
| Payment processing | Not built | ❌ Operational | **DON'T BUILD** — PCI compliance, financial regulations |
| Underwriting | Not built | ❌ Operational | **DON'T BUILD** — requires insurance license |

---

## 6. Synthesis: The Info Broker Product Direction

### 6.1 Proposed Identity (Brainstorm Recommendation — User Decides)

> **CoverWise is the single source of truth for your insurance information.**
> We help you understand, access, and manage your policies — nothing more, nothing less.
> We don't sell policies, file claims, or communicate with insurers on your behalf.
> We work for you, not the insurance industry.
>
> *This is the brainstorm's recommendation for the product identity. The user will decide final scope.*

### 6.2 The Info Broker Value Stack

```
Layer 5: INSIGHT    — Health scores, coverage gaps, optimization tips
Layer 4: ACCESS     — Search, Q&A, emergency screen, digital cards
Layer 3: ORGANIZE   — Family management, renewal calendar, notifications
Layer 2: UNDERSTAND — Policy summaries, terminology, comparisons
Layer 1: INGEST     — Upload, OCR, processing, extraction
```

### 6.3 The Retention Strategy

For an info broker, the "between renewals" problem is the #1 retention risk. The solution is:

1. **Preventive reminders** — "Your policy covers free checkups, book before Dec 31"
2. **Insurance literacy** — Weekly "Did you know?" about policy terms
3. **Health score updates** — "Your family coverage score changed from 72 to 75"
4. **Market changes** — "Did you know? Some health plans now offer unlimited restoration" (general info, not product-specific)

These keep users engaged WITHOUT crossing into operational territory.

### 6.4 The Trust Architecture

| Trust Element | How We Build It |
|--------------|----------------|
| **Transparency** | Confidence badges, source citations, document preview |
| **Independence** | No commissions, no insurer partnerships, no sales |
| **Verification** | Users can always check extracted info against source |
| **Control** | User-controlled notifications, no spam, no pressure |
| **Scope clarity** | "We're an info broker, not an insurer" disclaimer |

---

## 7. Verification Checkpoints

| Checkpoint | What to Verify | How |
|-----------|---------------|-----|
| Scope alignment | Every feature maps to info broker scope | Cross-reference with §0.1 |
| Trust architecture | Confidence badges + sources work end-to-end | Manual testing |
| Retention strategy | Preventive reminders fire correctly | Runtime test |
| No scope creep | No operational features built | Code review |
| User understanding | "What is CoverWise?" is clear | Onboarding survey |

---

## 8. Decision Record

| Decision | Date | Context | Chosen Path | Rationale |
|----------|------|---------|-------------|-----------|
| Define info broker scope | 2026-07-16 | User clarified CoverWise is info broker, not operations | Document scope boundaries and feature classification | motto_v3 §0.1 (boldness), §0.14 (operator workflow) |
| Rank features by info broker value | 2026-07-16 | User asked to brainstorm without deleting anything | 4-role cross-analysis with ranked actions | motto_v3 §0.13 (scope control) |
| Keep 16 features as core | 2026-07-16 | User asked to decide which to keep/reframe/remove | All info-access features kept; operational features rejected | Info broker identity requires focus on understanding, not operations |
| Reframe claims features | 2026-07-16 | Claims Assistant/Tracking feel operational | Rename to "Claims Info Guide" + "My Claims Log" | Removes operational feel while preserving informational value |
| Reject 5 operational features | 2026-07-16 | Claims filing, policy purchase, insurer API, payments, underwriting | DON'T BUILD | Scope creep would dilute info broker identity, create liability |
| Defer 2 backend-dependent features | 2026-07-16 | Cross-document Q&A and What-If Calculator need backend changes | Post-MVP, after backend RAG pipeline supports multi-doc | High value but medium effort, not blocking for solo launch |
| Defer 3 post-launch features | 2026-07-16 | Multi-language, premium tips, family coverage map | Post-launch | Large effort or needs market data, not critical for initial launch |
| Document Re-upload deferred | 2026-07-16 | M6 (replace document flow) — not critical for solo launch | Defer to post-launch | Delete + re-upload is sufficient for initial version; replace flow is UX polish |
| **Keep 16 features as core** | 2026-07-16 | User asked to decide which to keep/reframe/remove | All info-access features kept; operational features rejected | Info broker identity requires focus on understanding, not operations |
| **Reframe claims features** | 2026-07-16 | Claims Assistant/Tracking feel operational | Rename to "Claims Info Guide" + "My Claims Log" | Removes operational feel while preserving informational value |
| **Reject 5 operational features** | 2026-07-16 | Claims filing, policy purchase, insurer API, payments, underwriting | DON'T BUILD | Scope creep would dilute info broker identity, create liability |
| **Defer 2 backend-dependent features** | 2026-07-16 | Cross-document Q&A and What-If Calculator need backend changes | Post-MVP, after backend RAG pipeline supports multi-doc | High value but medium effort, not blocking for solo launch |
| **Defer 3 post-launch features** | 2026-07-16 | Multi-language, premium tips, family coverage map | Post-launch | Large effort or needs market data, not critical for initial launch |

---

## 9. Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-07-16 | Initial wide-open brainstorm created | Buffy |
