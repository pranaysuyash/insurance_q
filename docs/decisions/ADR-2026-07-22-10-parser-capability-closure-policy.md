# ADR-2026-07-22-10 — Parser capability closure policy for launch claims

## Decision

We will treat document parser capability coverage as a **three-state runtime model** for launch: **Owned**, **Candidate**, and **Open**.

- Owned: capability status is `available` in `src/ocr/capability_registry.py` and is covered by live manifest cases in `docs/eval/document_intelligence/capability_manifest_v1.json`.
- Candidate: capability status is `candidate` but requires explicit benchmark, privacy, license, and recovery gates before policy-facing claims.
- Open: capability status is `routing_only`, `unavailable`, or not yet represented as stable evidence, and must stay out of policy claims except where explicitly marked as non-evidential annotations.

## Date

2026-07-22

## Context

The local research catalog `/Users/pranay/Downloads/document_parsers_extractors_catalog_2026_v2.xlsx` has strong breadth signals for text/layout/tables/forms-like tooling, but does **not** guarantee production-safe coverage for sentence boundaries, headings semantics, scanned tables, formula fidelity, handwriting, multilingual quality, or semantic image understanding.

We needed one durable way to prevent “catalog-driven optimism” and keep product claims aligned with source-linked evidence and gates.

## Options considered

1. **Use catalog status as launch status** (directly map local `Yes` counts to production readiness).
2. **Use manifest/registry status only** (ignore catalog signals for route decisions).
3. **Use a layered model** (catalog informs candidate lanes and exploration, but launch requires runtime ownership and gates).

## Chosen path

Option 3: layered model.

- Keep catalogs in a **discovery** role.
- Use `src/ocr/capability_registry.py` as the runtime truth for ownership.
- Use `docs/eval/document_intelligence/capability_manifest_v1.json` and evidence files as hard gates before default policy-facing routing.
- Preserve separate frontier candidates for later promotion, never as default lanes.

## Why this path

- It aligns with the evidence contract: structured source data is authoritative for claims.
- It preserves velocity by allowing frontier exploration without creating false launch confidence.
- It provides explicit close gates for each class, making planning and risk communication consistent across teams.

## Tradeoffs

- Slower feature promotion for frontier models (frontier research does not auto-promote).
- More explicit documentation and validation work is required for each class before user-facing claims.
- Reduced risk of policy or coverage misclaims and easier incident analysis when quality drops in one class.

## Assumptions

- The manifest is the canonical launch gate source for all policy-facing parser claims.
- Capability registry status is accurate for installed/disabled profiles and reflects runtime behavior.
- Runtime evidence must be source-linked (`CIR`/spans/artifacts), not just output text.

## Risks

- Gate debt can build if frontiers are never re-benchmarked.
- Candidate lanes may look attractive for demos but remain incorrectly used in UX copy if process discipline slips.
- Multilingual/handwriting exceptions may be over-used as “best effort” unless explicitly blocked in policy paths.

## Validation plan

- Keep per-commit-unit evidence audits in:
  - `docs/technical/document_parser_capability_catalog_2026-07-22.md`
  - `docs/technical/document_parser_capability_full_lane_map_2026-07-22.md`
  - `docs/review/exploration_map.md`
  - `docs/review/evidence/local-model-eval/capability_frontier_candidates_2026-07-22.json`
- Re-run:
  - `venv/bin/python tools/inspect_document_capabilities.py`
  - `venv/bin/python -m pytest -q tests/test_document_capability_benchmark.py`
  - targeted capability fixture generation before any default routing promotion.

## Rollback or migration path

- Any candidate promoted into default routing requires manifest evidence closure and explicit ADR update.
- If a promoted class regresses on benchmark gates, revert that class to Candidate and gate user-facing claims immediately while preserving legacy artifacts.

## Owner / next reviewer

- Owner: CoverWise engineering lead
- Reviewer: Product + trust/QA representative before each major capability promotion

## Links

- [src/ocr/capability_registry.py](../..//src/ocr/capability_registry.py)
- [docs/eval/document_intelligence/capability_manifest_v1.json](../eval/document_intelligence/capability_manifest_v1.json)
- [docs/technical/document_parser_capability_full_lane_map_2026-07-22.md](../technical/document_parser_capability_full_lane_map_2026-07-22.md)
- [docs/technical/document_parser_capability_catalog_2026-07-22.md](../technical/document_parser_capability_catalog_2026-07-22.md)
- [docs/review/evidence/local-model-eval/capability_frontier_candidates_2026-07-22.json](../review/evidence/local-model-eval/capability_frontier_candidates_2026-07-22.json)
- [docs/review/evidence/local-model-eval/workbook_class_summary_2026-07-22.json](../review/evidence/local-model-eval/workbook_class_summary_2026-07-22.json)
- [tools/inspect_document_capabilities.py](../../tools/inspect_document_capabilities.py)

## Update log

- 2026-07-22: Initial decision published to lock “evidence-first, not catalog-first” promotion.
- 2026-07-22: Parser capability pass revalidated local workbook counts (149 rows / 17 columns), updated frontier candidates (incl. WACV DTBench and socOCRbench), and corrected `capability_class_coverage_index_2026-07-22.json` runtime anchor state for `scanned_ocr` to match `src/ocr/capability_registry.py`.
