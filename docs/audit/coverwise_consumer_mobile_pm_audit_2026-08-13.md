# CoverWise — Consumer Mobile Product Manager Audit

**Audit date:** 2026-08-13
**Auditor persona:** Consumer Mobile Product Manager (voluntary-individual, mobile, trust-sensitive category)
**Product:** CoverWise — a private, source-verifiable personal insurance knowledge workspace (Flutter client + Python FastAPI/Supabase backend)
**Workspace:** `/Users/pranay/Projects/medpiper/insurance_app`
**Evidence tier:** Mixed. Code-level findings are S1/S2-verified (read at file:line). Product-strategy findings are decision-grade reasoning (Tier 0) — not yet validated by representative user research or production behaviour.
**Governing doctrine:** `OPERATING_DOCTRINE.md` v6.1 (canonical operating authority — `motto_v5.md` is retired and is *not* cited as authority per §4.1.8). Product-boundary constitution this audit tests against: `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`, `docs/architecture/FIRST_PRINCIPLES_WEDGE.md`, `docs/architecture/FREE_VS_PAID_BOUNDARY.md`.
**Evidence taxonomy (per §2):** code-level claims are **Observed/Verified** at `file:line` (Tier 1 static inspection; some corroborated by Tier 2 checks). Product-strategy claims are **Inferred/Proposed** (decision-grade reasoning, Tier 0) — not yet validated by representative user research or production behaviour. Contested items (e.g. global vs India-first, §10.4) are flagged as **Contested** with both positions preserved.

---

## 0. How to read this audit

A first-principles UX/launch audit already exists (`docs/review/coverwise_launch_readiness_review_2026-07-22.md`, "Buffy review"). That review owns the **trust/launch-gate** domain (misleading insurance-intelligence surfaces, identity-migration safety, production proof, store binaries). This document deliberately **does not re-litigate it**. It adds the *Consumer Mobile PM* lens the prior review does not fully apply:

- Is the product a **healthy complete consumer loop** (discovery → install → first value → activation → repeat → retention → advocacy → monetization)?
- Is **time-to-value** genuinely short, and is **activation** measured?
- Is the **core loop** coherent, and is **usage frequency** honest (not manufactured)?
- Is **monetization** aligned with a naturally *occasional* product and with the product's *global* posture?
- Is the **trust/verification promise** actually delivered on the surface users touch most?
- Are **metrics** defined so the loop can be managed?

Where a finding overlaps the launch-readiness review, it is cross-referenced and the new lens-specific angle is stated.

---

## 1. Target consumer

**Who (derived from constitution + wedge + code):** An individual who *already owns* one or more insurance policies (health, motor, travel, life, home, etc.) across global markets and needs to *understand and organise* them — not shop for them, not be advised, not be quoted.

**Strong points:**
- The product correctly refuses the "insurance shopper" and the "advice-seeker." The wedge's Gate C (role) and the Cut list (what-if, lead capture, shopping comparison, newsletter) keep the audience honest. This is rare discipline for an insurance-adjacent app and is the right call.
- Anonymous-by-default identity (`app_bootstrap.dart:132-140`, `auth_service.dart:759`) means the user is **not forced to become an account** before value. For a trust-sensitive, occasionally-used product, this lowers the bar to first value.

**Gaps:**
- **No behavioural/segment definition exists in product docs or code.** The persona requires more than "people who want to understand insurance." There is no documented segmentation by policy count, life stage, trigger event, or willingness-to-pay. The commercial layer asserts "most users have 1-2 policies (founder input)" — that is founder intuition, not researched segmentation.
- **Global vs India is unresolved (see §10.4).** The constitution and the standing product instruction treat CoverWise as **global**; the billing/store/entity docs treat it as **India-first** (`coverwise_india_billing_revenuecat_dodo_decision_2026-07-21.md:6`, PSRS Technologies Private Limited, ₹ pricing, UPI/Dodo). The target consumer cannot be precisely defined until this is reconciled, because currency, payment method, language, regulatory posture, and store discovery differ by market.

**Verdict:** The *boundary* of the target consumer is excellent. The *definition* is under-specified and currently internally contradictory on geography.

---

## 2. Underlying job / problem (Jobs-to-be-Done)

**Job:** *"I own insurance policies I don't fully understand. When something happens — a renewal date, a claim, a question — I need to know what I'm actually covered for, with proof I can check."*

The constitution states the durable outcome precisely: **comprehension**, not upload, not chat (`PRODUCT_FIRST_PRINCIPLES.md §1`; `FIRST_PRINCIPLES_WEDGE.md §1`).

**Strengths:**
- The job is real, recurring, and high-emotion (renewals, accidents, hospital admissions). High natural willingness to return *at the moment of need*.
- The product translates technology into consumer jobs: upload → "what am I covered for?"; Q&A → "does my policy cover X?"; renewal dates → "when does this lapse?"; emergency card → "who do I call and what's covered right now?"

**Gaps:**
- **The value proposition copy is still abstract.** Store/positioning copy reads "understand and organise policies they already own" (`README.md:18`). That is category-language, not a job. A Consumer PM would sharpen to a concrete job-users-can-picture: *"Upload your policy. See what you're covered for — in plain language, with the exact clause it came from."* The persona's test (§8): weak = "An AI-powered lifestyle companion"; strong = "Search thousands of your photos by describing what you remember." CoverWise's current line is closer to weak.
- **Category-education burden is high (see §9).** "Source-verifiable personal insurance knowledge workspace" is a *new category*. Users have no mental model for it. That load currently falls on a 3-page onboarding carousel — pre-value explanation (§5).

---

## 3. Promised outcome & value proposition

**Promise (constitution):** CoverWise reports what the uploaded policy workspace establishes, what it does not establish, and where each fact comes from. The policy is authoritative; CoverWise is the interpreter.

**This is a strong, defensible, trust-first promise.** It directly answers the persona's trust mandate (§30): trust comes from predictability, transparency, reliability, privacy, good recovery, clear communication — not polish.

**Gap — the promise is not fully delivered on the primary surface (see §11.1).** The signature design element in `DESIGN.md:32-35` is: *"Every generated answer carries an explicit verification state."* On the streaming Q&A path — the interface users actually use — that promise is not met. The value proposition's moat ("every answer cites its source") is asserted in copy and rendered in UI scaffolding, but the data that would fulfil it is dropped at the API boundary.

---

## 4. Why mobile (mobile-native opportunity)

Insurance comprehension is a **mobile-native** job: policies live in email/portals/messaging on the phone; the moment of need (hospital, accident, renewal reminder) is mobile and often low-connectivity. The product uses the right native capabilities:

- **File picker / share sheet / document import** for policy PDFs (digital-first — correct per wedge §4.2).
- **Offline-readable cached summaries** for the emergency surface (see §11.3 — genuinely well done).
- **Notifications** only for factual renewal reminders, lazily requested (correct, §13).
- **Camera/photos** only inside the claims workflow (optional fallback, correct).

**Gap:** The product is **document-import-first but not yet "instant capture" first**. For printed/in-accessibly-emailed policies the camera fallback exists only inside claims. That is the right *launch* call (wedge §4.2), but the share-sheet/email-forward/insurer-portal import paths are "requires actual user evidence before priority claims" (wedge §4.2) — i.e., the most natural mobile import (forward the email) is not yet a first-class, measured flow.

---

## 5. First-use experience & time-to-value

**Flow (verified):** `SplashScreen` (~1.1s) → `OnboardingScreen` (3-page carousel, two required consent checkboxes) → "Add my first policy" → `DocumentsScreen` auto-opens file picker → processing-consent gate → upload → on `status=='completed'` fires `first_value_delivered` and routes to Q&A with the document preselected (`documents_screen.dart:453-462`).

**Strengths (this is a genuine product strength — defend it):**
- **No signup wall.** Anonymous identity + 3-tap onboarding + auto file-picker → first extracted summary in ~4-5 user actions. This is a *short* time-to-value by consumer-mobile standards.
- **No first-run paywall.** Monetization appears only when a free cap is hit (§10), not before value.
- The code explicitly names the moment: `documents_screen.dart:453` "this IS the first value moment" and `:460-461` "the real 'aha' moment is asking questions about a real policy."

**Gaps:**
- **Onboarding is pre-value explanation.** The 3 carousel pages (UNDERSTAND / ASK / STAY INFORMED) sell the product before the user has seen *their* value. The persona (§9) asks "What appears first?" — here, explanation appears first. Acceptable, but it could be tightened: show the value faster, request the document-processing consent *in context* at the moment of upload (which the code already does via `_ensureConsent`, `documents_screen.dart:604-644`) rather than also front-loading it in the carousel.
- **The post-upload destination is philosophically split.** Code routes to **Q&A** as the "aha." The wedge (§3.3) argues the **coverage summary** should be the destination ("Q&A becomes the fallback for edge cases, not the primary interface"). The DECISION_LOG P0-2 added an executive-summary card, but the *navigation* still lands on Q&A. This is a real product-philosophy inconsistency: is the primary surface comprehension (summary) or conversation (Q&A)? The persona says the core loop must be unambiguous. Resolve it: land on the summary; offer Q&A as the obvious next step.

---

## 6. Activation

**Operational definition (exists):** `first_value_delivered` fires when a document completes processing and the app routes to Q&A (`documents_screen.dart:457`, schema `analytics_schema.dart:260-262`). The funnel `first_upload_started → document_processing_succeeded → first_value_delivered → first_question_asked` is event-declared.

**Gap (this is a core Consumer PM finding):**
- **Activation is not metricized.** No code computes an activation *rate*, no D1/D7/D30 retention is defined (repo-wide grep for `activation rate|D1 retention|D7 retention|retention_rate|north_star` returns nothing relevant), and `first_question_asked` is **declared in the analytics schema but has no client fire site** (subagent: `analytics_schema.dart:295` comment vs no `track()` call; `first_value_delivered` is the only reliably-fired activation signal).
- You cannot manage a loop you do not measure. The persona (§18, §52-54) requires a defined activation event, a computed activation rate, and cohort retention. **This is a P1: wire `first_question_asked` (or redefine activation as "first summary viewed + first question asked"), compute activation rate and D1/D7/D30, and put them on a dashboard before scaling acquisition.**

---

## 7. Core repeat-use loop

**Loop (as built):** upload policy → comprehension (summary + Q&A) → organisation (dashboard, family, renewals) → reminders → return at need (renewal, claim, new question).

**Strengths:**
- The stored-value loop is real: the user's *own* policy data + extracted comprehension accumulates. Each return makes the next return more valuable (the persona's "investment" — saved data, history, personalization).
- Renewal reminders are the correct **event-driven** re-trigger (factual dates, user-opted).
- No dark patterns: no notification addiction, no engagement theatre (persona §20, §63). The only notifications are renewal reminders.

**Gap — no social / no network effect, by design (correct), but that makes retention entirely dependent on *insurance moments*.** For an occasional product that is fine *if* the return triggers are strong. They are currently weak:
- Renewal reminders are **not actually scheduled** in the current build (launch-readiness P0-3: `NotificationService.scheduleRenewalReminders` calls `show()` immediately, not zoned scheduling). Until fixed, the single best retention trigger is broken.
- There is no "new clause / new uncertainty" prompt after a policy changes, no "review your cover before renewal" nudge that is *evidence-stated*, and no lightweight "your policy expires in 30 days — here's what it covers" summary push. The persona (§17) asks "why do users return?" — today the only honest answer is "when they remember they have the app," which is fragile.

---

## 8. Natural usage frequency

**This is the single most important strategic framing for CoverWise.** Insurance is, per the persona's own taxonomy (§15), an **event-driven** product — like travel and tax, not like messaging or social. The user opens it when something happens, not daily.

**Implication (persona §15, §63 "false frequency"):** The product must **not** try to manufacture daily engagement. The current design mostly respects this (no daily push, no streaks, no feed). Good.

**But two tensions:**
1. The **Dashboard/Home** is built as if the user visits often (welcome card, recent activity, preventive tips, workspace health score). For an occasional product, a heavy home screen is dead weight most of the time and dilutes the core mental model (launch-readiness §9 agrees: "too broad; several labels do not match behavior"). At an insurance moment, the user wants *their policy facts fast*, not a dashboard.
2. **Monetization assumes recurrence (see §10.2).** A subscription monetizes *ongoing* value. An occasional product delivers most of its value in 1-2 sessions and may not return for months — so the free tier (1 policy, 20 Q&A/month) may rarely be hit, and the paid tiers (comparison, family matrix, annual review) must be *compelling enough at the moment of need* to convert. This is the central economic question and it is currently unanswered by evidence.

---

## 9. Acquisition & distribution / discovery

**Gap (P1 for a consumer launch):** CoverWise is **not yet deployed** (`README.md:50-65`) and has **no defined discovery strategy** beyond store-listing copy docs (`docs/review/coverwise_play_store_listing.md`). For a Consumer Mobile PM, discovery → install is the top of the funnel and it is currently undefined:

- **No ASO / keyword strategy** documented. "Personal insurance knowledge workspace" is not a search term anyone types.
- **No screenshot strategy** that demonstrates the "aha" (upload → plain-language summary with source). Store screenshots are the highest-leverage discovery asset for a new category and are unspecified.
- **No rating/review strategy** (persona §41). For a trust category, launch reviews are make-or-break; there is no plan to seed honest early reviews or respond to them.
- **Category-education load is high (§2).** Users don't understand the category, so store copy, first-run, and screenshots must carry heavy education. None of that is specified as a coordinated asset set.
- **No referral / virality loop** (persona §27-28). Correct to avoid bolted-on referral in a private, single-user product — but the *natural* virality (share a coverage summary with a family member) is currently **free-but-ungated-or-mis-gated** (export/share is free per code, should be paid per commercial G1). A clean, intentional share-to-family loop could be both a retention and acquisition mechanic — and it is currently neither designed nor correctly packaged.

---

## 10. Monetization

Framework used: persona §34-39 (CAC/LTV/ARPU/conversion/churn/margin/platform fees) + the three value categories from the commercial layer (🧠 Comprehension free / ⚡ Convenience paid / 🔬 Depth paid).

### 10.1 What is right
- **Server-authoritative entitlements**, RevenueCat webhook authority, idempotent Q&A reservation, policy-slot reservation (`subscription.py`, `qa_usage_service.py`, `policy_slot_reservation_service.py`). Keep this architecture (launch-readiness §3.1, §11).
- **Free floor is trust-correct:** comprehension (summary, detail, citation badges, emergency facts, renewal reminders, basic Q&A) is free. Monetizing comprehension would violate the wedge.
- **Q&A packs** (₹49/119/199) are a good microtransaction fit for *occasional heavy use* — they let a user who rarely needs more questions pay per use instead of subscribing. This is the right shape for an event-driven product.

### 10.2 Core strategic risk — subscription vs occasional product (P0 opinion)
A subscription's job is to capture *recurring* willingness to pay. CoverWise delivers most comprehension value **front-loaded in 1-2 sessions** and is **occasional by nature** (§8). Therefore:
- The free tier (1 policy, 20 Q&A/month) is unlikely to be *hit* by most users → weak upgrade pressure from the cap.
- The paid tiers (comparison, family matrix, annual review, advanced search) are *depth* features the user only values **at an insurance moment** — which may be months apart. A monthly subscription competing for attention it doesn't get is a poor fit.
- **Implication:** the monetization model should be **comprehension-free, depth-priced, and usage-shaped**. Lean harder on (a) Q&A packs / per-analysis microtransactions, (b) a *household/annual* plan framed around the renewal cycle (pay once per policy year, not monthly), and (c) correctly gating export/share and advanced comparison. Re-examine whether a *monthly* Plus/Family subscription is the right default vs an *annual / per-event* shape. The current ₹149/mo vs ₹999/yr split exists but is **unsourced hypothesis** (§10.4).

### 10.3 Packaging gaps (from commercial layer, carried forward)
- **G1:** Export/share is free in code but is a *convenience* (paid candidate) per the wedge. Either gate it or decide deliberately. For an occasional product, a clean **share-to-family** loop is both retention and acquisition — design it intentionally, don't leave it free-by-accident.
- **G4:** Comparison is all-paid, but *basic neutral owned-policy comparison* is comprehension (free). Split it: basic free, advanced paid.
- **G5:** Separate emergency *facts* (free constitutional floor) from any paid *support channel*.

### 10.4 Global vs India — unresolved positioning (P0 for launch)
- **Standing instruction + constitution:** CoverWise is **global**, not India-specific.
- **Billing/store/entity docs:** **India-first** — `coverwise_india_billing_revenuecat_dodo_decision_2026-07-21.md:6` ("India-first consumer mobile application"), PSRS Technologies Private Limited, ₹ pricing, UPI/Dodo, India storefronts.
- **Commercial layer:** ₹ prices, "most users have 1-2 policies (founder input)."
- **Conflict:** If the product is global, the ₹-only pricing, India entity, and UPI/Dodo-centric billing are a **launch-strategy mismatch** (currency locale, payment methods, store listings, ASO, tax). If it is India-first, the constitution's global language is aspirational and should be re-scoped.
- **Action:** Make the geography decision explicit *before* store submission. It drives store listing, pricing locale, payment configuration, and the very definition of the target consumer (§1). This is not a code issue; it is a product-strategy decision that blocks a credible launch.

### 10.5 Pricing evidence
All exact prices (₹149/999, ₹249/1799, packs ₹49/119/199) are **Proposed hypotheses without sourced benchmarks** (`FREE_VS_PAID_BOUNDARY.md §7`: the "RevenueCat 2026 India median ₹300-315" claim is explicitly unsourced). Per the persona (§37) and the commercial layer's own evidence-audit skeleton, **no price should ship in copy or store listings until §7 is completed and the operator approves.** Treat every number as experimental.

---

## 11. Privacy & trust

### 11.1 Streaming Q&A drops the verification promise (P0 — code-verified)
This is the audit's sharpest finding and it is **not** covered by the launch-readiness review (which says "citations before follow-up suggestions" and "answer confidence hidden until calibrated," implicitly assuming citations are present).

- `QueryResponse` (`main.py:100-112`) has **no `verification_status` field**. The backend computes `VerificationStatus` (fully_backed / partially_backed / abstained / unverified) and stamps it on the internal result (`pipeline.py:1478-1521`), but it is **not returned** to the client.
- The **primary** Q&A endpoint `/query/stream` (`pipeline.py:1741-1743`) explicitly: *"For full structured response with citations, we'd need a second pass. For now, we just stream the answer text."* It yields **only answer tokens** — no citations, no confidence, no verification.
- The mobile `QaScreen` renders a full verification/citation UI (`qa_screen.dart:1755-1917`: verification-status badge, confidence badge gated on `confidenceCalibrated`, citation cards with verified/approximate/rejected states + page navigation). **On the streaming path those surfaces are empty**, because the endpoint supplies none of the data.
- The non-streaming `/query` returns `citations` + `confidence` but still **omits answer-level `verification_status`**.

**Why it matters:** The product's entire differentiation and trust moat is "every answer cites its source / carries an explicit verification state" (`DESIGN.md:32-35`; wedge §3.5 "the moat"). Delivering the answer surface *without* that state — on the path users actually use — quietly breaks the promise. It also contradicts the launch-readiness requirement that "every answer identifies its scope" and "citations before follow-up suggestions."

**Fix (pre-launch, before "Ask CoverWise" ships publicly):** Either (a) make `/query/stream` emit citations/verification as a structured tail (SSE event after the text tokens), or (b) have the client call the non-streaming `/query` for grounding and stream only for the typing effect, or (c) explicitly show "verification pending — tap to verify" and resolve it. Do **not** ship the streaming answer surface with empty citation/verification UI. This is a small, well-scoped backend+client change, not a rewrite.

### 11.2 Consent & analytics — exemplary (defend)
- Consent is purpose-specific, explicit, versioned, server-authoritative, append-only, withdrawable (`consent_ledger.dart`; onboarding records privacy + ToS + optional analytics). Fail-closed.
- Analytics is **opt-in** and schema-enforced with PII checks (`analytics_service.dart`, `analytics_schema.dart`). Strong hygiene.
- **Minor inconsistency:** `ConsentPurpose.cameraAccess` exists in the ledger (`consent_ledger.dart:43`) and is displayed in Settings, but no runtime code records/requests it (subagent). Either wire it or remove the displayed purpose to avoid implying a permission was taken.

### 11.3 Offline at the moment of need — done right (strength, not gap)
- `EmergencyScreen` reads Hive-cached summaries even when the backend is unreachable (`emergency_screen.dart:22-29`): background refresh is best-effort and failures are swallowed. **The user can see their policy facts offline at the moment of need.** This is exactly what the constitution's Principle 9 (reliability at moment of need) requires, and it is implemented.
- **Honest boundary:** interactive Q&A (asking a *new* question) requires the backend (`README.md:62-64` — policy analysis is online; local pending-upload is transport-recovery only). That is acceptable *if* the offline views are clearly labelled "last known / as of <date>" (launch-readiness §8 "Show source and last-updated state"). Verify the emergency/policy-detail offline views carry a visible staleness label before launch.

### 11.4 Trust surfaces the launch-readiness review already gates
Health Score, Coverage Gaps, phone-capture-as-backup, All-Documents silent-single-doc query, privacy-copy mismatch — these are covered by Buffy's P0-2/3/4/5/8. **Do not ship those surfaces.** This audit adds only that the *streaming Q&A grounding gap* (§11.1) is a missing piece of that same trust gate.

---

## 12. Complexity & unnecessary features

**Strengths:** The wedge Cut list is disciplined (what-if, lead capture, newsletter, shopping comparison, demo all rejected). Feature creep is actively resisted at the doctrine level.

**Gaps (feature-creep / wedge-adjacency risks to verify):**
- **"Preventive tips"** (`dashboard_preventive_tips.dart`) — if these are generic advice, they are out of wedge (Gate C) and were explicitly listed for hiding in launch-readiness §8 ("generic preventive tips that imply advice"). Confirm they are either removed or reframed as *policy-stated* reminders, not invented advice.
- **"Workspace health score" / "readiness"** — largely superseded by the launch-readiness P0-4 (remove Health Score). The readiness checklist replacement (policy-type identified, insurer identified, dates identified, source pages available) is the correct, evidence-stated shape. Ensure only the evidence-stated readiness view ships, not a scored/advice surface.
- **"Smart Suggestions"** stub (`l10n/app_en.arb:227`) — labelled "Coming soon." Remove or implement; do not ship "coming soon" in primary navigation (launch-readiness §8).
- **Dashboard breadth** — 10+ cards on Home dilute the core mental model for an occasional product (§8). Trim to: primary action (add/ask) + next-expiry/attention + most-recent verified answer. Everything else belongs in "More."

---

## 13. Measurable outcomes / metrics

**Gap (P1):** There is **no north-star metric, no activation-rate computation, no cohort retention, no input-metric tree** defined in code or docs (grep confirmed; subagent confirmed). The backend has an `/analytics/funnel` and `/analytics/summary` operator endpoint, but no *product* north-star is declared.

**Recommended metric system (persona §53-55):**
- **North-star (value delivered):** *Policies understood* = count of policies with a completed extraction + at least one viewed summary or answered question. (Analogous to "successful retrievals.")
- **Activation:** *first_value_delivered* AND *first question asked* within session 1 → activation rate.
- **Input metrics:** upload completion rate, processing-success rate, summary-view rate, Q&A rate/user, citation-open rate, no-evidence rate.
- **Guardrails (must not deteriorate):** crash-free sessions, refund rate, notification opt-out, uninstall rate, support complaints, no-evidence rate, cross-owner citation rate (security).
- **Retention:** D1/D7/D30 by acquisition cohort; segment by policy count and trigger event.

Wire `first_question_asked` (currently schema-only, unfired). Make activation + guardrails a launch dashboard *before* paid acquisition.

---

## 14. Prioritized recommendations

Ranked by **user impact × business impact × confidence × strategic importance ÷ complexity** (persona §65-67). "Resolve before" = blocks a credible consumer launch.

### P0 — resolve before public release
| # | Finding | Recommended action | Confidence | Complexity |
|---|--------|--------------------|-----------|-----------|
| P0-1 | **Streaming Q&A drops citations/verification** (§11.1) — breaks the core trust promise on the primary surface | Emit grounding on `/query/stream` (structured tail) or resolve citations via non-streaming call; show "verify" state honestly if deferred. Block "Ask CoverWise" public ship until done. | High (code-verified) | Low |
| P0-2 | **Geography undecided: global vs India-first** (§10.4) | Explicit decision before store submission. Drives pricing locale, payment config, store listing, target-consumer definition. | High | Low (decision) |
| P0-3 | **Renewal reminders not scheduled** (launch-readiness P0-3) | Hide reminder CTA until zoned scheduling is real; or implement correctly (plugin init, iOS+Android perms, quiet hours, stable IDs, reschedule on policy change, device-test). The best retention trigger is currently broken. | High | Med |
| P0-4 | **Misleading trust surfaces** (launch-readiness P0-2/4/5/8) | Do not ship Health Score, Coverage Gaps, phone-as-backup, All-Documents silent-single-doc query, mismatched privacy copy. | High | Med |

### P1 — required to manage the loop
| # | Finding | Recommended action | Confidence | Complexity |
|---|--------|--------------------|-----------|-----------|
| P1-1 | **Activation/retention not metricized** (§6, §13) | Define north-star (policies understood), compute activation rate, wire `first_question_asked`, add D1/D7/D30 cohorts + guardrails dashboard before paid acquisition. | High | Med |
| P1-2 | **No discovery/ASO/screenshot/review strategy** (§9) | Build store listing + screenshot set demonstrating upload→plain-language-summary-with-source; ASO keyword plan; rating/review plan. Category education is the launch blocker for installs. | High | Med |
| P1-3 | **Monetization shape vs occasional product** (§10.2) | Stress-test subscription vs per-event/annual + Q&A-pack model with unit economics (CAC/LTV/churn). Reconsider monthly-default. | Med (strategic) | Med |
| P1-4 | **Post-upload destination split** (§5) | Land on coverage summary (comprehension) post-upload; offer Q&A as the obvious next step. Resolve summary-vs-Q&A philosophy. | High | Low |

### P2 — sharpen
| # | Finding | Recommended action | Confidence | Complexity |
|---|--------|--------------------|-----------|-----------|
| P2-1 | **Abstract value-prop copy** (§2) | Rewrite positioning to a concrete job: "Upload your policy. See what you're covered for — in plain language, with the exact clause." | High | Low |
| P2-2 | **Packaging gaps G1/G4/G5** (§10.3) | Gate export/share; split basic(free)/advanced(paid) comparison; separate emergency facts from paid support. | High | Low-Med |
| P2-3 | **Dashboard breadth / feature creep** (§12) | Trim Home to core action + next-expiry + recent answer; verify preventive tips & smart suggestions are removed/reframed. | High | Low |
| P2-4 | **Pricing evidence audit** (§10.5) | Complete `FREE_VS_PAID_BOUNDARY.md §7` before any price ships in copy. | High | Low |
| P2-5 | **Consent ledger consistency** (§11.2) | Wire or remove `cameraAccess` displayed purpose. | High | Low |

---

## 15. KPI tree (proposed)

```text
North-star: Policies Understood
  ├─ Upload completion rate
  ├─ Processing success rate
  ├─ Summary view rate
  ├─ Q&A rate / user
  │    ├─ Citation open rate        (trust signal)
  │    └─ No-evidence rate          (honesty signal)
  ├─ Activation rate (first value + first question, session 1)
  └─ D1 / D7 / D30 retention (by cohort)

Guardrails (must not deteriorate):
  ├─ Crash-free sessions
  ├─ Refund rate
  ├─ Notification opt-out
  ├─ Uninstall rate
  ├─ Support complaints (by failure class)
  ├─ Cross-owner citation rate (security)
  └─ No-evidence rate (trust)
```

---

## 16. Anything else?

- **The loop is fundamentally sound; the trust promise is the risk.** Discovery → install → first value → activation is genuinely good (anonymous, short TTV, no paywall). The danger is not friction — it is that the *primary answer surface does not deliver the verification it advertises* (P0-1) and that the product is *occasional*, so retention and monetization must be engineered around insurance moments, not engagement.
- **Do not manufacture frequency.** The biggest temptation will be to add daily nudges / streaks / feed to "improve retention." Resist (persona §63 "false frequency"). The right retention levers are: working renewal reminders (P0-3), a share-to-family loop (P1-2/G1), and honest "review before renewal" prompts.
- **Measurement is the missing discipline.** The codebase is engineered for trust (consent ledger, outbox, verification pipeline) but the *product* is not yet measured for the consumer loop. P1-1 is the highest-leverage non-code change.
- **Global vs India is a decision, not a detail.** It blocks a credible store launch and must be made explicitly (P0-2).
- **Honour the launch-readiness review.** This audit is additive to Buffy's; P0-3/P0-4 here are Buffy's gates, restated through the consumer lens. The two reviews together define the launchable product: *one policy-understanding loop that is impossible to misunderstand, impossible to cross-contaminate, and now impossible to use without seeing its source.*

---

## Appendix A — Evidence index (file:line)

| Claim | Evidence |
|-------|---------|
| Anonymous-by-default identity | `mobile/lib/bootstrap/app_bootstrap.dart:132-140`; `mobile/lib/services/auth_service.dart:759` |
| First-run flow & consent gate | `mobile/lib/screens/onboarding_screen.dart:30-55,80-91,276-365,397-400`; `mobile/lib/screens/documents_screen.dart:604-644` |
| `first_value_delivered` + route to Q&A | `mobile/lib/screens/documents_screen.dart:453-462`; schema `mobile/lib/services/analytics_schema.dart:260-262` |
| `first_question_asked` declared, unfired | `mobile/lib/services/analytics_schema.dart:295` (comment); no client `track()` matched |
| Streaming endpoint drops grounding | `src/app/main.py:100-112` (no `verification_status`); `src/rag/pipeline.py:1741-1743` ("just stream the answer text") |
| QaScreen renders citation/verification UI | `mobile/lib/screens/qa_screen.dart:1755-1917` |
| Emergency screen offline-first | `mobile/lib/screens/emergency_screen.dart:22-29` |
| Renewal reminders call `show()` not schedule | launch-readiness P0-3; `mobile/lib/services/notification_service.dart` |
| Monetization backend authority | `src/api/subscription.py`; `src/services/qa_usage_service.py`; `src/services/policy_slot_reservation_service.py` |
| Export/share free but convenience (G1) | `FREE_VS_PAID_BOUNDARY.md §3 G1`; `entitlement_provider.dart` (share ungated) |
| Pricing unsourced | `FREE_VS_PAID_BOUNDARY.md §7` |
| India-first billing/entity | `coverwise_india_billing_revenuecat_dodo_decision_2026-07-21.md:6`; PSRS Technologies Pvt Ltd |
| Global product instruction | project memory (standing): "CoverWise is GLOBAL, not India-specific" |
| Constitution outcome = comprehension | `PRODUCT_FIRST_PRINCIPLES.md §1`; `FIRST_PRINCIPLES_WEDGE.md §1` |
| No D1/D7/D30/north-star in repo | repo-wide grep (no relevant hits) |
| Dashboard breadth / feature creep | launch-readiness §9; `mobile/lib/screens/dashboard_screen.dart` |

## Appendix B — Relationship to other reviews
- **Launch-readiness review (2026-07-22, "Buffy"):** owns trust/launch gates. This audit is additive (consumer-loop lens). P0-3/P0-4 here = Buffy's P0-3/P0-4.
- **Product constitution / wedge / commercial layer:** the product-boundary doctrine this audit tests against.
- **DECISION_LOG (2026-07-23):** prior first-principles UX execution (executive summary card, streaming QA, nav restructure). This audit confirms those were directionally right and adds the measurement + grounding gaps they did not close.
