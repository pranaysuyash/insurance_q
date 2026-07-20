# CoverWise Testing, Release Engineering, Developer Experience, and Documentation Audit

**Date:** 2026-07-18  
**Repository:** `pranaysuyash/insurance_q`  
**Branch:** `main`  
**Commit:** `e3440a5da174c0cbbe279878bdff21950d8cab63`  
**Evidence tier:** Tier 1 static inspection  
**Current check evidence:** GitHub combined status returned no statuses for the audited commit  
**Scope:** automated tests, evaluation, CI, builds, migration validation, security scanning, release promotion, contracts, fixtures, developer setup, repository hygiene, documentation truth, and agent handoff

---

## Executive Summary

CoverWise has many test files and a strong habit of writing review documents. It does not currently have a trustworthy release signal.

The present CI workflow is structurally stale:

- it runs `npm install` and `npm run build` at repository root;
- no root `package.json` exists at the audited commit;
- it never installs Flutter;
- it never runs `flutter analyze`, `flutter test`, Android/iOS builds, or mobile integration tests;
- it does not apply/test Supabase migrations;
- it does not run real parser/retrieval/evaluation fixtures;
- it does not run secret, dependency, SAST, container, licence, SBOM, or provenance gates;
- it builds/pushes a mutable Docker `latest` tag after Python tests/lint only;
- no current check status is attached to `main`.

The test suite also overstates evidence:

- `tests/test_integration.py` mostly asserts hard-coded sample variables and reimplements production algorithms locally;
- `tests/test_performance.py` measures sleeps and test overhead, not product performance;
- the evaluation runner is disconnected from the actual response schema;
- account-deletion tests explicitly accept success when source cleanup fails;
- model/RAG tests mutate global settings and often exercise constructed objects rather than production composition;
- high-risk paths have unit/widget coverage but no production-like system evidence;
- earlier documents claim hundreds of passing tests, clean analysis, or production readiness without a reproducible run for this commit.

Documentation is abundant but contradictory. The README starts with the current Cloud Run/Supabase decision, then preserves a long historical section with production URLs, green checks, fully operational, all tests passing, offline functionality, and Play Store readiness.

**Verdict: NO-GO for a release based on current repository signals.**

The next goal is a reproducible evidence pipeline that builds the actual backend and mobile app, validates migrations/contracts, runs risk-based tests, produces immutable artifacts, and publishes one machine-readable release manifest.

---

# 1. What Is Strong and Should Be Preserved

- Tests exist for authentication, upload validation, ownership, leases, Q&A, policy detail, offline emergency, processing status, components, motion, entitlements, consent, and RAG helpers.
- Anonymous token validation, upload signatures, and owner-scoped access have targeted tests.
- Production and local requirements are separated.
- The top of README identifies current canonical deployment and missing gates.
- `motto_v3` provides a useful evidence-tier discipline.

The issue is not absence of testing intent. It is inaccurate test classification and no enforced release pipeline.

---

# 2. P0 Findings

## P0-01: The audited commit has no current CI/check evidence

GitHub combined status returned no checks for `e3440a5...`. Commit messages or prior local claims are not a reproducible release signal.

### Required action

Protect `main` with required checks and include exact run IDs/artifacts in a release manifest.

---

## P0-02: CI references a missing root Node project

`.github/workflows/ci.yml` installs Node 16, runs `npm install`, and `npm run build`. No root `package.json` exists.

### Required action

Remove stale Node stages or add a clearly owned current web build with lockfile and tests.

---

## P0-03: Flutter is absent from CI

The customer surface is Flutter, but CI does not install a pinned Flutter SDK, run formatting, analyse, test, Android build, iOS build, release configuration, or integration tests.

### Required action

Make Flutter checks required for every product change.

---

## P0-04: “Integration tests” do not execute integration

`tests/test_integration.py` claims upload → OCR → extract → query → answer, but constructs sample text/entity lists and duplicates classifier/evaluator/RRF logic inside tests.

### Required action

Rename helper tests honestly and add real integration against a disposable Postgres/pgvector environment, object-store adapter, canonical API, durable jobs, and deterministic model fixtures.

---

## P0-05: “Performance tests” do not measure the product

The performance tests sleep for milliseconds and assert framework overhead. They do not call parser, storage, retrieval, model, or API paths.

### Required action

Create component benchmarks, page/size scaling tests, query p50/p95 harness, scheduled live-provider benchmark, and load tests with cost/resource output.

---

## P0-06: The evaluation runner does not match actual responses

It reads sources at the wrong level, checks structured fields in a general answer response, and can skip source requirements when no sources are read.

### Required action

Replace with task-specific evaluation suites tied to immutable source documents and evidence labels.

---

## P0-07: Tests codify unsafe behaviour as success

`tests/test_user_account_deletion.py` expects HTTP 200 and metadata deletion when source-object deletion fails.

### Required action

Treat tests as product contracts. Unsafe expected behaviour must change before implementation.

---

## P0-08: No production-data-plane integration tests

No required CI path applies Supabase migrations and verifies owner isolation, service-role-only RPCs, vector dimensions, Storage privacy, claim migration, deletion, leases, filtered retrieval, or upgrade/rollback compatibility.

### Required action

Use disposable Postgres with pgvector plus a faithful Supabase test project/container where needed.

---

## P0-09: No mobile/backend contract tests

Dart manually accepts multiple legacy response shapes. No generated client or check proves OpenAPI and mobile DTO agreement.

### Required action

Generate or validate DTOs in CI and run response/error fixtures for every supported contract.

---

## P0-10: No real mobile end-to-end flow

No required emulator/device test proves:

```text
install
  -> consent
  -> anonymous identity
  -> upload supported policy
  -> durable process
  -> evidence summary
  -> verified question
  -> remote deletion
```

Account claim/switch/restore, offline queue, notifications, deep links, purchases, and erasure also lack production-like end-to-end gates.

---

## P0-11: No release security and supply-chain gates

CI lacks visible secret scanning, dependency vulnerability scan, SAST, container scan, SBOM, licence policy, image signing/provenance, mobile dependency review, and infrastructure/config linting.

---

## P0-12: Supabase migrations are manual and not release-gated

Documentation instructs applying SQL in the Supabase editor. No migration tool, ordered CI/staging application, schema-version check, or rollback exists.

### Required action

Treat migrations as immutable release artifacts, applied and verified before traffic promotion.

---

## P0-13: No release build or store-package verification

No required evidence covers Android AAB, signing, minification, release environment, data-safety declaration, deep links, backup rules, permissions, iOS archive/signing, or store metadata/screenshots matching the binary.

---

## P0-14: Documentation contains contradictory readiness claims

README says not deployed and lists missing launch evidence, then retains historical fully operational, full offline functionality, all tests passing, and Play Store readiness. Labels do not eliminate agent/human confusion.

### Required action

Move historical body to archive. README must describe current truth only.

---

## P0-15: No machine-readable release manifest

A release should record git SHA, image digest, Flutter/lock versions, mobile build numbers, schema version, model/prompt/index versions, test/eval/security results, accepted risks, environment, and deployment revision.

---

# 3. P1 Findings

1. Python dependencies are not fully hash-locked.
2. Several pinned packages are old relative to current model/API assumptions.
3. ranged dependencies reduce reproducibility.
4. Flutter caret ranges and `pubspec.lock` are not enforced in CI.
5. no `pyproject.toml` centralises package/tool config.
6. lint commands are not evidenced as passing and may conflict with code style.
7. no coverage threshold.
8. stale Node stages may prevent the test job reaching execution.
9. no unit/integration/e2e markers and selective pipelines.
10. tests mutate global settings, environment, caches, and module globals.
11. no hermetic network-blocking test mode.
12. fake keys can still instantiate real clients or heavy local paths.
13. local OCR tests may require large downloads.
14. no fixture provenance/licensing manifest.
15. no reviewed golden extraction labels.
16. no prompt/schema snapshot/version strategy.
17. no property/mutation tests for amounts, dates, identifiers, and filters.
18. no fuzzing for files, PDFs, multipart, JSON, or deep links.
19. no concurrency tests for upload, lease, duplicate, claim, delete races.
20. no controlled-clock tests for expiry, reminders, token, and entitlement reset.
21. no process-death tests for upload/migration.
22. many widget tests verify controls rather than outcomes.
23. accessibility tests are not required.
24. no golden visual regression for core screens.
25. no marketing-site accessibility/security-header test.
26. no smoke test against exact promoted image.
27. no canary acceptance/rollback threshold.
28. mutable `latest` tags reduce reproducibility.
29. no generated release notes/changelog.
30. no minimum mobile/API compatibility policy.
31. no production test that retired routes are unavailable.
32. no repository gate against customer files, `.env`, DBs, or build secrets.
33. `.gitignore` is incomplete and no `.dockerignore` was found.
34. historical AWS/Azure scripts remain in active paths.
35. planning/review docs repeat and contradict canonical decisions.
36. older AI audits lack a central freshness/supersession index.
37. comments contain unsupported “SOTA” and percentage claims.
38. no docs lint/link/freshness checks.
39. canonical docs lack enforced owner/status/verified-commit metadata.
40. developer setup still references multiple historical stacks and lacks one tested bootstrap command.

---

# 4. Target Test Architecture

## Unit

Pure state transitions, normalisers, validators, redaction, evidence matching, and safe arithmetic.

## Component

Parser/OCR fixtures, extraction with deterministic model doubles, retrieval against real pgvector, repositories/storage, and Flutter services with mock server.

## Contract

OpenAPI ↔ Dart DTO, model provider adapters, Supabase RPC signatures, migrations, deep links, and billing callbacks.

## Integration

API + Postgres/pgvector + object store + durable jobs, including ownership, claim, delete, reprocess, restore, and evidence answer.

## Mobile end to end

Emulator/device critical paths with a controlled backend.

## Evaluation

Real labelled policy corpus for parser, fields, retrieval, answer, citation, abstention, latency, and cost.

## Staging acceptance

Exact release artifacts, external providers, operational alerts, instance kill/retry, backup restore, and erasure.

---

# 5. Target CI/CD Pipeline

```text
repository validation
  -> secrets/licences/dependencies
  -> Python format/lint/type/unit
  -> Flutter format/analyse/unit/widget
  -> migration lint/apply
  -> backend integration
  -> document-intelligence evaluation
  -> mobile contract/integration
  -> image build + SBOM + scan + sign
  -> Android AAB / iOS archive
  -> staging exact digest
  -> staging acceptance/security smoke
  -> risk approval
  -> canary
  -> observation/rollback gate
```

Required outputs:

- test/coverage reports;
- evaluation report;
- schema diff;
- SBOM/vulnerability result;
- image digest/signature;
- mobile artifacts/checksums;
- release manifest;
- deployment revision and acceptance result.

---

# 6. Documentation Architecture

Canonical set:

1. current-only `README.md`;
2. architecture overview;
3. domain/API;
4. document intelligence;
5. security threat model;
6. privacy/data lifecycle;
7. operations runbook;
8. evaluation/quality gates;
9. product scope/boundary;
10. accepted ADRs;
11. archive for superseded material.

Every canonical document should include owner, status, last verified commit, and superseded links.

---

# 7. Ordered Remediation

## Phase 0

Repair CI, remove missing Node stages, add pinned Flutter job, make checks visible, archive historical README, and stop readiness claims without artifacts.

## Phase 1

Correct unsafe tests, replace fake integration/performance/evaluation, add Supabase/API integration and critical Flutter flows.

## Phase 2

Add security/supply-chain gates, automate migrations, build immutable artifacts, and create release manifest.

## Phase 3

Staging acceptance, canary/rollback, load/chaos/restore/erasure drills, and documentation freshness enforcement.

---

# 8. Release Gates

- exact commit has required checks;
- CI has no stale stages;
- Python and Flutter format/lint/tests pass;
- critical mobile end-to-end passes;
- migrations apply from zero and upgrade current schema;
- ownership/deletion/claim integration passes;
- document-intelligence evaluation meets thresholds;
- security scans meet policy;
- backend/mobile artifacts are immutable;
- staging uses the exact artifacts;
- rollback and restore are exercised;
- README/launch copy match the manifest;
- no failure is dismissed as pre-existing.

---

# 9. Evidence Index

| Area | Paths |
|---|---|
| Current CI | `.github/workflows/ci.yml` |
| Missing Node project | root `package.json` not found |
| Flutter package/tests | `mobile/pubspec.yaml`, `mobile/test/` |
| Fake integration | `tests/test_integration.py` |
| Fake performance | `tests/test_performance.py` |
| Broken evaluation | `src/eval/runner.py`, `src/eval/dataset.py` |
| Unsafe deletion expectation | `tests/test_user_account_deletion.py` |
| Documentation contradiction | `README.md` |
| Dependency split | `requirements.txt`, `requirements-local.txt` |
| Manual migrations | `infra/supabase/README.md`, migrations |
| No current status | GitHub combined status for `e3440a5...` returned no statuses |

---

# 10. Bottom Line

CoverWise has tests and documents, but not a release evidence system. The next quality milestone is a reproducible pipeline that proves the actual backend, mobile app, schema, model pipeline, and critical flows at the exact commit and artifact being shipped.
