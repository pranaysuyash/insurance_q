# 09 — Anything else? (motto §0.1.1 standing prompt)

**Bundle:** 2026-07-30-project-wide-recon
**Doc I (Part 0 / standing-review prompt)** — the answer to the motto §0.1.1 standing prompt, recorded inline per the doctrine
**Author:** session-init agent
**Date:** 2026-07-30

---

## What is this doc?

`motto_v4.md` §0.1.1 mandates a standing-review prompt:

> *"At the end of every ADR, plan, review, or completion summary, ask and answer: 'Anything else?' ... The prompt catches cross-cutting concerns that per-item analysis missed. Document the answer inline in the artifact (an 'Anything else?' section), not just in chat."*

This is the project-wide answer. (The workstream-scope answer lives in `docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/09-anything-else.md`.)

## Direct answer

**Yes — twelve project-wide items the per-doc analysis missed. They live below.**

### 9.1 The project has two parallel doctrine vocabularies ("doctrine stack" vs "first-principles audit")

The doctrine stack (constitution, wedge, commercial, ADR-2026-07-29-02) is the *current* terminology. The "first-principles" terminology from the 2026-07-23 UX audit and 2026-07-28 naming session is partly superseded but still appears in older docs. Future readers will encounter both; cross-walking matters. The Addendum 2026-07-29 layers in `UX_AUDIT_FIRST_PRINCIPLES.md` does most of the work; project-wide future docs should pick one term.

### 9.2 The motto versioning story is operational, not just historical

`motto_v4.md` §0.17 (one-canonical-motto rule) is itself a recently-added rule (2026-07-19). Future motto versions trigger a project-wide rename + git-history-preserve workflow that operators may not have seen run. The first such event will reveal operational gaps; future sessions should confirm that agent-start install hooks (`tools/agent-start` etc.) handle the rename correctly and that `attest_motto.py` runs as expected.

### 9.3 The pattern-families doctrine (ADR-2026-07-29-02 §0.12.3) has not yet been operationalised project-wide

Three pattern families were introduced: substrate extension (new nullable columns + new extractors + version bump + four-face verification contract + launch-claim registry entry); privacy policy per surface; data-handling policy per third-party integration. **These are doctrine**, not yet observed as project-wide practice. A future audit could check whether new features created in this period apply the families uniformly; the present bundle cannot observe that because no new features were created.

### 9.4 The launch-claim registry location is suggested but not surfaced

`motto_v4.md` §0.11.1 says the registry lives in `docs/launch_claims/`. README cross-references launch-claim registry. ADR-2026-07-19-09 establishes the evidence-backed contract that the registry enforces. But this session did not surface the registry content (read paths included `motto_v4.md`, `DECISION_LOG.md`, `README.md`, `DESIGN.md`, the constitution files, the wedge, the commercial boundary, ADR-2026-07-29-02, ADR-2026-07-21-01 user journey map, ADR-2026-07-19-08 cut/keep/finish, and the strategic assessment — but **not** `docs/launch_claims/` directory). It exists; its content is unverified by this session.

**Recommendation:** future project-wide audit should read `docs/launch_claims/` and confirm it tracks every public claim with enforcing test + Tier 3+ evidence. Open question OQ-6 covers this.

### 9.5 The `coverwise_native_mobile_platform_store_readiness_audit_2026-07-21.md` (rephrased 2026-07-29) deserves project-wide attention

The doc title says "native mobile platform store readiness audit." That is *exactly* the gap R-17 (iOS deployment) tracks. The audit likely enumerates Android vs iOS launch readiness, store-listing commitments, and review-process pitfalls. The bundle did not read it in depth; it's a known-but-not-deeply-surfaced reference.

### 9.6 The doctrine-stack reconciliation ADR (ADR-2026-07-29-02) contains 13 specific conflict resolutions that have not been verified as observed

ADR-2026-07-29-02 §4.1–§4.13 resolves 13 specific conflicts (comparison-=OUT→IN, evidence-tier-overclaim correction, demo-policy reclassification, etc.). **The bundle did not verify each resolution is currently observed in code or UI.** For example, ADR-2026-07-29-02 §4.1 makes owned-policy comparison IN-the-wedge; the code path on `mobile/lib/screens/policy_comparison_screen.dart` would need audit to confirm. This workstream did not do that audit.

**Recommendation:** a future project-wide audit could check each ADR-2026-07-29-02 §4.X resolution against current code/UI state; not in scope here.

### 9.7 The retro-decisions (2026-07-18-XX) treated shipped work — and adopted motto §0.12.1 (append-only update logs) — but the *signature* of those retro-decisions could be questioned

Retroactive decisions are a useful pattern: the code is on `main`; the rationale is captured. But "retroactive" decision records are sometimes uncomfortable because: (a) the operator's sign-off is recorded after the work shipped; (b) the addendum discipline may be enforced selectively; (c) the temptation to re-litigate old decisions increases if the rationale is captured separately. The project has used this pattern correctly so far; future readers should preserve the discipline.

### 9.8 The "Anything else?" pattern is itself a project-wide discipline worth codifying into templates

`motto_v4.md` §0.1.1 specifies the standing prompt. The "Anything else?" sections are present in MANIFEST, in the workstream bundle's 09, in this doc, and in Past ADRs that the user instruction explicitly asked for ("anything else?" review on 2026-07-19). The template could be standardised: a footer/section called "Anything else?" with documented intent and required content. Currently, the prompt is non-optional-but-non-enforced; codifying it would catch drift.

### 9.9 The seven parallel-agent edits visible in this session represent a project-wide workstream

This session observed 10 files modified by a parallel agent (456+/189- lines, mostly auth + workspace + pubspec). That is a substantial workstream that affects multiple modules. No ADR yet exists for the parallel-agent's migration to Riverpod service DI (which retro-Decision 2026-07-22-02 / ADR-2026-07-22-02 says is Proposed). The 10-file diff may or may not be the ADR-2026-07-22-02 land. **No way to know without comparing.**

**Recommendation:** future session reads ADR-2026-07-22-02 in full and compares to the in-flight diff. If the diff implements ADR-2026-07-22-02, that is a partial-sign-off signal worth recording. If it implements something else, that is a new architecture decision that needs its own ADR.

### 9.10 The "anything else?" pattern from 2026-07-19 produced 4 additional ADRs (ADR-13, -14, -15, -16, -17, -18, -19, -20, -21, -22, -23, -24, -25)

The historical record at `docs/decisions/README.md` "Future ADRs written (per operator's 'anything else?' review, 2026-07-19)" lists 13 Accepted or Proposed ADRs added because the operator asked "anything else?" and the discussion surfaced concrete needed decisions. That single prompt produced ~13 ADR candidates in one review session. **The standing prompt is therefore load-bearing**: when invoked deliberately, it has generated the project's largest single burst of decision records.

**Implication for this bundle:** the prompt was invoked once (in MANIFEST + 09 of workstream bundle + this 09). It surfaced items 9.1–9.12 above. If the operator invokes it again tomorrow, the bundle will look different.

### 9.11 The session covered two bundles at different scopes

The workstream bundle (`docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/`) is a single-feature verification with 10 files. This project-wide bundle is a project-wide Part 0 + Part 1 + Part 8 attempt with 9 files written in this single session. The two bundles have *different scope, different audience, different roles*: the workstream bundle is a handoff for future feature maintainers; this project-wide bundle is a handoff for future operator-level decisions.

A future session could merge them or keep them separate. The workstream bundle is more thorough (it ran tests, made a real disposition); this project-wide bundle is broader (it covers the whole project). Both belong in the discovery/`docs/planning/discovery/` tree.

### 9.12 The session exhausted the operator's patience around the "full thing" question

The operator's first message asked the agent to do "the full thing, not just Part 0." The agent (in the previous answer of this same session) executed Parts 0–7 for the share-gate workstream only. Then the operator re-asked, "so why did you not [do the full thing]?" The agent clarified scope; the operator chose "project-wide full cycle." This bundle implements that choice — but it does so at the speed and depth of a single session, not a multi-session project.

**A candid note:** Parts 2, 8, 9, 10, 11, 12, 13, 14, 15, 16 at project scope would each constitute real work. Phase 2 (Parts 1–7) and Phase 3 (Parts 8–16) of this bundle's plan are written but not executed in this session. The next operator session can pick up at `10-part1-mission-restatement.md` and continue; the file is referenced in this MANIFEST's bundle layout but does not yet exist on disk.

## What this bundle does *not* cover

- Live deployment evidence (`tools/deploy_cloud_run.sh` execution logs)
- Test-suite run output (other than the share-gate trio verified in the workstream bundle)
- Code coverage numbers (`flutter test --coverage`)
- Product analytics events (`SELECT * FROM analytics_events LIMIT 10`)
- Specific iOS App Store Connect state
- `docs/launch_claims/` content (not read in this session)
- Detailed mobile screen flow audit (Buffy's `FLOW_AND_SCREEN_AUDIT.md` is referenced but not re-read)
- `coverwise_native_mobile_platform_store_readiness_audit_2026-07-21.md` (not read in this session)

## Closing

The single highest-leverage contribution the operator can make this week is **G-1 / OQ-1 / R-1 — sign off on `ADR-2026-07-29-02` and the proposed constitution in a single dated Update Log entry**. That single act unlocks downstream decisions on pricing, comparison, demos, camera, partnerships, and substrate-extension completeness. It would also flip the constitution from "Proposed" to "Accepted," enabling Parts 11 (Continuous Documentation) and 12 (Change Traceability) at the regulatory level rather than the directional level.

---

*Per motto §0.1.1: evidence that this prompt matters.* In the past two answer cycles of this session alone, the prompt has surfaced (a) the bundle-vs-plan-mode artifact split, (b) the doctrine-stack ratification as highest-leverage opening, (c) the four retro-decisions from the prior "anything else?" review, (d) the unbinding-of-launch-claim-registry location question. Each is a structural insight per item, not per answer.
