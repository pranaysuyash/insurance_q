# Legacy `policy_rag_hybrid.py` review — 2026-07-24

## Finding

`src/policy_rag_hybrid.py` is not a runnable application despite its historical
Streamlit-oriented header. Static inspection shows 25 lines: a module
docstring and 14 imports, with no functions, classes, state, or executable
application setup. A repository-wide reference search found no runtime caller
or packaging entrypoint. The file compiles, but compilation only proves its
import syntax is valid; it does not establish a usable feature.

The launch-preparedness audit already identifies this path as a dead parallel
implementation alongside the retired OCR sidecar and other earlier surfaces.

## Buyer and operator impact

Leaving an empty prototype under `src/` creates a misleading apparent product
surface, adds unused optional dependencies, and prevents a clean static-check
baseline. It is not part of the canonical authenticated document-query flow.

## Decision (2026-07-24)

**Product owner decision:** Archive the Streamlit prototype — the product is
mobile-first and the Streamlit-based approach does not serve the current
architecture.

**Action taken:**
1. Moved to `docs/legacy/policy_rag_hybrid_prototype.py` with a historical
   header explaining its context and pointing to the canonical implementation.
2. Removed `src/policy_rag_hybrid.py` from the source tree.
3. Verified the archived copy compiles and preserves the original content.
4. Confirmed no dependencies are orphaned — the imported packages
   (`streamlit`, `pdfplumber`, `pytesseract`, `pdf2image`, `pypdf`, `pandas`,
   `langchain_community`) were not listed in any requirements file and are
   not used elsewhere in the project.

## Evidence

- Static source inspection: 25 lines; only docstring/import nodes (Tier 1).
- Repository reference search: no live caller or entrypoint found (Tier 1).
- `.venv/bin/python -m py_compile src/policy_rag_hybrid.py`: passed (Tier 2
  syntax-only evidence).
- Archived file at `docs/legacy/policy_rag_hybrid_prototype.py` (Tier 2).
- Full Ruff static check after removal (Tier 2).

## Closure criteria

- [x] Product owner recorded archive decision (mobile-first product rationale).
- [x] File preserved in `docs/legacy/` with historical context header.
- [x] Dependency review complete — no orphaned dependencies.
- [x] Route/module-map updated — file removed from `src/`.
- [x] Full static check pass confirmed.
