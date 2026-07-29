# Product First Principles

**Project:** CoverWise / `insurance_q`
**Status:** Proposed canonical product doctrine
**Prepared against:** `main` at `755df24be171b87fc1d5f66eceb25d3909d2784d`
**Date:** 2026-07-28
**Owner / next reviewer:** Pranay
**Governing doctrine:** [`motto_v4.md`](../../../motto_v4.md)
**Decision record:** [`ADR-2026-07-28-03`](../../decisions/ADR-2026-07-28-03-product-first-principles-and-boundary.md)

> This document defines the intended product shape. The code remains the current implementation truth. When code, copy, tests, architecture, or older documents conflict with these principles, the conflict must be surfaced and reconciled through an append-only decision record rather than silently ignored.

---

## 0. Why this document exists

The repository contains strong but distributed product doctrine across the README, canonical journey map, architecture, audits, launch-claim registry, and multiple ADRs. Several decisions were made at different points in the product's evolution:

- the product was widened around coverage check-ins, coverage adequacy, family organization, claim documents, and partnerships;
- the evidence and substrate work established a verifiability contract;
- later product and regulatory reviews clarified that several existing surfaces crossed from document understanding into advice, quoting, claims consultancy, or transaction facilitation;
- neutral policy-readiness and personal-claim-log decisions then narrowed some semantics without creating one upstream product constitution.

The result is individually useful documents but no single test that every feature, claim, workflow, and business model must pass.

This file is that test.

---

## 1. Canonical product statement

> **CoverWise transforms insurance policies a person already owns into a private, durable, source-verifiable body of knowledge that remains useful across everyday management, household organization, renewal awareness, and moments of urgency. It explains what the documents say, exposes what they do not establish, preserves user control over the complete data lifecycle, and never substitutes itself for the insurer, contract, broker, claims representative, underwriter, or professional adviser.**

The name may change. This product constitution survives the rename.

---

## 2. The first-principles derivation

### 2.1 The durable problem

People possess financially and legally important insurance contracts but frequently cannot:

- understand their language;
- find the clause that matters;
- know whether the app processed the complete document;
- retrieve details when stressed or offline;
- organize policies across a household;
- distinguish a documented fact from an assumption;
- verify what a model or interface claims;
- carry their information, corrections, consent, and deletion choices across the full lifecycle.

The product exists to reduce this information asymmetry.

### 2.2 What is not fundamental

The following are implementation choices, not product principles:

- Flutter;
- FastAPI;
- Supabase;
- Cloud Run;
- a particular OCR engine;
- a particular embedding model;
- RAG;
- a particular LLM;
- a particular vector store;
- a specific product name.

They may change without changing the product.

### 2.3 The irreducible product loop

```text
user-owned policy
  -> explicit purpose and consent
  -> secure import
  -> completeness-aware processing
  -> source-preserving normalization
  -> evidence and uncertainty
  -> plain-language explanation
  -> organization and retrieval
  -> user verification
  -> correction, export, replacement, retention, or deletion
```

Every major feature must strengthen this loop or be rejected as a different product.

---

## 3. Non-negotiable product principles

## Principle 1: The policy is authoritative; the model is an interpreter

The uploaded policy and its valid source artifacts are the highest authority inside the product.

A model may:

- extract;
- normalize;
- retrieve;
- summarize;
- explain;
- classify uncertainty;
- suggest a neutral question the user can ask the insurer.

A model must not:

- override policy wording with generic insurance knowledge;
- convert an absent field into a negative conclusion;
- silently fill missing values;
- fabricate premiums, coverage, limits, eligibility, claim status, or likely outcomes;
- present a generated statement as policy text.

When policy text is incomplete, conflicting, unreadable, or missing, the system must say so.

---

## Principle 2: Verifiability is the product, not a supporting feature

A fluent answer that cannot be checked is a product failure.

Every material policy-specific claim must preserve a trace to the strongest available source chain:

```text
document version
  -> page artifact
  -> source span or table cell
  -> extraction method and version
  -> raw value
  -> normalized value
  -> generated explanation
  -> customer-visible citation
```

The user must be able to inspect the source page or artifact behind a claim.

`source_text` and model-generated `retrieval_text` must remain distinct. Generated retrieval context must never become customer-visible policy evidence.

Related decisions:

- [`ADR-2026-07-19-09`](../../decisions/ADR-2026-07-19-09-evidence-backed-release-grade-definition.md)
- [`ADR-2026-07-19-11`](../../decisions/ADR-2026-07-19-11-substrate-as-primary-deliverable.md)
- [`coverwise_canonical_architecture.md`](../../architecture/coverwise_canonical_architecture.md)

---

## Principle 3: Abstention is a valid successful outcome

For high-stakes information, a false positive is worse than an explicit unknown.

The system must prefer:

- `not found in the uploaded policy`;
- `document processing is incomplete`;
- `the cited pages conflict`;
- `this value is not yet verified`;
- `the source page could not be read`;
- `please confirm this with the insurer`;

over a polished but unsupported answer.

Confidence must change behaviour, not merely change a badge colour.

A partial document must never be presented as fully processed. A failed retrieval must never silently become generic advice. An unknown value must never become zero, empty-but-successful, or a default conclusion.

---

## Principle 4: Explain and organize; do not advise, quote, sell, or transact

The governing boundary test for every surface is:

> **Does this help the user understand or organize a policy they already own, or does it perform an activity expected from an insurer, broker, intermediary, underwriter, claims consultant, or adviser?**

The first is the product. The second requires a different product, legal posture, operating model, data contract, and explicit ADR.

### In scope

- explaining what an owned policy states;
- showing cited facts, exclusions, limits, dates, contacts, and uncertainty;
- comparing owned policies dimension by dimension without a winner;
- organizing household members named in owned policies;
- tracking personal notes and documents;
- reminding the user about factual dates;
- showing insurer contact information found in the user's policy or an explicitly maintained reference dataset;
- helping the user prepare neutral questions to ask the insurer;
- showing what is not present or not verifiable in the uploaded workspace.

### Out of scope by default

- premium estimation or quoting;
- underwriting simulation;
- declaring that a person is adequately or inadequately insured;
- assigning a suitability or protection score;
- recommending a policy, insurer, rider, sum insured, or renewal decision;
- guided claim filing, claim representation, claim adjudication, or claims escalation as a CoverWise workflow;
- initiating or facilitating a renewal transaction;
- product ranking or a "best policy" verdict;
- sharing sensitive policy, medical, or household data for lead generation;
- presenting partner offers as neutral policy interpretation.

Disclaimers do not convert an out-of-scope activity into an in-scope activity. The activity is the boundary.

Related artifacts:

- [`coverwise_regulatory_scope_risk_audit_2026-07-28.md`](../../audits/coverwise_regulatory_scope_risk_audit_2026-07-28.md)
- [`ADR-2026-07-23-01`](../../decisions/ADR-2026-07-23-01-evidence-backed-policy-readiness.md)
- [`ADR-2026-07-24-02`](../../decisions/ADR-2026-07-24-02-personal-claim-log-boundary.md)

---

## Principle 5: One user principal owns one complete information graph

A policy upload creates more than a file:

```text
source object
pages and images
OCR and parsed text
normalized fields
chunks and embeddings
summaries
questions and answers
citations
family links
claim notes
notifications
analytics
billing and entitlement records
local caches
operator events
deletion work
```

These objects form one logical aggregate.

Every stored object must have:

- a canonical principal;
- a data classification;
- a purpose;
- a source;
- a processor;
- an access policy;
- a retention rule;
- an export path;
- a deletion path;
- audit evidence for privileged access or lifecycle completion.

A bearer token proves access at one moment. It does not prove ownership transfer, complete deletion, backup expiry, or derived-data cleanup.

---

## Principle 6: Consent and privacy are enforced product behaviour

Consent is not a local boolean or legal-page decoration.

Consent must be:

- purpose-specific;
- explicit;
- versioned;
- principal-associated;
- server-authoritative where remote processing occurs;
- append-only;
- withdrawable;
- enforceable;
- auditable.

A missing or corrupt record must not become consent.

Privacy copy is a launch claim. Statements such as "private", "never shared", "deleted", "stays local", or "backed up" may ship only when the operational path can prove them.

Medical and claim documents are not merely "more files". They raise the sensitivity and operator-access burden. Any expansion into medical-record storage requires its own accepted privacy boundary and complete lifecycle implementation before release.

---

## Principle 7: The feature is the end-to-end user and operator workflow

A screen is not a feature.

For every meaningful capability, the product must define:

- who triggers it;
- what they provide;
- what processing occurs;
- what state changes;
- what the user sees;
- what the operator sees;
- what happens on failure;
- what happens on retry;
- what persists locally and remotely;
- what can be audited;
- how the user corrects, exports, replaces, or deletes it;
- what public claims it enables;
- how support and recovery work.

If the user cannot understand the result, the feature is incomplete.

If the operator cannot explain or recover the state, the feature is incomplete.

If the lifecycle cannot complete durably, the feature is incomplete.

---

## Principle 8: There is one canonical path per truth

Parallel truths are unacceptable in a trust-sensitive product.

The intended canonical truths are:

| Concern | Canonical truth |
|---|---|
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

---

## Principle 9: Reliability is designed around the moment of need

The app may be opened during hospital admission, an accident, a renewal deadline, a family emergency, or a support call.

The quality question is not merely "does the screen load?"

It is:

> **Can the user retrieve the correct information under stress, poor connectivity, partial processing, stale data, device changes, and provider failures?**

This requires:

- resumable or safely retryable imports;
- truthful processing stages;
- durable retries and dead-letter recovery;
- explicit partial and terminal states;
- locally available emergency information where safe;
- stale timestamps;
- no simulated progress;
- no silent generic fallback;
- clear recovery actions.

Emergency information is extracted information, not official proof of insurance, unless an authoritative issuer-backed verification contract is added later.

---

## Principle 10: The business model must align with the trust model

Clean monetization charges for value the product itself delivers:

- document processing;
- storage;
- verified Q&A;
- policy and household capacity;
- organization;
- export;
- neutral owned-policy comparison;
- advanced retrieval and history.

The product may charge for its own software usage. It must not blur software revenue with an insurance recommendation or commission relationship.

Partnerships, referrals, or external offers are disabled by default. Any future partner path requires:

- a separate accepted ADR;
- legal and product-boundary review;
- explicit opt-in;
- purpose-specific consent;
- no default sharing of uploaded documents or derived sensitive signals;
- clear source and compensation disclosure;
- withdrawal and deletion propagation;
- launch-claim registry coverage.

An earlier ADR's exploration of a quote-aggregator partner does not itself authorize that surface for launch.

---

## Principle 11: Every public claim is an operational contract

Examples:

- "evidence-backed";
- "private";
- "verified";
- "fully processed";
- "works offline";
- "family-aware";
- "never shared";
- "permanently deleted";
- "subscription cancelled";
- "every citation can be opened."

Each claim must map to:

- exact claim text;
- implementation path;
- enforcing tests;
- runtime evidence tier;
- operator recovery path;
- release state;
- known limitations.

A claim without a registry entry does not ship. A claim whose gate is failing does not ship.

---

## Principle 12: Long-term thinking is not maximalism

`motto_v4` requires the whole right answer. It does not require preserving every feature already in the repository.

The rule is:

- if a capability belongs to the durable product shape, finish it properly;
- if it is an honest thin slice, scope it to the honest part;
- if it belongs to a different product, cut or gate it;
- do not keep it merely because code exists;
- do not cut it merely because finishing it is difficult.

The right product, completed coherently, is the target.

---

## 4. Canonical product wedge

The durable product wedge is:

```text
owned policy
  -> secure import
  -> evidence-backed policy workspace
  -> source-verifiable explanation and Q&A
  -> neutral organization across policies and household
  -> factual reminders and emergency retrieval
  -> personal notes and document lifecycle
```

The following may extend the wedge only under the allowed contracts below.

| Surface | Allowed long-term contract | Forbidden interpretation |
|---|---|---|
| Policy workspace readiness | Measures freshness, readability, extraction completeness, citations, and unresolved verification | Measures whether the person has enough insurance |
| Coverage facts | Present / not found / unverified / conflicting / expired, with citations | "You are underinsured", "buy more", or suitability scoring |
| Owned-policy comparison | Dimension-by-dimension cited differences and missing-data warnings | Overall recommendation, ranking, or "best policy" |
| Coverage check-in | Life changes, stale policy data, and questions to verify | Actuarial or financial adequacy verdict |
| Coverage adequacy | What the uploaded policy states for a user-selected scenario, plus unknowns | Premium estimates, outcome prediction, or purchase advice |
| Family coverage map | Organizes members and cited policy relationships | Declares household protection sufficiency |
| Renewal awareness | Factual dates, reminders, source document, neutral contact display | "Start renewal", recommended renewal, or transaction facilitation |
| Emergency information | Fast access to extracted policy and contact facts, with staleness and source | Issuer-backed proof unless cryptographically or contractually verified |
| Personal claim log | User-entered records, documents, references, notes, and `Recorded as ...` states | Insurer status, claim management, filing, adjudication, or representation |
| Claim document vault | Private organization of user-provided documents with complete lifecycle controls | Claims consultancy or default medical-record expansion |
| Insurance glossary | Contextual definitions while viewing the user's own policy | Generic quiz as an authoritative advisory surface |
| External resources | Clearly external, source-labelled, user-initiated information | Hidden referral, lead routing, or implied CoverWise recommendation |

---

## 5. Current surface decisions derived from these principles

These are doctrine-level classifications. Actual code changes require the ADR's implementation sequence and a fresh current-head audit.

### Keep and finish

- secure upload and durable processing;
- evidence-backed policy detail;
- source-page opening and citation verification;
- grounded policy Q&A with calibrated abstention;
- policy search and organization;
- neutral comparison of owned policies;
- policy workspace readiness;
- passive renewal reminders;
- emergency information access with honest labels;
- personal claim log;
- account, consent, export, replacement, and complete deletion;
- transparent server-enforced billing and entitlements for CoverWise usage.

### Keep but constrain or redesign

- coverage check-in;
- coverage adequacy;
- family coverage map;
- claim document vault;
- contextual glossary;
- insurer contact display;
- external-resource links.

These surfaces must use the contracts in Section 4 and may not inherit the broader semantics suggested by their names.

### Gate or remove in current form

- fabricated What-If Premium calculator;
- coverage or protection suitability scores;
- claim assistance and claim guide workflows that structure filing or escalation;
- "Start renewal" or transaction-oriented renewal CTAs;
- generic in-app insurance quiz;
- partner quote aggregation or sensitive-data-driven lead generation without a separate accepted boundary decision.

---

## 6. Product decision test

Every new or existing feature must answer all of these questions.

1. What real user trigger does it serve?
2. Does it strengthen the canonical product wedge?
3. Is it grounded in a policy the user owns or information the user explicitly entered?
4. Can every material policy-specific claim be traced to a current source?
5. Does it explain or organize rather than advise, quote, rank, sell, represent, or transact?
6. What happens when evidence is absent, conflicting, incomplete, or stale?
7. Which principal owns every source and derived object?
8. What purpose and consent permit each processing step?
9. How is the data corrected, exported, retained, replaced, and deleted?
10. Does it use one canonical backend and data path?
11. How does failure, retry, idempotency, and operator recovery work?
12. Which public claims does it enable, and where are their gates?
13. What user, business/team, and internal/operational value does it deliver?
14. Anything else?

A feature that fails Questions 2, 3, or 5 is probably a different product.

A feature that passes the product test but fails Questions 4 or 6 through 12 belongs in the product but is not finished.

---

## 7. Architecture consequences

These principles require the architecture to preserve:

1. one principal and ownership graph;
2. immutable source artifacts;
3. separate source and generated retrieval text;
4. versioned extraction and model lineage;
5. explicit partial and failed states;
6. verified citations and answer classification;
7. durable outbox-backed work;
8. purpose-specific consent enforcement;
9. server-enforced entitlements;
10. auditable operator access;
11. complete deletion propagation;
12. launch claims tied to evidence.

A model upgrade cannot repair missing provenance.

A stronger prompt cannot repair an incomplete lifecycle.

A polished interface cannot repair a false product boundary.

---

## 8. Metrics that follow from the principles

Primary product quality metrics should measure trusted task completion, not manufactured engagement.

### User-value metrics

- policy import completion rate;
- time from import to first verifiable fact;
- percentage of visible material fields with resolvable citations;
- grounded Q&A fully-backed rate;
- abstention correctness;
- source-page open success;
- policy retrieval success during emergency or renewal flows;
- correction and replacement completion;
- export and deletion completion.

### Trust and safety metrics

- partial documents incorrectly marked complete;
- unsupported claim display rate;
- citation verification failure rate;
- cross-principal access failures;
- consent enforcement failures;
- lifecycle orphan rate;
- deletion partial-failure rate;
- sensitive telemetry rejection rate;
- out-of-bound copy or feature regression count.

### Operational metrics

- processing-stage latency and failure distribution;
- retry and dead-letter volume;
- model/provider fallback use;
- cost per processed policy and verified answer;
- operator recovery time;
- support access reason and audit completeness;
- entitlement reconciliation lag.

Retention, daily opens, and session length are secondary. A policy product can be valuable precisely because it works reliably when needed and does not manufacture reasons to open it.

---

## 9. Anti-principles

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

## 10. Decision precedence and conflict handling

This document is the upstream product doctrine once accepted.

It does not erase historical decisions. Per `motto_v4`, prior ADRs remain intact and their reasoning stays visible.

When this doctrine conflicts with an earlier product-scope decision:

1. preserve the earlier ADR;
2. append or create a superseding ADR;
3. cite the exact conflicting clause;
4. state the new governing interpretation;
5. re-derive dependent feature, copy, privacy, architecture, and launch decisions;
6. do not silently implement whichever document is convenient.

This document does not supersede technical contracts that remain aligned, including the evidence-backed four-face contract, substrate visibility, canonical principal model, outbox, consent ledger, operator trust model, or launch-claim registry.

---

## 11. Source artifacts

This doctrine was derived from the current repository, particularly:

- [`README.md`](../../../README.md)
- [`motto_v4.md`](../../../motto_v4.md)
- [`coverwise_user_journey_map.md`](../../user_experience/coverwise_user_journey_map.md)
- [`coverwise_canonical_architecture.md`](../../architecture/coverwise_canonical_architecture.md)
- [`coverwise_document_intelligence_trust_audit_2026-07-18.md`](../../audits/coverwise_document_intelligence_trust_audit_2026-07-18.md)
- [`coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md`](../../audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md)
- [`coverwise_regulatory_scope_risk_audit_2026-07-28.md`](../../audits/coverwise_regulatory_scope_risk_audit_2026-07-28.md)
- [`ADR-2026-07-19-08`](../../decisions/ADR-2026-07-19-08-cut-keep-finish-half-built-features.md)
- [`ADR-2026-07-19-09`](../../decisions/ADR-2026-07-19-09-evidence-backed-release-grade-definition.md)
- [`ADR-2026-07-19-11`](../../decisions/ADR-2026-07-19-11-substrate-as-primary-deliverable.md)
- [`ADR-2026-07-19-13`](../../decisions/ADR-2026-07-19-13-what-if-premium-refused-as-product-capability.md)
- [`ADR-2026-07-23-01`](../../decisions/ADR-2026-07-23-01-evidence-backed-policy-readiness.md)
- [`ADR-2026-07-24-02`](../../decisions/ADR-2026-07-24-02-personal-claim-log-boundary.md)

---

## 12. Update log

- **2026-07-28, original proposal:** Consolidated the product's durable problem, evidence contract, regulatory boundary, lifecycle requirements, and surface-level decisions into one proposed canonical doctrine. Prepared against `main` commit `755df24be171b87fc1d5f66eceb25d3909d2784d`. Status: Proposed, awaiting operator sign-off and repository integration.

---

## 13. Anything else?

Yes.

The principles must become a working gate, not another descriptive document. Once accepted, the repository should:

- link this file from the README, canonical architecture, user journey map, and decision index;
- classify every reachable mobile surface against Section 4;
- reconcile contradictory product ADRs through append-only updates;
- gate current out-of-bound surfaces before making launch-readiness claims;
- add regression tests for forbidden semantics and routes;
- register every public trust claim;
- rerun the core journey against representative policies and deployed infrastructure.

Without those steps, the repository will contain the right doctrine while the product can still behave differently.
