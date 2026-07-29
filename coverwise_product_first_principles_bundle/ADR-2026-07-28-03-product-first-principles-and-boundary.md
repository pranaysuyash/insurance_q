# ADR-2026-07-28-03: Canonical product first principles and document-understanding boundary

**Status:** Proposed, awaiting operator sign-off
**Date:** 2026-07-28
**Owner / next reviewer:** Pranay
**Prepared against:** `main` at `755df24be171b87fc1d5f66eceb25d3909d2784d`
**Governing doctrine:** [`motto_v4.md`](../../motto_v4.md)
**Canonical product artifact proposed by this ADR:** [`PRODUCT_FIRST_PRINCIPLES.md`](../planning/product/PRODUCT_FIRST_PRINCIPLES.md)

---

## Decision

Adopt `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` as the canonical upstream product doctrine for CoverWise.

The product is a private, source-verifiable system for understanding and organizing insurance policies a person already owns. It may explain, cite, compare owned documents neutrally, organize household information, remind, and preserve personal records. It does not, by default, advise, quote, underwrite, rank, sell, transact, represent claims, or operate as insurer/broker/claims-consultant infrastructure.

Every existing or future surface must pass one governing boundary test:

> **Does this help the user understand or organize a policy they already own, or does it perform an activity expected from an insurer, broker, intermediary, underwriter, claims consultant, or adviser?**

The first is in scope. The second requires a separate product-boundary decision, legal and operating review, and an accepted ADR before implementation or release.

This ADR supersedes only the conflicting product-scope portions of earlier decisions. It does not erase them. Their original reasoning and update logs remain intact.

---

## Update log

- **2026-07-28, original proposal:** Proposed one canonical product constitution and a single boundary test after reconciling the July 19 widened wedge, the evidence and lifecycle contracts, the July 23 neutral policy-readiness decision, the July 24 personal-claim-log boundary, and the July 28 regulatory-scope audit. Status: Proposed, awaiting operator sign-off.
- **2026-07-29, superseded in part by [ADR-2026-07-29-02](../../docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md):** This Proposed ADR's product-boundary test and canonical doctrine are adopted and subsumed into the layered doctrine stack. The canonical product statement and constitution now live at `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` (revised). This ADR's original Proposed status is unchanged (no sign-off evidence was ever recorded). The conflict-resolution clauses of ADR-2026-07-29-02 §4 govern where they overlap with this ADR. Original reasoning preserved above.

---

## Context

The repository currently contains several layers of product intent:

1. The README defines the core promise as helping people understand policies they already own.
2. The canonical journey map defines the durable loop as secure import, processing, evidence, explanation, organization, reminders, and preparation.
3. The trust architecture makes source-verifiable evidence the truth layer for every claim-shaped surface.
4. `ADR-2026-07-19-08` widened the wedge to include Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault, billing, and partnerships.
5. `ADR-2026-07-19-13` correctly refuses fabricated premium answers but still explores insurer and partner paths.
6. `ADR-2026-07-23-01` narrows the readiness and coverage surfaces to neutral evidence states.
7. `ADR-2026-07-24-02` narrows claims to a personal log rather than an insurer workflow.
8. The 2026-07-28 regulatory-scope audit finds that current What-If, claim-guidance, and renewal-transaction surfaces still cross the intended document-understanding boundary.

These documents are not all wrong. They were written at different stages and answer different questions. The problem is that there is no canonical upstream product constitution that determines which interpretation wins when they conflict.

Under `motto_v4`:

- product-shape decisions are load-bearing and ADR-first;
- decision history is append-only;
- cut/keep/finish must be anchored to the long-term product shape;
- long-term thinking does not mean uncontrolled scope;
- public claims require operational proof.

A canonical product doctrine is therefore required before further feature and launch decisions.

---

## Decision scope

This ADR decides:

- the durable product role;
- the governing product-boundary test;
- the precedence of the product-first-principles document;
- how existing widened-wedge surfaces are constrained;
- which conflicting portions of earlier product decisions are superseded;
- the required repository reconciliation sequence.

This ADR does not decide:

- whether the current product name remains CoverWise;
- legal compliance or licensing as a matter of law;
- a future regulated-insurance business model;
- a specific OCR, model, vector database, cloud, or billing provider;
- implementation details beyond the dependency and acceptance contracts below.

---

## Options considered

### Option A: Keep the current distributed doctrine

Continue using the README, journey map, audits, and individual ADRs without one upstream product constitution.

**Rejected.**

This preserves ambiguity. A future engineer can cite the widened wedge to justify a claim-assistance or partner surface, while another can cite the regulatory audit to remove it. Both appear repo-grounded. The conflict will be repeatedly rediscovered.

### Option B: Narrow only the first public release

Gate the obvious launch-risk surfaces but preserve the broad long-term product as currently described.

**Rejected as insufficient.**

Launch gating is necessary but does not answer whether the capabilities belong in the long-term product. Without an upstream doctrine, the same surfaces return after launch under stronger disclaimers or new names.

### Option C: Adopt a canonical product constitution and re-derive all surfaces

Define the durable user problem, trust hierarchy, product boundary, lifecycle contract, business-model boundary, and feature decision test in one canonical document. Preserve older ADRs as history but supersede conflicting clauses through this ADR and append-only updates.

**Chosen.**

This creates one durable product shape without discarding useful historical reasoning.

### Option D: Expand into an insurance adviser, broker, quote, and claims platform

Treat the current boundary crossings as intended strategic expansion.

**Rejected for the current product.**

This is a different company and operating model. It would require licensing and legal analysis, insurer or broker relationships, authoritative transaction and claims integrations, expanded data governance, different support obligations, and new trust contracts. It cannot be introduced by feature creep or disclaimers.

---

## Chosen path

Adopt Option C.

The canonical doctrine is:

```text
owned policy
  -> secure import
  -> evidence-backed policy workspace
  -> source-verifiable explanation and Q&A
  -> neutral organization across policies and household
  -> factual reminders and emergency retrieval
  -> personal notes and complete document lifecycle
```

Extensions remain possible, but their allowed contracts are constrained:

| Surface | Governing interpretation |
|---|---|
| Policy readiness | Workspace quality, freshness, extraction, citations, unresolved verification; not protection adequacy |
| Coverage facts | Present / not found / unverified / conflicting / expired; not purchase advice |
| Coverage check-in | Life changes and questions to verify; not suitability scoring |
| Coverage adequacy | Cited policy facts for a scenario; not outcome prediction or premium estimation |
| Family coverage map | Organizes cited member-policy relationships; not household sufficiency |
| Renewal awareness | Dates and reminders; not renewal initiation |
| Emergency card | Extracted information with staleness and source; not official proof |
| Claim log and vault | User-entered notes and document organization; not claim filing, representation, or insurer status |
| Glossary | Contextual explanation tied to the user's policy; generic quiz is outside the core app |
| Partnerships | Disabled by default; separate accepted ADR and explicit consent required before any referral or offer surface |

---

## Supersession and preservation map

### Preserved and strengthened

This ADR preserves:

- `ADR-2026-07-19-09`: evidence-backed four-face contract;
- `ADR-2026-07-19-10`: outbox-only durable work;
- `ADR-2026-07-19-11`: substrate as primary deliverable;
- `ADR-2026-07-19-12`: operator trust model;
- `ADR-2026-07-19-13`: no fabricated premium number;
- `ADR-2026-07-23-01`: neutral evidence-backed policy readiness;
- `ADR-2026-07-24-02`: personal claim log, not insurer workflow;
- principal ownership, consent, privacy, deletion, evidence, and launch-claim contracts.

### Superseded where conflicting

This ADR supersedes the following only where they imply a broader activity than the canonical boundary:

1. **`ADR-2026-07-19-08` revision 2**
   - Its widened wedge remains an exploration inventory.
   - Coverage Check-in, Coverage Adequacy, Family Coverage Map, and Claim Document Vault remain possible only under the constrained contracts in this ADR.
   - The partnership framework is not enabled for launch by its inclusion in the wedge.
   - A feature is not retained merely because revision 2 classified it as keep or finish.

2. **`ADR-2026-07-19-13` partner option**
   - The no-fabricated-premium decision remains accepted.
   - Insurer calculator and "ask the insurer" resource paths require neutral, external-source framing and product-boundary review.
   - A quote-aggregator partnership is not authorized for launch by the earlier ADR. It requires a new accepted ADR covering regulatory role, compensation, consent, disclosures, data flow, withdrawal, deletion, and legal review.

3. **Substrate-extension and privacy ADRs for widened surfaces**
   - They remain valid technical and privacy designs if the corresponding surface survives the product-boundary test.
   - They do not independently prove that the surface belongs in the product.
   - Product inclusion precedes substrate extension, not the reverse.

No historical ADR is deleted or rewritten. Follow-up changes append dated update-log entries pointing to this ADR.

---

## Immediate product consequences

Subject to a fresh current-head code audit before implementation:

### Gate or remove in current form

- What-If Premium calculator and all generated premium figures;
- claims assistance and claim guide workflows that structure filing or escalation;
- renewal CTAs that initiate or facilitate a renewal transaction;
- generic insurance quiz inside the core product;
- partner quote aggregation and sensitive-data-driven lead generation.

### Preserve

- policy upload, processing, evidence summary, citations, source pages, grounded Q&A;
- neutral policy workspace readiness;
- factual coverage states and owned-policy comparison;
- passive renewal reminders;
- emergency information with honest labels;
- personal claim log;
- secure lifecycle, consent, export, replacement, and deletion;
- server-enforced billing for CoverWise software usage.

### Redesign before public use

- Coverage Check-in;
- Coverage Adequacy;
- Family Coverage Map;
- Claim Document Vault;
- insurer contact and external-resource surfaces;
- contextual insurance definitions.

---

## Why this path

### 1. It is derived from the durable user problem

The user has a contract they cannot reliably understand or retrieve. The product solves that problem without requiring the company to become an insurer or intermediary.

### 2. It makes the evidence architecture commercially meaningful

The substrate is not engineering ceremony. It is the differentiator: the product is useful because the user can verify what it says.

### 3. It resolves the widened-wedge contradiction without throwing away useful work

Family organization, scenario questions, readiness, documents, and reminders can remain valuable. Their semantics change from advice and adequacy to evidence, organization, unknowns, and neutral preparation.

### 4. It prevents disclaimer-driven scope creep

The product boundary is based on activity, not labels. A stronger disclaimer cannot rescue premium quoting, claims consultancy, or transaction facilitation.

### 5. It aligns monetization with trust

The product can charge for processing, verified answers, storage, organization, and software capacity without monetizing sensitive policy-derived leads or recommendations.

### 6. It is `motto_v4` aligned

It chooses the whole right product, not the smallest launch patch and not the widest possible app. It preserves decision history, uses ADR-first governance, and re-derives cut/keep/finish from one durable shape.

---

## Tradeoffs

- Some existing code and polished UI will be gated or removed.
- The product may appear narrower in feature count.
- Engagement may fall if users were interacting with inaccurate or out-of-bound surfaces.
- Neutral wording can feel less decisive than advice.
- The product must invest more in evidence, lifecycle, and failure-state quality than competitors that rely on generic AI answers.
- Partnerships and quote paths become slower to introduce because they require separate decisions and operational proof.
- The doctrine creates documentation and regression-test work across the repository.

These are accepted costs. Feature breadth that weakens trust or changes the regulated role is negative leverage.

---

## Assumptions

- The founder's intended role remains a non-regulated policy-information product.
- The product does not currently have authoritative insurer transaction, underwriting, or claim-status integrations.
- The user-owned policy remains the primary source of policy-specific truth.
- The evidence substrate and source-verification direction remain strategic.
- The product may be renamed without changing this doctrine.
- External legal review remains appropriate before enabling any boundary-adjacent capability.
- A fresh code and route audit will be run before implementation because parallel work may have changed current head.

---

## Risks

### Risk 1: The doctrine is accepted but not enforced

**Mitigation:** link it from canonical docs, classify every route, add forbidden-semantics tests, and connect public claims to the launch-claim registry.

### Risk 2: Useful surfaces are over-cut

**Mitigation:** use the allowed-contract table. Preserve workflow value while removing unsupported conclusions.

### Risk 3: Boundary language becomes vague

**Mitigation:** test activities, not labels. Ask whether the feature quotes, recommends, represents, ranks, or facilitates a transaction.

### Risk 4: Older ADRs continue to be cited as authorization

**Mitigation:** append updates to the affected ADRs and add the supersession map to the decision index.

### Risk 5: A future commercial opportunity justifies expansion

**Mitigation:** expansion is allowed through a new explicit product-boundary ADR. It is not allowed through incremental copy or feature changes.

### Risk 6: The doctrine is mistaken for legal certification

**Mitigation:** state clearly that it is a product and risk boundary, not legal advice or a regulatory determination.

---

## Validation plan

### Documentation gate

- Add `PRODUCT_FIRST_PRINCIPLES.md`.
- Add this ADR.
- Add both to `docs/decisions/README.md`, README, canonical architecture, and journey map.
- Append update-log entries to affected ADRs rather than rewriting them.

### Product-surface gate

Create a current-head inventory of every reachable mobile route and backend capability, classified as:

- core;
- allowed with current contract;
- redesign required;
- gated;
- removed;
- separate ADR required.

Each row must cite code and user-visible copy.

### Automated gate

Add checks for:

- no generated premium values;
- no "Start renewal" transaction semantics;
- no claim filing, adjudication, or insurer-status semantics;
- no "best policy", "underinsured", or purchase recommendation;
- personal claim states remain `Recorded as ...`;
- unsupported claims cannot render as verified;
- every policy-specific material claim has resolvable evidence;
- gated routes are unreachable in release builds.

### Runtime gate

On a deployed production-like environment and representative policy corpus, verify:

- upload through cited summary;
- fully backed, partially backed, and abstained Q&A;
- source-page opening;
- partial and failed processing;
- principal isolation;
- correction, replacement, export, and deletion;
- passive renewal reminder;
- emergency information and staleness;
- claim-log user provenance;
- entitlement and subscription recovery.

### Launch-claim gate

Reconcile public copy against the registry. No product-boundary, privacy, evidence, deletion, offline, or subscription claim ships without its implementation, tests, runtime tier, and release state.

---

## Migration and execution path

This ADR does not authorize code changes until accepted.

After acceptance, execute in dependency order:

### Commit 1: Canonical doctrine

- add the product-first-principles document;
- add this ADR as Accepted with the operator's sign-off appended;
- update decision index and canonical cross-links;
- append supersession entries to affected ADRs.

### Commit 2: Current-surface reconciliation

- inventory every reachable route and capability;
- classify against the doctrine;
- update launch claims and open-item tracking;
- identify exact gates and migrations.

### Commit 3: Boundary enforcement

- gate or remove out-of-bound current surfaces;
- neutralize renewal, readiness, coverage, and claim semantics;
- add static and focused regression tests.

### Commit 4: Core-flow closure

- close upload -> evidence -> source -> Q&A -> lifecycle gaps;
- verify failure, retry, offline/staleness, identity, consent, billing, and deletion;
- record runtime evidence and residual risks.

### Later commits: Approved extensions

Implement Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault, or external resources only when each passes the doctrine and has its required data, privacy, operator, lifecycle, and launch-claim contracts.

The exact commit count may change after the current-head inventory, but the dependency order does not.

---

## Rollback

If the doctrine is rejected before implementation:

- do not add it as canonical;
- retain this proposal outside the repository or mark it Rejected with an update-log entry;
- continue using existing ADRs, while explicitly recording the unresolved conflict.

If the doctrine is accepted and later revised:

- do not delete or rewrite this ADR;
- append the revision and trigger;
- create a new superseding ADR for a material product-role change;
- migrate code, copy, tests, data, and launch claims deliberately.

Do not roll back to unsupported customer claims merely to restore a removed feature.

---

## Revisit triggers

Revisit this decision if:

- the founder intentionally changes the company into a licensed or partnered insurance intermediary;
- authoritative insurer integrations provide transaction, underwriting, or claim-status truth;
- external legal review establishes a different safe operating boundary;
- the product enters a jurisdiction with materially different requirements;
- representative user research shows the document-understanding wedge does not solve a valuable problem;
- a new evidence contract supports a stronger claim without advice or inference;
- the business model depends on commissions, referrals, or partner offers;
- the product begins storing medical records or other materially more sensitive data by default.

A revisit requires a new or appended decision record. It does not occur through implementation drift.

---

## Affected files and related artifacts

Primary:

- `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`
- `docs/decisions/ADR-2026-07-28-03-product-first-principles-and-boundary.md`
- `docs/decisions/README.md`
- `README.md`
- `docs/architecture/coverwise_canonical_architecture.md`
- `docs/user_experience/coverwise_user_journey_map.md`
- `docs/review/exploration_map.md`
- `docs/launch_claims/`

Related decisions and audits:

- `docs/decisions/ADR-2026-07-19-08-cut-keep-finish-half-built-features.md`
- `docs/decisions/ADR-2026-07-19-09-evidence-backed-release-grade-definition.md`
- `docs/decisions/ADR-2026-07-19-11-substrate-as-primary-deliverable.md`
- `docs/decisions/ADR-2026-07-19-13-what-if-premium-refused-as-product-capability.md`
- `docs/decisions/ADR-2026-07-19-14-family-coverage-map-substrate-extension.md`
- `docs/decisions/ADR-2026-07-19-15-claim-document-vault-privacy-policy.md`
- `docs/decisions/ADR-2026-07-19-16-value-add-partnerships-framework.md`
- `docs/decisions/ADR-2026-07-19-17-coverage-adequacy-substrate-extension.md`
- `docs/decisions/ADR-2026-07-19-18-coverage-check-in-substrate-extension.md`
- `docs/decisions/ADR-2026-07-19-19-claim-document-vault-substrate-extension.md`
- `docs/decisions/ADR-2026-07-19-20-family-coverage-map-privacy-policy.md`
- `docs/decisions/ADR-2026-07-19-21-coverage-check-in-privacy-policy.md`
- `docs/decisions/ADR-2026-07-19-22-coverage-adequacy-privacy-policy.md`
- `docs/decisions/ADR-2026-07-23-01-evidence-backed-policy-readiness.md`
- `docs/decisions/ADR-2026-07-24-02-personal-claim-log-boundary.md`
- `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md`
- `docs/audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md`
- `docs/audits/coverwise_regulatory_scope_risk_audit_2026-07-28.md`

---

## Anything else?

Yes.

This ADR resolves the product-level contradiction, but it does not prove the current app conforms to the decision. The first implementation artifact after acceptance must be a fresh current-head surface inventory. No launch-readiness conclusion should be derived from this document alone.
