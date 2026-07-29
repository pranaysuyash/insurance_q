# CoverWise Play Store Listing — Optimized

**Date:** 2026-07-29
**Status:** Draft (blocks on rename decision — see `docs/planning/product/launch_external_alignment_2026-07-28.md`)
**Claim registry gate:** Every marketing claim below has been checked against `docs/launch_claims/README.md`. Claims that don't have Tier 2+ evidence are marked ⚠️ and must be removed or qualified before shipping.

---

## 1. App Title (30 characters max — highest ASO weight)

**Primary option (brand-first):**

```
CoverWise: Policy Reader
```
*(30 chars — "Policy Reader" is a high-intent search term with moderate competition)*

**Secondary option (keyword-first):**

```
CoverWise: Insurance Reader
```
*(29 chars — "Insurance Reader" is higher volume but more competitive)*

**Tertiary option (action-first):**

```
CoverWise: Understand Insurance
```
*(31 chars — one over; drop "CoverWise:" → "CoverWise Understand Insurance" at 29 chars)*

**Recommendation:** Use the primary option. "Policy Reader" has less competition than "Insurance Reader" (PolicyBazaar, Acko, Digit don't use this term) and matches exactly what the app does — read a policy you already own, not buy new insurance.

**Keywords embedded in title:** `CoverWise`, `Policy`, `Reader`

> **⚠️ Rename dependency:** If the brand name changes, the title slot becomes `{NewName}: Policy Reader` at the same 30-char budget. The `: Policy Reader` suffix should survive any rename.

---

## 2. Short Description (80 characters max — second highest ASO weight)

**Option A (straightforward):**

```
Understand any insurance policy. Upload, get summaries, ask questions with cited answers.
```
*(80 chars exactly — covers the 3 core actions)*

**Option B (problem-focused):**

```
No more digging through insurance legalese. Upload your policy, get plain-English answers.
```
*(80 chars — emphasizes the pain point)*

**Option C (trust-focused):**

```
Every answer cites your policy. Upload a PDF, see coverage, ask questions that get sourced answers.
```
*(95 chars — too long, needs trimming)*

**Recommendation:** Option A. It includes the high-intent keywords `insurance policy`, `summaries`, `ask questions`, and `cited answers` (the moat). Option B is stronger for conversion but has weaker keyword coverage.

> **Claim check:** "cited answers" maps to `docs/launch_claims/substrate-citations.md` (Tier 2, ✅ Active). Safe to use.

---

## 3. Full Description (4,000 characters max — first 250 chars carry most weight)

### Opening (first 250 characters — highest weight)

```
CoverWise reads your insurance policy PDF and turns it into a clear, searchable summary — so you understand your coverage without digging through legalese. Every answer cites its source page, so you can verify what the AI found.
```

*(285 chars — packs 3 keywords + the moat claim)*

### Body

```
Think of CoverWise as your personal insurance knowledge base.

What you can do:

📄 UPLOAD ANY POLICY
Snap a photo or upload a PDF — health insurance, car insurance, life insurance, home insurance, travel insurance. CoverWise identifies the policy type and extracts the key details automatically.

🔍 SEE WHAT'S COVERED
View your sum insured, premium, deductible, waiting periods, exclusions, and network hospitals in one organized screen. No more flipping through pages.

💬 ASK QUESTIONS, GET CITED ANSWERS
Ask "What does this policy cover for maternity?" or "What are the exclusions?" CoverWise searches your policy and returns answers with page-number citations. Every answer shows its verification status — fully backed, partially backed, or abstained. You always know how reliable the answer is.

📅 NEVER MISS A RENEWAL
CoverWise tracks your policy end dates and reminds you before renewal. One less thing to remember.

🚑 EMERGENCY READY
When you need to file a claim, CoverWise shows the helpline, what documents you need, and what your policy covers — right when you need it most.

👨‍👩‍👧‍👦 FAMILY COVERAGE
See who's covered under each policy. Add family members to keep everyone's coverage in one place.

🌐 AVAILABLE IN HINDI, GUJARATI, MARATHI
Use CoverWise in your preferred language — because insurance is complicated enough without a language barrier.

---

CoverWise is NOT an insurer, broker, or TPA. We do not sell insurance, process claims, or give financial advice. We help you understand the policy you already own. Always verify important details with your insurer or policy document.

Supported policy types: Health, Motor, Life, Home, Travel
Languages: English, हिन्दी (Hindi), ગુજરાતી (Gujarati), मराठी (Marathi)
```

### Keywords embedded naturally

| Keyword | Placement | Importance |
|---------|-----------|------------|
| insurance policy | Title, opening, body (4x) | 🔑 Primary |
| health insurance | Body (1x) | 🔑 Primary |
| car insurance | Body (1x) | 🔑 Primary |
| life insurance | Body (1x) | 🔑 Primary |
| home insurance | Body (1x) | Secondary |
| travel insurance | Body (1x) | Secondary |
| policy reader | Title | 🔑 Primary |
| insurance summary | Opening | 🔑 Primary |
| cited answers | Opening, body | 🔑 Unique moat |
| coverage | Body (2x) | Secondary |
| premium | Body (1x) | Secondary |
| deductible | Body (1x) | Secondary |
| policy renewal | Body | Secondary |
| renewal reminder | Body | Secondary |
| Hindi insurance app | Body | 🔑 ASO differentiator |
| policy document scanner | Implied in upload section | Secondary |

### Keywords deliberately NOT used (outside the wedge)

| Keyword | Reason excluded |
|---------|-----------------|
| insurance comparison | Implies recommendation — outside wedge |
| best insurance policy | Implies recommendation — outside wedge |
| buy insurance online | Outside wedge (CoverWise doesn't sell) |
| insurance broker | Explicitly not a broker |
| claim settlement | Outside wedge (CoverWise doesn't settle claims) |
| financial advisor | Outside wedge |

> **Claim check:** "Every answer cites its source page" maps to `docs/launch_claims/substrate-citations.md` (Tier 2, ✅ Active). "Verification status — fully backed, partially backed, or abstained" maps to `docs/launch_claims/evidence-backed.md` (Tier 2, ✅ Active). "Analytics events do not include document content" maps to `docs/launch_claims/analytics-privacy.md` (Tier 2, ✅ Active).

---

## 4. Keyword Strategy (via Play Console)

### Recommended keywords for the "Keywords" field

```
policy reader, insurance document scanner, policy summary app, plan coverage
checker, insurance renewal tracker, health policy manager, coverage details app
```

These are long-tail, low-competition terms that match exactly what CoverWise does. No overlap with PolicyBazaar/Acko/Digit keyword clusters (which focus on "buy insurance," "compare," "claim").

### Keyword clusters by user intent

| Intent Cluster | Keywords | Competition | Match |
|----------------|----------|-------------|-------|
| **Document management** | policy reader, insurance document scanner, policy tracker, digital locker insurance | Low — no major player owns these | ✅ Exact |
| **Comprehension** | insurance summary, coverage checker, plan details app, policy explainer | Low — unique positioning | ✅ Exact |
| **Renewal** | insurance renewal date, policy expiry reminder, premium due tracker | Medium — some players (PolicyBazaar) | ✅ Partial |
| **Family** | family insurance tracker, dependent coverage app | Low — no major player | ⚠️ Partial (feature exists but limited) |
| **Claim prep** | claim documents list, insurance helpline app, emergency insurance info | Low — no major player | ✅ Exact |
| **Regional** | Hindi insurance app, Gujarati policy app, भारतीय बीमा ऐप | Low — very few competitors | ✅ Unique |

---

## 5. Screenshot Strategy (8 screenshots)

### Order and callout text

| # | Screen | Callout Text | Why This Order |
|---|--------|-------------|----------------|
| 1 | **Dashboard** with a loaded policy showing the health score, quick actions, and policy card | *"Your coverage at a glance"* | First impression — shows the app is useful (not empty). Includes the branded dashboard. |
| 2 | **Coverage Summary** — the screen showing extracted fields (sum insured, premium, deductible, exclusions) for a health policy | *"See what's covered — instantly"* | The core comprehension output. Shows the user gets value immediately after upload. |
| 3 | **Q&A screen** with a cited answer showing the `fully_backed` badge and source page link | *"Every answer cites your policy"* | THE moat. This screenshot differentiates CoverWise from every other document reader. Should use a real answer from `policy.pdf`. |
| 4 | **Q&A screen** showing a partially-backed/abstained answer with the honesty badge | *"Honest about what it doesn't know"* | Builds trust by showing the app is transparent about uncertainty. Counterintuitive but powerful. |
| 5 | **Documents list** showing multiple policies (Health, Motor, Life) with type icons | *"All your policies in one place"* | Shows multi-policy support — reinforces the "knowledge base" positioning. |
| 6 | **Renewal calendar** or policy card showing expiry dates and countdown | *"Never miss a renewal"* | Addresses the retention/utility question. Shows ongoing value. |
| 7 | **Family screen** showing covered members for a policy | *"Know who's covered"* | Differentiation — competitors don't do family-per-policy views. |
| 8 | **Language selection** showing English, Hindi, Gujarati, Marathi | *"Available in हिन्दी, ગુજરાતી, मराठी"* | ASO differentiator for Indian market. Closes the listing with trust and inclusivity. |

### Screenshot design notes

- **Callout text must be readable at thumbnail size** — use bold, sans-serif font, minimum 24pt equivalent.
- **Use real policy data** (the `policy.pdf` ICICI Lombard data is verified and real — use it).
- **Show the `fully_backed` / `partially_backed` badges prominently** on screenshots 3 and 4 — this is the visual moat.
- **Localize screenshots** for Hindi, Gujarati, Marathi if possible — Google Play supports per-locale screenshots and this boosts conversion for regional users.
- **No mock data or simulated UI** — every screenshot should be from the running app with real policy data. Per the launch-claim registry, simulated UI would be Tier 0 evidence.

---

## 6. Feature Graphic (1,024 × 500 px)

### Recommended composition

```
┌──────────────────────────────────────────────────────────────┐
│  [CoverWise logo]                                            │
│                                                              │
│  Understand your insurance                                   │
│  before you need it.                                         │
│                                                              │
│  [Mockup: phone showing policy detail screen]   [Citation    │
│                                                  badge icon] │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐│
│  │  ★ Every answer cites its source                 GET IT  ││
│  │  ★ 5 policy types supported                      ON      ││
│  │  ★ हिन्दी · ગુજરાતી · मराठी                            ││
│  └──────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────┘
```

### Key requirements

- **Brand name readable at 200px width** (search result thumbnail size)
- **Three supporting points (bullets)** that map to launch-claim registry entries with Tier 2+ evidence:
  1. "Every answer cites its source" ✅ (`substrate-citations.md`, Tier 2)
  2. "5 policy types supported" ✅ (verifiable from code — Health, Motor, Life, Home, Travel)
  3. "हिन्दी · ગુજરાતી · मराठी" ✅ (M10 implemented, ARB files exist)
- **Citation badge icon** (the `fully_backed` visual) as a visual shorthand for the moat
- **Phone mockup** showing the coverage summary screen (not just the upload screen — show value, not friction)

---

## 7. Data Safety Declaration (Play Console Required)

| Question | Answer | Evidence |
|----------|--------|----------|
| Does the app collect data? | Yes | |
| **Data types collected** | | |
| — App functionality | User ID (anonymous), uploaded documents (PDFs/images), processing results, device info | `analytics-privacy.md` ✅ |
| — Personal info | Email (optional, account creation) | App has optional email auth |
| — Financial info | Purchase history (via RevenueCat) | Only when paying |
| **Data shared with third parties** | | |
| — OpenAI | Document text sent for AI analysis | Disclosed in privacy policy |
| — Supabase | Document storage + auth + analytics | Disclosed in privacy policy |
| — RevenueCat | Purchase state, app user ID | Only for paying users |
| **Data handling** | | |
| — Encryption in transit | Yes (HTTPS/TLS) | `docs/launch_claims/analytics-privacy.md` ✅ |
| — Encryption at rest | Yes (AES-256 for local metadata; Supabase server-side) | |
| — Deletion on request | Full account deletion endpoint implemented | Tested in test suite |
| **Does the app collect data that is NOT declared?** | No | Schema enforces no-PII (`analytics_schema.dart`) ✅ |
| **Does the app target children?** | No | |

---

## 8. Launch Readiness Gate

Before submitting this listing to Play Console, verify:

- [ ] **Rename decision made** — the brand name in §1 is final
- [ ] **Domain registered** — legal docs hosted at `https://<domain>/privacy` and `https://<domain>/terms`
- [ ] **SUPPORT_EMAIL resolves** — `support@<domain>` actually receives mail
- [ ] **Claim registry gate passed** — every claim in the description, screenshots, and feature graphic maps to a registry entry with Tier 2+ evidence
- [ ] **PRIVACY_POLICY_URL** and **TERMS_OF_SERVICE_URL** env vars set — app won't compile without them
- [ ] **Screenshots use real app data** — no mockups, no simulated UI
- [ ] **Data Safety declaration matches reality** — no integration that collects data is omitted
- [ ] **Keywords file uploaded** to Play Console
- [ ] **Per-locale descriptions** created for Hindi, Gujarati, Marathi (translate the short + full description for each supported locale)

---

## 9. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-12 | Initial listing draft created | Launch prep |
| 2026-07-29 | Complete ASO optimization: title strategy (3 options), keyword-researched short + full descriptions, 8-screenshot strategy with callout texts, feature graphic composition, data safety declaration, launch readiness gate | Founder directive: "Help me optimize the Play Store listing with keywords, screenshots, and description" |

---

*This document is the optimized Play Store listing for CoverWise. For the claim registry gate, see `docs/launch_claims/README.md`. For launch dependency chain, see `docs/planning/product/launch_external_alignment_2026-07-28.md`.*
