# CoverWise — Product Specification (First Principles)

## Addendum (2026-07-16): permanent solo, non-regulated scope

CoverWise will remain a solo, non-regulated personal-information product. It helps users understand and organize policies they already own. It does not recommend, rank, sell, solicit, procure, or renew insurance; earn commissions; sell leads; represent claims; or operate tools for insurers/brokers.

This supersedes prescriptive language later in this snapshot:

- "coverage gap" may only mean a term/category was not found in uploaded documents. It must not label a user under-insured or recommend an amount, product, insurer, purchase, or renewal.
- comparison may make sourced, dimension-specific judgments between owned policies, such as "lower premium" or "broader documented benefits." It must not produce an unsupported overall winner, tell the user what to buy/renew, or imply equivalence when fields are missing.
- renewal may store dates and remind users to review documents or contact their insurer, but cannot initiate or recommend renewal.
- claims may include contacts, document-derived instructions, and a personal log, but not submission, negotiation, prediction, or representation.
- premium simulation, shopping, compensated referral, paid insurance advice, and insurer/broker tooling are out of scope.
- optional health tracking is limited to private records, neutral trends, reminders, and export. It cannot diagnose, treat, predict, prescribe, triage, or produce clinical/insurance risk scores.

### Comparison copy and evidence contract

CoverWise may say:

> Policy A costs ₹10,000 per year and Policy B costs ₹6,000. Based on the uploaded documents, Policy B is ₹4,000 cheaper (40% less). Policy A lists a shorter waiting period for [benefit], while Policy B lists [exclusion/sub-limit]. The documents do not establish which policy is better for your personal situation.

Use scoped labels such as **lower premium**, **broader documented benefits**, **shorter listed waiting period**, **higher deductible**, and **more exclusions listed**. Link each material conclusion to source clauses and show missing or uncertain fields.

Do not use: "better for you," "switch," "best plan," "overpriced," or "under-insured." Price equivalence must be verified across payment frequency, taxes, riders, sum insured, deductibles, exclusions, sub-limits, waiting periods, and missing pages. The pipeline must generate structured evidence before the UI renders comparative copy.

**Date:** 2026-07-12
**Approach:** What should exist, derived from the problem and the user — not
from what is currently built. This is the target architecture to measure
against.

---

## The problem

People buy insurance and then don't understand it. They have policies they've
paid for — health, auto, life, home — and they can't answer basic questions
about their own coverage:

- What am I covered for?
- What's excluded?
- When does this expire?
- How much coverage do I actually have?
- If something happens right now, what do I do?
- Am I under-insured? Do I have gaps?
- Is this policy worth renewing?

The policy document is a 20-60 page PDF full of legalese. The user files it
and forgets it. When they need it — at a hospital, after an accident, during
renewal — they're unprepared and stressed.

## The product

CoverWise is an insurance companion. You upload your policies; it reads them,
understands them, and stays ready to answer when you need it. It's not a
comparison site, not a broker, not an insurer. It's the thing that sits between
you and the documents you already have but can't read.

**One sentence:** Upload your insurance policies, and CoverWise turns them into
answers you can actually use.

## Who it's for

Indian consumers, solo-founder personal brand launch. Initially:

- People who have 1-5 insurance policies (health, auto, life)
- Who are digitally literate enough to find and upload a PDF
- Who want to understand their coverage without reading 40 pages
- Who will use it most when they need it: at renewal, at claim time, or when
  considering a new policy

## Core principles

1. **The document is the source of truth.** Every answer, every display, every
   recommendation must trace back to the user's actual policy text. No generic
   advice masquerading as personalized.

2. **Show, don't hide.** If the system extracted it, the user should be able to
   see it. Benefits, exclusions, waiting periods, coverage items — these are
   the most valuable parts of the policy. Hiding them defeats the purpose.

3. **Ready when needed.** The app must work offline (policies are already
   uploaded). The most critical info (helpline, policy number, coverage amount,
   claim process) must be accessible instantly — including with no internet.

4. **Honest about limits.** Answers are AI-generated from the document. The app
   must say what it knows, what it doesn't, and always defer to the source
   document and the insurer for binding decisions.

5. **Proactive, not just reactive.** Don't wait for the user to ask. Surface
   expirations, gaps, and actionable insights before they become problems.

---

## What should exist — the complete flow map

### Flow 1: Onboarding (first launch)

**Purpose:** Get the user from "installed" to "value" in under 2 minutes.

What should happen:
1. User opens app → sees a clear, simple intro: what CoverWise does, what it
   needs (a policy PDF), what it does with the data (processes it, stores it
   locally, sends text to the backend for AI analysis)
2. User uploads their first policy document
3. App processes it (direct text extraction → RAG ingestion → summary
   extraction)
4. User sees their policy summary — the first moment of value: "Here's what
   your policy actually covers"
5. App suggests: "Ask a question about your policy" / "See your coverage
   gaps"

What should NOT exist:
- No account creation, no login, no email wall for the core flow
- No demo data injected — the user's real policy is the only data
- No forced tour — the summary IS the onboarding

### Flow 2: Document management

**Purpose:** Let the user add, view, and remove their insurance policies.

What should exist:
- **Upload:** pick a PDF (or image, if OCR is available). App extracts text,
  ingests into RAG, extracts structured summary. Shows clear processing
  status: Uploading → Reading → Analyzing → Ready (or Failed with retry).
- **Document list:** each document shows: filename, policy type, insurer,
  status (ready/processing/failed), upload date. Expandable to show full
  metadata.
- **Document detail:** tapping a document opens a rich view — the full policy
  summary (see Flow 4). Not just metadata.
- **Delete:** removes the document and all derived data (summaries, Q&A history
  for that doc, family members detected from it). Everything stays consistent.
- **Re-process:** if a document failed or was uploaded when the backend was
  down, the user can retry processing.
- **Storage:** honest about limits. "Free tier: up to 5 policies." Configurable.

### Flow 3: Policy summary (the core value display)

**Purpose:** Turn a 40-page PDF into a page the user can actually understand.

This is the most important screen in the app. It should show everything the
system extracted, organized so a non-expert can understand it:

- **Header:** Policy type, insurer, policy number, status (Active/Expiring/
  Expired), coverage period (start → end)
- **Money:** Sum insured, premium amount + frequency, deductible
- **What's covered (key benefits):** bulleted list of the top covered benefits,
  in plain language ("Hospitalization expenses up to ₹5L", "Pre and post
  hospitalization covered", "Daycare procedures covered")
- **What's NOT covered (exclusions):** bulleted list of exclusions ("Pre-
  existing diseases (first 2 years)", "Cosmetic surgery", "Dental treatment
  unless due to accident")
- **Waiting periods:** if any ("Specific diseases: 2 years", "Pre-existing:
  4 years")
- **Coverage items:** individual line items with name, limit, covered status
- **Quick actions:** Ask a question about this policy, View claim process,
  Call insurer helpline, Add to renewal reminders

This screen is what makes CoverWise valuable. If the user sees nothing else,
they should see this. It is the answer to "what does my policy actually do?"

### Flow 4: Q&A (ask anything)

**Purpose:** Let the user ask any question about any policy and get a grounded,
sourced answer.

What should exist:
- **Document selector:** pick which policy to ask about. Only real, processed
  documents. No "all documents" option unless the backend supports it.
- **Suggested questions:** intelligent, policy-type-aware suggestions. Health
  policy → "What's my maternity coverage?" Auto policy → "What's my IDV?"
  Don't show auto-specific questions for a health policy.
- **Custom question:** free text input.
- **Answer display:** the answer, the confidence level, the sources (with page
  references and quoted text), and a clear "this is AI-generated, verify with
  your insurer" disclaimer.
- **Answer feedback:** 👍/👎 so the user can signal if the answer was helpful
  (for future improvement).
- **History:** previous Q&A, searchable, with timestamps.
- **Follow-up questions:** when the answer is incomplete, suggest a follow-up.

### Flow 5: Emergency / Claim-time access

**Purpose:** When something happens — accident, hospitalization, emergency —
the user needs to act fast. This flow must work offline and be instant.

What should exist:
- **Emergency card:** for each policy, the critical info at a glance: policy
  number, insurer helpline (call button), insurer email, coverage amount, what
  to do first.
- **Claim guide:** step-by-step, specific to the incident type and the policy.
  Not generic templates — derived from the actual policy's claim process
  section. "For cashless claims: go to a network hospital, show your policy
  card, the hospital will coordinate with [insurer]."
- **Document checklist:** what documents the user needs for this claim type,
  pulled from the policy.
- **Offline guarantee:** this entire flow must work with no internet. All data
  is cached from the policy summary.
- **Share:** ability to share the emergency card / claim guide with a family
  member who might need it.

### Flow 6: Renewal tracking

**Purpose:** Prevent the user from missing a renewal and losing coverage.

What should exist:
- **Renewal timeline:** all policies sorted by expiry date. Clear visual:
  expired (red), expiring soon (amber, <30 days), active (green).
- **Reminders:** local notifications at 30, 15, 7, and 1 day before expiry.
  The user should never miss a renewal because they forgot.
- **Add to calendar:** one-tap export to the phone's calendar.
- **Renewal decision support:** when a policy is expiring, show the current
  coverage summary and suggest "review your coverage gaps before renewing" or
  "this policy covers X but not Y — consider checking alternatives."
- **Handle unknown dates:** if the policy has no parseable end date, show it
  as "Expiry date not found — check your policy document" rather than hiding it.

### Flow 7: Coverage gap analysis

**Purpose:** Proactively tell the user where they're under-insured before a
gap becomes a loss.

What should exist:
- **Gap detection:** based on what policies the user has and what they cover:
  - No health insurance? → High priority gap
  - Health insurance but no critical illness rider? → Medium gap
  - No life insurance with dependents? → High gap
  - No term insurance? → Medium gap
  - Auto policy expiring soon? → Action needed
  - Coverage amount too low for family size / city? → Medium gap
- **What you have vs. what's missing:** show both sides. "You have health
  (₹5L) and auto. You're missing life insurance and your health coverage may
  be low for a family of 4 in Mumbai."
- **Recommendations:** honest, non-salesy. "Consider increasing your health
  coverage to ₹10L+ for a family in a metro." Not "buy this policy from us."
- **Type-aware:** must correctly classify Indian policy types (Mediclaim =
  health, Family Floater = health, Term Plan = life, etc.)

### Flow 8: Family coverage view

**Purpose:** Show who is insured, under which policy, and whether anyone is
left out.

What should exist:
- **Family roster:** each member with their name, relationship, DOB, and which
  policy/policies they're covered under.
- **Coverage status per member:** "Advay (Child) — covered under Niva Bupa
  Health (₹5L sum insured, family floater)" or "Not covered under any policy"
- **Manual add:** for dependents who have their own separate policies or who
  need to be tracked separately.
- **Gap detection at family level:** "Your spouse is not covered under any
  policy" or "Your parents are not covered — consider a senior citizen health
  plan."
- **Source link:** tap a member to see which policy insures them.

### Flow 9: Policy comparison

**Purpose:** Help the user decide between policies at renewal or purchase time.

What should exist:
- **Select which policies to compare:** user picks 2-3 from their documents.
- **Side-by-side comparison:** coverage, premium, deductible, exclusions,
  benefits, waiting periods, claim process.
- **Highlight differences:** cheaper premium but higher deductible? More
  exclusions? Shorter waiting period? Surface the tradeoffs explicitly.
- **Verdict:** "Policy A has higher coverage but more exclusions. Policy B is
  cheaper but has a longer waiting period." Not a recommendation — a clear
  comparison that helps the user decide.

### Flow 10: Settings & data management

**Purpose:** Let the user control their data and app behavior.

What should exist:
- **Storage usage:** how many policies stored, how much local storage used.
- **Clear data:** actually clears everything — Hive boxes (documents, history,
  family, summaries) AND SharedPreferences. With clear confirmation of what
  will be deleted.
- **Export data:** let the user export their policy summaries + Q&A history as
  JSON or PDF. Their data is their data.
- **Backend status:** show whether the backend is reachable (health check).
- **App version + about.**

### Flow 11: Help, privacy, legal

**Purpose:** Be transparent and compliant.

What should exist:
- **Privacy policy:** real, hosted, linked. Covers: what data is collected
  (policy text, questions), where it's processed (backend, OpenAI), how long
  it's stored, how to delete it, third-party processors.
- **Terms of service:** the app provides information, not insurance advice.
  Answers are AI-generated. Always verify with the insurer.
- **Help / FAQ:** how to upload, why a scanned PDF might not work, what
  "extraction failed" means, how to get help.
- **Contact:** a real, monitored channel.
- **Disclaimer:** prominently, on the app and on every answer — "CoverWise
  helps you understand your policies. It does not provide insurance advice.
  Coverage decisions are determined by your policy and insurer."

---

## What should NOT exist (and why)

- **Demo mode in production:** `bootstrapPolicyDemo` injecting a stranger's
  policy data. This is a development tool that must never ship. If a demo is
  needed for marketing, it should be a separate, clearly-labeled demo build —
  not a flag in the production app.

- **"All Documents" Q&A option:** if the backend can't answer cross-document
  queries, don't offer it. A dead path is worse than no path.

- **Static claim guides pretending to be policy-specific:** if the claim
  guidance is generic templates (not read from the actual policy's claim
  section), say so. "General claim process for health insurance" not "Your
  claim process."

- **Feature promises without delivery:** "get reminders" in the renewal
  calendar when there are no reminders. Either build it or don't claim it.

- **Extracted data that's never shown:** if the system extracts benefits,
  exclusions, and waiting periods, the user must be able to see them. Hiding
  the most valuable output is a product failure.

---

## The minimum launch set (MVP+)

For a solo-founder personal-brand launch, these flows are essential:

| Flow | Essential? | Why |
|---|---|---|
| Onboarding (upload first policy → see summary) | ✅ | This is the entire value proposition |
| Document management (upload, list, delete) | ✅ | Core CRUD |
| Policy summary (benefits, exclusions, coverage) | ✅ | The "aha" moment — must display extracted data |
| Q&A (ask questions, get sourced answers) | ✅ | The interactive value |
| Emergency / claim access (offline) | ✅ | The high-stakes use case |
| Renewal tracking (list + handle unknown dates) | ✅ (without reminders) | Proactive value; reminders can come later |
| Coverage gap analysis | ✅ | Differentiator; shows the app thinks ahead |
| Family coverage view | ⚠️ (basic) | Auto-detect + manual add; family-level gaps can come later |
| Policy comparison | ⚠️ (basic) | Compare 2 selected; difference highlighting can come later |
| Settings & data management | ✅ | Must work correctly (clear = actually clear) |
| Help, privacy, legal | ✅ | Store requirement + trust |

---

## Success criteria

A user should be able to:
1. Upload a policy and within 30 seconds see what it covers and excludes
2. Ask "am I covered for X?" and get a sourced answer
3. In an emergency, open the app and instantly find the helpline and claim steps
4. Know when their policy expires without checking the document
5. See if they have coverage gaps before something goes wrong
6. Trust that the app is showing their data, not generic templates
7. Delete their data and have it actually deleted
