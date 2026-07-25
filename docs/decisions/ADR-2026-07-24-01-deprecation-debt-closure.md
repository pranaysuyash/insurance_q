# ADR-2026-07-24-01: Deprecation debt closure at the supported boundaries

## Status

Accepted for implementation.

## Decision

CoverWise will keep deprecation warnings at zero for application-owned and
supported dependency boundaries. Dependency upgrades must be coordinated with
their framework peers and pinned in the production requirements. Third-party
warnings that remain in an optional path may be isolated only at that import,
with an explicit reason and an upgrade/replacement trigger.

The first closure slice is:

- FastAPI `0.104.1` -> `0.115.14`, which brings Starlette `0.46.2` and removes
  the legacy `TestClient` -> HTTPX `app=` construction.
- HTTPX `0.27.2` -> `0.28.1`, the supported API after the `app` shortcut was
  removed.
- Qdrant Client `1.6.9` -> `1.18.0`, removing the generated HTTPX `data=`
  upload path that emitted a deprecation warning during RAG health checks.
- `python-doctr[torch]` `0.7.0` -> `1.0.1`, the current release already used
  by the local environment.
- docTR predictor construction is lazy, so native-text documents do not load
  the optional OCR stack.

The current Supabase Python client remains `2.31.0`, its latest published
release. It is not replaced with an unvalidated alternative. Its integration
surface remains subject to the warning gate after the HTTPX upgrade.

## Context and first-principles reasoning

Deprecation debt is a product reliability issue: it obscures real failures,
raises upgrade cost, and makes the supported runtime contract unclear. The
right solution is to move each call site or dependency to its maintained API,
not to delete useful behavior or globally filter warnings.

Native PDF extraction and scanned-image OCR are different capability paths.
Initializing docTR for every document made the native path depend on an
optional ML/XML stack and exposed an upstream compatibility warning even when
OCR was not needed. Lazy construction preserves scanned-document capability
while making the fast, lower-dependency path independently reliable.

## Validation

- Focused FastAPI/TestClient/webhook/account tests: 44 passed.
- Native PDF, text-file, and Docling fallback tests under
  `-W error::DeprecationWarning`: 4 passed.
- Image OCR fallback under `-W error::DeprecationWarning`: 1 passed.
- RAG pipeline tests after the Qdrant upgrade: 9 passed with no deprecation
  warning. A separate Qdrant `UserWarning` remains when the configured local
  server is unreachable during a health-check test; it is operational status,
  not deprecation debt, and should remain visible until the runtime health
  surface owns that state explicitly.
- The full Python suite baseline before this slice was 532 passed, 1 skipped,
  and 47 warnings. Re-run the full suite after the requirements lock is
  refreshed; the deployed integration skip remains a separate environment
  gate.

## Remaining risk and revisit trigger

docTR 1.0.1 still imports the deprecated `defusedxml.cElementTree` alias.
The warning is narrowly filtered only around that optional import because the
upstream package has not moved to `defusedxml.ElementTree`. Replace the
filter with the upstream fix or a maintained OCR alternative when available;
do not broaden the filter or use it for application code.

Revisit this decision when FastAPI/Starlette, HTTPX, Supabase Python, or docTR
publish a compatibility release that changes these boundaries, or when the
OCR workload justifies evaluating a maintained alternative.

## Anything else?

The next gate is a clean full Python run with warnings enabled, followed by a
fresh lockfile/production install verification. No commit or push is implied
by this ADR.
