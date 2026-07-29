# Doctrine Conflict-Closure Matrix

> **Date:** 2026-07-29
> **Governing ADR:** [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) (Proposed)
> **Status:** All identified conflicts have a final rule assigned. No unresolved doctrine contradiction remains.

---

| # | Conflict | Previous Documents | Final Rule | Governing Source | Status | Remaining Implementation Work |
|---|----------|-------------------|------------|------------------|--------|-------------------------------|
| 1 | **Policy comparison: IN vs OUT** | Wedge (§3.4): "policy comparison is outside"; Commercial: comparison as paid tier feature | Neutral owned-policy comparison IN (basic free / advanced paid candidate); shopping comparison OUT at every tier | ADR-2026-07-29-02 §4.1; Constitution Principle 4 | ✅ Closed | Split comparison into basic (free) and advanced (paid) in code; update entitlement gates |
| 2 | **"Actual insurance situation" overclaim** | Wedge (§1): "single source of truth for what does my insurance actually cover" | CoverWise = source-verifiable workspace; policies are authoritative. "What do uploaded policies establish, what remains unknown, where does each fact come from?" | ADR-2026-07-29-02 §4.2; Constitution §1 | ✅ Closed | Audit marketing copy, onboarding text, and UI strings for overclaims |
| 3 | **"Not covered" from absence** | Wedge (§3.5): "Your motor policy doesn't cover flood damage" alert | Evidence-state wording only: found, not found, unverified, incomplete, stale, conflicting. Rename "gap alerts" to "Coverage facts and verification prompts" | ADR-2026-07-29-02 §4.3 | ✅ Closed | Rename UI feature; replace negative-conclusion strings with evidence-state wording |
| 4 | **Claims scope: process vs consultancy** | ADR-2026-07-19-04: claim-assistance thin slice | Policy-stated process (cited), insurer contacts, user-authored records = IN. Filing, representation, adjudication, escalation = OUT | ADR-2026-07-29-02 §4.4 | ✅ Closed | Reframe claim screens: process/contacts only; remove guided filing language |
| 5 | **Renewal: reminder vs transaction** | Exploration map: "Start renewal" | Expiry dates, factual reminders, read-only contact = IN. "Renew now", switching, transaction = OUT | ADR-2026-07-29-02 §4.5 | ✅ Closed | Replace "Start renewal" CTA with neutral reminder text |
| 6 | **Free/paid contradictions** | Commercial: exact prices as settled; Principles: "comprehension is free" | Durable principle only: free baseline = at least 1 policy, limited Q&A, emergency facts. All exact prices demoted to Proposed experiments | ADR-2026-07-29-02 §4.6 | ✅ Closed | Commercial layer must resolve 9 open questions (G1-G5) as Proposed |
| 7 | **Pricing evidence: unsourced claims** | Commercial: "PPP-adjusted", "RevenueCat 2026 India median ₹300-315" | Every price requires: source URL, date, geography, store, category, currency, PPP method. All exact prices are experiments | ADR-2026-07-29-02 §4.7 | ✅ Closed | Complete evidence-audit skeleton in Commercial layer §7 |
| 8 | **"Not multi-tenant" conflates product with architecture** | Wedge (§4.1): "not multi-tenant" | CoverWise = consumer/household product, not broker/employer/enterprise. Backend remains multi-user with strict principal isolation | ADR-2026-07-29-02 §4.8 | ✅ Closed | Replace "not multi-tenant" in all documentation |
| 9 | **Camera reject as permanent principle** | Wedge (§4.2): "camera-first flow fails the decision framework" | Direct digital import preferred. Camera = optional fallback for printed docs. Not the default. Strategy decision, not permanent principle | ADR-2026-07-29-02 §4.9 | ✅ Closed | No code change; camera stays as optional fallback |
| 10 | **Demo reject as permanent principle** | ADR-2026-07-28-reject-demo-mode: "rejected" | Rejected for launch. Read-only marketing-site example = experiment. Strategy decision, not constitutional ban | ADR-2026-07-29-02 §4.10 | ✅ Closed | No code change; demo remains absent from onboarding |
| 11 | **Coverage-summary-first as universal proof** | Wedge (§3.3): described as first-principles ordering | Strategy hypothesis: coverage overview first, Q&A second. Must be validated through usability evidence | ADR-2026-07-29-02 §4.11 | ✅ Closed | Track usability metrics; do not treat as proven |
| 12 | **Accepted status without sign-off evidence** | ADR-2026-07-29-01: "Accepted" | No sign-off evidence found. Status corrected to Proposed. This ADR is the only sign-off gate | ADR-2026-07-29-02 §4.12 | ✅ Closed | Single sign-off question on this ADR |
| 13 | **Evidence tier: conceptual reasoning mislabeled** | Wedge: "Tier 4 (runtime/manual reasoning)" | Tier 0: decision-grade product reasoning. Not runtime evidence | ADR-2026-07-29-02 §4.13 | ✅ Closed | Update evidence-tier label in Wedge header |

---

## Verification

All 13 conflicts identified by the reconciliation are assigned a final rule. No two documents in the working tree independently claim sole canonical authority. The Constitution and Wedge now cite each other. The doctrine index in [`docs/decisions/README.md`](./README.md) makes precedence explicit.

**Remaining open items (none are contradictions):**
- 9 commercial open questions (G1-G5 in FREE_VS_PAID_BOUNDARY.md)
- Pricing evidence audit (skeleton created, not filled)
- Implementation inventory (post-sign-off, separate task)

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | Initial conflict-closure matrix — all 13 conflicts resolved, 0 contradictions remaining across 6 doctrine files, 17+ ADRs, and 37+ modified files. | Final deliverable for ADR-2026-07-29-02 Phase 8. |
