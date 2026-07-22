# ADR-2026-07-21-06: Deployed launch verification must require full service health

## Status

Accepted for implementation.

## Date

2026-07-21

## Context

The deployed launch verifier checked liveness, readiness, authentication, and
owner isolation, but did not check the full `/health` contract. The API can be
ready to accept requests while the canonical embedding provider is unusable.
In that state, document processing may initialize while RAG is degraded; a
green launch smoke test would therefore overstate the product's actual
capability.

The current staging API reproduced this exact case: `/readyz` returned HTTP 200
and `/health` returned HTTP 503 with the canonical Supabase embedding provider
refusing to mix embedding spaces after an invalid OpenAI credential response.

## Decision

`tools/verify_deployed_launch.py` treats `/health` as a required launch gate.
The service-health check passes only when the endpoint returns HTTP 200 and a
`{"status": "ok"}` payload. A degraded response is a release failure,
not a warning that can be ignored by the verifier.

## Why this path

Liveness answers whether the process exists; readiness answers whether the API
can serve its basic contract; full health answers whether the product's
configured capabilities are operational. Launch acceptance needs all three.
Keeping the check in the existing canonical verifier avoids a second smoke
tool or a parallel health definition.

## Tradeoffs

- A provider outage or invalid credential blocks release even when basic API
  routes work.
- This increases launch truthfulness and prevents a degraded RAG experience
  from being shipped under a green operational label.
- A deliberately partial deployment must use a separate, explicitly named
  development check; it cannot reuse the production launch verdict.

## Assumptions and risks

- `/health` remains the canonical aggregate capability endpoint.
- A future intentional partial-product launch would need a separately reviewed
  contract rather than weakening this gate.
- The check does not prove extraction quality, real-data correctness, or
  production provider quotas; those remain separate evidence gates.

## Validation plan

- Unit tests prove degraded health fails and an `ok` health response passes.
- The local staging verifier must show the current provider failure explicitly.
- A deployed verification run must pass after the embedding credential and
  remote schema gates are repaired.

## Rollback or migration path

There is no data migration. Revert the verifier and its tests only through a
new reviewed decision if `/health` is replaced by a canonical successor. Do
not add an `--ignore-health` bypass to the production verifier.

## Owner / next reviewer

Owner: Pranay. Next review: before the first production deployment.

## Links

- `tools/verify_deployed_launch.py`
- `tests/test_verify_deployed_launch.py`
- `docs/review/launch_execution_status_2026-07-21.md`
- `src/app/main.py`

## Anything else?

Yes: this gate distinguishes process availability from product capability,
which is especially important for model-backed extraction and RAG. The verifier
still does not claim production readiness until real provider credentials,
remote schema state, deployed runtime, and consented end-to-end evidence are
all independently verified.

## Update log

### 2026-07-21 — Initial record

Recorded after the current staging API reproduced readiness 200 versus health
503 and the verifier was strengthened to fail closed on degraded health.

### 2026-07-21 — Durable worker gate

The same canonical verifier now supports an optional `--worker-url` for the
internal outbox worker. When supplied, `/readyz` must return both
`{"status":"ready"}` and `{"worker":"outbox"}`. This remains optional at
the public API smoke boundary because the worker is intentionally internal;
production acceptance requires running it from an authorized network context.
