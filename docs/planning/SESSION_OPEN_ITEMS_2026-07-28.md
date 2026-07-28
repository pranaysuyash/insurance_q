# Session Open Items — 2026-07-28

**Date:** 2026-07-28
**Status:** **OPEN — pending operator discussion and decision.** No work started on any item below. This document exists to surface the live open items from the 2026-07-28 session in one place, with state / blockers / next action each, so the operator can sequence and decide. Per motto_v4 §0.3 (documentation continuity) and §0.12.2 (decisions-first): nothing here is implemented until its decision is made and signed off.
**Companion artifacts:**
- `docs/audits/coverwise_regulatory_scope_risk_audit_2026-07-28.md` — F-1…F-6 findings (regulatory boundary).
- `docs/audits/coverwise_overlooked_risks_round2_2026-07-28.md` — G-1…G-9 findings (G-1 retracted rev C).
- `docs/audits/coverwise_g2_deletion_subscription_analysis_2026-07-28.md` — G-2 deep dive (superseded by ADR-01 for the decision).
- `docs/decisions/ADR-2026-07-28-01-account-deletion-subscription-handoff.md` — G-2 decision (Proposed → operator-approved-inline).
- `docs/decisions/ADR-2026-07-28-02-stray-android-directory-disposition.md` — stray `android/` disposition (Accepted, executed, in commit `f2e2b3c`).

---

## How to read this doc

- **Item** — short name.
- **State** — where it stands (audit-only / ADR-written / blocked / ready-to-implement / etc.).
- **Blocks / Blocked-by** — dependency edges.
- **Owner action needed** — what the operator must decide or provide.
- **My next action** — what I do once the decision is made. Blank until decided.

Nothing below is in progress. Sequencing is the operator's call.

---

## A. Deletion-path cluster (G-2, G-3, G-9)

These three share one root pattern, identified in ADR-01's "Anything else?" section: `account_lifecycle_service.process_deletion` declares `completed` for obligations it does not fully discharge. The honest-staging fix is one mechanism applied three times.

### A1 — G-2: account deletion does not cancel the store subscription
- **State:** ADR written and operator-approved-inline (`ADR-2026-07-28-01`); implementation NOT started.
- **Decision (recorded):** full intermediary contract — mobile gate + Play deep-link + server-side RevenueCat defund + copy alignment + launch-claim registry entry. 5 commits, dep order `1→2→(3‖4)→5`.
- **Blocked-by:** none at the ADR level. Implementation commit 2 (server-side defund) is blocked on the operator's Supabase/RevenueCat prod creds (see D1).
- **Operator action needed:** explicit sign-off to begin commit 1 (`src/services/revenuecat_client.py` outbound RC REST client); provide RC secret API key when commit 2 starts.
- **My next action (on sign-off):** commit 1 — revenuecat REST client + env wiring + idempotency, gated.

### A2 — G-3: account deletion does not purge Qdrant vectors (embeddings persist)
- **State:** audit-only (round-2 finding); NO ADR yet. Flagged as a sibling by ADR-01.
- **Decision needed:** choose the fix shape. Two options surfaced —
  - (a) call `delete_document_data` for each owned document inside `process_deletion` (backend-agnostic; works for Qdrant and pgvector);
  - (b) commit to `RAG_VECTOR_BACKEND=supabase` (pgvector) in production so `document_chunks` deletion covers it.
  - Option (a) is safer (backend-agnostic); option (b) makes the vector-backend choice a compliance decision, not just performance.
- **Blocked-by:** D2 (production vector backend decision).
- **Operator action needed:** pick option (a) vs (b), or defer to a sibling ADR (recommended: `ADR-2026-07-28-03`, reusing the ADR-01 honest-staging pattern).
- **My next action:** write ADR-03 on operator request; do not implement before.

### A3 — G-9: deletion orphans rows in `qa_usage_ledger`, `consent_ledger`, `billing_ledger`
- **State:** audit-only (round-2 finding); NO ADR yet. Possibly intentional (audit-trail retention) but undocumented.
- **Decision needed:** per-ledger retention decision —
  - `consent_ledger`: retain for consent-evidence period (how long?), then purge;
  - `billing_ledger`: retain for tax/refund-dispute period (3–7 yrs), then purge;
  - `qa_usage_ledger`: usage telemetry tied to user → purge on deletion.
  - Then align `docs/legal/privacy_policy.md` retention table to the carve-outs.
- **Blocked-by:** none; this is an editorial + per-ledger product/legal decision.
- **Operator action needed:** confirm retention periods per ledger (or defer to legal review).
- **My next action:** write ADR-04 (sibling to ADR-01/A2) on operator request; update privacy policy once periods confirmed.

---

## B. Regulatory-scope cluster (F-1…F-4)

From the round-1 audit. Each removes or gates a surface that crosses the "document-understanding only" boundary. These are gate-off (feature-flag / route removal), not code deletion — keeps them reversible.

### B1 — F-1: What-If Calculator (fabricates premium figures)
- **State:** audit-only; NO ADR. **Highest-severity regulatory finding.** Directly contradicts the app's own `LeadGenerationService` posture ("does not quote prices").
- **Decision needed:** gate off `/what-if` route + dashboard entry (`mobile/lib/main.dart:454`, `dashboard_screen.dart:208`). Keep file for a possible later non-priced "understand your numbers" view; remove the premium-fabrication logic.
- **Operator action needed:** sign-off to gate off.
- **My next action:** gate the route + dashboard CTA behind a feature flag; keep `what_if_calculator*.dart` on disk.

### B2 — F-2: claim-assistance + claim-guide cluster (claims consultancy)
- **State:** audit-only; NO ADR. Removes `claim_assistance_screen.dart` + `claims_assistant_screen.dart` entry points; KEEPS `claim_tracking_screen.dart` (personal log, clean).
- **Decision needed:** gate off the two advisory screens; keep the personal claim log.
- **Operator action needed:** sign-off to gate off.
- **My next action:** gate the entry points; leave the tracking screen reachable.

### B3 — F-3: "Start renewal" / "Contact insurer to renew" CTA (transaction facilitation)
- **State:** audit-only; NO ADR. Passive reminder stays; the transacting CTA goes.
- **Decision needed:** drop `renewalStartRenewal` / `renewalContactToRenew` CTAs; optionally replace with read-only insurer-contact display extracted from the user's own policy text.
- **Operator action needed:** sign-off to drop the CTA; decide on the read-only contact replacement.
- **My next action:** remove the CTA buttons; optional read-only contact card on decision.

### B4 — F-4: Insurance Literacy Quiz (scope drift, low legal risk)
- **State:** audit-only; NO ADR. Optional — hide for focus, not compliance-required.
- **Decision needed:** hide from launch surface (or soften definitions to descriptive + "verify in your policy").
- **Operator action needed:** hide / soften / keep.
- **My next action:** per decision.

---

## C. Prompt-layer (F-5, F-6)

### C1 — F-5: HyDE prompt says "do not hedge"
- **State:** audit-only; small fix.
- **Decision needed:** invert the instruction (encourage calibration, "stay tightly to what a typical policy would state; do not speculate beyond it").
- **Operator action needed:** sign-off (it's a behavior change to retrieval expansion).
- **My next action:** edit `src/rag/pipeline.py:770` system-prompt string; add/adjust a test if one covers it.

### C2 — F-6: confirm answer-generation prompt carries the grounded-only / not-advice boundary
- **State:** audit-only; verification task. The security prefix (`src/security/prompt_injection.py:52-60`) already enforces "answer ONLY from context"; need to confirm the *answer-generation* prompt (not just HyDE) inherits it end-to-end.
- **Operator action needed:** none (verification).
- **My next action:** trace the answer prompt path; if the boundary is missing from the answer prompt, add it; record finding.

---

## D. Production-wiring decisions (blockers)

### D1 — Supabase production credentials
- **State:** blocked on operator. The `.env` only has a non-JWT `sb_secret_…`, not a service-role key — that's why `verify_local_tenant_isolation.py` / identity checks fail with "Invalid API key."
- **Operator action needed:** provide three things —
  1. Project URL (`https://xxxx.supabase.co`), region **ap-south-1 (Mumbai)** recommended (aligns with the AWS App Runner backend + data residency);
  2. `service_role` key (JWT, 3 dot-segments) — backend `.env` only, never mobile;
  3. `anon` / publishable key — mobile only (safe to ship).
  Plus: confirm new project vs existing (determines whether to run the migration set or diff schema).
- **Recommendation recorded:** Supabase Cloud (Pro, ~$25/mo), not self-hosted — solo-founder, Android-first, schema/RLS/auth already designed for Cloud.
- **Blocks:** A1 (commit 2), A2 (backend decision), the broader deployment path, G-8 (hosted legal pages can sit on Supabase hosting or a separate static host).
- **My next action:** on creds, wire `.env` + mobile `--dart-define`; run/verify migrations; verify RLS.

### D2 — Production vector backend (Qdrant vs pgvector)
- **State:** decision needed. Per G-3, this is now a *compliance* decision, not just performance.
- **Operator action needed:** pick Qdrant (current default) or pgvector. If Qdrant, A2 must add the purge stage; if pgvector, `document_chunks` deletion covers G-3.
- **Blocks:** A2.
- **My next action:** none until decided.

---

## E. Copy / policy / ops (G-4, G-5, G-6, G-8)

### E1 — G-4: analytics retention 30d (policy) vs 90d (code)
- **State:** audit-only; copy-vs-code lie.
- **Decision needed:** pick one number; recommendation = set `ANALYTICS_RETENTION_DAYS=30` in config + code default, match policy. (Code now at `src/services/analytics_retention_service.py` after commit `f2e2b3c`.)
- **Operator action needed:** confirm 30 vs 90.
- **My next action:** one-line config + code default change + policy alignment.

### E2 — G-5: children's threshold "under 13" (COPPA) vs DPDP's 18
- **State:** audit-only; wrong for India.
- **Decision needed:** raise to 18 with age-gating (heavy, likely unnecessary), OR take "not directed at users under 18" position + plain-language line (recommended for a policy-document tool).
- **Operator action needed:** pick position (a) vs (b).
- **My next action:** policy edit on decision.

### E3 — G-6: no data-breach notification process (DPDP requires it)
- **State:** audit-only; ops gap. Only a roadmap checkbox today.
- **Operator action needed:** none (I can draft).
- **My next action:** draft a one-page breach-notification runbook (what counts, who notified, window, content, trigger detection). Cheap to write, expensive to be without.

### E4 — G-8: `support@coverwise.app` referenced 6×, domain doesn't resolve
- **State:** audit-only; Play-approval risk + erasure-right failure path.
- **Operator action needed:** stand up the support inbox (forwarding is fine) + host privacy/terms at real URLs. Coordinate with E3 (same inbox can serve breach contact).
- **Blocks:** store submission.
- **My next action:** none (operator infrastructure); can draft the hosted legal-page content.

---

## F. Carry-forward / iOS

### F1 — G-7: iOS OAuth callback scheme/path mismatch
- **State:** audit-only; carried from `coverwise_native_mobile_platform_store_readiness_audit_2026-07-21.md`; still present on current head.
- **Decision needed:** none (it's a bug, not a decision); fix when iOS work begins.
- **Operator action needed:** confirm Android-first means this stays parked.
- **My next action:** track; fix at iOS sprint start; do not let it reach iOS submission.

---

## G. Residual from commit `f2e2b3c`

### G1 — Tier-3 flutter build verification of `android/` deletion
- **State:** stated residual gap in the commit's acceptance report.
- **Verification needed:** `cd mobile && flutter build apk --release` (debug-fallback signing, `COVERWISE_RELEASE_BUILD` unset) before + after the deletion confirms the build is unaffected.
- **Operator action needed:** run it, or ask me to.
- **My next action:** on request, run the build and record the outcome against ADR-02.

### G2 — post-commit re-modified files (not mine)
- **State:** working-tree dirty after push — `docs/context/agent-start/SESSION_CONTEXT.md` (pre-commit hook's agent-start refresh), `docs/planning/naming/rename_strategy_and_inventory_2026-07-28.md`, `docs/planning/product/launch_external_alignment_2026-07-28.md`.
- **Owner:** parallel agents / their owners. Per motto_v4 §4, not silently committed by me.
- **Operator action needed:** decide whether to commit these (and who attests).
- **My next action:** none unless asked.

### G3 — historical chargeback cases
- **State:** out of scope for ADR-01 (going-forward contract). Users who already deleted while still subscribed — a remediation question.
- **Operator action needed:** decide whether to query `account_deletion_requests` × `subscription_sync` to size the exposure, and the refund posture (proactive vs complaint-only).
- **My next action:** on request, write the query (needs read access + your creds).

---

## H. Parallel workstreams (not mine, surfaced for visibility)

- **`docs/planning/deployment/platform_decision_reassessment_2026-07-28.md`** — backend platform reassessment (AWS App Runner vs alternatives). Driven by another agent/operator; may interact with D1 (Supabase) and deployment.
- **`docs/planning/naming/rename_strategy_and_inventory_2026-07-28.md`** — product naming / rename work. Parallel.
- **`CoverWise_Name_Clearance_and_Brand_Risk_Report_2026-07-28.docx`** — brand-risk report. Parallel input, not action by me.

These are flagged so sequencing decisions can account for them, not because I act on them.

---

## Dependency graph (text)

```
D1 (Supabase creds) ──┬─→ A1 commit 2 (RC defund needs RC creds, hosted on Supabase)
                      ├─→ A2 (vector-backend decision informs purge path)
                      ├─→ E4 (hosted legal pages)
                      └─→ deployment path (separate workstream)

D2 (vector backend)  ──→ A2

A1 (ADR-01, approved) ── commit 1 ready now; commits 2-5 gated on D1 + per-commit sign-off
A2 (no ADR)          ── needs ADR-03 first; blocked on D2
A3 (no ADR)          ── needs ADR-04 first; blocked on operator per-ledger retention call

B1-B4 (regulatory)   ── each needs operator sign-off to gate off; otherwise independent
C1-C2 (prompt)       ── small; C2 is verification-only
E1-E4 (copy/ops)     ── E1/E2 need a number/position; E3 I can draft; E4 operator infra
F1 (iOS OAuth)       ── parked until iOS sprint
G1-G3 (residual)     ── G1 operator-runs-or-asks; G2 owner-decides; G3 operator-decides
```

---

## Process note (recorded per operator feedback, 2026-07-28)

The operator's standing instruction is "all work motto_v4 long-term first-principles." The 2026-07-28 commit (`f2e2b3c`) exposed that I had been treating the motto as a commit-time gate to satisfy, rather than as the working method applied *throughout* each unit of work. The hooks (pre-commit / prepare-commit-msg / commit-msg + the 51-section attestation) are the *enforcement* of doctrine; the doctrine itself — verification, risk classification, §9 artifact handling, evidence tiers — is supposed to be done as the work proceeds, so that by commit/push time the attestation is recording what was already true, not retrofitting it under pressure.

**Corrected practice going forward (for every item in this doc):**
- Risk-class is assigned when the change is scoped, not at commit time.
- Evidence-tier work (Tier-1 static, Tier-2 unit, Tier-3 integration) is part of the implementation, done before the commit is attempted.
- §9 artifact classification is done as files are produced, not at `git add -A`.
- Each gated commit carries its own forward-built attestation evidence; the commit-msg hook passes because the work was done right, not because the hook was satisfied.

This is the standard the operator has been asking for all session. Recorded here so it is durable, not chat-only.
