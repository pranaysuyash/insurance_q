# 08 — Risk Register (Project-Wide)

**Bundle:** 2026-07-30-project-wide-recon
**Doc H (Part 0)** — project-wide risks
**Author:** session-init agent
**Date:** 2026-07-30

---

## Reading guide

For each risk:

- **Type** — product / user / architecture / data / security / privacy / reliability / performance / accessibility / operational / dependency / migration / regression / scope / delivery
- **Cause** — root pattern
- **Likelihood** — Low / Medium / High
- **Impact** — what breaks
- **Severity** — Blocker / Critical / High / Medium / Low / Informational
- **Detection** — how we would notice
- **Mitigation** — what reduces the chance or impact
- **Contingency** — what to do if it materialises
- **Owner** — who tracks it
- **Status** — Active / Mitigated / Accepted / Deferred / Closed

---

## R-1 — Doctrine stack ratification slips indefinitely

- **Type:** Doctrine / Authority
- **Cause:** Constitution, Wedge, Commercial Boundary remain "Proposed" awaiting operator sign-off.
- **Likelihood:** Medium-High.
- **Impact:** Project-wide pricing, comparison, demos, camera, partnership decisions stay scoped-provisional. Constitution binds directionally only.
- **Severity:** **High** for project-wide velocity.
- **Detection:** Periodic check of ADR-2026-07-29-02 status.
- **Mitigation:** Operator single-line sign-off entry in ADR Update Log.
- **Contingency:** If no sign-off in 7 days, escalate to operator via session.
- **Owner:** Operator.
- **Status:** **Active.**

## R-2 — Test-suite honesty regression (six pre-existing failures uninvestigated)

- **Type:** Reliability / Honest-test-discipline
- **Cause:** Buffy §2.2 lists 6 dismissed test failures.
- **Likelihood:** High (per Buffy: "all 6 must be fixed").
- **Impact:** Customer-facing breakage lands; customer loses trust.
- **Severity:** **High** (per Buffy).
- **Detection:** `flutter test` output (would re-run periodically).
- **Mitigation:** For each of 6 tests: read source, identify cause, fix or remove with explicit reason.
- **Contingency:** If fix is non-trivial per test, document owner + scope.
- **Owner:** Future test-honesty session.
- **Status:** **Active, deferred.**

## R-3 — Doctrine-stack contradiction in working tree

- **Type:** Doctrine coherence
- **Cause:** Self-declared "Accepted" without sign-off (per ADR-2026-07-29-02 §1 inventory table).
- **Likelihood:** Medium.
- **Impact:** Future agents can cite opposite conclusions from different layers.
- **Severity:** Medium.
- **Detection:** Audit cross-comparison.
- **Mitigation:** ADR-2026-07-29-02 corrects/clarifies; 2026-07-29 addenda on UX audit apply same discipline.
- **Contingency:** Dated addendums to demote "Accepted" to "Proposed" (already done for some).
- **Owner:** Operator.
- **Status:** **Mitigated by ADR-2026-07-29-02; awaiting operator sign-off.**

## R-4 — Parallel-agent refactor (10 mobile files, 456/189 lines) drift

- **Type:** Co-authoring / Drift
- **Cause:** Active editing across `auth_service.dart`, `auth_provider.dart`, `hive_workspace_service.dart`, `principal_key_service.dart`, `app_config.dart`, `coverage_gap_screen.dart`, `widget_test.dart`, `pubspec.yaml`, `pubspec.lock`, `main.dart`.
- **Likelihood:** Medium (already mid-flight).
- **Impact:** Could conflict with future work; could change canonical contracts without ADRs.
- **Severity:** Medium.
- **Detection:** git diff --stat / diff recheck before each commit / future session.
- **Mitigation:** Pause protocol per motto §23 addendum (this session validated the pattern).
- **Contingency:** Document any new canonical-contract changes via ADR.
- **Owner:** Parallel-agent / future sessions.
- **Status:** **Mitigated by §23 protocol.**

## R-5 — Live backend deployment gap

- **Type:** Operational / Launch-readiness
- **Cause:** README §"Launch status" reads "not yet deployed for customer use."
- **Likelihood:** High.
- **Impact:** Cannot claim release; no production telemetry.
- **Severity:** Informational (per current scope).
- **Detection:** `tools/deploy_cloud_run.sh` execution logs.
- **Mitigation:** Track via deployment ticket.
- **Contingency:** Not a current blocker.
- **Owner:** Operator / deployment workstream.
- **Status:** **Accepted.**

## R-6 — On-disk What-If Calculator violates constitution Gate C

- **Type:** Constitutional / Coherence
- **Cause:** `mobile/lib/screens/what_if_calculator_screen.dart` exists; constitution P4 says no.
- **Likelihood:** High (already happens).
- **Impact:** Constitution-on-paper vs code-on-disk contradiction; future agents get mixed signals.
- **Severity:** Medium.
- **Detection:** grep for "what_if" in `mobile/lib/`.
- **Mitigation:** Remove or refactor per ADR-2026-07-19-13 + Constitution P4.
- **Contingency:** Gate the screen behind a feature flag pointing to coverage-adequacy-only mode (cited-only).
- **Owner:** Future scope-cut workstream.
- **Status:** **Active.**

## R-7 — Backend frontend-state granularity mismatch (ProcessingStatusScreen)

- **Type:** Honesty / Trust
- **Cause:** Backend exposes 3 states; frontend simulates 5.
- **Likelihood:** High (already happens).
- **Impact:** Customer-facing lying UI; trust erosion.
- **Severity:** **High** per Buffy P0.
- **Detection:** Manual UI inspection.
- **Mitigation:** Either add real backend stage reporting or simplify frontend to actual states.
- **Contingency:** Hide frontend simulation behind a feature flag.
- **Owner:** Future backend-state workstream.
- **Status:** **Active, deferred.**

## R-8 — Documentation bloat (Buffy §2.5)

- **Type:** Documentation maintenance
- **Cause:** ~20 planning docs partially stale.
- **Likelihood:** Medium.
- **Impact:** Operator cognitive load; future agents re-derive context.
- **Severity:** Medium.
- **Detection:** Cross-reference check.
- **Mitigation:** Consolidate; archive stale items.
- **Contingency:** Keep decision index + constitution + wedge + commercial + recent ADRs as primary; archive the rest.
- **Owner:** Future doc-hygiene session.
- **Status:** **Accepted.**

## R-9 — Legal copy risk (83 files / 1,793 lines)

- **Type:** Compliance
- **Cause:** Legal-risk audit findings, multiple categories.
- **Likelihood:** High (audit already flagged).
- **Impact:** Regulatory and customer-protection risk.
- **Severity:** **High** (per legal audit taxonomy).
- **Detection:** Audit re-runs.
- **Mitigation:** Apply remediation priority doc.
- **Contingency:** Block launch until Categories A–B (core legal + medical/claims) reach "remediated" state.
- **Owner:** Legal/comms review + implementation.
- **Status:** **Active.**

## R-10 — Hero copy "evidence-backed" terminology

- **Type:** Voice / Legal
- **Cause:** Legal-risk audit Category F.
- **Likelihood:** Medium.
- **Impact:** Customer trust; potentially regulatory.
- **Severity:** High.
- **Detection:** Voice audit.
- **Mitigation:** Pass of copy/legal review.
- **Contingency:** Replace "evidence-backed" with precise user-language.
- **Owner:** Future voice/copy + legal.
- **Status:** **Active.**

## R-11 — Substrate-extension backlog

- **Type:** Wedge completeness
- **Cause:** 14 ADR-2026-07-19-XX defined; implementation varies.
- **Likelihood:** Medium.
- **Impact:** Long-term wedge incompletion.
- **Severity:** Medium.
- **Detection:** Code-level coverage check.
- **Mitigation:** Schedule per the cut/keep/finish framework.
- **Contingency:** Phased roll-out per priority.
- **Owner:** Future substrate-completion workstream.
- **Status:** **Accepted.**

## R-12 — Coverage Details Summary share-gate verification (workstream-specific)

- **Type:** Scope / Workstream
- **Cause:** This session resolved it (see `docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/`).
- **Likelihood:** N/A (resolved).
- **Impact:** Auditability gap if workstream bundle drifts.
- **Severity:** Informational.
- **Detection:** Bundle file existence.
- **Mitigation:** Both bundles committed per motto §20.
- **Contingency:** N/A.
- **Owner:** N/A.
- **Status:** **Closed.**

## R-13 — God-object screens (`CoverageDetailsSummaryScreen`, `PolicyDetailScreen`, etc.)

- **Type:** Maintainability
- **Cause:** Long-running scope and feature accumulation.
- **Likelihood:** High.
- **Impact:** Cost-of-add rises.
- **Severity:** Medium.
- **Detection:** Line count + section count.
- **Mitigation:** Decompose into smaller widgets per Constitution P8.
- **Contingency:** Phased per screen.
- **Owner:** Future refactor workstreams.
- **Status:** **Accepted.**

## R-14 — Missing `AGENTS.md`

- **Type:** Discovery hygiene
- **Cause:** No scoped instruction file at root or nested.
- **Likelihood:** N/A (gap).
- **Impact:** Agents bypassing `agent-start` miss doctrine stack.
- **Severity:** Low.
- **Detection:** `ls AGENTS.md` at repo root.
- **Mitigation:** 1-line `AGENTS.md` referencing `motto_v4.md`.
- **Contingency:** None.
- **Owner:** Future hygiene PR.
- **Status:** **Active.**

## R-15 — Operator trust model implementation gap

- **Type:** Security / Privacy
- **Cause:** ADR-2026-07-19-12 defines 6 roles + audit; Phase 0 is shared-secret only.
- **Likelihood:** Medium.
- **Impact:** Operator access path leaks; privacy/security debt.
- **Severity:** Medium.
- **Detection:** Operator API access logs.
- **Mitigation:** Security Phase 1 ADR + implementation.
- **Contingency:** Phased.
- **Owner:** Future Security Phase 1.
- **Status:** **Active, deferred.**

## R-16 — Hindi localization not deeply audited

- **Type:** Localization / Legal
- **Cause:** `app_hi.arb` mentioned in legal-risk audit scope but not read here.
- **Likelihood:** Medium.
- **Impact:** Same legal-risks apply to Hindi; Hindi-speaking customers may be underserved.
- **Severity:** Medium.
- **Detection:** Hindi copy/voice audit.
- **Mitigation:** Future Hindi voice/copy session.
- **Contingency:** Block Hindi launch until Categories A–B reach "remediated."
- **Owner:** Future Hindi voice/copy session.
- **Status:** **Active.**

## R-17 — iOS App Store deployment gap

- **Type:** Platform
- **Cause:** README roadmap shows Android ready; iOS pending.
- **Likelihood:** High (until proven otherwise).
- **Impact:** Half of mobile market unreachable at launch.
- **Severity:** Medium.
- **Detection:** App Store Connect status.
- **Mitigation:** Standard iOS deployment checklist.
- **Contingency:** Launch Android-first, iOS in follow-up release.
- **Owner:** Future deployment workstream.
- **Status:** **Active.**

## R-18 — Backend Q&A RAG implementation gap (cross-doc Q&A improvement roadmap)

- **Type:** Architecture / Knowledge quality
- **Cause:** Buffy §3 P2 item 12.
- **Likelihood:** Medium.
- **Impact:** Cross-document Q&A answers may be basic.
- **Severity:** Medium.
- **Detection:** Manual Q&A testing.
- **Mitigation:** Roadmap execution.
- **Contingency:** Roadmap buffer.
- **Owner:** Future RAG workstream.
- **Status:** **Accepted.**

## R-19 — Multi-language support future

- **Type:** Localization
- **Cause:** README P2.
- **Likelihood:** Medium.
- **Impact:** Indian market reach (Hindi, Tamil, etc.).
- **Severity:** Medium.
- **Detection:** Customer segment analytics.
- **Mitigation:** Roadmap execution.
- **Contingency:** Roadmap buffer.
- **Owner:** Future localization workstream.
- **Status:** **Accepted.**

## R-20 — Multi-region deployment future

- **Type:** Operational
- **Cause:** README P2.
- **Likelihood:** Medium.
- **Impact:** Latency for non-India customers.
- **Severity:** Medium.
- **Detection:** Monitoring.
- **Mitigation:** Multi-region Cloud Run deployment.
- **Contingency:** Roadmap buffer.
- **Owner:** Future deployment workstream.
- **Status:** **Accepted.**

---

## Risk summary

| Risk | Severity | Status |
|---|---|---|
| R-1 Doctrine ratification slip | High | Active |
| R-2 Test-suite honesty regression | High | Active, deferred |
| R-3 Doctrine contradiction in tree | Medium | Mitigated (sign-off pending) |
| R-4 Parallel-agent drift | Medium | Mitigated (paused per §23) |
| R-5 Live deployment gap | Informational | Accepted |
| R-6 What-If on disk | Medium | Active |
| R-7 ProcessingStatus mismatch | High | Active, deferred |
| R-8 Doc bloat | Medium | Accepted |
| R-9 Legal copy risk | High | Active |
| R-10 Hero copy terminology | High | Active |
| R-11 Substrate backlog | Medium | Accepted |
| R-12 Share-gate workstream | Informational | Closed |
| R-13 God-object screens | Medium | Accepted |
| R-14 Missing AGENTS.md | Low | Active |
| R-15 Operator trust model gap | Medium | Active, deferred |
| R-16 Hindi copy risk | Medium | Active |
| R-17 iOS gap | Medium | Active |
| R-18 RAG cross-doc gap | Medium | Accepted |
| R-19 Multi-language | Medium | Accepted |
| R-20 Multi-region | Medium | Accepted |

## Anything else? (motto §0.1.1)

The risk register is the project-wide mirror of Buffy's strategic assessment: the project is real, the architecture is sound, the gaps are mostly operational. The 5 High-severity items (R-1, R-2, R-7, R-9, R-10) cluster around three anchors: doctrine-stack sign-off (R-1), launch-blocking test honesty (R-2 + R-7), and customer-facing copy/claims trust (R-9 + R-10). Those three anchors are the highest-leverage available contributions this week.
