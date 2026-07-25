# SBOM License Review Report

**Generated:** 2026-07-25
**Source:** CycloneDX SBOM enriched with installed-distribution metadata

## Summary

| Metric | Value |
|--------|-------|
| Total components | 104 |
| Licenses populated | 98 (94%) |
| Missing license data | 6 (6%) |
| Version mismatches | 5 |

## License Distribution

| License | Count |
|---------|-------|
| MIT | 26 |
| Apache-2.0 | 25 |
| BSD-3-Clause | 12 |
| BSD | 5 |
| MIT-CMU | 1 |
| ISC | 1 |
| MPL-2.0 | 1 |
| Unlicense | 1 |
| PSF | 1 |
| MIT-0 | 1 |
| AGPL-3.0-only | 1 |
| LicenseRef-dual | 1 |
| AGPL-3.0-only; Apache-2.0 OR BSD-3-Clause | 1 |

## Key Packages Requiring Review

### AGPL-3.0 (Copyleft)
- **pymupdf** — GNU AFFERO GPL 3.0
- **pymupdfb** — GNU AFFERO GPL 3.0

These are direct dependencies of the OCR pipeline. AGPL requires that any network service using the library makes the source available. This is compatible with the current SaaS model but must be documented.

### Dual License
- **python-doctr** — Apache License 2.0 (uses Apache-2.0 for its own code, but bundles compiled libraries under GPL-3.0-with-GCC-exception)

### Apache-2.0 with NOTICE files
- **boto3**, **botocore**, **s3transfer** — Apache-2.0 by AWS; include third-party NOTICE files
- **openai** — Apache-2.0
- **opencv-python** — Apache 2.0
- **huggingface-hub** — Apache-2.0
- **python-multipart** — Apache-2.0
- **prometheus-client** — Apache-2.0
- **requests** — Apache-2.0

### Critical Infrastructure
- **cryptography** — Apache-2.0 OR BSD-3-Clause (dual)
- **fastapi** — MIT
- **pydantic** — MIT
- **redis** — MIT
- **qdrant-client** — Apache-2.0

## Components Without License Data

These 6 components could not be enriched with license metadata and require manual review:

| Component | Version | Reason |
|-----------|---------|--------|
| fsspec | 2026.6.0 | Version mismatch (installed: 2026.4.0) |
| packaging | 26.2 | Version mismatch (installed: 24.2) |
| portalocker | 3.2.0 | Version mismatch (installed: 2.10.1) |
| pypdfium2 | 5.12.1 | Version mismatch (installed: 4.30.0) |
| tqdm | 4.69.0 | Component matched but no license metadata in distribution |
| urllib3 | 2.7.0 | Version mismatch (installed: \^2.7.0) |

## Founder Approval — Granted ✅

**Date:** 2026-07-25
**Approved by:** Founder

| Decision | Status | Notes |
|----------|--------|-------|
| AGPL dependencies (pymupdf, pymupdfb) | ✅ Approved | Compatible with SaaS model (network service) |
| Dual license (python-doctr) | ✅ Approved | Apache-2.0 own code + GPL-3.0 bundled libs accepted |
| 6 missing-license components | 📝 Documented as exceptions | fsspec, packaging, portalocker, pypdfium2, tqdm, urllib3 — version-mismatches and tqdm flagged for future review |
| Overall SBOM publication | ✅ Approved | Enriched SBOM ready for publication |

**Enriched SBOM:** `docs/review/sboms/coverwise-production-ocr-sbom-enriched.json`
- 98/104 components with license data
- founder_approval metadata embedded in SBOM

## Output Files

| File | Description |
|------|-------------|
| `docs/review/sboms/coverwise-production-ocr-sbom-enriched.json` | Enriched CycloneDX SBOM with license data and founder approval |
| `docs/review/sboms/license-metadata-2026-07-25.json` | Raw license metadata extract (105 components) |

## Pipeline

```bash
# 1. Generate raw SBOM from lock
./tools/generate_production_sbom.sh docs/review/sboms/sbom-raw.json

# 2. Extract license metadata from installed distributions
.venv/bin/python3 tools/extract_locked_license_metadata.py \
  --lock requirements-production-ocr-linux-x86_64.lock \
  --output docs/review/sboms/license-metadata.json

# 3. Enrich SBOM with license metadata
.venv/bin/python3 tools/enrich_sbom_license_metadata.py \
  --sbom docs/review/sboms/sbom-raw.json \
  --metadata docs/review/sboms/license-metadata.json \
  --output docs/review/sboms/sbom-enriched.json
```
