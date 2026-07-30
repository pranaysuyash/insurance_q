# 01 — Instruction Applicability Map (Project-Wide)

**Bundle:** 2026-07-30-project-wide-recon
**Doc A (Part 0)** — full project instruction stack
**Author:** session-init agent
**Date:** 2026-07-30

---

## Cross-links

- Operating-system doctrine: `motto_v4.md` (1,424 lines; only canonical doctrine filename)
- Doctrine hierarchy: `docs/decisions/README.md` (per `ADR-2026-07-29-02`)
- Product constitution: `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` (Proposed)
- Strategy: `docs/architecture/FIRST_PRINCIPLES_WEDGE.md` (subordinate, Proposed)
- Commercial: `docs/architecture/FREE_VS_PAID_BOUNDARY.md` (Proposed)
- Decisions: `docs/decisions/ADR-*.md` (40+ records; see `docs/decisions/README.md`)
- Auth context: `agent-start` regenerated `docs/context/agent-start/SESSION_CONTEXT.md`

---

## Instruction stack — full inventory

| Layer | Source | Status | Last update | Scope | Notes |
|---|---|---|---|---|---|
| **motto_v4.md** | `motto_v4.md` | Accepted | 2026-07-30 (synced) | Whole project | Sole permitted doctrine filename in working tree; motto_v3 and motto_v2 retired per §0.17 |
| **Product constitution** | `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` (322 lines) | **Proposed** | 2026-07-29 | Whole project | Five gates (A–E); twelve principles; awaits operator sign-off via ADR-2026-07-29-02 |
| **Strategy & wedge** | `docs/architecture/FIRST_PRINCIPLES_WEDGE.md` (206 lines) | Proposed, subordinate to constitution | 2026-07-29 (revised per ADR-2026-07-29-02) | Strategy layer | Corrected 2026-07-29 (8 clauses narrowed/replaced); original 2026-07-28 text preserved where not in conflict |
| **Commercial boundary** | `docs/architecture/FREE_VS_PAID_BOUNDARY.md` | Proposed | 2026-07-29 | Commercial layer | All exact prices/limits are Proposed pending operator approval |
| **Reconciliation ADR** | `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md` | **Proposed — operator sign-off required** | 2026-07-29 | Whole project | Establishes the layered stack; resolves 13 conflicts; no boundary-shaped code changes authorised until signed |
| **Decision index** | `docs/decisions/README.md` (236 lines) | Living | 2026-07-24 (latest ADR-07) | Whole project | Lists 40+ ADRs (Accepted/Proposed/Deferred); retroactive decisions for shipped work |
| **AGENTS.md** | (not found at root or nested) | **Missing** | n/a | n/a | Hygiene gap; flagged for future commit |
| **Equivalent scoped-instruction files** | (not found: CLAUDE.md / CODEX.md / COPILOT.md / GEMINI.md / QWEN.md) | Missing | n/a | n/a | Same hygiene gap as AGENTS.md |
| **Session context (regenerated)** | `docs/context/agent-start/SESSION_CONTEXT.md` | Regenerable | 2026-07-30 04:47 UTC | Per-session | Carries per-session instruction surface |

---

## Sub-layer documentation references

| Sub-area | Anchor file | What it provides |
|---|---|---|
| Long-term platform decision | `docs/planning/coverwise_long_term_platform_decision_2026-07-12.md` | One Cloud Run FastAPI service backed by Supabase Postgres, pgvector, private Storage |
| Launch readiness review | `docs/review/launch_readiness_review_2026-07-12.md` | Live release gate criteria |
| Strategic assessment | `docs/strategic_assessment_2026-07-17.md` | Buffy's diagnostic — what's working, what's broken, 6 test failures dismissed |
| Flow & screen audit | `docs/FLOW_AND_SCREEN_AUDIT.md` | Screen-by-screen audit, every screen rated |
| Content audit (Lens 6) | `docs/CONTENT_AUDIT_2026-07-19.md` | User-facing copy review; 14 of 44 strings flagged |
| Customer-needs research | `docs/CUSTOMER_NEEDS_RESEARCH.md` | Persona-driven requirement maps |
| User personas | `docs/user_personas.md` | Persona definitions |
| Legal risk inventory | `docs/legal_risk_copy_audit_2026-07-24.md` | 83 files flagged, 1,793 copy lines; Category A–G taxonomy |
| Legal risk remediation priority | `docs/legal_risk_remediation_priority_2026-07-25.md` | Prioritised fixes for the legal/copy inventory |
| Legal risk remediation | `docs/legal_risk_remediation_2026-07-25.md` | Implementation plan for the legal/copy remediation |
| User experience audits | `docs/DASHBOARD_SCREEN_AUDIT.md`, `docs/UX_ISSUES_AUTH_AUDIT.md` | Per-surface UX audits |
| Copy audit | `docs/COPY_MICROCOPY_AUDIT_2026-07-21.md` | Microcopy inventory |
| Naming package | `docs/planning/naming/`, `CoverWise_Name_Clearance_and_Brand_Risk_Report_2026-07-28.docx`, `CoverWise_Renaming_Agent_Pitch_and_Voting_Pack_2026-07-28.docx` | Naming process and decision |
| Payments planning | `docs/planning/payments/` | Payment provider decision (Dodo primary + Razorpay secondary per retro-Decision 2026-07-18-03) |
| Deployment archive | `docs/archive/deployment/` | Historical AWS deployment records; superseded by long-term-platform decision |
| API documentation | `docs/reference/api_documentation/` | API contract reference |
| Architecture reference | `docs/technical/architecture/` | Component / interface / data-flow maps |
| Strategy and assessment | `docs/strategic_assessment_2026-07-17.md` | Diagnostic |

---

## Key project-wide rules

### From `motto_v4.md` (binding for everything)

- **§0 (whole answer)** — long-term + bold + coherent + accountable; smallest-coherent-change.
- **§0.3 / §0.3.1** — documentation is part of delivery; chat is ephemeral; the repo is durable memory; *everything* is a documentation candidate; verbatim redirects.
- **§0.4 / §0.4.1** — acceptance contract; multi-pass review (Pass 1/2/3).
- **§0.5** — evidence tiers (0–5); claims must state tier.
- **§0.6** — risk-based verification; high-risk paths require Tier 3+.
- **§0.7** — AI output is a proposal, not a fact; verify before accepting.
- **§0.8** — data dependencies are production code (prompts, configs, lookup tables).
- **§0.9** — model/prompt/routing changes are architecture.
- **§0.10** — observability is delivery.
- **§0.11 / §0.11.1** — customer-facing claims need claim registry entries.
- **§0.12 / §0.12.1 / §0.12.2 / §0.12.3 / §0.12.4** — ADR rules; append-only update logs; ADR-first for load-bearing; pattern families; cut/keep/finish anchored to long-term shape.
- **§0.13** — scope expansion control; long-term thinking ≠ unbounded rewrites.
- **§0.14** — product reality and operator workflow rule; a feature = user + operator workflow.
- **§0.15** — third-layer rule: model / pipeline / data-configuration layers are separate.
- **§3** — git safety; read-only by default; mutating commands need explicit approval.
- **§4** — local work preservation; classify every local item.
- **§5** — stale state rule; recheck before relying on any prior summary.
- **§6** — "pre-existing" is not an excuse; fix it in the same pass (blast-radius rule).
- **§7** — supersession / canonical-replacement; migrate to canonical path.
- **§8** — group-by-group preservation; one concern per commit.
- **§9** — artifact handling; classify before commit or delete.
- **§10** — pattern & related-issue search.
- **§11–§15** — engineering standards, product alignment, analysis expectations, validation rules, documentation rules.
- **§16–§18** — branches, cleanup, communication.
- **§19** — primary goal: best long-term solution.
- **§20** — **no AI agent co-author trailers** (Co-Authored-By Claude/Codex/etc).
- **§21** — code is evidence; refactor downstream of decision change.
- **§22** — automated checks are advisory; don't silence the linter to satisfy it.
- **§23** — parallel-authored, long-term continuity, contested runtime boundary + **2026-07-28 addendum** on parallel-editor hold and resync protocol.

### From the proposed constitution (binding *directional* until ADR-2026-07-29-02 sign-off)

- **Gate A (Outcome)** — reduces effort/time/uncertainty for insurance comprehension.
- **Gate B (Truth)** — every material statement grounded in current owned-source evidence; handle found/not-found/unverified/incomplete/stale/conflicting/unsupported/abstained.
- **Gate C (Role)** — explanation / evidence / organisation / retrieval / reminders / recordkeeping only; reject by default recommendation, suitability/adequacy judgement, premium quoting, underwriting, ranking, claims filing, lead generation.
- **Gate D (Lifecycle)** — canonical principal, consent, retention, deletion, idempotency, observability, recovery, launch claims.
- **Gate E (Commercial)** — within wedge; free/paid treatment decided in the commercial layer.
- **12 non-negotiable principles** (P1: policy is authoritative; P2: verifiability is the product; P3: abstention is valid; P4: explain-don't-advise; P5: one principal owns one graph; P6: consent is enforced behaviour; P7: feature = end-to-end workflow; P8: one canonical path per truth; P9: reliability at moment of need; P10: business model aligns with trust; P11: every public claim is operational contract; P12: long-term thinking ≠ maximalism).
- **Anti-principles** (12 catch-outs the product must reject).

### From the wedge (Proposed, subordinate to constitution)

- **Wedge:** owned policy → secure import → evidence-backed workspace → source-verifiable explanation and Q&A → neutral organisation → factual reminders/emergency retrieval → personal notes/document lifecycle.
- **Long-term shape set** in retro-Decision 2026-07-18-08 / ADR-2026-07-19-08: Coverage Check-in, Coverage Adequacy, Family Coverage Map, Renewal Awareness, Emergency Info, Personal Claim Log, Claim Document Vault.
- **Cut:** what-if premium calculator; advisor marketplace; demo policy as default; camera-first as default; lead capture.
- **Status decisions** (per Addendum 2026-07-29): comparison now IN (neutral owned-policy only), "proactive gap alerts" renamed "coverage facts and verification prompts," demo/camera reclassified as strategy not principles, "not multi-tenant" reclassified "consumer/household product."

### From commercial boundary (Proposed)

- **Three value categories:** 🧠 Comprehension (free baseline), ⚡ Convenience (paid candidate), 🔬 Depth (paid candidate).
- Durable principle: "user must receive enough source-verifiable comprehension to understand the product's value without paying."
- All exact prices/limits are **Proposed** — pending operator approval.

### From decisions (`docs/decisions/README.md`)

- 40+ ADRs, chronologised; full schema per `motto_v4.md` §0.12.
- Retroactive records for shipped work (`fa02854`, earlier) capture rationale that would otherwise be rediscovered and debated.
- Five accepted ADRs of 2026-07-19 are load-bearing (cut/keep/finish rev 2, evidence-backed rev 1, outbox-only rev 1, substrate-as-primary-deliverable rev 1, operator trust model rev 1). Updates are appends, not edits.
- **14 × `ADR-2026-07-19-XX`** define the long-term substrate extensions and privacy/data-handling policies for the wedge surfaces.

---

## Conflicts found (project-wide)

| Conflict | Locations | Resolution |
|---|---|---|
| UX Audit §9 P0-1 "direct-to-camera" vs ADR-2026-07-29-02 §4.9 | `UX_AUDIT_FIRST_PRINCIPLES.md` vs `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md` | Addendum supersedes; camera optional fallback, not default |
| UX Audit §9 "demo policy as default" vs ADR-2026-07-29-02 §4.10 | Audit vs ADR | Rejected for launch; revisitable through evidence |
| UX Audit §9 "what-if calculator" vs Constitution P4 | Audit vs constitution | Out of scope (constitution P4) |
| UX Audit §9 "policy health score" vs Constitution P4 | Audit vs constitution | Out of scope (suitability judgement) |
| UX Audit §9 "claim assistant v1" vs ADR-2026-07-29-02 §4.4 | Audit vs ADR | Narrowed to policy-stated process + contacts only |
| UX Audit §9 "advisor marketplace" vs Constitution P4 | Audit vs constitution | Out of scope |
| Constitution / Wedge / Free vs Paid vs ADR-2026-07-29-02 status | All self-declare "Accepted" or "Accepted (revision 2)" without external verification | Per doctrine-stack reconciliation, status is "Proposed" until operator sign-off |
| Internal `DEMO POLICY` references | Audit §3.1 vs Addendum | Addendum (latest) |
| `claim_assistance_screen.dart` "grounded" / "substrate" jargon | Content Audit 2026-07-19 (NEEDS REVIEW HIGH) | Open work; remediated by voice/copy future session |
| README at repo root preserves June 2025 AWS Material | README lines 71–311 | Preserved historical snapshot per README §"Historical company-era status" |
| `wp-content/`, `tools/`, shell scripts (deploy_*.sh, aws_*.sh) at repo root | `REPO README` context | Live launch path is `tools/deploy_cloud_run.sh`; legacy scripts preserved but not the launch path |

---

## Hygiene gaps surfaced

| Gap | Severity | Recommended fix |
|---|---|---|
| `AGENTS.md` (or CLAUDE.md / CODEX.md / GEMINI.md / QWEN.md / COPILOT.md) does not exist at the repo root or any nested directory | Medium | Create `AGENTS.md` referencing `motto_v4.md` + constitution + wedge + ADR + DECISION_LOG + DESIGN; defer broader instruction-surface rewrite to a future session |
| `motto_v4.md` "Anything else?" standing prompt is unrecorded for several past ADRs (especially the older accepted ones) | Low | Re-check during next ADR review; append "Anything else?" sections |
| `motto_v3.md` and `motto_v2.md` retired — git history preserves them but the working tree carries only `motto_v4.md` — confirmed by `ls` | Verified | None |
| 6 test failures dismissed in `strategic_assessment_2026-07-17.md` §2.2 | High | Each is a pre-existing issue; per motto §6, fix unless explicitly out of scope |
| Documentation bloat (`docs/planning/**` ~20 files partly stale per Buffy) | Medium | Strategic assessment recommends consolidation; not in this scope |
| `legal_risk_copy_audit_2026-07-24.md` flagged 83 files / 1,793 lines; remediation priority 2026-07-25 exists | High | Two remediation docs exist; implementation tracked elsewhere |

---

## Anything else? (motto §0.1.1)

The doctrine stack is mature, layered, and self-describing. The biggest actionable open item is `ADR-2026-07-29-02` sign-off — it would convert the constitution from "Proposed" to "Accepted" and unlock downstream pricing/comparison/demos/camera decisions. Until then, directional guidance from the constitution stands but is not strictly binding.
