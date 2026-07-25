# ADR-2026-07-24-06: Pin the compatible FastAPI and Starlette security baseline

## Status

Accepted for implementation.

## Decision

CoverWise pins `fastapi==0.139.2` and `starlette==1.3.1` in
`requirements.txt`. The generated Linux production lock is the only release
dependency graph. Starlette remains an explicit direct pin so a future
resolver run cannot silently retain a known-vulnerable, lower compatible
version.

## Context

The prior production lock selected `starlette==0.46.2` through an older
FastAPI pin and `pip-audit` reported nine known vulnerabilities in that
package. The prior remediation note correctly declined an incompatible
transitive override. Current upstream FastAPI metadata for 0.139.2 permits
`starlette>=0.46.0`, making Starlette 1.3.1 a compatible candidate and a
security fix path.

## Options considered

1. Keep Starlette 0.46.2 and accept the findings. Rejected: fixed upstream
   releases are available and the path carries avoidable known risk.
2. Override Starlette while retaining the old FastAPI framework pin. Rejected:
   the old direct framework contract was not sufficient evidence for a major
   transitive jump.
3. Upgrade FastAPI and pin the fixed Starlette baseline, regenerate the
   canonical lock, audit it, and run the complete backend suite. Chosen.

## Implementation and validation

- `requirements.txt` pins FastAPI 0.139.2 and Starlette 1.3.1.
- `requirements-production-ocr-linux-x86_64.lock` was regenerated with the
  documented Linux x86_64 hash-lock command.
- The local interpreter was updated to the same pair for verification.
- `pip-audit -r requirements-production-ocr-linux-x86_64.lock
  --require-hashes --disable-pip` reports no known vulnerabilities. It still
  reports that CPU-suffixed Torch wheels cannot be audited through PyPI; this
  is an explicit provenance/container-scan gate, not an audit pass for Torch.
- `tools/run_backend_tests.sh tests/` completed after collecting 615 tests
  with 2 skips under the upgraded framework (Tier 2).

## Risks, rollback and revisit

This is a framework upgrade, so it can affect request parsing, middleware,
exception handling, and test-client behavior despite passing local contracts.
Before production use, rebuild the container from the regenerated lock and
exercise authenticated, deployed API paths (especially upload, identity,
tenant isolation, deletion, billing webhooks, and streaming).

Rollback only by pinning a separately reviewed non-vulnerable framework pair
and regenerating the lock; do not restore Starlette 0.46.2 merely to recover a
local compatibility behavior. Revisit on any new FastAPI/Starlette advisory,
CI lock drift, or production compatibility regression.

Owner: engineering. Release still requires container provenance/scanning,
remote CI, credentials, and account-backed runtime evidence.
