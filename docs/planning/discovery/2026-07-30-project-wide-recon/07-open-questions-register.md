# 07 — Open-Questions Register (Project-Wide)

**Bundle:** 2026-07-30-project-wide-recon
**Doc G (Part 0)** — project-wide open questions
**Author:** session-init agent
**Date:** 2026-07-30

---

## Reading guide

For each question:

- **Why it matters** — concrete impact at project level
- **Available evidence** — what we have
- **Current assumption** — what we operate on
- **Confidence** — Low / Medium / High
- **Risk** — what could go wrong
- **Blocks implementation?** — yes / no
- **Decision owner** — who should answer

---

## OQ-1 — Is `ADR-2026-07-29-02` (and the proposed Product Constitution) signed off?

- **Why it matters:** Highest-impact open question at project level. Until answered, the doctrine stack is directional only; downstream pricing/comparison/demos/camera decisions are scoped provisional.
- **Available evidence:** Both constitution and ADR read "Proposed, awaiting operator sign-off." No Update Log entry recording acceptance.
- **Current assumption:** Treat as *Proposed* for project-wide work.
- **Confidence:** Medium. Operator may have signed off out-of-band.
- **Risk:** If signed off, downstream rules tighten (no flag day for code change); not a defect.
- **Blocks implementation?** No for this bundle; yes for product-boundary decisions.
- **Decision owner:** Operator.

## OQ-2 — What is the live status of the 6 "dismissed" test failures?

- **Why it matters:** Per Buffy, six test failures were dismissed without root-cause analysis. Per motto §6 / retro-Decision 2026-07-18-05, this is a launch-blocking gap.
- **Available evidence:** Strategic assessment 2026-07-17 §2.2 names the 6 tests.
- **Current assumption:** At least one of them is a real fix; timeouts likely real infrastructure failures.
- **Confidence:** Medium-High.
- **Risk:** If ignored at launch, customer-facing test breakage (e.g., confidence badge rendering).
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Future test-honesty session.

## OQ-3 — Is the ProcessingStatusScreen backend-granularity mismatch a high-priority fix?

- **Why it matters:** Buffy lists it as P0 launch blocker; Constitution P3 (abstention) and P4 (don't lie) both forbid simulating truth.
- **Available evidence:** Buffy §2.3; not otherwise verified.
- **Current assumption:** Yes, high-priority fix before launch.
- **Confidence:** High.
- **Risk:** Customer-visible lying UI.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Future backend-state workstream.

## OQ-4 — What is the What-If Calculator's intended disposition?

- **Why it matters:** Code exists; constitution says no; ADR-2026-07-19-13 says no.
- **Available evidence:** `mobile/lib/screens/what_if_calculator_screen.dart` exists; route registered in `main.dart`; on docs/review/exploration_map.md line 311 listed for removal.
- **Current assumption:** Remove or refactor into Coverage Adequacy (cited-only).
- **Confidence:** High.
- **Risk:** Constitution violation lives indefinitely.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Future scope-cut or adequacy-workstream.

## OQ-5 — How much scope cut is actually feasible for v1?

- **Why it matters:** Buffy §6 recommends cut to 15 screens; constitutional P12 supports; cut/keep/finish framework exists (retro-Decision 2026-07-19-08).
- **Available evidence:** 32 screens enumerated; recommended cut list in Buffy §2.4.
- **Current assumption:** Feasible with multi-commit workstream; not a single-session change.
- **Confidence:** Medium.
- **Risk:** Inaction means ongoing maintenance burden.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Operator (drives scope decisions); future workstream executes.

## OQ-6 — Has the launch-claim registry (`docs/launch_claims/`) reached steady state?

- **Why it matters:** `motto_v4.md` §0.11.1 requires every customer-facing claim to map to a registry entry with enforcing test. The session did not surface `docs/launch_claims/` content.
- **Available evidence:** Path mentioned; not read.
- **Current assumption:** Partial; each public claim registered; some gaps remain.
- **Confidence:** Low (didn't read).
- **Risk:** Unverified launch claims.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Future launch-readiness session.

## OQ-7 — Is the legal-risk copy remediation complete?

- **Why it matters:** `legal_risk_copy_audit_2026-07-24.md` flags 83 files / 1,793 lines across Categories A–G. Two remediation docs exist (2026-07-25 priority + remediation). Implementation status unclear.
- **Available evidence:** Audit doc + two remediation docs.
- **Current assumption:** In progress; not complete.
- **Confidence:** Medium.
- **Risk:** Customer-facing copy carries legal risk.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Future legal/remediation session.

## OQ-8 — Are the substrate extensions (Coverage Check-in, Adequacy, Family Map, Claim Vault, Partnerships) at parity with their ADRs?

- **Why it matters:** The 14 ADR-2026-07-19-XX define substrate and privacy/data-handling policies. Implementation completion varies.
- **Available evidence:** `mobile/lib/models/policy_summary.dart` shows 6 type-specific groups (motor, travel, life, home, health, marine) + 3 deferred (cyber, liability, pet). Check-in / adequacy / family / vault / partnerships not directly visible in that file.
- **Current assumption:** Mixed; some substrate extensions implemented; others pending.
- **Confidence:** Medium.
- **Risk:** Long-term wedge incompleteness.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Future substrate-completion workstream.

## OQ-9 — Is `AGENTS.md` (or equivalent) needed at repo root?

- **Why it matters:** Hygiene. Agents that bypass `agent-start` lose doctrine-stack signposting.
- **Available evidence:** Missing at root and nested.
- **Current assumption:** Yes, needed.
- **Confidence:** High.
- **Risk:** Future agent re-derives doctrine hierarchy.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Future hygiene PR.

## OQ-10 — Will the live deployment happen in this period?

- **Why it matters:** README claims "not yet deployed." `tools/deploy_cloud_run.sh` exists.
- **Available evidence:** README.
- **Current assumption:** No for this bundle.
- **Confidence:** High.
- **Risk:** None immediate.
- **Blocks implementation?** No.
- **Decision owner:** Operator / deployment workstream.

## OQ-11 — Is Hindi (`app_hi.arb`) production-ready?

- **Why it matters:** Legal-risk audit applied to Hindi l10n strings; not specifically read here.
- **Available evidence:** Path mentioned in legal-risk audit scope.
- **Current assumption:** Mixed; same risks as English copy.
- **Confidence:** Medium.
- **Risk:** Customer-facing Hindi copy carries same risks as English.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Future Hindi voice/copy session.

## OQ-12 — What is iOS App Store readiness?

- **Why it matters:** APK ready per README; iOS pending per README roadmap.
- **Available evidence:** README.
- **Current assumption:** Not this period.
- **Confidence:** High.
- **Risk:** Half the mobile market unreachable at launch.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Operator / deployment workstream.

## OQ-13 — Have any retro-decisions been updated since their original record date?

- **Why it matters:** Several retro-decisions record "accepted rev 1, operator sign-off 2026-07-19". Update-log discipline says append, not edit.
- **Available evidence:** Decision index shows rev-2 entries for some; others remain rev-1.
- **Current assumption:** Some have appends; some don't.
- **Confidence:** Medium.
- **Risk:** Documentation drift.
- **Blocks implementation?** No.
- **Decision owner:** Future doc-hygiene review.

## OQ-14 — Are there any uncovered operator trust-model rules that haven't been implemented?

- **Why it matters:** ADR-2026-07-19-12 establishes 6 roles + audit + reason-required + TTL + revocation. The operator trust model is the entry point for sensitive-data access.
- **Available evidence:** ADR file exists, but implementation details not deeply audited in this session.
- **Current assumption:** Mostly implemented (Phase 0 shared-secret) with full RBAC deferred.
- **Confidence:** Low.
- **Risk:** Operator RBAC deferral might be hiding privacy/security debt.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Future Security Phase 1 workstream.

## OQ-15 — What's the implementation status of long-term platform decision (Cloud Run + Supabase Postgres/pgvector/Storage)?

- **Why it matters:** `docs/planning/coverwise_long_term_platform_decision_2026-07-12.md` selects one Cloud Run FastAPI service. Live deployment status: "not yet per README."
- **Available evidence:** Long-term decision + README.
- **Current assumption:** Planned; not yet deployed.
- **Confidence:** High.
- **Risk:** None immediate.
- **Blocks implementation?** No.
- **Decision owner:** Operator / deployment workstream.

## OQ-16 — How do the *named* in-flight mobile refactors relate to canonical entities?

- **Why it matters:** 10 modified files in `mobile/` as of session start represent parallel-agent work. Some touch canonical entities (`auth_provider.dart`, `coverage_gap_screen.dart`, etc.); the relation to doctrine stack unclear.
- **Available evidence:** Diff stat showed 456/189 lines.
- **Current assumption:** Mostly infrastructure refactor (auth → workspace migration); not product-surface changes.
- **Confidence:** Medium-Low.
- **Risk:** If the refactor introduces scope expansion, it could violate §0.13.
- **Blocks implementation?** No for this bundle.
- **Decision owner:** Parallel-agent session / operator.

---

## Summary

| ID | Severity | Blocks impl? | Owner |
|---|---|---|---|
| OQ-1 | High | No (this bundle) | Operator |
| OQ-2 | High | No | Future test-honesty |
| OQ-3 | High | No | Future backend-state |
| OQ-4 | Medium | No | Future scope-cut or adequacy |
| OQ-5 | Medium | No | Operator + workstream |
| OQ-6 | Medium | No | Future launch-readiness |
| OQ-7 | Medium | No | Future legal/remediation |
| OQ-8 | Medium | No | Future substrate-completion |
| OQ-9 | Low | No | Future hygiene PR |
| OQ-10 | Informational | No | Operator / deployment |
| OQ-11 | Medium | No | Future Hindi voice/copy |
| OQ-12 | Medium | No | Operator / deployment |
| OQ-13 | Low | No | Future doc-hygiene |
| OQ-14 | Medium | No | Future Security Phase 1 |
| OQ-15 | Informational | No | Operator / deployment |
| OQ-16 | Medium | No | Parallel-agent / operator |

## Anything else? (motto §0.1.1)

The pattern: 16 open questions, 4 of them High severity, none directly blocking this bundle. They cluster into 4 categories: doctrine sign-off (1), implementation honesty (2-3), scope completion (4-5, 8), ops/launch-readiness (6, 7, 9-15), parallel-agent coordination (16). The single highest-leverage decision the operator could make this week is **OQ-1** (doctrine sign-off); everything else cascades from that anchor.
