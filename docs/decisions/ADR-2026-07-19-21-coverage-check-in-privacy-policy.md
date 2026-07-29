# ADR-2026-07-19-21: Coverage Check-in privacy policy — life events handled with the same privacy discipline as the rest of the wedge

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Coverage Check-in tool (per ADR-2026-07-19-08 #1) handles life events that are sensitive personal data** (new baby, new diagnosis, age change, family member change, lifestyle change, new job with group coverage). The privacy policy is the same shape as ADR-2026-07-19-15's policy (consent + retention + encryption + access rules + export/delete + no-share) but simpler (no medical records, no formal `medical_records` consent purpose). The policy: (1) the auto-generated observations are substrate-grounded (per ADR-2026-07-19-18); (2) the user-input life events are stored locally on the device, encrypted with the principal encryption (per ADR-2026-07-19-06 reopened); (3) the life events are not shared with anyone, ever; (4) the user can dismiss observations, edit/delete life events, and export the Check-in history. The launch-claim registry entry: "Coverage Check-in life events are stored locally on the device, never shared with anyone." The minimum-viable privacy stance is the launch state; the formal consent purpose, retention enforcement, and per-event encryption are deferred (per the ADR-15 pattern).
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** the Coverage Check-in privacy policy is the minimum-viable privacy stance: auto-generated observations are substrate-grounded (per ADR-18), user-input life events are stored locally on the device encrypted with the principal encryption (per ADR-06), events are not shared with anyone ever, user can dismiss observations and edit/delete life events locally, support-operator cannot read the local history in the meantime, no-share rule (absolute). The launch-claim registry entry is "Coverage Check-in life events are stored locally on the device, never shared with anyone." The formal consent purpose (`life_events`), retention enforcement, server-side encrypted sync, support-operator access rules, and export-as-PDF are deferred. The Coverage Check-in tool surface (per ADR-2026-07-19-08 #1) is unblocked. Implementation may begin in dependency order: in-app disclosure card → local encryption verification → no-share CI test → launch-claim registry entry → canonical doc update. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #1 (the Coverage Check-in tool that this ADR governs), [ADR-2026-07-19-18](./ADR-2026-07-19-18-coverage-check-in-substrate-extension.md) (the substrate extension that produces the auto-generated observations), [ADR-2026-07-19-15](./ADR-2026-07-19-15-claim-document-vault-privacy-policy.md) (the pattern this ADR follows; deferred per operator's reasoning), [ADR-2026-07-19-06](./ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md) (the principal encryption).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Coverage Check-in tool handles life events that are sensitive personal data. The privacy policy is the same shape as ADR-15 but simpler (no medical records). The minimum-viable privacy stance is the launch state. The launch-claim registry entry is the no-share rule. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The Coverage Check-in privacy policy is the minimum-viable privacy stance: auto-generated observations are substrate-grounded (per ADR-18), user-input life events are stored locally on the device encrypted with the principal encryption (per ADR-06), events are not shared with anyone ever, user can dismiss observations and edit/delete life events locally, support-operator cannot read the local history in the meantime, no-share rule (absolute). The launch-claim registry entry is "Coverage Check-in life events are stored locally on the device, never shared with anyone." The formal consent purpose (`life_events`), retention enforcement, server-side encrypted sync, support-operator access rules, and export-as-PDF are deferred. The Coverage Check-in tool surface (per ADR-2026-07-19-08 #1) is unblocked. Implementation may begin in dependency order: in-app disclosure card → local encryption verification → no-share CI test → launch-claim registry entry → canonical doc update.


---

## Context

The Coverage Check-in tool (per ADR-2026-07-19-08 #1) is a periodic surface that helps the user notice when their coverage is keeping up with their life. The operator's per-feature thinking was: "people have an insurance but under the coverage do they know how their health fares etc? maybe to build a regular checkin tool etc."

The Check-in has two kinds of inputs:
- **Auto-generated observations** (from the substrate + life-event signals + inflation data). Examples: "your sum insured has not changed in 3 years, but medical inflation has been ~14% per year; your real coverage is lower than when you bought it."
- **User-input life events** (manually entered by the user). Examples: "new baby," "new diagnosis," "age change."

The user-input life events are sensitive personal data:
- "new baby" — reproductive health
- "new diagnosis" — health status
- "age change" — demographic
- "family member change" — family structure
- "lifestyle change" — behavior
- "new job with group coverage" — employment

The Check-in's privacy policy is the same shape as ADR-15's policy but simpler (no medical records, no formal `medical_records` consent purpose). The policy is a "minimum-viable privacy stance" — the formal consent purpose, retention enforcement, and per-event encryption are deferred.

---

## The policy in detail

### 1. The auto-generated observations are substrate-grounded

- The observations are extracted by the parser pipeline v4 (per ADR-18) from the user's policy documents + life-event signals + inflation data. The observations cite the policy, the page, the inflation source, the date. The four-face contract (per ADR-09) applies.
- The user can dismiss observations. Dismissed observations are stored in the substrate with a `dismissed=true` flag; the substrate does not delete the observation (the audit trail requires the record).

### 2. The user-input life events are stored locally

- The life events are entered by the user in the Check-in tool's "what changed in your life?" input. The events are stored on the user's device, in a local box (Hive) encrypted with the principal encryption (per ADR-06 reopened, stable random 256-bit DEK).
- The events are **not** sent to the server. The events are the user's own record. The substrate does not see them. The four-face contract does not apply to them (they are not substrate claims).
- The user can edit or delete a life event at any time. The deletion is local.

### 3. The life events are not shared with anyone, ever

- The life events are local-first. The events do not leave the device.
- The launch-claim registry entry: "Coverage Check-in life events are stored locally on the device, never shared with anyone."

### 4. The user can dismiss observations, edit/delete life events, and export the Check-in history

- **Dismiss observations**: the user can dismiss any auto-generated observation. The dismissal is stored in the substrate (audit trail).
- **Edit/delete life events**: the user can edit or delete any life event. The edit/delete is local (no server roundtrip).
- **Export the Check-in history**: the user can export the Check-in history (observations + life events) as a JSON. The export is encrypted with a user-chosen password. The PDF export is deferred (per the ADR-15 pattern).

### 5. The support-operator role cannot read the Check-in history (in the meantime)

- The Check-in history is local. The support operator cannot read the device's local storage.
- When the formal privacy work lands (per the deferred components below), the Check-in history may be synced to the server (encrypted) so the support operator can help the user. The deferral is per the ADR-15 pattern.

### 6. The no-share rule (absolute)

- The Check-in history is not shared with anyone, ever. Not with insurers. Not with partners (per ADR-16). Not with third parties. Not with model training. Not with analytics.

---

## What ships in the meantime (the "minimum-viable privacy stance")

1. **Life events are stored locally on the device**, encrypted with the principal encryption (per ADR-06).
2. **No-share rule (absolute)** is enforced by a CI test (the launch-claim registry entry).
3. **User can edit/delete life events** at any time. The edit/delete is local.
4. **User can dismiss observations**. The dismissal is stored in the substrate (audit trail).
5. **User can export the Check-in history** as a JSON. The export is encrypted.
6. **In-app disclosure** — the Check-in tool's first-open UX shows a card: "Your life events are stored locally on your device. We don't see them. We don't share them with anyone. You can export or delete them at any time. We may add additional protections in the future — see ADR-2026-07-19-21 for the full policy."

**What is deferred (when the operator revisits):**
1. Server-side encrypted sync of life events (so the support operator can help the user)
2. Formal consent purpose `life_events` + the formal consent card
3. Retention enforcement
4. Support-operator access rules
5. Export-as-PDF
6. Legal review

**When the operator revisits:** the six deferred components are the implementation checklist. The effort is M. 2-3 weeks.

---

## Anything else flagged

The "privacy policy per surface" pattern is now well-established:
- ADR-15: Claim Document Vault privacy (deferred; medical records)
- ADR-20: Family Coverage Map privacy (proposed; per-member data)
- ADR-21 (this): Coverage Check-in privacy (proposed; life events)
- Coverage Adequacy privacy (future ADR; scenario picks)

All follow the same minimum-viable privacy stance: no-share + principal encryption + user's right to export/delete. The formal consent purpose, retention enforcement, per-event/per-scenario encryption, support-operator access rules, and export-as-PDF are deferred to a future revisit, following the ADR-15 pattern.


---

## Doctrine reconciliation note (2026-07-29)

> Append-only note added 2026-07-29. This section does not modify any prior
> content in this ADR; the original decision, reasoning, and existing update
> logs above remain intact and authoritative for their date.

- **Date:** 2026-07-29
- **Governing ADR:** [ADR-2026-07-29-02 (doctrine stack reconciliation)](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
- **What changed:** [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) establishes a layered doctrine stack. The [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`) now sits above feature ADRs, with a five-gate stack (Gates A-E: Outcome, Truth, Product role, Lifecycle, Strategy/commercial). Reaffirmed: privacy policy remains valid (life events stored locally, never shared). Surface semantics narrowed (no actuarial/adequacy verdict - Gate C).
- **Why:** Operator direction to unify two competing uncommitted first-principles documents into one layered stack before any boundary-shaped code changes.
- **What triggered it:** Discovery that the repository held conflicting uncommitted doctrine (Principles vs Wedge) and that ADR-2026-07-29-01 self-declared "Accepted" without sign-off evidence.
- **What original reasoning remains valid:** All prior reasoning in this ADR is preserved unchanged. This note only constrains surface semantics where they intersect the constitution's gates.
- **Status change for this ADR:** None (this ADR's own status is unchanged by this note).
- **Operator sign-off:** None required for this note; it records the reconciliation linkage. The reconciliation ADR itself remains Proposed pending operator sign-off.
- **Code authorization:** None. No code, route, entitlement, pricing, comparison, claims, renewal, camera, demo, or onboarding change is authorized by this note.
