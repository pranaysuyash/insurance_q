# ADR-2026-07-19-05: Canonical architecture document lives at `docs/architecture/coverwise_canonical_architecture.md`

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** The canonical CoverWise architecture document lives at `docs/architecture/coverwise_canonical_architecture.md`. It is the single source of truth for "how does the system work end-to-end." All other architecture-shaped docs (dated audits, dated planning docs, dated decisions) are inputs to the canonical doc, not replacements for it.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** Accepted.
- **Related artifacts:** [`docs/architecture/coverwise_canonical_architecture.md`](../../architecture/coverwise_canonical_architecture.md) (the doc itself), [`docs/README.md`](../../README.md) (the meta-table-of-contents that points to the canonical doc), [`docs/decisions/README.md`](../../decisions/README.md) (the ADRs that the canonical doc references).

---

## Context

The architecture audit flagged this as ADR-10. The question is: where does the canonical CoverWise architecture document live? The audit's framing: the wrong location has compounding costs (the doc goes stale, drifts from reality, becomes a lie; the lie compounds as future work uses the stale doc as a reference).

The current state of the repo (before this ADR):

- `README.md` (top-level) and `docs/README.md` (top-level).
- `docs/planning/` — 17 dated planning docs. Some are architecture-shaped (`coverwise_platform_architecture_decision_2026-07-12.md`, `coverwise_supabase_canonical_plan_2026-07-16.md`, `coverwise_auth_architecture_2026-07-16.md`) but each is dated and is a planning artifact, not a living architecture doc.
- `docs/architecture/` — new directory I created on 2026-07-19 for the embedding methodology. This commit makes it the canonical home.
- `docs/decisions/` — the ADRs I created on 2026-07-19.
- `docs/audits/` — the 4 NO-GO audits from 2026-07-18.
- `docs/technical/deployment/` — the launch playbook.

There is **no canonical architecture doc today.** The `docs/planning/coverwise_supabase_canonical_plan_2026-07-16.md` is the closest, but it is dated, is about the Supabase plan (not the whole system), and was written before the substrate + outbox + coverage-gap work.

---

## Options considered

### Option A: `docs/CANONICAL_SYSTEM.md` (top-level, screaming snake case). REJECTED.

- **How it works:** the doc is at `docs/CANONICAL_SYSTEM.md`; one file, top-level, easy to find via the repo tree.
- **Pros:** findable in one click from `docs/`.
- **Cons:**
  - The screaming-snake-case name (`CANONICAL_SYSTEM.md`) is a style break. The repo convention is lowercase or Title-Case file names.
  - A top-level file in `docs/` is harder to discover via the directory structure. The agent skill conventions point to `docs/decisions/`, `docs/audits/`, `docs/architecture/` — not `docs/CANONICAL_SYSTEM.md`.
  - It implies a single file; the architecture doc grows over time and may need sub-docs.
- **Why rejected:** style break, convention break, no directory structure for future sub-docs.

### Option B: `docs/planning/coverwise_canonical_architecture_<date>.md` (dated, under planning). REJECTED.

- **How it works:** the doc is dated and lives in `docs/planning/`, following the existing convention of dated planning docs.
- **Pros:** matches the existing `docs/planning/` convention.
- **Cons:**
  - A date suffix in the filename implies versioning. The canonical doc is the long-lived version; the version is in the git log and the doc's "last updated" header, not in the filename.
  - `docs/planning/` reads as "decisions made in the past, not the system as it is today." Future readers looking for "the architecture" will not look there.
  - `docs/planning/` is the wrong semantic location. Planning is "what we are going to do"; architecture is "how the system is built."
- **Why rejected:** semantic mismatch; the dir reads as historical, not current.

### Option C: `docs/architecture/coverwise_canonical_architecture.md` (under the existing `docs/architecture/` dir). CHOSEN.

- **How it works:** the doc is at `docs/architecture/coverwise_canonical_architecture.md`. The directory `docs/architecture/` already exists (created on 2026-07-19 for the embedding methodology). The canonical doc joins its siblings.
- **Pros:**
  - The dir already exists; the convention is established.
  - The filename `coverwise_canonical_architecture.md` is unambiguous. Future readers see the name and know it is the canonical one.
  - The doc is the only one in the dir without a date suffix; the dated sub-docs (like `embedding_model_benchmark_methodology_2026-07-19.md`) are clearly not the canonical one.
  - Matches the agent skill conventions: agents looking for architecture docs naturally look in `docs/architecture/`.
  - Future sub-docs (per-component architecture, per-integration architecture) live in the same dir.
- **Cons:** none significant. The doc is at one extra path component (under `architecture/`) but the dir already exists.
- **Why chosen:** the dir is established, the filename is unambiguous, the convention is the right one.

---

## Chosen path

**Option C: `docs/architecture/coverwise_canonical_architecture.md`.**

The doc is:

- The single source of truth for "how does CoverWise work end-to-end."
- Updated when the system changes. The "last updated" header inside the doc carries the timestamp.
- Not versioned in the filename; the version is in the git log.
- Cross-referenced from `docs/README.md` (the meta-table-of-contents).
- Cross-referenced from the ADRs (each ADR's "Links" section).
- The doc's content is a map, not a code dump. The code is the truth; the doc is the navigation.

The doc is **not**:

- A code reference (that's the source files).
- An audit (that's `docs/audits/`).
- A decision record (that's `docs/decisions/`).
- A planning doc (that's `docs/planning/`).
- A deployment guide (that's `docs/technical/deployment/`).

---

## Why this path

### 1st-principle argument

The architecture doc is the **map of the system.** It is the entry point that says "here is the system, here are the pieces, here is how they fit." The map is a single artifact. A map that lives in many places is not a map; it is a set of competing claims about the territory. The wrong answer to "where does the canonical doc live" is "everywhere" or "nowhere" — both make the doc untrustworthy. The right answer is one place, findable, durable.

### Anti-staleness argument (motto v3 §0.4 acceptance contract)

A doc that goes stale is a lie. The chosen path has a maintenance contract: when the system changes, the doc is updated in the same commit. The contract is enforceable by the launch playbook's pre-commit hook and the motto v3 §0.4 rule that "the doc is part of the work, not optional polish." Without this contract, the doc drifts; the audit's NO-GO is partly about this exact failure mode.

### Anti-parallel-paths argument (motto v3 §0.1)

If the doc lived in `docs/` and `docs/architecture/` and `docs/planning/`, three different readers would find three different versions. The contradictions would compound. One location eliminates the parallel-paths anti-pattern for documentation.

### Convention argument

The repo already has `docs/architecture/` (with one doc). The dir is the convention. The chosen path joins the convention; it does not invent a new one. The convention is findable from the agent skill catalog and the `docs/README.md` directory structure.

### Findability argument

Three paths to the doc:

1. **From `docs/README.md`:** the meta-table-of-contents has a "Canonical architecture" section that points to the doc.
2. **From `docs/architecture/`:** the dir's only undated file.
3. **From the ADRs:** every ADR's "Links" section points to the doc.

A reader who knows what they are looking for (architecture, system design, end-to-end flow) finds the doc in one click from any of these paths.

### Long-term argument (motto v3 §0)

The doc is the long-term-correct artifact. The code is short-term (it changes every commit); the doc is long-term (it changes when the system changes, not every commit). The filename has no date because the doc is the same doc over time. The version is in the git log. This matches the motto v3 §0 "build the best app, not the safest small change" — the doc is a long-term investment, not a per-commit churn.

---

## Tradeoffs

- **The doc is one file.** A long file (500+ lines) is harder to navigate than a directory of sub-docs. Mitigation: the doc is organized with a clear table of contents at the top; sub-docs (like the embedding methodology) live in the same dir and are cross-referenced.
- **The doc is updated by hand.** There is no automated doc-generation. If the system changes and the doc is not updated, the doc drifts. Mitigation: the pre-commit hook + motto v3 §0.4 enforcement; the "What would cause this decision to be revisited" section below.
- **The doc is not exhaustive.** It is a map, not the territory. Code is the truth. The doc is the navigation. If the doc disagrees with the code, the code is right; the doc is updated.
- **The doc may be controversial in scope.** Some readers will say it is too long; some will say it is too short. The chosen length is "what a new engineer needs to understand the system in 30 minutes." That is a deliberate choice; it is not a free-form length.

---

## Assumptions

- **`docs/architecture/` is the right directory.** It was created on 2026-07-19 for the embedding methodology and is the right place for the canonical doc. If the dir is renamed in the future, the doc moves with it; the ADR is updated.
- **The doc will be updated when the system changes.** The operator (you) is the doc's primary maintainer; agents and future engineers update it in the same commit as the system change.
- **The `docs/README.md` "current source of truth" section is updated to point to the canonical doc.** The dated planning docs that previously held that role are demoted to "historical inputs to the canonical doc."
- **The doc is single-file, not multi-file.** A multi-file architecture (with a top-level `index.md` and per-section sub-docs) is a future option; the single-file approach is the v1.

---

## Risks

- **The doc goes stale.** Mitigation: the launch playbook's pre-commit hook reminds contributors to update docs in the same commit; the agent skill catalog points to the doc; the motto v3 §0.4 rule is the discipline.
- **The doc becomes too long.** Mitigation: the doc's structure is "sections, not chapters"; each section is 30-50 lines. If a section grows, it becomes a sub-doc in the same dir, cross-referenced from the canonical doc.
- **The doc disagrees with the code.** The code is the truth. If they disagree, fix the doc in the next commit. The doc is not a contract; the schema and the tests are the contract.
- **A future agent creates a competing architecture doc.** Mitigation: the agent's skill catalog points to `docs/architecture/coverwise_canonical_architecture.md` as the canonical location; the ADR is the citation.

---

## Validation plan

- **Cross-references:** every ADR (5 of them, as of this commit) has a "Links" section that points to the canonical doc. Future ADRs do the same.
- **README pointer:** `docs/README.md` has a "Canonical architecture" section that points to the doc.
- **Launch playbook pointer:** `docs/technical/deployment/launch_playbook_2026-07-18.md` has a "System reference" section that points to the doc.
- **Doc self-test:** the doc answers 5 questions without consulting the code:
  1. What are the 5 main components?
  2. What are the 5 async paths?
  3. What happens when a user uploads a PDF? (the data flow)
  4. What is the trust + security boundary?
  5. What is the substrate and how is it populated?

  The 5 questions are the "new engineer 30-minute check." If a new engineer can answer all 5 from the doc alone, the doc is sufficient.

- **Doc-vs-code diff:** every 6 months (the same cadence as the embedding benchmark), the operator reviews the canonical doc against the current code. Drift is fixed in a doc-update commit; the commit message references the drift.

---

## Rollback or migration path

If the doc location is wrong (e.g. a future operator finds it unfindable), the rollback is:

1. Update the ADR to the new location.
2. Move the doc.
3. Update all cross-references (ADRs, README, launch playbook).
4. Leave a redirect in the old location if a git history search would otherwise break.

The doc itself is not a contract; the schema and the tests are the contract. Moving the doc does not break the system.

---

## What would cause this decision to be revisited

- **The doc is too long for one file.** Mitigation: split into `coverwise_canonical_architecture.md` (the top-level map) and per-section sub-docs in the same dir. The canonical doc remains the entry point; the sub-docs are the deep-dives.
- **The dir is renamed.** `docs/architecture/` becomes `docs/system/` or similar. The doc moves with the dir; the ADR is updated.
- **A new agent convention is established.** The agent skill catalog points to a different location. The doc moves; the ADR is updated.
- **The operator wants multi-version docs.** A v1 + v2 + v3 with explicit version-in-filename. Mitigation: this is the wrong shape for a canonical doc; the version is in the git log. Reject.
- **The audit's ADR-10 is updated.** New requirements from the operator or the audit; the ADR is updated; the doc is updated.

---

## Links

- **Affected files (this commit):**
  - `docs/architecture/coverwise_canonical_architecture.md` (new, the canonical doc itself)
  - `docs/decisions/ADR-2026-07-19-05-...md` (this file)
  - `docs/decisions/README.md` (updated index)
  - `docs/README.md` (updated; the "Canonical architecture" section replaces the "current source of truth" section)
  - `docs/technical/deployment/launch_playbook_2026-07-18.md` (updated; the "System reference" section)
  - `docs/planning/coverwise_audit_task_classification_2026-07-18.md` (updated; Bucket 5 #22 marked shipped)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-01](./ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md)
  - [ADR-2026-07-19-02](./ADR-2026-07-19-02-outbox-migration-deferred.md)
  - [ADR-2026-07-19-03](./ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default.md)
  - [ADR-2026-07-19-04](./ADR-2026-07-19-04-coverage-gap-claim-assistance-thin-slice.md)
  - `coverwise_architecture_audit_2026-07-18.docx` (the source audit, ADR-10)
- **Related code:** the canonical doc cross-references the 7 SQL migrations, the 5 main components, and the 5 async paths. The full code reference is the source tree.
- **Motto v3 alignment:** §0.1 (no parallel paths; one canonical doc, one location), §0.4 (acceptance contract; the doc is part of the work, not optional polish), §0.5 (evidence tiers; the doc is T1 static evidence, refreshed when the system changes), §0.10 (observability is delivery; the doc is the visible evidence of the system's shape), §0.12 (this document).
