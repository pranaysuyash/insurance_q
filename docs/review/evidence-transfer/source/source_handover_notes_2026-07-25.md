# Source-code transfer evidence (BR-14 row 1)

Scope: one-time handover metadata for repository ownership transfer review.
Owner: Solo founder.

## Canonical references

- Repository path: `/Users/pranay/Projects/medpiper/insurance_app`
- Branch: `main`
- HEAD commit: `1eb3ccb858fc7ae5fb9d6eda25119fb16fbd7613`

## Current workspace state (owner-facing)

- Working tree: modified and with untracked files present.
- Modified tracked files: `200`
- Untracked files/dirs: `185`
- Branch drift vs `origin/main`: none shown as forced divergence in local branch status header.

## Reproducibility handoff command set

Use this command set when reconstructing a clean handoff source snapshot:

- `git fetch origin`
- `git checkout main`
- `git reset --hard origin/main`
- `git clean -fd` (only if you intentionally want a pristine export)
- `git status --short` (must return empty for a clean handoff state)

## Integrity snapshot (current state only)

```text
branch=main
head=1eb3ccb858fc7ae5fb9d6eda25119fb16fbd7613
modified_count=200
untracked_count=185
snapshot_updated_utc=2026-07-25T11:12:20+05:30
```

## Handoff note

- This file is non-secret and does not include binary artifacts.
- This row is attached for BR-14 with owner-side status: `in-progress (owner signatures + final archive hash still pending)`.
