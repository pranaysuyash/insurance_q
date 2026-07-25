# ADR-2026-07-24-03: Use PyJWT for anonymous HS256 identity tokens

## Status

Accepted for implementation.

## Decision

CoverWise uses `PyJWT` for its server-issued anonymous HS256 bearer tokens.
The canonical anonymous identity helper remains
`src/utils/anonymous_auth.py`; there is no additional token issuer, verifier,
or route.

## Context

The previous direct dependency, `python-jose[cryptography]`, brought
unresolved vulnerable transitive packages (`ecdsa` and `pyasn1`) into the
production OCR lock. The application uses only symmetric HS256 signing and
verification, issuer/audience validation, expiry validation, and bounded
previous-key rotation. None of the asymmetric algorithms or JWK capabilities
provided by that dependency are part of this flow.

## Options considered

1. Override the vulnerable transitive packages. Rejected: it would conceal
   ownership and could violate the JWT library's tested dependency contract.
2. Retain `python-jose` and accept the unresolved findings. Rejected: the
   dependency is limited to one small symmetric-token use case and a safer
   supported replacement is available.
3. Replace the direct JWT library with `PyJWT` while preserving the existing
   token contract and tests. Chosen.

## Implementation and validation

- `requirements.txt` pins `PyJWT==2.13.0` and removes `python-jose`.
- `src/utils/anonymous_auth.py` keeps HS256, issuer, audience, expiry,
  anonymous-subject fencing, bounded prior-key verification, and the existing
  generic 401 response for invalid credentials.
- The focused anonymous-auth suite exercises issuance, refresh continuity,
  key rotation, invalid tokens, production configuration, and API access.
- The Linux production OCR lock is regenerated before release. A full locked
  graph audit must be rerun; remaining findings are independently owned by
  the FastAPI/Starlette constraint and must not be hidden by an override.

## Risks, rollback and revisit

The token format stays standard JWT with the same HS256 algorithm and claims,
so existing valid anonymous tokens should continue to verify. Roll back by
restoring the prior direct dependency and implementation only if compatibility
testing demonstrates an unexpected client-token failure. Revisit if the
product introduces asymmetric signing, external JWKS, or account-provider
token verification; that would require a separate identity architecture
decision and end-to-end migration evidence.

Owner: engineering. A deployment remains gated on authenticated runtime,
production-key, and full locked-graph audit evidence.
