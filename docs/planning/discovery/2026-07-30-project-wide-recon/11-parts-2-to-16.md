# 11 — Parts 2-16 (Project-Scope Planning Skeleton)

**Bundle:** 2026-07-30-project-wide-recon
**Parts 2-7 + 8-16 skeleton** — what each part would do at project scope, what was actually executed in this session, what is deferred
**Author:** session-init agent
**Date:** 2026-07-30

---

## What this document is

The system prompt requires Parts 2-16 at project scope. This session's Part 0 (Docs A-J) covered project discovery. Part 1 restated mission. **Parts 2-16 are execution- and integration-oriented** — they require either authorised implementation work or formal cross-system integration review.

This single document captures, for each of Parts 2-16:

- **What the part requires** (per the system prompt).
- **What was executed in this session** (Part 0 only + Decision 7 workstream verification).
- **What is deferred** (operator authorisation needed; multi-session work needed).
- **The opening question for the operator** — what to do next.

The deferred items are listed because pretending they were completed would violate motto §0.7 (AI output boundary rule) and §0.4.1 (confidence gate).

---

## Part 2 — Revalidate Before Implementation

**Requires:** before any code change, re-read applicable scoped instructions; re-read approved execution brief; re-check parallel work; re-check affected contracts and tests; re-check open blockers; re-check dependency and migration assumptions; re-check ownership boundaries; re-check whether new evidence changes the approved strategy.

**Executed this session:** Workstream-scope Part 2 was executed for Decision 7 (re-read trio + parallel-agent diff + polling + blast-radius check). Project-scope Part 2 was **not** systematically executed because no implementation was authorised.

**Deferred:** a project-scope revalidation session would re-check the 15 dirty files + 6 untracked items against doctrine stack + decision index. Pre-existing parallel-agent work is not revalidated for sign-off; only the canonical entities this session touched are revalidated.

**Operator question:** is doctrine-stack sign-off (R-1, OQ-1) the next project-scope move? If yes, revalidation would lock onto that.

## Part 3 — Core Implementation Rules

**Requires:** a statement of which rules apply. Project-wide, all 23 motto clauses + 12 constitution principles + 8 project-specific first principles apply.

**Executed this session:** rules were *cited* in MANIFEST, this bundle's docs, and the workstream bundle. They were not *applied* to new project-scope implementation because no new project-scope implementation occurred.

**Deferred:** an explicit "implementation rules applied" doc would document per-rule conformance for any future project-scope change.

**Operator question:** what project-scope change is the operator authorising?

## Part 4 — Decompose the Approved Work

**Requires:** break approved mission into connected workstreams, each with objective + user outcome + affected modules + boundaries + dependencies + risks + deliverables + acceptance criteria.

**Executed this session:** workstream bundle decomposed the share-gate verification into WS-1, WS-2 (conditional), WS-3 (conditional), WS-4. Project-scope decomposition was not attempted.

**Deferred:** project-scope decomposition depends on which scope the operator authorises. Three candidate decompositions exist:

- (a) "Cut to 15 screens" → ~3 workstreams.
- (b) "Doctrine sign-off + Wedge adoption" → 1 workstream + decisions.
- (c) "Backend granularity fix" → 1-2 workstreams.
- (d) "Legal/copy remediation" → ~5 workstreams mapped to the priority doc.

**Operator question:** which scope does the operator want decomposed first?

## Part 5 — Specialist-Agent Execution

**Requires:** assign focused agents only after ownership and dependencies are established. Every specialist receives doctrine + first principles + ADRs + approved brief + scope + exclusions + architecture + files + contracts + risks + acceptance criteria + evidence requirements.

**Executed this session:** the workstream bundle ran the share-gate verification in a single-agent mode (me), without specialist fan-out. Project-scope work did not fan out.

**Deferred:** fan-out project-scope work requires operator authorisation per workstream.

**Operator question:** if multiple workstreams are active simultaneously, does the operator want parallel specialist agents with explicit handoffs? That would require building owned-agent runbooks first.

## Part 6 — Independent Critic Roles

**Requires:** every material deliverable reviewed by an independent critic with adversarial lens.

**Executed this session:** every Doc A-I was self-critic'd in MANIFEST's "Anything else?" + Phase plan. No second-agent review.

**Deferred:** project-scope multi-agent critic setup is out of scope for one session.

**Operator question:** does the operator prefer to review the bundle directly, or want a second agent to review first?

## Part 7 — Iterative Quality Loop

**Requires:** for every workstream: run static checks → tests → regression → manual/device/E2E → measure perf → inspect failures → capture evidence → update docs → submit to critic → rank findings → fix justified findings → re-test → re-submit → record.

**Executed this session:** workstream bundle completed the loop for share-gate verification (Tier 1+2+3 evidence captured in MANIFEST). Project-scope iterations are out of scope.

**Deferred:** project-scope iterations depend on which workstream is authorised.

**Operator question:** which workstream, if authorised, would the operator want to start with?

## Part 8 — Project-Specific Quality Scorecard

**Requires:** baseline vs target per quality dimension (vision alignment, motto alignment, first-principles alignment, product coherence, user value, core-flow completeness, functional correctness, data integrity, architecture, usability, visual quality, interaction quality, accessibility, performance, reliability, security, privacy, maintainability, scalability, testability, test quality, observability, error handling, edge cases, platform compatibility, documentation, integration, migration safety, operational readiness, deployment readiness).

**Executed this session:** see `17-part8-quality-scorecard.md` (to be written). Scorecard exists at the level of *evidence I read* — not at the level of *measurement I performed*. Several dimensions are scored Tier 1 only.

**Deferred:** project-scope measurement — `flutter test --coverage`, `flutter analyze` over the full mobile tree (not just the trio), `pytest --cov` over the full backend, Sentry/analytics logs sample, operator-dashboard data sample, deployment evidence. None executed.

**Operator question:** does the operator want scorecard completion before or after a project-scope change is authorised?

## Part 9 — Reference and Benchmark Comparison

**Requires:** pick references based on the project's vision and quality standard; compare outcomes (before-and-after, side-by-side, blind A/B, interaction comparisons, etc.); use applicable evidence with the operator explaining why one outcome is stronger.

**Executed this session:** none directly. Buffy's strategic assessment 2026-07-17 cites "348 tests passing" as a comparable metric; README cites "636 Flutter tests, 378 backend tests" — these are partial references. No A/B comparison of outcomes.

**Deferred:** project-scope references are out of scope without benchmark targets defined.

**Operator question:** does the operator want a competitor / insurance-app reference comparison future session?

## Part 10 — Integration Review

**Requires:** cross-workstream end-to-end; cross-module consistency; shared state; data ownership; contract compatibility; error propagation; auth; persistence; sync; naming; terminology; visual coherence; interaction coherence; perf interactions; security boundaries; privacy boundaries; dependency direction; migration correctness; backward compatibility; recovery; observability; deployment behaviour; dead code; duplicate systems; documentation accuracy; motto_v4 alignment; product-vision alignment.

**Executed this session:** "End-to-end C-1 / C-2 / C-3 data flows" in `04-current-state-architecture.md` is the closest analogue. Real cross-workstream integration review would require real workstreams.

**Deferred:** integration review is meaningless without executed workstreams.

**Operator question:** not applicable until a project-scope change authorises workstreams.

## Part 11 — Continuous Documentation

**Requires:** documentation is part of implementation. Maintain decision log, risk register, open-questions register, execution brief, implementation plan, change log, test plan, test evidence, migration plan, rollback plan, recovery plan, operational runbook, deployment notes, known limitations, future work, user-facing and contributor documentation. Keep aligned with implementation.

**Executed this session:** this entire bundle IS the continuous-documentation output for project scope at Part 0. The MANIFEST index + cross-link block + Phase plan is the maintenance scheme.

**Deferred:** for project-scope implementation, a future session would keep the bundle updated each commit.

**Operator question:** not applicable at Part 0; future sessions inherit the maintenance scheme.

## Part 12 — Change Traceability

**Requires:** every material change traceable to approved requirement + user outcome + motto principle + first principle + applicable project instruction + decision record + files changed + behaviour changed + architecture changed + data changed + contracts changed + dependencies changed + tests added/changed + documentation updated + risks introduced + risks reduced + validation evidence + builder + critic + approval status.

**Executed this session:** workstream Decision 7 carried all 12 fields. Project-scope Decision 8 is a documentation-only decision; its traceability per the schema is in `06-decision-log-append.md` of this bundle.

**Deferred:** material change traceability applies per change.

**Operator question:** not applicable at Part 0.

## Part 13 — Deviation Management

**Requires:** distinguish minor deviation (proceed + document) from material deviation (stop + return for approval).

**Executed this session:** no deviation at workstream level (Tests passed cleanly once auth_service.dart compile cleared). No material deviation at project-scope level (no implementation).

**Deferred:** deviation management applies when deviations occur.

**Operator question:** not applicable yet.

## Part 14 — Hard Completion Gates

**Requires:** no "done" claim until: approved scope implemented; aligned with motto_v4; critical acceptance criteria pass; no unresolved blocker; no critical-severity defect; automated tests pass; important user journeys pass E2E; regression-tested; runtime inspected; failure states tested; recovery tested; perf measured; a11y checked; security reviewed; privacy reviewed; migrations validated; independent critic approves; integration review passes; docs match implementation; traceability complete; compromises explicit; rollback instructions exist; another person can run/review/maintain/deploy/use.

**Executed this session:** workstream Decision 7 + 8 satisfy Part 14 at *documentation* level. The follow-on Parts 2-16 deferred items remain unsatisfied at *implementation* level.

**Deferred:** Part 14 satisfaction at *implementation* level requires operator authorisation and multi-session execution.

**Operator question:** do you want this bundle's status (Docs A-J + Parts 1, 11-13 documented) to count as "Part 14 satisfied at documentation discovery level," or do you want stricter closure at implementation level?

## Part 15 — Handling Constraints and Impossible Targets

**Requires:** do not pretend a goal is achieved when evidence says otherwise. Report target, constraint, evidence, achieved, gap, user impact, technical impact, shipping risk, alternative, additional resources, additional decision, motto violation, temporary vs structural.

**Executed this session:** see `09-anything-else.md` Item 9.12 — this very Parts 2-16 skeleton is a Part 15 report. The Parts 8-16 execution is constrained by session scope and operator authorisation. They are not achieved.

**Deferred:** Part 15 satisfaction requires operator acknowledgement of the constraint.

**Operator question:** same as Part 14's operator question — is the Parts 8-16 deferral accepted, or do you want to see them executed now?

## Part 16 — Final Delivery

**Requires:** completed implementation + final approved project-specific mission + summary of discovered context + summary of governing instructions + motto_v4 interpretation + requirement-to-change mapping + user outcomes delivered + files/systems affected + architecture decisions + product decisions + data/contract changes + tests/validation evidence + runtime/visual evidence + before-and-after comparisons + quality scorecard + specialist-agent contributions + independent critic findings + integration-review findings + documentation created/updated + deviations from approved plan + known limitations + unresolved risks + migration instructions + rollback/recovery instructions + next highest-leverage improvements.

**Executed this session:** the bundle's MANIFEST + acceptance contract + handoff log + Parts 1-15 (this skeleton) IS the project-scope final delivery at *documentation discovery* level. No implementation was delivered; no quality scorecard was completed; no integration review occurred.

**Deferred:** full Part 16 closure at implementation level.

**Operator question:** same as Parts 14 and 15.

---

## Summary — what was executed, what is deferred

| Part | Executed | Deferred |
|---|---|---|
| 0 | ✓ (Docs A-I, 9 files) | — |
| 1 | ✓ (mission restatement, 10) | — |
| 2 | partial (workstream-level) | project-scope |
| 3 | partial (rules cited, not applied to new code) | rule-application layer |
| 4 | partial (workstream decomposed) | project-scope decomposition |
| 5 | partial (single-agent mode) | specialist fan-out |
| 6 | partial (self-critic) | second-agent critic |
| 7 | partial (workstream loop closed) | project-scope loop |
| 8 | not yet drafted (17 placeholder) | full scorecard |
| 9 | partial (Buffy's strategic assessment cited) | explicit reference comparison |
| 10 | partial (data flows + auth state in 04) | full integration review |
| 11 | ✓ (this bundle is the discovery output) | updates as changes land |
| 12 | ✓ (Decisions 7 and 8 carry all 12 fields) | per future change |
| 13 | ✓ (no deviations this session) | per future deviation |
| 14 | partial (closure at doc-discovery level) | closure at implementation level |
| 15 | ✓ (this doc IS a Part 15 report) | per future constraint |
| 16 | partial (final delivery at doc-discovery level) | final delivery at implementation level |

---

## Anything else? (motto §0.1.1)

The deferral pattern across Parts 2-16 is consistent: **every Part's deferred item requires operator authorisation to extend beyond documentation discovery**. The bundle cannot fabricate implementation. It can document what *would* be done for each Part if authorisation were given.

The next operator action that closes the largest number of deferred parts at once: **authorising a single project-scope change** (e.g., fix the 6 dismissed test failures, or cut to 15 screens, or sign off the doctrine stack). With one authorisation, Parts 4, 5, 7, 12, 14, 15, 16 collapse from "deferred" to "executable in next session."
