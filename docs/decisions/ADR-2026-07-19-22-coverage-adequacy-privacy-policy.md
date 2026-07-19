# ADR-2026-07-19-22: Coverage Adequacy privacy policy — scenario picks handled with the same privacy discipline as the rest of the wedge

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Coverage Adequacy tool (per ADR-2026-07-19-08 #2) handles scenario picks that are sensitive personal data** (C-section, knee replacement, day-care procedures, ICU, dental, maternity, OPD, pre-existing disease). The privacy policy is the same shape as ADR-2026-07-19-15's policy (consent + retention + encryption + access rules + export/delete + no-share) but simpler (no medical records, no formal `medical_records` consent purpose). The policy: (1) the scenario answers are substrate-grounded (per ADR-2026-07-19-17); (2) the scenario picks are stored locally on the device, encrypted with the principal encryption (per ADR-2026-07-19-06 reopened); (3) the picks are not shared with anyone, ever; (4) the user can dismiss scenario answers, edit/delete picks, and export the Coverage Adequacy history. The launch-claim registry entry: "Coverage Adequacy scenario picks are stored locally on the device, never shared with anyone." The minimum-viable privacy stance is the launch state; the formal consent purpose, retention enforcement, and per-pick encryption are deferred (per the ADR-15 pattern).
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** the Coverage Adequacy privacy policy is the minimum-viable privacy stance: scenario answers are substrate-grounded (per ADR-17), scenario picks are stored locally on the device encrypted with the principal encryption, picks are not shared with anyone ever, user can dismiss answers and edit/delete picks locally, support-operator cannot read the local history in the meantime, no-share rule (absolute). The What-If Premium question is refused (per ADR-13). The launch-claim registry entry is "Coverage Adequacy scenario picks are stored locally on the device, never shared with anyone." The formal consent purpose (`scenario_picks`), retention enforcement, server-side encrypted sync, support-operator access rules, and export-as-PDF are deferred. The Coverage Adequacy tool surface (per ADR-2026-07-19-08 #2) is unblocked. Implementation may begin in dependency order: in-app disclosure card → local encryption verification → no-share CI test → launch-claim registry entry → canonical doc update. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #2 (the Coverage Adequacy tool that this ADR governs), [ADR-2026-07-19-17](./ADR-2026-07-19-17-coverage-adequacy-substrate-extension.md) (the substrate extension that produces the scenario answers), [ADR-2026-07-19-15](./ADR-2026-07-19-15-claim-document-vault-privacy-policy.md) (the pattern this ADR follows; deferred per operator's reasoning), [ADR-2026-07-19-06](./ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md) (the principal encryption).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Coverage Adequacy tool handles scenario picks that are sensitive personal data. The privacy policy is the same shape as ADR-15 but simpler (no medical records). The minimum-viable privacy stance is the launch state. The launch-claim registry entry is the no-share rule. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The Coverage Adequacy privacy policy is the minimum-viable privacy stance: scenario answers are substrate-grounded (per ADR-17), scenario picks are stored locally on the device encrypted with the principal encryption, picks are not shared with anyone ever, user can dismiss answers and edit/delete picks locally, support-operator cannot read the local history in the meantime, no-share rule (absolute). The What-If Premium question is refused (per ADR-13). The launch-claim registry entry is "Coverage Adequacy scenario picks are stored locally on the device, never shared with anyone." The formal consent purpose (`scenario_picks`), retention enforcement, server-side encrypted sync, support-operator access rules, and export-as-PDF are deferred. The Coverage Adequacy tool surface (per ADR-2026-07-19-08 #2) is unblocked. Implementation may begin in dependency order: in-app disclosure card → local encryption verification → no-share CI test → launch-claim registry entry → canonical doc update.


---

## Context

The Coverage Adequacy tool (per ADR-2026-07-19-08 #2) answers "am I covered for scenario X?" for user-picked scenarios. The operator's per-feature thinking was: "what if scenarios that the user wants to know if he has enough coverage or not etc."

The scenario picks are sensitive personal data:
- "C-section" — reproductive health
- "knee replacement" — orthopedic
- "day-care procedures" — surgical
- "ICU" — critical care
- "dental" — dental health
- "maternity" — reproductive health
- "OPD" — outpatient care
- "pre-existing disease" — health status

The user picks a scenario because they are interested in that specific medical event. The pick itself is a signal of the user's health concerns.

The Coverage Adequacy's privacy policy is the same shape as ADR-15's policy but simpler (no medical records, no formal `medical_records` consent purpose). The policy is a "minimum-viable privacy stance" — the formal consent purpose, retention enforcement, and per-pick encryption are deferred.

---

## The policy in detail

### 1. The scenario answers are substrate-grounded

- The answers are extracted by the parser pipeline v3 (per ADR-17) from the user's policy documents. The answers cite the policy, the page, the quote. The four-face contract (per ADR-09) applies.
- The user can dismiss answers. Dismissed answers are stored in the substrate with a `dismissed=true` flag; the substrate does not delete the answer (the audit trail requires the record).

### 2. The scenario picks are stored locally

- The picks are entered by the user in the Coverage Adequacy tool's scenario list. The picks are stored on the user's device, in a local box (Hive) encrypted with the principal encryption (per ADR-06 reopened, stable random 256-bit DEK).
- The picks are **not** sent to the server. The picks are the user's own record. The substrate does not see them. The four-face contract does not apply to them (they are not substrate claims).
- The user can edit or delete a pick at any time. The deletion is local.

### 3. The picks are not shared with anyone, ever

- The picks are local-first. The picks do not leave the device.
- The launch-claim registry entry: "Coverage Adequacy scenario picks are stored locally on the device, never shared with anyone."

### 4. The user can dismiss answers, edit/delete picks, and export the history

- **Dismiss answers**: the user can dismiss any auto-generated answer. The dismissal is stored in the substrate (audit trail).
- **Edit/delete picks**: the user can edit or delete any pick. The edit/delete is local (no server roundtrip).
- **Export the history**: the user can export the Coverage Adequacy history (answers + picks) as a JSON. The export is encrypted with a user-chosen password. The PDF export is deferred.

### 5. The What-If Premium question is refused (per ADR-13)

- The "What would this cost?" question is refused as a product capability (per ADR-13). The product offers three honest options: deep-link to insurer, vetted partner (per ADR-16), "ask your insurer." The picks are not used to fabricate a premium number.

### 6. The support-operator role cannot read the Coverage Adequacy history (in the meantime)

- The Coverage Adequacy history is local. The support operator cannot read the device's local storage.
- When the formal privacy work lands, the history may be synced to the server (encrypted) so the support operator can help. The deferral is per the ADR-15 pattern.

### 7. The no-share rule (absolute)

- The Coverage Adequacy history is not shared with anyone, ever. Not with insurers. Not with partners (per ADR-16). Not with third parties. Not with model training. Not with analytics.

---

## What ships in the meantime (the "minimum-viable privacy stance")

1. **Scenario picks are stored locally on the device**, encrypted with the principal encryption.
2. **No-share rule (absolute)** is enforced by a CI test (the launch-claim registry entry).
3. **User can edit/delete picks** at any time. The edit/delete is local.
4. **User can dismiss answers**. The dismissal is stored in the substrate.
5. **User can export the history** as a JSON. The export is encrypted.
6. **What-If Premium question is refused** (per ADR-13). The three honest options are offered.
7. **In-app disclosure** — the Coverage Adequacy tool's first-open UX shows a card: "Your scenario picks are stored locally on your device. We don't see them. We don't share them with anyone. You can export or delete them at any time. We may add additional protections in the future — see ADR-2026-07-19-22 for the full policy."

**What is deferred (when the operator revisits):**
1. Server-side encrypted sync of picks (so the support operator can help)
2. Formal consent purpose `scenario_picks` + the formal consent card
3. Retention enforcement
4. Support-operator access rules
5. Export-as-PDF
6. Legal review

**When the operator revisits:** the six deferred components are the implementation checklist. The effort is M. 2-3 weeks.

---

## Anything else flagged

The "privacy policy per surface" pattern is now well-established and applied to all four privacy-sensitive surfaces:
- ADR-15: Claim Document Vault privacy (deferred; medical records)
- ADR-20: Family Coverage Map privacy (proposed; per-member data)
- ADR-21: Coverage Check-in privacy (proposed; life events)
- ADR-22 (this): Coverage Adequacy privacy (proposed; scenario picks)

All follow the same minimum-viable privacy stance. The full set is the privacy workstream. The workstream is a future exploration (per the operator's reasoning). The minimum-viable privacy stance is the launch state for each surface.
