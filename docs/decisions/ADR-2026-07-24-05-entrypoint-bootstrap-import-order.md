# ADR-2026-07-24-05: Preserve intentional API entrypoint import order

## Status

Accepted for implementation.

## Decision

`src/app/main.py` retains its intentionally non-standard import order and has
a file-scoped, documented Ruff E402 deviation.

## Context

The canonical API sets macOS native-library search paths before importing code
that can reach optional OCR/PDF dependencies. It also normalizes Supabase's
modern server-key name before modules construct server clients. Finally, it
imports and mounts the public frontend after API route registration so the API
continues to win route precedence.

Moving all imports above bootstrap or moving the frontend mount earlier would
make the code look conventional while risking native runtime failures,
configuration drift, or a duplicate public route boundary.

## Options considered

1. Reorder imports mechanically. Rejected: violates the required startup and
   route-precedence contracts.
2. Suppress individual warnings without explanation. Rejected: hides a
   material architectural decision.
3. Keep the order, add an inline scoped reason and durable ADR. Chosen.

## Validation and revisit

The isolated production-entrypoint host test imports the canonical app with a
complete fake production configuration and verifies configured/malformed Host
behavior. Revisit if bootstrap moves into a dedicated pre-import launcher or
the frontend gains a separately deployed entrypoint; then remove the deviation
only after equivalent native/configuration/route-precedence coverage exists.

Owner: engineering.
