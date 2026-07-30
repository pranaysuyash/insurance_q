# 10 — Part 1: Approved Project-Specific Mission (Restatement)

**Bundle:** 2026-07-30-project-wide-recon
**Part 1 restatement** — the mission as it stands at project scope
**Author:** session-init agent
**Date:** 2026-07-30

---

## Project at a glance

- **Canonical name:** CoverWise
- **Product category:** Insurance knowledge workspace (mobile-first, India-focused)
- **Platforms:** Flutter mobile (Android primary, iOS pending); FastAPI backend on Cloud Run; Supabase persistence; multi-payment (Dodo + Razorpay).
- **Target users:** policyholders who want to understand their insurance.
- **Primary user:** an Indian retail insurance customer who wants plain-language explanations of their own policies.
- **Secondary users:** family members, prospective buyers (post-purchase), insurance support teams.
- **Jobs to be done:** comprehend policies, organise by family member, find claims process, prepare neutral questions for the insurer, get renewal reminders.
- **Core value proposition:** *"Help people understand the insurance policy they already own — and never pretend to be something it is not (insurer, broker, advisor)."*
- **User promise:** the policy document is the source of truth; CoverWise shows you what your policy establishes, what it doesn't, and where each fact came from.
- **Core product loop:** see Constitution §2 (`user-owned policy → consent → secure import → completeness-aware processing → source-preserving normalisation → evidence and uncertainty → plain-language explanation → organisation → user verification → correction/export/replacement/retention/deletion`).
- **Long-term vision:** per Constitution §1 — durable wedge, no recommendations, no quoting, no underwriting, no brokering, no transacting, no claims representation.

## Current state (project-wide)

- **Code:** substantial mobile + backend; ~636 Flutter tests passing with 6 dismissed failures; ~378 backend tests passing.
- **Documentation:** mature layered doctrine (motto_v4 + constitution + wedge + commercial + 40+ ADRs + indexes).
- **Tests passing (workstream):** 6/6 share-gate tests + 32/32 regression tests + `flutter analyze` clean — this session's workstream contribution.
- **Tests passing (project):** unknown at this session; 6 dismissed failures per Buffy.
- **Deployment:** not yet (per README §"Launch status").
- **Doctrine stack:** all layers "Proposed" — awaiting operator sign-off on `ADR-2026-07-29-02`.

## Target state (project-wide)

- **Code:** clean, lean, doctrine-aligned; backend state-granularity honest; on-disk constitution-violators removed or gated.
- **Tests:** zero failures; every surface tested; deny-by-default surfaced with evidence.
- **Documentation:** doctrine stack ratified; cut/keep/finish applied; `AGENTS.md` present; legal doc source-of-truth consolidated.
- **Deployment:** Cloud Run service live; APK + iOS shipped; analytics events flowing; no critical errors.
- **Doctrine stack:** Accepted (operator sign-off on ADR-2026-07-29-02).

## Mission statement (this session's contribution)

> **Verify and document. No code change beyond what's already committed.** Confirm the share-gate test contract is canonically aligned, document the project-wide state at the level of doctrine stack + audit corpus + decision index, and surface actionable gaps + open questions + risks for future operator-driven work.

## Approved scope (project-wide)

- **In scope:** Part 0 discovery + Part 1 mission restatement + Doc A–J authoring at project scope.
- **In scope (workstream):** share-gate test verification (workstream bundle, complete).
- **Out of scope:** production code changes; new ADRs; commits to canonical files (DECISION_LOG.md Decision 7 is appended; project-root files otherwise untouched).
- **Out of scope (deferred):** Parts 2, 8-16 at project scope (operator authorisation required).

## User outcome (project-wide)

The bundle's outcome is **readability + decision-readiness** — a future operator or future agent can read these 9 files and understand: (a) what the project is, (b) why it is shaped that way, (c) what the existing gaps are, (d) what is open for decision, (e) what is at risk.

## Affected systems

- **Documentation:** `docs/planning/discovery/2026-07-30-project-wide-recon/` (this bundle, 9 files; untracked, not committed).
- **Decision Log:** canonical `DECISION_LOG.md` — Decision 7 appended (workstream); Decision 8 in the bundle (project-scope, optional append).
- **Existing parallel-agent work:** 15 dirty files preserved untouched.
- **No code or runtime changes.**

## Excluded systems

- Production code (mobile, backend, infra, scripts) — unchanged.
- Doctrine stack canon files (`motto_v4.md`, `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`, wedge, commercial, ADR-2026-07-29-02) — read-only.
- Decision index (`docs/decisions/README.md`) and 40+ ADR files — read-only.
- The 15 dirty files in working tree — preserved untouched.

## Behaviour to preserve

- The doctrine stack precedence hierarchy (motto_v4 > constitution > wedge > commercial > feature ADRs > code).
- The single-source-of-truth rule for cross-cutting concerns (entitlement, consent, billing, etc.).
- The constitution's irreducible loop.
- The 5-gate stack (A–E).
- The append-only update log discipline on ADRs.

## Motto and first principles

- **motto_v4.md** is the operating-system doctrine: §0 (whole answer), §0.3 / §0.3.1 (docs continuity / everything is a doc candidate), §0.4 (acceptance), §0.5 (evidence tiers), §0.6 (risk-based verification), §0.13 (scope expansion control), §20 (no AI co-author), §23 (parallel-editor hold).
- **Constitution** Gates A–E (proposed; directional until operator sign-off).
- **First principles (this project):** source-of-truth precedence; one canonical path per truth; evidence-graded confidence; risk-based verification; abstracted-responsibility boundaries; privacy by design; reliability at moment of need; long-term thinking ≠ maximalism.

## Applicable project instructions

- `motto_v4.md` (operating system).
- `docs/decisions/README.md` (decision discipline + ADR index).
- `README.md` (project overview + launch status).
- `DESIGN.md` (visual direction).
- `docs/launch_claims/` (referenced; content not surfaced in this session).

## Quality target

- Tier 1 (static inspection) for every claim made in this bundle.
- Tier 2 (tested) where appropriate (workstream bundle achieved Tier 1+2+3).
- Tier 3+ for any high-risk claims ("evidence-backed", "private", "verified", "offline-ready", "family-aware", "never shared").

## Constraints

- Read-only on doctrine canon files.
- Read-only on dirty parallel-agent work.
- No commits without operator approval (motto §3).
- No AI co-author trailers (motto §20).
- Cannot claim "done" without evidence (motto §0.4.1).

## Acceptance criteria

- Bundle files exist at canonical paths.
- Cross-link to canonical sources.
- Multi-pass review notes recorded (Pass 1/2/3).
- "Anything else?" sections present per motto §0.1.1.
- Final acceptance contract in chat report (this session's last message).

## Evidence required

- Static inspection (Tier 1) — every Doc A–I cites a source for its claims.
- Cross-bundle integrity check (workstream bundle + project-wide bundle cohere).

## Explicit non-goals

- New feature implementation.
- Refactoring screens.
- Removing on-disk What-If Calculator (operator decision required).
- Cutting screens (operator decision required per constitution P12).
- Signing off doctrine stack (operator decision required).
- Committing anything without operator approval.

---

## Anything else? (motto §0.1.1)

The mission at project scope is fundamentally a *decision-support* mission, not a *code* mission. The product already has substantial code; the leverage is in (a) doctrine sign-off, (b) gap closure, (c) test honesty, (d) scope discipline. The bundle exists to make those four levers readable for future operator-driven work.
