# BR-14 Evidence Bundle: Dependencies and OSS obligations (2026-07-25)

Purpose: Provide non-sensitive dependency and license-obligation evidence for BR-14 transfer continuity.
Mode: Non-secret evidence only.

## Included artifacts

| File | SHA-256 | Notes |
|---|---|---|
| `docs/review/sboms/coverwise-production-ocr-sbom-2026-07-25.json` | `d9561b1fe61a97af097a209bb560a747a9c63603bafde6233e2e050bc3e70b95` | Canonical production OCR dependency SBOM from `requirements-production-ocr-linux-x86_64.lock` generated earlier in-session. |
| `docs/review/sboms/license-metadata-2026-07-25.json` | `801b16890e3e4a7e0ee034097613a69c05db42075c7c9df0f74bf7e5f54aa89b` | Per-component license metadata snapshot for SBOM evidence. |
| `docs/review/evidence/license-metadata-review-2026-07-25.json` | `c91af0cb1a8f11b1635e69030d8e0e71090b9042e5596edd9f89716bece9b8e0` | Approved license review ledger with copyleft/obligation notes and founder sign-off timestamp. |

## Compliance and obligations snapshot

- Total components reviewed: `106`.
- Declared metadata coverage: `99/106`.
- Approved copyleft acceptance: `AGPL-3.0` for `pymupdf` + `pymupdfb` (backend-only usage rationale documented).
- Current non-technical obligations to preserve on transfer:
  - Keep copyright/licensing notices for included OSS components.
  - Apply AGPL-3.0 source-distribution obligations for the accepted AGPL chain if redistribution practices change.
  - Keep mismatch notes for `fsspec`, `packaging`, `portalocker`, `pypdfium2`, `torch`, `torchvision`, `urllib3` (lock vs installed version mismatch).
- Approval basis: founder review log marks this packet as approved for continuity handoff at `2026-07-25T12:00:00+05:30`.

## Evidence status

- `Owner`: Solo founder.
- `Current status`: `Attached`.
- `Reviewer`: Founder.
- `Signature status`: `Pending owner handoff signature in BR-14 matrix`.
- `Last updated`: `2026-07-25T10:49:00+05:30`.

