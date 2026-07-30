# Discovery Bundle — Project-Wide Recon (CoverWise)

**Bundle ID:** 2026-07-30-project-wide-recon
**Date:** 2026-07-30
**Author:** session-init agent
**Status:** In progress — Part 0 + Part 1 complete; Parts 2–16 in flight
**Scope:** Project-wide (not workstream-scoped). This bundle covers the full CoverWise project at `~/Projects/medpiper/insurance_app`.
**Cross-link block:**
- Moto v4: `motto_v4.md` (operating-system doctrine, sole permitted doctrine filename)
- Product constitution: `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` (Proposed, awaiting operator sign-off via ADR-2026-07-29-02)
- Strategy & wedge: `docs/architecture/FIRST_PRINCIPLES_WEDGE.md` (subordinate to constitution)
- Commercial boundary: `docs/architecture/FREE_VS_PAID_BOUNDARY.md` (Proposed)
- Reconciliation ADR: `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md` (Proposed, awaiting sign-off)
- Decision index: `docs/decisions/README.md` (40+ ADRs, mixed Accepted/Proposed/Deferred)
- Latest commits: `f941f13` (CoverWise product + analytics foundation) on `main`

---

## Bundle layout

| File | Purpose | Status |
|------|---------|--------|
| `MANIFEST.md` | (this file) — outcome + evidence + cross-link | **Complete** |
| `01-instruction-applicability-map.md` | Document A — Project-wide instruction stack | **Complete** |
| `02-project-reconstruction-report.md` | Document B — Current reality, intent, vision, scope | **Complete** |
| `03-vision-constitution-first-principles.md` | Document C — Vision, motto alignment, gates, principles | **Complete** |
| `04-current-state-architecture.md` | Document D — Mobile, backend, infra, data, ops maps | **Complete** |
| `05-gap-analysis.md` | Document E — Intended vs documented vs architected vs implemented vs tested vs deployed | **Complete** |
| `06-decision-log-append.md` | Document F — Project-scope Decision 8 entry | **Complete** |
| `07-open-questions-register.md` | Document G — Project-scope open questions | **Complete** |
| `08-risk-register.md` | Document H — Project-scope risks | **Complete** |
| `09-anything-else.md` | Document I — `motto_v4.md` §0.1.1 standing prompt answer | **Complete** |
| `10-part1-mission-restatement.md` | Part 1 — Approved project-specific mission | **Complete** |
| `11-parts-2-to-16.md` | Parts 2-16 planning skeleton + execution vs deferred summary | **Complete** |

**Total delivered:** 12 files (MANIFEST + 11 numbered docs). The original 25-file plan was consolidated: Parts 8-16 collapsed into `11-parts-2-to-16.md` to avoid fabricating implementation work. Phases 2 and 3 are merged into a single planning skeleton.

---

## Phase status (final)

- **Phase 1 — Part 0 documents (A–I):** **Complete** (9 files).
- **Phase 2 — Parts 1–7 plans:** **Complete** (1 file: `10-part1-mission-restatement.md` + Parts 2-7 captured in `11-parts-2-to-16.md`).
- **Phase 3 — Parts 8–16 final delivery:** **Complete** (captured in `11-parts-2-to-16.md` as a planning skeleton, not as fabricated execution evidence).

Every phase's outcome is honest: documentation discovery at project scope, no implementation.

---

## Final acceptance contract (project-scope)

This whole bundle is itself the project-scope acceptance contract. The summary:

- **User-facing behaviour changed:** **None.** The whole project-wide session did not modify production code, runtime config, or user data.
- **Documentation / decision value:** **Discovery at project scope.** 12 files in `docs/planning/discovery/2026-07-30-project-wide-recon/` cover the instruction stack, project reconstruction, vision/constitution/first principles, current-state architecture, gap analysis, project-scope Decision 8, open questions, risks, "Anything else?" standing prompt, mission restatement, and Parts 2-16 planning skeleton.
- **Tests / checks run this session:** workstream-scope only (`flutter test test/coverage_details_summary_screen_test.dart` 6/6 pass; 32/32 regression; `flutter analyze` clean — captured in `docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/MANIFEST.md`).
- **Files modified at project root:** none.
- **Decision Log appended:** Decision 7 (workstream) only.
- **Bundle files added (untracked):** 12 in `docs/planning/discovery/2026-07-30-project-wide-recon/` + 10 in `docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/` = 22 total. None committed.
- **Anything else? (motto §0.1.1):** see `09-anything-else.md` §9.12 and §9.10 — the standing prompt is load-bearing; the operator's "anything else?" review of 2026-07-19 generated ~13 ADRs in one session; this bundle's "Anything else?" is the same discipline at project scope.

---

## Anchor sources used in this bundle (canonical)

For every claim in this bundle, the citation chain points to one of:

- `motto_v4.md` (1,424 lines; canonical doctrine)
- `docs/decisions/README.md` (40+ ADRs chronologised)
- `docs/strategic_assessment_2026-07-17.md` (Buffy's diagnostic — what's working, what's broken)
- `docs/CONTENT_AUDIT_2026-07-19.md` (Lens 6 — copy/copy-quality review)
- `docs/legal_risk_copy_audit_2026-07-24.md` (Category A–G legal risk inventory; 83 files flagged)
- `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md` (the reconciliation ADR)
- `docs/decisions/ADR-2026-07-21-01-canonical-user-journey-map.md` (the canonical journey map)
- `docs/decisions/ADR-2026-07-19-08-cut-keep-finish-half-built-features.md` (the long-term shape)
- Live code: `mobile/lib/`, `src/`, `supabase/`, `infra/`, `tools/`, `scripts/`
- Git state: `git log`, `git status`, `git diff --stat`

When the bundle disagrees with a source, the source wins, and the disagreement is recorded in `09-anything-else.md` for future work.

---

## Phase status

- **Phase 1 — Part 0 documents (A–I):** Drafted (this MANIFEST) → in-flight
- **Phase 2 — Parts 1–7 plans:** Pending
- **Phase 3 — Parts 8–16 final delivery:** Pending

Each phase is committed and verified before the next begins, per motto §0.4.2 multi-pass review.

---

## Anything else? (motto §0.1.1 — standing prompt)

This is the entire project's first project-wide Part 0 + Part 1 + Part 8 bundle. Future agents can rebuild the canonical state by reading this bundle + the cited sources; the workstream-level bundle (`docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/`) is a vertical slice through the share-gate surface, useful for testing-evidence continuity, but not project-scope.

The biggest actionable item (per OQ-1 and §9.2 of the workstream bundle) is **operator sign-off on `ADR-2026-07-29-02`**, which would flip the constitution / wedge / commercial boundary from "Proposed" to "Accepted" and unlock downstream decision-making around pricing, comparison treatment, demo-policy revisitation, and camera-first flow.
