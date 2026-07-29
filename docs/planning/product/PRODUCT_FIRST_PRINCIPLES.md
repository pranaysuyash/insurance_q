# CoverWise Product First Principles — the Constitution

**Status:** Proposed, awaiting operator sign-off on [ADR-2026-07-29-02](../../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
**Date:** 2026-07-29
**Layer:** Product constitution (top of the doctrine stack beneath `motto_v4.md`)
**Prepared against:** `main` at `755df24be171b87fc1d5f66eceb25d3909d2784d`
**Owner / next reviewer:** Pranay
**Evidence tier:** Decision-grade product reasoning informed by repository review; not yet validated by representative user research or production behaviour. (Aligns with Tier 0 in [`docs/launch_claims/README.md`](../../launch_claims/README.md).)

> This document defines the intended product shape. The code remains the current implementation truth. When code, copy, tests, architecture, or older documents conflict with these principles, the conflict must be surfaced and reconciled through an append-only decision record rather than silently ignored.

---

## 0. Where this document sits in the doctrine stack

```text
motto_v4.md                                  (operating rules; always top)
  └─ THIS DOCUMENT — Product constitution
      └─ docs/architecture/FIRST_PRINCIPLES_WEDGE.md        (strategy & current wedge)
          └─ docs/architecture/FREE_VS_PAID_BOUNDARY.md      (commercial & packaging)
              └─ Feature ADRs (docs/decisions/ADR-*)
                  └─ Architecture, code, tests, ops, launch claims
```

A lower layer may not contradict this constitution. Downward links:

- Strategy and current wedge: [`FIRST_PRINCIPLES_WEDGE.md`](../../architecture/FIRST_PRINCIPLES_WEDGE.md)
- Commercial boundary: [`FREE_VS_PAID_BOUNDARY.md`](../../architecture/FREE_VS_PAID_BOUNDARY.md)
- Reconciliation ADR: [`ADR-2026-07-29-02`](../../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md)

---

## 1. Canonical product statement

> CoverWise is a private, source-verifiable personal insurance knowledge workspace that helps people understand and organise policies they already own. It reports what the uploaded policy workspace establishes, what it does not establish, and where each material fact comes from. It does not recommend, quote, underwrite, broker, transact, or represent claims.

Important distinctions:

- The insurance policy is the **authoritative source**.
- CoverWise is the **interpretation and organisation workspace**, not the legal source of truth.
- CoverWise knows only what the user has uploaded, what was successfully processed, and what remains current and verifiable.
- **Missing information must remain missing or unknown.** It must not become a negative conclusion.

The durable user outcome is **comprehension** — understanding and organising policies a person already owns.

The name may change. This constitution survives the rename.

---

## 2. The irreducible product loop

```text
user-owned policy
  -> explicit purpose and consent
  -> secure import
  -> completeness-aware processing
  -> source-preserving normalisation
  -> evidence and uncertainty
  -> plain-language explanation
  -> organisation and retrieval
  -> user verification
  -> correction, export, replacement, retention, or deletion
```

Every major feature must strengthen this loop or be rejected as a different product.

What is **not** fundamental (implementation choices, not principles): Flutter, FastAPI, Supabase, Cloud Run, a particular OCR engine, a particular embedding model, RAG, a particular LLM, a particular vector store, a specific product name. They may change without changing the product.

---

## 3. The decision-gate stack

Every feature and engineering decision must pass **all applicable gates**. (Replaces the Wedge's single question, which rejected necessary infrastructure and could permit advisory features.)

### Gate A — Outcome

Does this materially reduce the effort, time, or uncertainty required to understand or organise user-owned insurance policies?

For infrastructure, ask: is this necessary to deliver that outcome **safely, privately, reliably, recoverably, or sustainably**?

### Gate B — Truth

Can every material policy-specific statement be grounded in **current owned-source evidence**?

Does the feature explicitly handle: found · not found · unverified · incomplete · stale · conflicting · unsupported · abstained?

**Hard rule:** "not found in the uploaded policy" must never silently become "not covered." Absence of extraction is not absence of coverage.

### Gate C — Product role

Does the activity remain within: **explanation · evidence · organisation · retrieval · reminders · user-authored recordkeeping**?

Reject by default when the activity becomes: recommendation · suitability or adequacy judgement · premium quoting or underwriting · insurer or product ranking · purchase, switching, or renewal facilitation · claim filing, representation, adjudication, or insurer-status assertion · sensitive-data-driven lead generation.

### Gate D — Lifecycle and operations

Are these defined and enforceable: canonical principal · consent and purpose · access · retention · correction · export · replacement · deletion · failure · retry · idempotency · observability · operator recovery · public launch claims?

### Gate E — Strategy and commercial fit

Is the feature inside the current wedge? Is the free or paid treatment **separately decided** without contradicting this constitution?

---

## 4. Non-negotiable product principles

### Principle 1 — The policy is authoritative; the model is an interpreter

The uploaded policy and its valid source artifacts are the highest authority inside the product.

A model may: extract, normalise, retrieve, summarise, explain, classify uncertainty, suggest a neutral question the user can ask the insurer.

A model must not: override policy wording with generic insurance knowledge · convert an absent field into a negative conclusion · silently fill missing values · fabricate premiums, coverage, limits, eligibility, claim status, or likely outcomes · present a generated statement as policy text.

When policy text is incomplete, conflicting, unreadable, or missing, the system must say so.

### Principle 2 — Verifiability is the product, not a supporting feature

Every material policy-specific claim must preserve a trace to the strongest available source chain:

```text
document version -> page artifact -> source span or table cell
  -> extraction method and version -> raw value -> normalised value
  -> generated explanation -> customer-visible citation
```

The user must be able to inspect the source page or artifact behind a claim. `source_text` and model-generated `retrieval_text` must remain distinct. Generated retrieval context must never become customer-visible policy evidence.

### Principle 3 — Abstention is a valid successful outcome

For high-stakes information, a false positive is worse than an explicit unknown. The system must prefer "not found in the uploaded policy", "document processing is incomplete", "the cited pages conflict", "this value is not yet verified", "the source page could not be read", "please confirm this with the insurer" over a polished but unsupported answer.

Confidence must change behaviour, not merely change a badge colour. A partial document must never be presented as fully processed. A failed retrieval must never silently become generic advice. An unknown value must never become zero, empty-but-successful, or a default conclusion.

### Principle 4 — Explain and organise; do not advise, quote, sell, or transact

The governing boundary test for every surface (Gate C):

> Does this help the user understand or organise a policy they already own, or does it perform an activity expected from an insurer, broker, intermediary, underwriter, claims consultant, or adviser?

The first is the product. The second requires a different product, legal posture, operating model, data contract, and explicit ADR.

**In scope:** explaining what an owned policy states · showing cited facts, exclusions, limits, dates, contacts, and uncertainty · **neutral, source-cited, dimension-by-dimension comparison of owned policies without a winner** · organising household members named in owned policies · tracking personal notes and documents · reminding the user about factual dates · showing insurer contact information found in the user's policy or a maintained reference dataset · helping the user prepare neutral questions to ask the insurer · showing what is not present or not verifiable.

**Out of scope by default:** premium estimation or quoting · underwriting simulation · declaring a person adequately or inadequately insured · assigning a suitability or protection score · recommending a policy, insurer, rider, sum insured, or renewal decision · guided claim filing, claim representation, claim adjudication, or claims escalation as a CoverWise workflow · initiating or facilitating a renewal transaction · product ranking or a "best policy" verdict · sharing sensitive policy, medical, or household data for lead generation · presenting partner offers as neutral policy interpretation.

Disclaimers do not convert an out-of-scope activity into an in-scope activity. **The activity is the boundary.**

### Principle 5 — One user principal owns one complete information graph

A policy upload creates source objects, pages, OCR/parsed text, normalised fields, chunks/embeddings, summaries, Q&A, citations, family links, claim notes, notifications, analytics, billing/entitlement records, local caches, operator events, and deletion work. These form one logical aggregate.

Every stored object must have: a canonical principal · a data classification · a purpose · a source · a processor · an access policy · a retention rule · an export path · a deletion path · audit evidence for privileged access or lifecycle completion.

A bearer token proves access at one moment. It does not prove ownership transfer, complete deletion, backup expiry, or derived-data cleanup.

### Principle 6 — Consent and privacy are enforced product behaviour

Consent is not a local boolean or legal-page decoration. Consent must be: purpose-specific · explicit · versioned · principal-associated · server-authoritative where remote processing occurs · append-only · withdrawable · enforceable · auditable. A missing or corrupt record must not become consent.

Privacy copy is a launch claim. Statements such as "private", "never shared", "deleted", "stays local", or "backed up" may ship only when the operational path can prove them. Medical and claim documents raise the sensitivity and operator-access burden. Any expansion into medical-record storage requires its own accepted privacy boundary and complete lifecycle implementation before release.

### Principle 7 — The feature is the end-to-end user and operator workflow

A screen is not a feature. For every meaningful capability, the product must define: who triggers it · what they provide · what processing occurs · what state changes · what the user sees · what the operator sees · what happens on failure · what happens on retry · what persists locally and remotely · what can be audited · how the user corrects, exports, replaces, or deletes it · what public claims it enables · how support and recovery work.

If the user cannot understand the result, the feature is incomplete. If the operator cannot explain or recover the state, the feature is incomplete. If the lifecycle cannot complete durably, the feature is incomplete.

### Principle 8 — There is one canonical path per truth

Parallel truths are unacceptable in a trust-sensitive product. The intended canonical truths:

| Concern | Canonical truth |
|---------|-----------------|
| Original policy document | Private object storage with principal ownership |
| Document lifecycle | Backend document state machine and append-only processing events |
| Policy-specific claims | Evidence substrate |
| Customer-visible citation | Immutable source text and resolvable page artifact |
| Durable asynchronous work | Outbox |
| Identity | Canonical anonymous or account principal plus explicit migration |
| Consent | Server-side append-only consent ledger |
| Entitlement | Server-side entitlement ledger reconciled with the store provider |
| Local sensitive data | Principal-scoped encrypted storage |
| Operator access | Role-scoped, reason-required, audited access |
| Deletion | Durable deletion workflow with completion evidence |
| Public product claims | Launch-claim registry backed by tests and runtime evidence |

The product must not retain legacy routes, shadow pipelines, simulated frontend state, or client-side truth sources that can disagree with these contracts.

### Principle 9 — Reliability is designed around the moment of need

The app may be opened during hospital admission, an accident, a renewal deadline, a family emergency, or a support call. The quality question is not merely "does the screen load?" It is: can the user retrieve the correct information under stress, poor connectivity, partial processing, stale data, device changes, and provider failures?

This requires: resumable or safely retryable imports · truthful processing stages · durable retries and dead-letter recovery · explicit partial and terminal states · locally available emergency information where safe · stale timestamps · no simulated progress · no silent generic fallback · clear recovery actions.

Emergency information is extracted information, not official proof of insurance, unless an authoritative issuer-backed verification contract is added later.

### Principle 10 — The business model must align with the trust model

Clean monetization charges for value the product itself delivers: document processing · storage · verified Q&A · policy and household capacity · organisation · export · neutral owned-policy comparison · advanced retrieval and history.

The product may charge for its own software usage. It must not blur software revenue with an insurance recommendation or commission relationship. Partnerships, referrals, or external offers are **disabled by default**. Any future partner path requires: a separate accepted ADR · legal and product-boundary review · explicit opt-in · purpose-specific consent · no default sharing of uploaded documents or derived sensitive signals · clear source and compensation disclosure · withdrawal and deletion propagation · launch-claim registry coverage.

The durable commercial principle (exact limits/prices live in the commercial layer, not here):

> A user must receive enough source-verifiable comprehension to understand the product's value without paying. Paid tiers may charge for higher usage, capacity, convenience, household collaboration, storage, processing priority and advanced workflows. Essential safety information and the truth of an already processed policy must not become inaccessible solely because a subscription expires.

### Principle 11 — Every public claim is an operational contract

Examples: "evidence-backed", "private", "verified", "fully processed", "works offline", "family-aware", "never shared", "permanently deleted", "subscription cancelled", "every citation can be opened."

Each claim must map to: exact claim text · implementation path · enforcing tests · runtime evidence tier · operator recovery path · release state · known limitations. A claim without a registry entry does not ship. A claim whose gate is failing does not ship.

### Principle 12 — Long-term thinking is not maximalism

If a capability belongs to the durable product shape, finish it properly. If it is an honest thin slice, scope it to the honest part. If it belongs to a different product, cut or gate it. Do not keep it merely because code exists. Do not cut it merely because finishing it is difficult.

---

## 5. Canonical product wedge

The durable product wedge is:

```text
owned policy
  -> secure import
  -> evidence-backed policy workspace
  -> source-verifiable explanation and Q&A
  -> neutral organisation across policies and household
  -> factual reminders and emergency retrieval
  -> personal notes and document lifecycle
```

The following surfaces may extend the wedge only under the allowed contracts below.

| Surface | Allowed long-term contract | Forbidden interpretation |
|---------|---------------------------|--------------------------|
| Policy workspace readiness | Measures freshness, readability, extraction completeness, citations, unresolved verification | Measures whether the person has enough insurance |
| Coverage facts | Present / not found / unverified / conflicting / expired, with citations | "You are underinsured", "buy more", or suitability scoring |
| Owned-policy comparison | **Dimension-by-dimension cited differences and missing-data warnings** | Overall recommendation, ranking, or "best policy" |
| Coverage check-in | Life changes, stale policy data, and questions to verify | Actuarial or financial adequacy verdict |
| Coverage adequacy | What the uploaded policy states for a user-selected scenario, plus unknowns | Premium estimates, outcome prediction, or purchase advice |
| Family coverage map | Organises members and cited policy relationships | Declares household protection sufficiency |
| Renewal awareness | Factual dates, reminders, source document, neutral contact display | "Start renewal", recommended renewal, or transaction facilitation |
| Emergency information | Fast access to extracted policy and contact facts, with staleness and source | Issuer-backed proof unless cryptographically or contractually verified |
| Personal claim log | User-entered records, documents, references, notes, and `Recorded as ...` states | Insurer status, claim management, filing, adjudication, or representation |
| Claim document vault | Private organisation of user-provided documents with complete lifecycle controls | Claims consultancy or default medical-record expansion |
| Insurance glossary | Contextual definitions while viewing the user's own policy | Generic quiz as an authoritative advisory surface |
| External resources | Clearly external, source-labelled, user-initiated information | Hidden referral, lead routing, or implied CoverWise recommendation |

---

## 6. Product decision test

Every new or existing feature must answer:

1. What real user trigger does it serve?
2. Does it strengthen the canonical product wedge?
3. Is it grounded in a policy the user owns or information the user explicitly entered?
4. Can every material policy-specific claim be traced to a current source?
5. Does it explain or organise rather than advise, quote, rank, sell, represent, or transact?
6. What happens when evidence is absent, conflicting, incomplete, or stale?
7. Which principal owns every source and derived object?
8. What purpose and consent permit each processing step?
9. How is the data corrected, exported, retained, replaced, and deleted?
10. Does it use one canonical backend and data path?
11. How do failure, retry, idempotency, and operator recovery work?
12. Which public claims does it enable, and where are their gates?
13. What user, business/team, and internal/operational value does it deliver?

A feature that fails 2, 3, or 5 is probably a different product. A feature that passes the product test but fails 4 or 6–12 belongs in the product but is not finished.

---

## 7. Anti-principles

The product must reject these recurring failure modes:

- "The model is probably right."
- "A disclaimer makes the activity safe."
- "Not found means not covered."
- "The UI shows progress, so progress exists."
- "The client says the user is paid, so entitlement is paid."
- "HTTP 200 means deletion completed."
- "The partner handles it, so our responsibility ends."
- "The feature already exists, so it belongs."
- "The feature is expensive, so it does not belong."
- "More engagement means more value."
- "The source is internal; the user does not need to see it."
- "Generic insurance knowledge is close enough to the contract."
- "A test passed, therefore the public claim is proven in production."

---

## 8. Decision precedence and conflict handling

This constitution is the upstream product doctrine once accepted via [ADR-2026-07-29-02](../../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md). It does not erase historical decisions. Per `motto_v4`, prior ADRs remain intact and their reasoning stays visible.

When this doctrine conflicts with an earlier product-scope decision: preserve the earlier ADR · append or create a superseding ADR · cite the exact conflicting clause · state the new governing interpretation · re-derive dependent feature, copy, privacy, architecture, and launch decisions · **do not silently implement whichever document is convenient**.

This document does not supersede technical contracts that remain aligned, including the evidence-backed four-face contract, substrate visibility, canonical principal model, outbox, consent ledger, operator trust model, or launch-claim registry.

---

## 9. Source artifacts

This constitution was derived from the current repository, particularly: `README.md`, `motto_v4.md`, `coverwise_user_journey_map.md`, `coverwise_canonical_architecture.md`, the trust/security/regulatory audits, and ADRs 2026-07-19-08/09/11/13, 2026-07-23-01, 2026-07-24-02. It unifies the previously separate `PRODUCT_FIRST_PRINCIPLES.md` (bundle) and `FIRST_PRINCIPLES_WEDGE.md` per [ADR-2026-07-29-02](../../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md).

---

## 10. Update log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-28 | Original proposal (bundle version): consolidated product durable problem, evidence contract, regulatory boundary, lifecycle requirements, surface decisions into one proposed canonical doctrine. | ADR-2026-07-28-03 (Proposed). |
| 2026-07-29 | Revised into layered-doctrine constitution per ADR-2026-07-29-02. Added comprehension as durable outcome, the five-gate stack (Gates A–E), explicit owned-policy comparison permission (Principle 4 + wedge table), durable commercial principle without exact prices. Removed exact pricing, exact UX ordering, and temporary strategy decisions (moved to Wedge/Commercial layers). Linked down to Wedge and Commercial. Status: Proposed, awaiting sign-off on ADR-2026-07-29-02. | Operator direction: layered doctrine stack with constitution on top. |

---

## 11. Anything else?

Yes. The principles must become a working gate, not another descriptive document. Once the constitution is accepted (via ADR-2026-07-29-02 sign-off), the repository should: link this file from README, canonical architecture, user journey map, and decision index · classify every reachable mobile surface against the wedge table · reconcile contradictory product ADRs through append-only updates · gate current out-of-bound surfaces before making launch-readiness claims · add regression tests for forbidden semantics and routes · register every public trust claim · rerun the core journey against representative policies and deployed infrastructure. Without those steps, the repository will contain the right doctrine while the product can still behave differently.
