# CoverWise Regulatory-Scope Risk Audit

**Date:** 2026-07-28
**Status:** Documentation-only audit. **No code changes applied.** Produced for founder review and external verification before any remediation.
**Method:** Tier-1 static inspection of source code and localized copy. Each finding cites `path:line` and quotes the offending text verbatim.
**Skill used:** `legal-risk-audit` (project convention: find and document before editing).
**Scope:** All user-visible surfaces in the Flutter app + RAG/LLM prompt layer that determine whether the product acts as (a) a document-understanding tool — the stated and intended scope — or (b) an insurance advisor / broker / claims consultant / price-quoting tool — the adjacent regulated space the founder has explicitly excluded.

---

## Problem statement

### The intended scope (firm constraint)

CoverWise is positioned, by the founder's explicit decision, as a **document-understanding tool**: it helps people read and understand their *own* insurance policy documents. It is:

- **not** an insurer
- **not** an insurance agent, broker, or intermediary
- **not** a claims consultant or claims-management service
- **not** a price-quoting or product-comparison service
- **not** a financial, legal, or insurance **advisor**

This is a standing constraint, not a feature request. The founder does not want to operate in, or appear to operate in, the IRDAI-regulated insurance intermediation space, the regulated claims-consultancy space, or any advisory space. "Document-understanding only" is the boundary.

### The risk

The boundary between "helping a user read their own document" and "advising on insurance / facilitating insurance transactions / consulting on claims" is the exact boundary that regulators and consumer-protection regimes police. The line is not about disclaimers — a "not financial advice" banner does not neutralize an activity that *is* advice, quoting, or facilitation. **The activity is what matters, not the label.** An app that fabricates premium figures and walks a user through filing a claim is engaged in those activities even if every screen carries a disclaimer.

Therefore this audit asks a single question of every surface:

> **Does this surface help the user understand a document they already own, or does it do something an insurer / broker / claims consultant / advisor would do?**

The first is in-scope and low-risk. The second is out-of-scope and must be removed or redesigned, regardless of how well it is disclaimed.

### What this audit is *not*

- It is **not** legal advice from a lawyer. The founder is using it to scope an external review.
- It is **not** a compliance certification. It identifies activities that *create exposure*; it does not assess whether any specific activity is unlawful under IRDAI or any other regime.
- It does **not** cover privacy/billing/data-deletion copy consistency (that is the separate `legal_risk_remediation_priority_2026-07-25.md` track). It is scoped to the *product-activity* boundary only.

---

## Method and scanned surface

Per the `legal-risk-audit` skill checklist, the following were inspected:

| Surface | Files |
|---|---|
| Feature screens | all of `mobile/lib/screens/*.dart` (45 files) |
| Models / services | `mobile/lib/services/*.dart`, `mobile/lib/models/*.dart`, `mobile/lib/utils/what_if_calculator.dart` |
| Localized copy | `mobile/lib/l10n/app_en.arb` |
| RAG / LLM prompts | `src/rag/pipeline.py`, `src/security/prompt_injection.py`, `src/llm/client.py`, `src/utils/document_classifier.py`, `src/services/evidence_pipeline.py`, `src/services/policy_extraction_service.py` |
| Entry-point / routing | `mobile/lib/main.dart`, `mobile/lib/screens/dashboard_screen.dart` |

Search vocabulary applied: `recommend | advise | should (buy/get/add) | quote | premium estimate | underwrit | file a claim | start renewal | broker | intermediary | IRDAI | health score | coverage score | not (financial/insurance/legal) advice | verify with insurer`.

---

## Executive summary

The app is **mostly disciplined** about staying inside the document-understanding boundary, and the single worst historical offender — the ungrounded "Insurance Health Score" — has already been removed (`widgets/policy_readiness_card.dart:7` documents its replacement). Grounded Q&A, the coverage review, the preventive notes, and the lead-generation CTAs are all on the right side of the line.

However, the app is **not yet clean**. Four surface clusters step across the boundary:

1. **🔴 The What-If Calculator fabricates insurance premium figures.** This is price-quoting / light underwriting — the clearest contradiction in the app. Highest priority.
2. **🟠 The claims-assistance / claims-guide cluster provides claim-filing guidance and an IRDAI-escalation flow.** This is claims consultancy — adjacent to regulated claims-consultancy and distribution.
3. **🟡 The "Start renewal" / "Contact insurer to renew" CTAs facilitate transacting with the insurer.** A passive reminder is a calendar feature; a button that initiates renewal is distribution-adjacent.
4. **🟡 The Insurance Literacy Quiz asserts authoritative generic facts about how insurance works.** Low legal risk; scope drift rather than boundary crossing.

Two prompt-level issues reinforce rather than cross the boundary and should be fixed regardless.

| Cluster | Risk tier | Activity | Recommendation |
|---|---|---|---|
| What-If Calculator | 🔴 High | Fabricates premium/coverage/deductible estimates from the user's real policy | **Remove from launch** |
| Claim assistance + Claim guide | 🟠 Med-high | Per-incident claim-prep guidance + IRDAI escalation | **Remove from launch** |
| Claim tracking | 🟢 Clean | Personal local log, not connected to any insurer | Keep |
| Renewal "Start renewal" CTA | 🟡 Med | Facilitates transacting a renewal | Drop the CTA, keep the reminder |
| Renewal calendar (passive) | 🟢 Clean | Expiry-date reminders | Keep |
| Insurance Literacy Quiz | 🟡 Low-med | Asserts generic authoritative insurance facts | Hide for focus (optional) |
| Grounded Q&A + Coverage review + Preventive notes + Lead CTAs | 🟢 Clean | Evidence-bound, returns user to their own doc | Keep |

The recommendation converges with the founder's own 2026-07-22 launch review: **ship narrow (upload → summary → source/citation → Q&A)** and pull the rest. The remediation in this doc is therefore the same action viewed through the regulatory-scope lens rather than the trust/grounding lens.

---

## Findings — detailed evidence

### F-1 🔴 What-If Calculator fabricates premium/coverage figures

**Files:**
- `mobile/lib/screens/what_if_calculator_screen.dart` (entry: `main.dart:454` `/what-if`, surfaced from `dashboard_screen.dart:208`)
- `mobile/lib/utils/what_if_calculator.dart`

**What it does.** The user selects one of their *real, uploaded* policies. The screen shows the real extracted `coverageAmount` and `premiumAmount` (`what_if_calculator_screen.dart:209-213`), then exposes sliders to change "Coverage amount" (0.5×–3×) and "Deductible" (0.5×–2×), and toggles for Maternity / Daycare / Pre-post hospitalization. It then computes an "estimated premium" via hardcoded multipliers:

`mobile/lib/utils/what_if_calculator.dart:29-46`:
```dart
///   factor = coverageMultiplier
///   if deductibleMultiplier > 1: factor *= 0.85  (higher deductible = lower premium)
///   if deductibleMultiplier < 1: factor *= 1.15  (lower deductible = higher premium)
///   if maternity: factor *= 1.08
///   if daycare: factor *= 1.03
///   if pre/post hospitalization: factor *= 1.05
///   estimated = basePremium * factor (rounded to nearest integer)
```

**Why this crosses the boundary.** Generating a money figure for what a hypothetical insurance product *would cost* given coverage and deductible parameters is **price-quoting and a crude form of underwriting modeling**. That is the core regulated activity of insurance intermediation and underwriting. The output is presented in rupees (`₹`, `Cr`/`L`/`K` formatting at `what_if_calculator.dart:51-60`) against the user's *actual* policy, which makes it read as a personalized estimate.

**Why the disclaimer doesn't help.** `what_if_calculator_screen.dart:163-191` carries:
> "These are rough estimates for planning purposes only. Actual premiums vary by insurer and underwriting."

A disclaimer does not change the *activity*. An entity that publishes personalized premium figures is engaged in quoting regardless of how many caveats surround the number. This is the same principle under which a "not financial advice" banner does not license unregistered investment advice.

**Internal contradiction.** This screen directly violates the app's own stated posture in `mobile/lib/services/lead_generation_service.dart` (lines ~30–40), which says explicitly:

> "CoverWise does not compare insurance products, quote prices, recommend cover, or broker an adviser relationship."

The calculator quotes prices. Two surfaces in the same product make opposite claims about what the product does.

**Grounding failure (separate, reinforcing).** The figures are also ungrounded — they are not extracted from or cited to any policy text. This independently re-triggers the "misleading trust surfaces" P0 from the 2026-07-22 launch review, which is a second, non-regulatory reason to remove it.

**Recommendation:** Remove from the first public release (feature-flag off / route gated). Keep the file for a possible later, clearly non-priced "understand your policy's numbers" view, but not the premium-fabrication logic.

**Alternatives considered:**
- *Keep with stronger disclaimer.* **Rejected.** The activity is the problem, not the label.
- *Keep but relabel as "purely hypothetical toy."* **Rejected.** Anchored to the user's real policy and real currency; still reads as a quote.
- *Convert to a read-only explainer* of what the user's extracted premium/coverage/deductible fields mean, with no computed projections. **Viable later**, out of scope for launch.

---

### F-2 🟠 Claim-assistance + Claim-guide cluster (claims consultancy)

**Files:**
- `mobile/lib/screens/claim_assistance_screen.dart` — "Claim assistance" (reached from policy detail)
- `mobile/lib/screens/claims_assistant_screen.dart` — "Claim guide" → "View preparation guide"
- `mobile/lib/widgets/claims_workflow_sheet.dart` (consumed by the above)

**What it does.**

(a) `claim_assistance_screen.dart` is a structured "Filing a claim" walkthrough. The code itself flags the problem — `claim_assistance_screen.dart:61`:
```dart
// CRITICAL: legal disclaimer. This is a regulated
```
It presents a per-insurer claim process and, most importantly, a dedicated `_IRDIAEscalationCard` (`claim_assistance_screen.dart:~380, 440-490`) that instructs the user on how to escalate a denied claim to the regulator:
> "You can escalate to the IRDAI (Insurance Regulatory and Development Authority of India) Bima Bharosa portal or the Insurance Ombudsman. Both are free, and IRDAI typically responds within 30 days."
…with an "Open IRDAI Bima Bharosa" button that deep-links `https://bimabharosa.irdai.gov.in/`.

(b) `claims_assistant_screen.dart` asks "What happened?" (Hospitalization / Auto accident / Life insurance claim / Other), lets the user attach a policy, and produces a "preparation guide" — a per-incident "document and contact checklist" for filing (`_incidentDescription`, e.g. "Prepare hospital, treatment and pre-authorization records").

**Why this crosses the boundary.** Structuring a claim-filing workflow and a claim-denial escalation path is **claims assistance / consultancy**. Helping a user *prepare and progress a claim* is precisely the work a claims consultant does; it is adjacent to regulated activity. Linking to the IRDAI ombudsman in isolation is defensible public-information, but *embedding it inside an app-built claims walkthrough* reframes it as part of a guided claims service offered by CoverWise.

Note the asymmetry the app itself draws: `claims_assistant_screen.dart` header correctly says *"CoverWise does not file or manage the claim"* — but then the screen proceeds to build the preparation checklist anyway. The disclaimer and the activity again contradict.

**Recommendation:** Remove both "claim *assistance*" and "claim *guide*" screens from launch. This also matches the "ship narrow" recommendation.

**What stays:** `mobile/lib/screens/claim_tracking_screen.dart`. Its own docstring is the cleanest in the codebase:
> "Claim tracking: a personal log of insurance claims the user has filed. This is NOT connected to any insurer system — it's a local record the user keeps…"
A passive personal log of claims the user *already filed themselves* is not consultancy. It's a notebook. **Keep.**

**Alternatives considered:**
- *Keep claim guidance with heavy disclaimer.* **Rejected.** Same activity-vs-label problem as F-1; the consultancy is in the guided workflow, not in the disclaimer.
- *Keep only the IRDAI link as a static public-info link.* **Borderline viable** as a single line in an "About / resources" page (not embedded in a claims flow). Would reduce but not eliminate the framing risk. Defer to external review.
- *Keep claim_tracking only.* **Recommended.** Lowest exposure, highest defensibility, and the user still gets value.

---

### F-3 🟡 "Start renewal" / "Contact insurer to renew" CTAs (transaction facilitation)

**Files:**
- `mobile/lib/l10n/app_en.arb:190-191`
- `mobile/lib/screens/renewal_calendar_screen.dart` (consumer)

**Copy (verbatim):**
```
"renewalContactToRenew": "Contact insurer to renew",
"renewalStartRenewal": "Start renewal",
```

**Why this is on the line.** A calendar that reminds a user "your policy expires on {date}" is a **calendar/reminder utility** — clearly in-scope and low-risk. But a button labeled **"Start renewal"** that initiates contact with the insurer to *transact* a renewal is **insurance-intermediation-adjacent**: it moves the user toward effecting a contract of insurance. The distinction regulators draw is often between *information* and *facilitation of a transaction*.

**Recommendation:** Keep the passive reminder (expiry dates, push notifications, "Expiring Soon" sections). **Drop the "Start renewal" / "Contact insurer to renew" action buttons.** A reminder card that ends at "this policy expires in 7 days — review your policy document" is a calendar; one that hands the user off to begin transacting is not.

**Alternatives considered:**
- *Keep but rename to neutral "View policy."* **Partially viable.** A read-only "open the policy document" action is fine; a "contact insurer to renew" action is not. The fix is to remove the transacting intent, not just reword.
- *Show insurer contact details as read-only extracted fields* (phone/email lifted from the user's own policy text), with no "start renewal" framing. **Viable.** That is "showing what's in your document," which is the entire product thesis.

---

### F-4 🟡 Insurance Literacy Quiz (scope drift, low legal risk)

**File:** `mobile/lib/screens/insurance_literacy_screen.dart`

**What it does.** A glossary + quiz that asserts generic, authoritative definitions of insurance concepts, e.g. (`insurance_literacy_screen.dart`):
> "Cashless Claim — Your insurer pays the hospital directly — you don't pay upfront (for network hospitals)."
> "No Claim Bonus (NCB) — A discount or increased coverage you earn for not making a claim in a year."

**Why it's flagged.** This is **educational**, and education is generally not regulated intermediation. The risk is lower and different in kind from F-1/F-2: the concern is that these are *oversimplified authoritative statements about how insurance works in general*, some of which are imprecise (NCB rules vary by product and insurer; cashless mechanics depend on network and pre-auth). Inaccurate general insurance education can still create consumer-protection exposure under unfair-trade-practice principles even where it isn't intermediation.

**Recommendation:** **Not a launch blocker**, but hide from the first release for focus and to keep the product's surface tightly on "your documents." If retained later, the definitions should be softened from prescriptive ("your insurer pays…") to descriptive ("typically means…") and carry a "verify in your policy" cue. This is scope drift, not boundary crossing.

---

## Findings — prompt layer (reinforce the boundary; fix regardless)

These do not *create* a regulated activity, but they affect whether the Q&A engine *sounds* advisory. Cheap to fix; do regardless of launch scope.

### F-5 🟡 HyDE prompt instructs the model "do not hedge"

**File:** `src/rag/pipeline.py:770`

The hypothetical-document-generation prompt reads:
```python
"You are an insurance document analyst. "
"Given a question about an insurance policy, "
"generate a brief hypothetical answer (2-3 sentences) "
"that would appear in the policy document. "
"Be specific and factual. Do not hedge."
```

**Why it matters.** "Do not hedge" is the wrong default for a domain where a confident wrong statement is a stronger misstatement than a hedged one. HyDE output is used internally for retrieval expansion, not shown to the user directly — so the blast radius is limited — but instructing an LLM to be un-hedged when manufacturing insurance statements is the opposite of the grounding posture the rest of the system enforces. If any HyDE text ever leaks into a visible answer, the instruction amplifies harm.

**Recommendation:** Invert the instruction to encourage calibration (e.g. "stay tightly to what a typical policy document would state; do not speculate beyond it").

### F-6 🟢 Answer grounding is correctly enforced

**Files:** `src/security/prompt_injection.py:52-60`, `src/llm/client.py:165-171`

The security system prefix establishes the right boundary:
> "4. Answer ONLY from the provided document context below.
>  5. If the answer is not in the provided context, say so — do not guess."

This is the correct posture for a document-understanding tool and is the strongest structural protection against the Q&A surface drifting into advice. **Keep, and ensure the *answer-generation* prompt (not only the HyDE helper) carries the same grounded-only / "not advice" boundary explicitly.** No change required if already enforced end-to-end; verify during remediation.

---

## Findings — already clean (verified, keep)

Recorded so the reviewer does not re-litigate settled ground and so the contrast with F-1…F-4 is explicit.

| Surface | File | Why it's in-scope |
|---|---|---|
| Health Score removed | `mobile/lib/widgets/policy_readiness_card.dart:7` | Docstring: *"Replaces ungrounded health scores and coverage gap heuristics."* The historical P0 trust blocker is already gone. |
| Preventive notes | `mobile/lib/services/preventive_health_service.dart:6-9` | Rewritten so it never infers coverage: *"A policy type alone cannot establish benefits… Notes therefore direct people to review the source document… they never infer coverage."* |
| Coverage review | `mobile/lib/screens/coverage_gap_screen.dart` | Relabeled "Coverage review"; explicitly *"Missing items do not mean your policy lacks that coverage."* Read-only, evidence-tiered. |
| Lead-generation CTAs | `mobile/lib/services/lead_generation_service.dart` | Every CTA returns the user to an evidence-backed question about *their own* policy; explicit non-quoting/non-advisory posture. |
| Onboarding scope disclaimer | `mobile/lib/screens/onboarding_screen.dart:318-336` | Accurate: *"CoverWise is a policy information assistant, not an insurer, agent, or broker."* |
| Claim tracking (personal log) | `mobile/lib/screens/claim_tracking_screen.dart` | Local-only log; not connected to any insurer. Notebook, not consultancy. |
| Billing | RevenueCat (own subscriptions only) | CoverWise never touches insurance money. The cleanest structural fact in the app's favor. |

---

## Contradictions to resolve explicitly

1. **What-If Calculator vs. LeadGenerationService posture.** The calculator quotes prices; `lead_generation_service.dart` states the product does not quote prices. One of them is wrong about what the product is. The recommendation is to make the calculator conform to the stated posture (remove it), not to weaken the posture.
2. **"CoverWise does not file or manage the claim" (claims_assistant header) vs. the preparation-guide workflow that follows.** The disclaimer says one thing; the screen does another. Same resolution pattern as F-1.

---

## Recommended remediation buckets

**Editorial / scope (do before launch, no external dependency):**
- Gate off `/what-if` route and dashboard entry (F-1).
- Gate off the claim-assistance and claim-guide screens and their entry points (F-2). Keep `claim_tracking_screen`.
- Remove the "Start renewal" / "Contact insurer to renew" CTAs from the renewal calendar; keep passive reminders (F-3). Optional replacement: read-only display of insurer contact details extracted from the user's own policy, with no "start renewal" framing.
- Soften F-4 quiz definitions or hide the quiz; defer.

**Prompt layer (do regardless):**
- Invert the HyDE "do not hedge" instruction (F-5).
- Verify the grounded-only / not-advice boundary is present in the *answer-generation* prompt, not just the security prefix (F-6).

**Defer to external review:**
- Whether a single static "IRDAI Bima Bharosa" public-information link is acceptable outside any claims flow (F-2 alternative).
- Final wording of the role/positioning copy across legal docs + app + web (overlaps with `legal_risk_remediation_priority_2026-07-25.md` Priority 1 and is out of scope here).

---

## Open questions for the reviewer

1. Is the founder's intended scope better captured as "read-only extraction + grounded Q&A over the user's own documents" — i.e. should any *computed/projection* output (not just the calculator) be treated as out-of-scope by policy?
2. Should "show insurer contact details extracted from my policy" be permitted as read-only display, or does even surfacing contact details toward a renewal count as facilitation in the reviewer's jurisdiction?
3. Does the reviewer agree that the *activity* (not the disclaimer) is the right unit of analysis for this boundary? (The audit assumes yes; if the reviewer disagrees, several recommendations weaken.)

---

## Acceptance checklist (per `legal-risk-audit` skill)

- [x] No code changes.
- [x] Evidence includes `path:line` references and verbatim quotes.
- [x] All scanned directories listed (Feature screens, services, l10n, prompts, routing).
- [x] Category buckets applied (price-quoting / claims consultancy / transaction facilitation / education / prompt layer / already-clean).
- [x] Open questions and contradictions called out explicitly.
- [x] Duplicate legal-source drift check: not in scope for this audit (covered by the parallel `legal_risk_remediation_priority_2026-07-25.md` track); flagged here for completeness.
