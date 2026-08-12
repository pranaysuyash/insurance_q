# RAG × Policy Wording Specialist — Audit & Fit Assessment

**Date:** 2026-08-12
**Author:** Forge (agent) for Pranay
**Status:** Implemented (additive, persona-aware) — see §10. Audit findings in §2–§6 unchanged.
**Doctrine:** motto_v5 (long-term, first-principles, evidence-tiered, document-in-pass)

---

## 0. TL;DR (verdict)

- **Is the RAG built around this persona?** **No.** There is exactly one hardcoded
  answer identity — a generic *"careful insurance-document assistant"* — and it carries
  **no** policy-wording reasoning (coverage trigger → scope → exclusions → exceptions →
  conditions → limits → endorsement interaction → adversarial test). There is **no**
  persona/agent/specialist framework in the RAG layer, no agent library (LangGraph,
  CrewAI, etc.), and the word "persona" appears only as a *blocked* prompt-injection
  pattern. *(Verified directly in source — see §2.)*
- **Can it benefit from this persona?** **Yes, strongly, and cheaply.** The persona is
  almost entirely a *reasoning scaffold* layered on top of retrieval — it does not need a
  new vector store or a different embedding model. The current system already has the hard
  part (a faithful evidence substrate + citation/answer verifiers). Adding a wording
  persona is mostly new **prompt logic + a richer chunk taxonomy + a coverage-mapping
  output schema**.
- **Risk of doing it wrong:** the persona's own "best agent instruction" is the guardrail —
  *preserve intended coverage before optimizing language*. A naive "rewrite the policy in
  plain English" layer would be the exact weak-agent failure mode the persona warns against.
  Keep the existing security boundary and evidence substrate intact.

---

## 1. Method (parallel, per motto_v5)

| Track | What was done | Evidence tier |
|-------|--------------|---------------|
| **Explore** | Two read-only agent sweeps of `src/` for RAG pipeline, prompts, persona/role references, tests | Direct (file:line) |
| **Research** | Mapped the 12-step wording-specialist reasoning chain onto the RAG's actual behavior | Analytical, grounded in code |
| **Testing** | Ran the existing `test_section_classifier.py` (9/9 pass) and exercised the real `_classify_section_type` on crafted multi-limb clauses | Direct (runtime) |
| **Document** | This report + durable notes | — |

No files were modified during the audit. The only runtime action was read-only test/classifier execution against the existing `.venv`.

---

## 2. Is the RAG built around the persona? — Evidence

**Verdict: No. The RAG is persona-agnostic and the persona concept is absent.**

Direct findings (all read from source):

1. **Single hardcoded answer identity.** `src/rag/pipeline.py:1316-1336` (and the
   streaming twin at `:1576-1584`):
   ```
   SYSTEM_PROMPT_PREFIX + "\n\nYou are a careful insurance-document assistant.
   Answer only from the provided context. Cite the source indices...
   If the context does not contain the answer, say so explicitly instead of guessing."
   ```
   This is a *grounding* instruction, not a *policy-wording* instruction. It never asks the
   model to identify a coverage trigger, resolve a defined term, check an exclusion against a
   grant, or test an adversarial interpretation.

2. **No persona/agent framework.** Grep for `langgraph|autogen|crewai|langchain|
   llama_index|haystack|semantic_kernel|pydantic_ai` in `src/` returns nothing (one local
   variable named "haystack"). The RAG is hand-rolled on the OpenAI SDK. "Agent" in this repo
   means the developer's coding harness, not an insurance agent.

3. **"Persona" is a blocked attack pattern, not a feature.** `src/security/prompt_injection.py:29-32`
   includes `new persona | act as | pretend to be | DAN mode` in the role-hijack regex. So the
   system is actively designed to *refuse* user-supplied personas. The legitimate, hardcoded
   identity is the only one.

4. **No coverage-reasoning logic in any prompt.** Every LLM instruction in the codebase is an
   inline string constant (no template files). None encodes a coverage-trigger → exclusions →
   exceptions → conditions → limits chain. The structured output (`RAGAnswer`,
   `src/models/rag.py:51`) is a generic grounded-answer schema, **not** a coverage decision.

5. **The only "expert/specialist" language** is for *backend document extraction*
   (`src/services/policy_extraction_service.py:147` — "expert insurance document analyst"),
   not the user-facing chat.

**Conclusion:** the product is deliberately *persona-light* (a conservative, no-personality
assistant per `UX_AUDIT_FIRST_PRINCIPLES.md`). That is a defensible trust position — but it
means the system has no machinery to *reason about policy structure*, which is precisely what
"makes understanding policies easier."

---

## 3. How policies are represented today (the substrate)

Two representations exist, and they are **not connected**:

- **Chat-path representation:** plain-text chunks + a coarse keyword `section_type`.
  Taxonomy (`src/rag/pipeline.py:2136-2144`, enforced by
  `supabase/migrations/20260720000000_chunk_links.sql:18-27`):
  `general, definition, exclusion, benefit, sub_limit, schedule, waiting_period, contact`.
  A chunk is labeled by *majority keyword count*.
- **Orphan representation:** `policy_extraction_service` produces a structured
  `document_policy_summaries` (benefits, exclusions, waiting periods, coverage items,
  type-specific clause fields). It is written at ingest (`document_processing_service.py`,
  `api/document.py`) but **the `query_rag` chat never reads it.** Confirmed by grep: those
  symbols appear only in ingest/extraction paths, never in the retrieval/answer path.

So the structure the persona needs (insuring agreement, conditions, endorsements, exceptions,
deductibles, clause interactions) is **partially extracted but discarded at query time**, and
**the live chunk taxonomy cannot even name most of it.**

---

## 4. Where the persona would help — gap map

Each gap is the persona's reasoning chain or a named failure mode, mapped to a concrete code
location.

### 4.1 Taxonomy gaps (chunk `section_type`)
| Persona concept | Current state | File |
|-----------------|--------------|------|
| Coverage trigger / insuring agreement | **No type.** A grant + carve-out is mislabeled (see §5). | `pipeline.py:2136`, migration `:18-27` |
| Conditions (incl. claims conditions, notification) | **No type.** Falls to `general`. | same |
| Endorsements / riders (override base wording) | **No type.** Falls to `general`. | same |
| Exceptions (to exclusions) | **No type.** Folded into `exclusion`. | same |
| Deductibles | **No type.** Only `sub_limit` approximates. | same |
| Definitions | *Weak:* type exists, but retrieval does not privilege definition chunks when a defined term is used in the query. | `pipeline.py:2136` |

### 4.2 Reasoning gaps (prompt / output)
| Persona step | Current state |
|--------------|--------------|
| Identify coverage trigger → confirm scope → check exclusions → check exceptions → confirm conditions → apply limits/deductibles → check endorsements | **Absent.** The answer prompt is generic grounding only (`pipeline.py:1319-1325`). |
| Defined-term resolution | **Absent.** No instruction to pull the defined meaning of a term when the query uses it. |
| Adversarial interpretation test ("most reasonable unintended reading?") | **Absent.** No prompt asks the model to surface ambiguity or alternative interpretations. |
| Coverage decision output | **Absent.** `RAGAnswer` has no `coverage_mapping` (covered / not-covered / conditional; which exclusion applies; which limit caps; which endorsement amends). |

### 4.3 Structural gap (the orphan layer)
The pre-extracted `document_policy_summaries` + `extracted_fields` (evidence substrate) are
**never fused** into the chat answer. A wording persona layer is the natural consumer that
would connect "structured benefits/exclusions" with "retrieved raw chunks" instead of leaving
them as parallel, disconnected artifacts.

---

## 5. Testing evidence — the gap is real, not theoretical

Ran `tests/test_section_classifier.py`: **9/9 passed** (baseline classifier works as designed).
Then exercised the **real** `_classify_section_type` on crafted multi-limb clauses drawn from
real wording patterns:

| Input clause | Classifier output | Why it's wrong vs the persona |
|-------------|------------------|-------------------------------|
| "We will pay for hospitalization **except where** caused by a pre-existing condition." | `exclusion` | A benefit grant with a carve-out is collapsed to pure `exclusion`; the benefit half is lost. Persona: treat grant + exception together. |
| "This policy covers cyber extortion losses, **but not** payments prohibited by sanctions law." | `general` | Coverage trigger + sanctions exclusion is **invisible** to the taxonomy. |
| "Subject to the overall aggregate limit, we will indemnify you for loss of baggage." | `general` | Benefit gated by a limit is invisible. |
| "In the event of a claim, the insured must notify us within 30 days in writing." | `general` | A claims **condition** has no type. |
| "Endorsement No. 4 amends the base wording to increase the sum insured." | `general` | An **endorsement** that overrides base wording has no type. |
| "For the purposes of this section, 'insured' means the person named on the schedule." | `definition` | Correct — the one category that works. |

**Interpretation:** the classifier literally cannot represent a clause that is *both* a grant
and an exclusion, or any endorsement/condition/exception. That is the persona's #1 and #2
failure modes ("treats clauses independently", "forgets endorsement interactions") encoded
into the data layer. This is the highest-leverage fix.

---

## 6. Recommendation — a persona-aware RAG (design, not yet built)

**Principle:** add the wording persona as a *reasoning + output* layer on top of the existing
retrieval and evidence substrate. Do **not** rewrite the security boundary, the two-text
evidence contract (`source_text` vs `retrieval_text`), or the citation/answer verifiers. They
are the strengths.

### 6.1 Change sites (concrete)
1. **System prompt** — `src/rag/pipeline.py:1319-1325` and `:1579-1584`. Replace the generic
   "careful assistant" with a *Policy Wording Specialist* instruction that:
   - requires the model to walk the 12-step chain for any "is X covered?" question;
   - instructs it to resolve defined terms via `definition` chunks;
   - instructs it to report the **applicable exclusion / exception / condition / limit /
     endorsement** explicitly;
   - includes the adversarial-interpretation step ("what is the most reasonable unintended
     reading, and does the wording permit it?");
   - preserves the existing grounding + abstain-if-unknown rules.
2. **Chunk taxonomy** — extend `_SECTION_TYPE_PATTERNS` (`pipeline.py:2136`) and the DB check
   constraint (`supabase/migrations/...chunk_links.sql:18-27`) to add
   `insuring_agreement`, `condition`, `endorsement`, `exception`, `deductible`. Keep
   multi-label (a chunk can be both `benefit` and `exclusion`) instead of majority-wins.
3. **Structured output** — extend `RAGAnswer` (`src/models/rag.py:51`) with an optional
   `coverage_mapping`: decision ∈ {covered, not_covered, conditional, ambiguous};
   `applicable_exclusions`, `applicable_exceptions`, `applicable_conditions`,
   `applicable_limits`, `amending_endorsements`; `alternative_interpretation` (the adversarial
   test result). The existing `verification_status` / citation machinery stays.
4. **Fuse the orphan layer** — have `query_rag` consult `document_policy_summaries` /
   `extracted_fields` for the asked-about policy as a structured priming context (not as
   citable answer text), so the model sees the pre-extracted benefit/exclusion map alongside
   retrieved chunks.
5. **Definition-privileging retrieval** — when a query contains a term defined in a
   `definition` chunk for that document, boost/append that definition chunk to context.

### 6.2 What NOT to do (persona failure modes to avoid)
- **Do not** make the persona "clarify the language" in a way that changes coverage. The
  instruction must forbid stylistic rewriting that alters obligations, exclusions, limits,
  timing, causation, or eligibility. Mirror the persona's "best agent instruction."
- **Do not** assume a jurisdiction or add undefined terms.
- **Do not** let the persona weaken the security boundary (`SYSTEM_PROMPT_PREFIX`,
  `SECURITY_SYSTEM_INSTRUCTION`) or the source-only citation rule. The persona is *added
  reasoning*, not a relaxation of grounding.
- **Do not** create a parallel/second RAG path. Extend the one pipeline; no shadow pipelines
  (motto_v5 canonical-route rule).

### 6.3 Test plan (to add alongside the change)
- Extend `test_section_classifier.py` for multi-label clauses (benefit+exclusion,
  condition, endorsement) — should pass after 6.1.2.
- New eval dataset (Ragas/Ragas-style) of "is X covered?" questions with **expected**
  coverage decisions + the specific exclusion/limit that decides it. Assert the
  `coverage_mapping` matches.
- Adversarial-interpretation assertions: for ambiguous clauses, the answer must surface the
  ambiguity rather than assert a single reading.
- Regression: existing `test_answer_verifier.py`, `test_citation_verifier.py`,
  `test_prompt_injection.py` must stay green (persona must not break grounding or open an
  injection vector).

---

## 7. Confidence & evidence tiers

- **Verified directly (code + runtime):** the single generic identity prompt
  (`pipeline.py:1316-1336`); the absence of any persona/agent framework; "persona" as a
  blocked injection pattern (`prompt_injection.py:29-32`); the 8-value `section_type` enum
  and majority-wins classifier (`pipeline.py:2136-2159`, migration `:18-27`); the orphan
  extractor layer (grep); classifier mislabeling of multi-limb clauses (ran it).
- **Inferred (high confidence, not runtime-tested):** that a wording persona would improve
  "is X covered?" correctness — inferred from the persona's reasoning chain matching the exact
  gaps found, and from the fact that the hard infrastructure (evidence substrate, verifiers) is
  already present.
- **Not verified this session (would need a live run):** end-to-end improvement measured on a
  real policy corpus with/without the persona; latency/cost delta of the longer reasoning
  prompt. Requires API keys + a representative policy set — recommended as the first
  implementation commit's eval.

---

## 8. Anything else? (motto_v5 standing review)

- **The orphan extraction layer is the biggest untapped asset.** It already extracts
  benefits/exclusions/clause fields per policy but is never shown to the chat model. Wiring it
  in (6.1.4) is likely a larger correctness win than prompt wording alone, and it is nearly
  free.
- **Mobile on-device lane is out of scope of this audit** but has its own hardcoded
  "offline reading assistant" prompt (`mobile/lib/services/on_device_inference_service.dart:19`)
  that also lacks wording reasoning. If the persona is adopted server-side, the on-device
  prompt should receive a parallel (lighter) instruction so the two lanes stay consistent.
- **Sub-personas from the brief** (Health / Cyber / Marine / Reinsurance Wording Specialist)
  are a natural future axis — the `section_type` taxonomy and the extraction service already
  have type-specific fields (health pre-existing, cyber sanctions, marine institute clauses).
  The persona can be parameterized by line-of-business without redesign.
- **No duplicate systems introduced** by this design — it extends the single pipeline.

---

## 9. Proposed next decisions (for Pranay)

1. **Adopt the Policy Wording Specialist as the RAG's reasoning persona?** (Recommended: yes,
   as an additive layer only.)
2. **Scope of first commit:** (a) taxonomy extension + multi-label, (b) prompt rewrite,
   (c) `coverage_mapping` schema, (d) orphan-layer fusion — which subset first?
3. **Eval corpus:** approve building a labeled "is X covered?" dataset as the acceptance gate
   before any prompt ships.

If yes, the work is a small number of gated commits on the existing pipeline (no new
infrastructure), each with its own test, ending in an eval that proves the coverage-reasoning
improvement.

---

## 10. Implementation Log (2026-08-12)

**Status of the recommendations above: implemented as an additive layer.** No new
infrastructure; the single `query_rag`/`query_rag_stream` pipeline was extended. Full
decision rationale, options, and the legal-safety contract are in
`adr_policy_wording_persona_2026-08-12.md`.

### 10.1 What was built

| # | Recommendation (from §6) | Delivered | Where |
|---|--------------------------|-----------|-------|
| a | Taxonomy extension + multi-label | New granular tags (`insuring_agreement`, `condition`, `endorsement`, `exception`, `deductible`) as multi-label `section_tags` in JSONB `metadata`; coarse parent mapping keeps the DB `section_type` enum stable (no migration) | `src/rag/pipeline.py`, `src/services/supabase_vector_store.py` |
| b | Persona prompt rewrite | Versioned Policy Wording Specialist (12-step reasoning scaffold) as single source of truth, stacked on `SYSTEM_PROMPT_PREFIX` (security boundary preserved) | `src/rag/persona.py` (NEW) |
| c | Coverage-interpretation schema | `WordingAssessment` + `CoverageLimitationRef`; `reading` enum (never "decision"); mandatory disclaimer; `persona_version` + `wording_assessment` stamped on `RAGAnswer` and the response | `src/models/rag.py`, `src/rag/pipeline.py` |
| d | Orphan-layer fusion | Pre-extracted policy structure surfaced as a **non-citable** priming block via `_build_policy_map_context` (reuses `PolicyExtractionService._load_summary`); defensive, never breaks retrieval | `src/rag/pipeline.py` |
| — | Retrieval refinement | Definition-privileging boost when the query asks about a term and the chunk is a definition | `src/rag/pipeline.py` (`_exact_match_boost`) |
| — | Evals + versioning | 12 labelled synthetic examples + offline/live harness + persona `CHANGELOG`/`PERSONA_VERSION` | `tests/evals/*`, `src/rag/persona.py` |

### 10.2 Verification (evidence tier: direct runtime)

- **44 tests pass** (existing `test_section_classifier.py` + `test_rag_pipeline.py` show no
  regression; new `test_persona_wording.py` + `test_evals_harness.py` cover persona
  construction, multi-label taxonomy, coarse mapping, definition boost, `WordingAssessment`
  schema, and `persona_version`/`wording_assessment` embedding in `query_rag`).
- **Offline eval harness runs end-to-end with zero network**: validates the dataset schema,
  runs the baseline judge, produces a scoreboard + JSON report
  (`tests/evals/report_offline.json`). The baseline is a heuristic smoke test, **not** a
  measure of the LLM persona.
- Syntax-checked all four edited modules; imports are clean.

### 10.2b Interim feature flag (2026-08-12, 13:36)

The persona is now gated by an **interim feature flag** `COVERWISE_POLICY_WORDING_PERSONA`
(**ON by default**; flip to `off/false/0/no/disabled` to revert byte-for-byte to the
pre-persona generic assistant). This was Pranay's proposal: ship the capability now, keep an
instant rollback/off-switch (legal-safety valve), and **defer the long-term decision about
*how* the persona gets invoked** (proper agentic flows) to later. Implementation detail: a
single chokepoint `build_system_message()` in `persona.py`; both query paths use it, and the
wording-assessment instruction + `persona_version` stamp are emitted only when on. Full
decision + design in ADR §9. Tests: flag parse matrix + `query_rag` integration asserting
`persona_version=None` / `wording_assessment=None` / instruction absent when off. (Test count
now **61 passing**.)

### 10.3 Legal-safety posture (verified in code)

- Persona interprets wording; never makes/approves/denies coverage, eligibility, claim, or
  legal decisions. Insurer decides. (`persona.py` hard rules + `WordingAssessment.disclaimer`.)
- No jurisdiction assumed; ambiguity surfaced rather than asserted.
- Security boundary (`SYSTEM_PROMPT_PREFIX` + `_harden_messages`) preserved and prepended;
  "persona/act as" remains a blocked injection pattern.
- Eval dataset is 100% synthetic — no real policies/PII.

### 10.4 Open item — DEFERRED live acceptance gate (task #16)

The **end-to-end accuracy lift and latency/cost** of the longer reasoning prompt were
**not** verified this session; that needs a live run on a **real policy corpus**. It is
implemented (`tests/evals/run_evals.py --mode live --allow-live`) and is the first
implementation commit's acceptance gate. Do **not** promote the persona from
"additive experimental" to "default" until this gate passes on a real corpus.

### 10.5 Recommended follow-ups

1. Run the deferred live gate on a licensed policy corpus; record accuracy/latency/cost.
2. Parameterize the persona by line-of-business (Health/Cyber/Marine — see §8) without redesign.
3. Align the on-device ("offline reading assistant") prompt with the server persona (§8).

