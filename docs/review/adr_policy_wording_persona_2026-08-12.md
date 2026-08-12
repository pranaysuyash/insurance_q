# ADR-2026-08-12 — Policy Wording Specialist persona for the RAG answer path

**Status:** Accepted (implemented, additive)
**Date:** 2026-08-12
**Author:** Forge (agent) for Pranay
**Doctrine:** motto_v5 — long-term, first-principles, evidence-tiered, document-in-pass
**Supersedes / extends:** `docs/review/rag_policy_wording_persona_audit_2026-08-12.md` (audit that preceded this decision)

---

## 1. Context

The audit (`rag_policy_wording_persona_audit_2026-08-12.md`) established two facts:

1. The RAG is **persona-agnostic**. There is exactly one hardcoded answer identity — a
   generic *"careful insurance-document assistant"* — with **no** policy-wording reasoning
   (coverage trigger → scope → definitions → exclusions → exceptions → conditions → limits →
   endorsement interaction → adversarial test). The word "persona" appears only as a
   *blocked* prompt-injection pattern.
2. The RAG **can benefit strongly and cheaply**. The persona is almost entirely a
   *reasoning scaffold* over retrieval; it needs no new vector store or embedding model.
   The hard part (faithful two-text evidence substrate + citation/answer verifiers) already
   exists.

The audit also flagged a structural gap: `document_policy_summaries` is extracted at ingest
but **never read** by `query_rag` (an orphan layer), and the chunk `section_type` enum is
too coarse for wording reasoning.

This ADR records the decision to make the RAG **persona-aware** in an **additive,
legally-safe** way — and explicitly defers the live accuracy/latency acceptance run.

---

## 2. Decision

Implement a **versioned Policy Wording Specialist persona** as an additive layer on the
existing RAG, with four concrete change sites:

### 2.1 Persona as a single source of truth — `src/rag/persona.py` (NEW)
- `PERSONA_VERSION = "2026-08-12.pws-v1"` is embedded in every `RAGAnswer.persona_version`
  for traceability/reproducibility.
- `build_policy_wording_specialist_system_message()` returns
  `SYSTEM_PROMPT_PREFIX + "\n\n" + POLICY_WORDING_SPECIALIST_BODY`.
  The security boundary is **preserved and prepended**, never weakened. (`SECURITY_SYSTEM_INSTRUCTION`
  is still auto-prepended by `LLMClient._harden_messages`.)
- A 12-step coverage-reasoning scaffold (intended outcome → trigger → covered subject →
  scope → definitions → restrictions → exclusions → exceptions → conditions → limits →
  clause interaction → adversarial test) plus hard rules (preserve coverage, cite, surface
  ambiguity, abstain if unknown, no jurisdiction assumption).

### 2.2 Richer chunk taxonomy without a migration — `section_tags` (JSONB)
- The DB-constrained `section_type` enum stays at its original 8 values (stable routing).
- Extended granular categories (`insuring_agreement`, `condition`, `endorsement`,
  `exception`, `deductible`) are emitted as **multi-label `section_tags`** stored in the
  existing JSONB `metadata` column — **no schema migration**. A `_SECTION_TYPE_COARSE_MAP`
  maps each granular tag to a DB-valid coarse parent.
- `supabase_vector_store.upsert` already passes `section_tags` through to `metadata`.

### 2.3 Orphan-layer fusion — non-citable priming context
- `_build_policy_map_context(document_ids)` reuses `PolicyExtractionService._load_summary`
  to surface the pre-extracted benefit/exclusion/limit map as a **clearly-labelled,
  NON-CITABLE** priming block prepended to the retrieved context. It is explicitly
  instructed to **never be cited as a numbered Source**. Defensive: returns `""` on any
  failure so retrieval is never broken.

### 2.4 Legal-safe coverage-interpretation schema — `src/models/rag.py`
- `WordingAssessment` (with `CoverageLimitationRef`) captures `reading`
  (`likely_covered | likely_not_covered | conditional | ambiguous`), the applicable
  exclusions/exceptions/conditions/limits/endorsements, an `alternative_interpretation`,
  and a mandatory `disclaimer`.
- Field names deliberately avoid "decision"; the default `reading` is `ambiguous` (never a
  confident decision). `query_rag` stamps `persona_version` and surfaces `wording_assessment`.

### 2.5 Evals + versioning as first-class (per user directive)
- `tests/evals/coverage_dataset.jsonl` — 12 labelled synthetic "is X covered?" examples
  (100% synthetic, no real policies/PII), spanning all four reading classes.
- `tests/evals/run_evals.py` — harness with an **offline** baseline (CI-safe, zero network)
  and a **live** real-pipeline gate that is implemented but **deferred** (requires
  `--allow-live` + `OPENAI_API_KEY` + a real corpus).
- `PERSONA_VERSION` + `CHANGELOG` in `persona.py` provide prompt versioning.

---

## 3. Options considered

| Option | Verdict | Why |
|--------|---------|-----|
| A. Full agent framework (LangGraph / CrewAI / multi-agent) | **Rejected** | The persona is a *reasoning scaffold*, not an orchestration problem. No retrieval/vector change is needed. An agent framework would add latency, cost, and a new failure surface for zero benefit. |
| B. "Plain-English rewrite" layer | **Rejected** | This is the exact weak-agent failure mode the persona warns against: it would *simplify wording in a way that could change coverage*. Forbidden by the persona's own hard rule. |
| C. **Additive prompt + taxonomy + schema + evals (chosen)** | **Accepted** | Cheapest durable path; reuses the existing faithful substrate and verifiers; keeps the security boundary intact; adds the reasoning the audit said was missing. |
| D. Block the persona entirely (keep generic assistant) | **Rejected** | Ignores the audit's strong "yes, cheaply" verdict and the user's explicit build directive. |

---

## 4. Legal-safety contract (non-negotiable)

- The persona **interprets wording as written**. It does **NOT** make, approve, or deny any
  coverage, eligibility, claim, or legal decision. The insurer decides.
- It must **never** rewrite wording in a way that could alter coverage, exclusions, limits,
  timing, causation, eligibility, or rights. Clarifying language must not change meaning.
- It must **surface ambiguity** rather than assert a single binding reading, and must **not
  assume a jurisdiction** or introduce undefined terms.
- The existing security boundary (`SYSTEM_PROMPT_PREFIX` + `_harden_messages`) is
  **preserved and prepended**; "persona/act as" remains a blocked injection pattern.
- The evals dataset is **100% synthetic**; no real customer policies or PII are used.

---

## 5. Consequences

**Positive**
- The RAG now reasons through coverage the way the audit recommended, with the existing
  grounding/citation guarantees intact.
- Persona changes are versioned and traced per answer; regressions are caught by unit tests
  + an offline eval gate.
- The orphan `document_policy_summaries` layer is finally consumed, at zero retrieval risk.

**Negative / costs**
- Slightly longer system prompt (one-time token cost; minor latency). Acceptable and
  measured-by-design via the deferred live gate.
- `section_tags` adds JSONB payload; negligible.

**Risks & mitigations**
- *Prompt drift weakening wording:* mitigated by hard rules + a mandatory disclaimer in the
  schema; monitored by the eval gate.
- *Accidental citation of the non-citable policy map:* mitigated by explicit "must NOT be
  cited" instruction + the existing citation verifier (which only accepts `source_text`).
- *Live accuracy/latency unknown:* **explicitly deferred** — see §6.

---

## 6. Deferred acceptance gate (explicit)

The **end-to-end accuracy lift and latency/cost** of the longer reasoning prompt were
**not** verified this session — that requires a live run on a **real policy corpus**.

- This is the **first implementation commit's acceptance gate** (per user directive).
- It is implemented in `tests/evals/run_evals.py` (`--mode live --allow-live`) and must be
  run against a real, licensed policy corpus with API keys before the persona is promoted
  from "additive experimental" to "default".
- Until then, the persona is wired into `query_rag`/`query_rag_stream` and versioned, but
  the live gate remains the open item (task #16).

---

## 7. Files changed

| File | Change |
|------|--------|
| `src/rag/persona.py` | NEW — versioned persona (single source of truth) |
| `src/rag/pipeline.py` | Persona wiring, multi-label taxonomy, policy-map fusion, definition boost, `persona_version`/`wording_assessment` in response |
| `src/models/rag.py` | `WordingAssessment`, `CoverageLimitationRef`; `wording_assessment` + `persona_version` on `RAGAnswer` |
| `src/services/supabase_vector_store.py` | Pass `section_tags` through to JSONB `metadata` |
| `tests/test_persona_wording.py` | NEW — persona / taxonomy / schema / query-wiring tests |
| `tests/evals/coverage_dataset.jsonl` | NEW — 12 labelled synthetic examples |
| `tests/evals/run_evals.py` | NEW — offline + deferred-live eval harness |
| `tests/test_evals_harness.py` | NEW — CI test for the offline harness |
| `docs/review/rag_policy_wording_persona_audit_2026-08-12.md` | §10 Implementation Log appended |

---

## 8. Anything else? (motto_v5 standing review)

- **No duplicate/shadow pipeline.** The persona reuses `query_rag` and the existing
  verifiers; there is no second answer path.
- **Evidence tiers respected.** Audit claims were file:line; implementation is verified by
  44 passing tests (existing + new) and a runnable eval harness.
- **Documentation is delivery.** This ADR + the audit's §10 are the durable records.
- **Open item kept visible:** the live acceptance gate (§6) is tracked as task #16 and must
  not be silently closed.

---

## 9. Amendment (2026-08-12, 13:36) — interim feature flag for the persona

### 9.1 Decision
Add an **interim feature flag** (`COVERWISE_POLICY_WORDING_PERSONA`) that gates whether the
Policy Wording Specialist persona is used in `query_rag` / `query_rag_stream`. The flag is
**ON by default** (preserves today's behaviour) and flips to a byte-for-byte revert of the
pre-persona generic assistant when set to `off/false/0/no/disabled`.

### 9.2 Why (discussion summary)
- **Pranay's proposal:** put a feature flag in *now*; defer the decision about *how* the
  persona gets invoked (proper agentic flows) to later. Agreed.
- **Rationale (Forge):** the persona was wired directly into the query path with no
  kill-switch. A flag is the cheapest way to make it A/B-able and **instantly rollback-able**
  — a legal-safety valve, since a bad prompt variant (or a bad live-eval result) should be
  revertible in seconds, not via a deploy.
- **Deferred:** the long-term *invocation architecture* (how/whether the persona is called
  inside proper agentic flows) is explicitly **out of scope** for this amendment. The flag is a
  stopgap; the real design is decided when agentic flows are built.

### 9.3 Design (kept as a single chokepoint)
- `src/rag/persona.py`:
  - `POLICY_WORDING_PERSONA_ENV = "COVERWISE_POLICY_WORDING_PERSONA"` + `_FLAG_OFF_VALUES`.
  - `is_policy_wording_persona_enabled()` — unset => enabled (default ON); live-read from env.
  - `build_system_message()` — the **single chokepoint** for answer-identity selection:
    persona message when on, `SYSTEM_PROMPT_PREFIX + GENERIC_ASSISTANT_BODY` when off.
  - `GENERIC_ASSISTANT_BODY` — exact pre-persona assistant text (recovered from git) so OFF
    is a precise revert.
  - `WORDING_ASSESSMENT_INSTRUCTION` — the "return a wording_assessment" user-message tail,
    emitted only when the persona is on (shared by both query paths).
- `src/rag/pipeline.py`:
  - Both `query_rag` and `query_rag_stream` call `build_system_message()`.
  - The wording-assessment instruction is appended to the user message **only** when the flag
    is on.
  - `answer_payload.persona_version` is stamped **only** when the flag is on (else `None`).
  - The security boundary (`SYSTEM_PROMPT_PREFIX`) is preserved in both states.
- `tests/test_persona_wording.py`: flag parse matrix, `build_system_message` on/off, and a
  `query_rag` integration test asserting `persona_version=None`, `wording_assessment=None`,
  and the instruction absent from the user message when off.

### 9.4 Consequences
- **Reversible without redeploy** (env flip). Behaviour today is unchanged (default ON).
- **No duplicate pipeline** — still one answer path; the flag only swaps the system message
  and the wording-assessment ask.
- **Clean migration path:** when agentic flows land, replacing `build_system_message()` is the
  only change required; the pipeline stays agnostic about *who* produced the identity.
- **Risk:** an operator could disable the persona and lose the coverage-reasoning benefit
  without realising it — mitigated by the ADR note + the default-ON posture.

### 9.5 Open follow-up
- Promote persona to default only after the **live acceptance gate** (§6 / task #16) passes on
  a real corpus. Until then the flag lets us ship the capability while keeping the off-switch
  within reach.
