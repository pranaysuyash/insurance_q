# 01 — Instruction Applicability Map

**Bundle:** 2026-07-30-coverage-details-summary-share-gating
**Doc A (Part 0)**
**Author:** session-init agent
**Date:** 2026-07-30
**Plan file:** `~/.commandcode/plans/coverwise-coverage-details-summary-share-gating.md`

---

## Cross-links

- Operating-system doctrine: `motto_v4.md` (only canonical motto file in working tree)
- Product constitution: `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` (Proposed, awaiting operator sign-off via ADR-2026-07-29-02)
- Strategy & wedge: `docs/architecture/FIRST_PRINCIPLES_WEDGE.md` (subordinate to constitution)
- Commercial boundary: `docs/architecture/FREE_VS_PAID_BOUNDARY.md` (Proposed)
- Reconciliation ADR: `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md` (Proposed)
- Audit: `UX_AUDIT_FIRST_PRINCIPLES.md` (2026-07-23 + 2026-07-29 supersession addenda)
- Decision log: `DECISION_LOG.md` (Decisions 1–6 logged)
- Design tokens: `DESIGN.md`
- AGENTS.md or equivalent: **not found** in repo root or any nested directory in this session's scope

---

## Instruction stack found

| Source | Path | Lines | Status | Scope | Notes |
|---|---|---|---|---|---|
| motto_v4.md | `motto_v4.md` | 1,424 | Accepted; sole permitted doctrine filename | Repo-wide, agent-wide | Synced from `~/Downloads/motto_v4.md` via `agent-start` on 2026-07-30 |
| Product constitution | `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` | 322 | Proposed | Repo-wide, product layer | Five gates (A–E), twelve principles, anti-principles |
| First Principles Wedge | `docs/architecture/FIRST_PRINCIPLES_WEDGE.md` | 206 | Proposed, subordinate to constitution | Strategy layer | Corrected 2026-07-29; supersedes earlier P0/P1 from `UX_AUDIT_FIRST_PRINCIPLES.md` §9 |
| Free vs Paid Boundary | `docs/architecture/FREE_VS_PAID_BOUNDARY.md` | (read separately if needed) | Proposed | Commercial layer | Detailed per-feature classification |
| ADR-2026-07-29-02 | `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md` | — | Proposed, awaiting sign-off | Doctrine stack | Establishes the layered doctrine |
| UX Audit | `UX_AUDIT_FIRST_PRINCIPLES.md` | 460 | Audit + addenda | Product/UX layer | P0/P1 recommendations *superseded* by 2026-07-29 addenda; engineering observations remain valid |
| Decision Log | `DECISION_LOG.md` | 176 | Append-only history | Repo-wide, chronologic | Decisions 1–6 logged as of 2026-07-23 |
| Design | `DESIGN.md` | 42 | Accepted | Visual / interaction | Authoritative for tokens + anti-references |
| AGENTS.md | (none found) | — | **Missing** | n/a | Should create or document gap |
| Codex/Claude/Cursor equivalent | (none found) | — | Missing | n/a | Should document gap |

---

## Key rules this discovery must apply

### From `motto_v4.md`

- **§0.3.1 — "Everything Is a Documentation Candidate"** (added 2026-07-28): chat is ephemeral; the repo is durable memory. Redirects and rejections are documented verbatim. The bundle this file belongs to is the direct application of this rule.
- **§0.4 — Acceptance Contract**: required for "done"; lists behavioral change, files changed, commands run, evidence tier, gaps, hardening.
- **§0.4.2 — Multi-Pass Review**: Pass 1 (correctness), Pass 2 (architecture), Pass 3 (compliance), each leaving a short outcome note.
- **§0.5 — Evidence Tiers**: 0=assumption, 1=static inspection, 2=tested, 3=integration, 4=runtime/manual, 5=production. This bundle's findings land at Tier 1 (static) and Tier 2 will land only after the compile errors clear.
- **§0.13 — Scope Expansion Control**: long-term thinking ≠ unbounded rewrites. Pause and report if scope expands.
- **§23 / 2026-07-28 Addendum — Parallel-Editor Hold**: contested files are paused, not patched. **This rule is the binding reason for WS-2 not being executed in this session.**
- **§20 — No Agent Co-Author Trailers**: even if committing, no AI attribution trailers.
- **§3 — Git Safety**: read-only commands OK; mutating commands need explicit approval.
- **§4 — Local Work Preservation**: untouched files must not be modified.

### From the proposed constitution

- **Gate A (Outcome)** — passed for this scope (verification strengthens audit trail).
- **Gate B (Truth)** — passed (no fabricated policy claims; tests assert behavior against source).
- **Gate C (Role)** — passed (no advisory surface added; mechanical alignment only).
- **Gate D (Lifecycle)** — N/A (no principal/consent/storage change).
- **Gate E (Commercial)** — passed; gate-reason copy is canonical and not edited.

### From the wedge

- **§3.3 — "Coverage Summary Is Closer to the Wedge Than Q&A"**: this workstream's target surface (`CoverageDetailsSummaryScreen`) is identified as the closest-to-wedge screen in the repo.
- **§5.1 — "Consumer/household product, not 'not multi-tenant'"**: backend stays multi-user with strict principal isolation.

### From DESIGN.md

- Token system: ink / blue / mint / cloud / line.
- Signature: every generated answer carries verification state. Local mobile assist = `Not verified`.
- Anti-references: no purple gradients, glass effects, sparkle/AI decoration, recursive cards, status theatre.

---

## Conflicts found

| Conflict | Locations | Resolution |
|---|---|---|
| UX Audit §9 P0-1 "direct-to-camera onboarding" vs ADR-2026-07-29-02 §4.9 | Audit 2026-07-23 vs 2026-07-29 addenda | Addendum supersedes; camera is *optional fallback* not default |
| UX Audit §9 P0-P2 "demo policy as default onboarding" vs ADR-2026-07-29-02 §4.10 | Audit vs addenda | Rejected for launch; read-only example allowed only via separate ADR |
| UX Audit §9 P3 "policy health score" vs Constitution P4 | Audit vs constitution | Constitution governs; health score = suitability judgement, OUT |
| motifv4 §0.4.2 multi-pass vs §0.5 evidence tier: directly tested fields vs inference | motto internal | Not in conflict; compose |

---

## Scoped rules for THIS workstream

- WS-1 must use real verification (`flutter test`). Static review alone is Tier 1, not enough for "done".
- The two modified `auth_service.dart` / `principal_key_service.dart` compile-error blockers are **inside the parallel-editor hold**, not inside the WS-1 verification path. Wedge them out.
- The plan's approved scope is single-test alignment. No retroactive scope widening.

---

## AGENTS.md / scope-equivalent: status

**No `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `COPILOT.md`, `GEMINI.md`, or `QWEN.md` exists in this repo as of 2026-07-30.** This is a discovered gap. The de facto instruction stack (motto_v4 + constitution + wedge + ADR + decision log + audit + design) supplies the rules; what is missing is a local pointer file that names them.

**Recommendation:** flag this for the operator. Not a blocker for this workstream (motto_v4 loads via `agent-start` independently), but a hygiene gap that future agents may miss without explicit `AGENTS.md` reference.

---

## Anything else? (motto §0.1.1)

- `motto_v3.md` and `motto_v2.md` are retired per §0.17 (one-canonical-motto). Working tree carries only `motto_v4.md` — confirmed via `ls` (no other `motto_*.md` present).
- The constitution is *Proposed*. Until operator sign-off, this bundle treats it as binding *directionally* but does not perform the constitution's own ratification work — that is its own ADR-class decision.
