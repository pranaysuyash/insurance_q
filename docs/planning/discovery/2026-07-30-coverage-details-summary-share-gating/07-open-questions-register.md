# 07 — Open-Questions Register

**Bundle:** 2026-07-30-coverage-details-summary-share-gating
**Doc G (Part 0)** — open questions raised during Part 0 discovery
**Author:** session-init agent
**Date:** 2026-07-30

---

## Reading guide

For each question:

- **Why it matters** — concrete impact on this workstream or future work
- **Available evidence** — what we already know
- **Current assumption** — what we are operating on until told otherwise
- **Confidence** — how sure we are of that assumption
- **Risk** — what could go wrong if the assumption is wrong
- **Blocks implementation?** — yes / no
- **Decision owner** — who should answer

---

## OQ-1 — Is ADR-2026-07-29-02 (and the proposed Product Constitution) signed off?

- **Why it matters:** Without explicit sign-off in the ADR's Update Log, the constitution remains "Proposed" — directional but not the upstream doctrine. Future doctrine-stack decisions depend on this anchor.
- **Available evidence:** Both docs (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` and `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md`) read *"Proposed, awaiting operator sign-off."* No Update Log entry recording acceptance.
- **Current assumption:** Treat as *Proposed* (directional, not binding) for this workstream.
- **Confidence:** Medium — the absence of an Update Log entry is itself a signal, but the operator may have signed off out-of-band.
- **Risk:** If it IS signed off, the layering in this bundle's classifications could be tighter; not a defect.
- **Blocks implementation?** No for this workstream (mechanical alignment).
- **Decision owner:** Pranay (operator).

## OQ-2 — Is the operator's intent broader than mechanical alignment?

- **Why it matters:** The IDE-open file is `coverage_details_summary_screen_test.dart`. Possible interpretations:
  - (a) Mechanical alignment (verify + smallest delta) — what the plan assumed.
  - (b) Expand coverage (add cases for expired plans, snackbar dismissal, etc.).
  - (c) Refactor the screen (extract sections into smaller widgets).
  - (d) Add deep-link route for the screen.
- **Available evidence:** Plan file approved as-is (auto-accept). Operator comment: *"not just part 0, its the full thing."*
- **Current assumption:** Option (a) — mechanical alignment only.
- **Confidence:** Medium. The phrasing "full thing" could mean (b)/(c)/(d) instead.
- **Risk:** If intent is broader, this workstream under-delivers; operator can re-prompt.
- **Blocks implementation?** No — the bundle records the assumption and remains honest.
- **Decision owner:** Operator.

## OQ-3 — Will the parallel-agent refactor land the auth_service.dart defensive parse soon?

- **Why it matters:** This workstream's WS-1 verification is blocked until auth_service.dart compiles. The visible diff already contains the defensive parse form (`if (createdAt is DateTime ? createdAt : DateTime.parse(createdAt as String)` style).
- **Available evidence:** File mutating mid-session (line number shifted 302 → 303; comment modified). Diff against HEAD shows 315 insertions spanning the file.
- **Current assumption:** The refactor will land within minutes-to-hours, but specific timing is unknown to this session.
- **Confidence:** Low on timing. High on intent (the defensive parse is in the diff).
- **Risk:** If refactor stalls, this workstream's WS-1 cannot complete.
- **Blocks implementation?** Yes for WS-1; no for documentation (this bundle can be written without re-running tests).
- **Decision owner:** Parallel-agent session (out-of-process) or operator (if escalation desired).

## OQ-4 — Is there a documented rationale for sharing the substring assertion in test 1?

- **Why it matters:** `find.textContaining('Export is available on Plus')` is a weaker contract than exact match. It's not necessarily wrong — substring flexibility is sometimes intentional (allows copy tweaks without test churn). Without a rationale, future agents might "tighten" the assertion and break a designed-flexibility contract.
- **Available evidence:** No source comment or commit message visible to this session.
- **Current assumption:** The substring is intentional leniency (allows adding "and Family plans" without test edits).
- **Confidence:** Medium (it's plausible but not documented; future agents will assume either way).
- **Risk:** If the design intent is *exact-match*, the substring assertion is masking copy drift. If the design intent is *substring-flex*, future "tightening" would be a regression.
- **Blocks implementation?** No (out of scope).
- **Decision owner:** Whoever last touched the test (likely the test author; unrecorded).

## OQ-5 — Should `_shareSummary` emit analytics on share attempts and gate displays?

- **Why it matters:** Currently no telemetry on share gate displays, gated-tap upgrades, or share completions. Operators can't measure free→plus conversion via share gate without it.
- **Available evidence:** `_shareSummary` source has no `AnalyticsService.track(...)` calls. `_trackEvent` exists in `auth_service.dart` after the parallel refactor — the pattern is established.
- **Current assumption:** Out of scope for this session; worth flagging in follow-up.
- **Confidence:** High (it's a clear gap, not a contested design).
- **Risk:** If done unobserved, ship feature without measurement.
- **Blocks implementation?** No (out of scope).
- **Decision owner:** Future telemetry hardening session.

## OQ-6 — Should `CoverageDetailsSummaryScreen` register a `/coverage-details-summary` deep-link route?

- **Why it matters:** Currently unreachable via deep links; only via direct `MaterialPageRoute` pushes from `dashboard_screen.dart` and `policy_detail_screen.dart`. Adding a route requires a contract decision (documentId → fetch summary).
- **Available evidence:** No `/coverage-details-summary` entry in `main.dart.routes`. Grep confirms no other reference.
- **Current assumption:** Out of scope; intentional architecture (screen takes PolicySummary object).
- **Confidence:** High (it's clearly intentional today).
- **Risk:** If the operator wants deep-link reachability, the contract decision bleeds back to the WS-1 scope and requires more than mechanical alignment.
- **Blocks implementation?** No for this session.
- **Decision owner:** Future deep-linking workstream or operator.

## OQ-7 — Was this workstream superseded by the parallel-agent's broader refactor?

- **Why it matters:** The parallel agent's 456-line / 10-file refactor is substantial. If their work covers auth/workspace/billing/persistence in a way that *subsumes* the share-gate workstream's intent, this bundle is mooted.
- **Available evidence:** No commit messages or in-flight branch names in this session.
- **Current assumption:** The refactor is focused on auth/workspace foundations, not on the share gate per se. The gate path remains relevant.
- **Confidence:** Low (could go either way).
- **Risk:** If superseded, the bundle's WS-1/WS-2 plan is wasted.
- **Blocks implementation?** No.
- **Decision owner:** Operator.

## OQ-8 — Does the operator want gate-reason copy edited for product-clarity reasons?

- **Why it matters:** The current gate-reason is `'Export is available on Plus and Family plans.'` — concise but slightly stiff. A/B testing or voice-tone revisions could be on the table.
- **Available evidence:** No A/B test framework in this codebase that I can see. `DESIGN.md` voice section says "Direct, honest, technical but accessible, conservative."
- **Current assumption:** Out of scope; voice matches the current copy.
- **Confidence:** High.
- **Risk:** Minor copy disagreement.
- **Blocks implementation?** No.
- **Decision owner:** Future copy/voice iteration session.

---

## Summary

| ID | Severity | Blocks impl? | Owner |
|---|---|---|---|
| OQ-1 | Medium | No | Operator |
| OQ-2 | Medium | No | Operator |
| OQ-3 | High (timing) | Yes (WS-1) | Parallel-agent / operator |
| OQ-4 | Low | No | Test author / unknown |
| OQ-5 | Medium | No | Future session |
| OQ-6 | Low | No | Future session |
| OQ-7 | Low | No | Operator |
| OQ-8 | Low | No | Future session |

## Anything else? (motto §0.1.1)

OQ-3 is the only one that gates this session's WS-1 evidence. The other seven are documentation-grade questions that do not block this bundle's authoring and are listed here so future sessions can pick them up without rediscovering.
