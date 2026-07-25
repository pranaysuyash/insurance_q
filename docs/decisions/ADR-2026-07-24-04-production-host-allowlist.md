# ADR-2026-07-24-04: Fail closed on production Host headers

## Status

Accepted for implementation.

## Decision

The canonical production API entrypoint uses Starlette's
`TrustedHostMiddleware` with an explicit `ALLOWED_HOSTS` deployment setting.
Production configuration fails before startup when the setting is absent,
wildcarded, or contains a URL/path instead of hostnames.

## Context

The application runs on a FastAPI/Starlette version constrained below a newer
Starlette security release. Some advisory impact depends on an application
reconstructing a request URL from an untrusted Host header. The canonical API
also uses request URL data for observability, so deployment must reject
unconfigured and malformed Host values rather than delegate that boundary
entirely to an upstream proxy.

## Options considered

1. Depend only on edge proxy normalization. Rejected: it is deployment
   dependent and leaves the application boundary unprotected.
2. Pin a newer transitive Starlette release outside FastAPI's declared
   contract. Rejected: it masks ownership and is not a tested dependency graph.
3. Require an explicit API host allow-list and enforce it in the canonical
   entrypoint. Chosen.

## Implementation and validation

- `src/utils/runtime_config.py` validates `ALLOWED_HOSTS` in production.
- `src/app/main.py` binds that allow-list through `TrustedHostMiddleware`.
- `.env.example` and the launch playbook document hostname-only configuration.
- Tier 2 evidence covers fail-closed configuration, valid host parsing,
  malformed Host rejection, and the canonical entrypoint binding.

## Risks, rollback and revisit

An omitted provider or API hostname will produce a deliberate 400 response;
the deployment owner must include every direct health-check and public API
hostname. Roll back only by restoring a corrected allow-list—not a wildcard.
Revisit when a FastAPI release permits a fully patched Starlette line; rerun
the full locked-graph audit and reassess any remaining upstream findings.

Owner: engineering and deployment-account owner.
