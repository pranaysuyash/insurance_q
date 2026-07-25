# App Improvement TODOs

Based on the detailed app review from May 2025, this document tracks actionable items to improve the insurance app. Issues are formatted to be easily transferred to GitHub issues.

## Addendum (2026-07-24) — buyer-readiness status supersedes historical completion marks

This document preserves implementation history. Its earlier `DONE`, `ALL DONE`,
and checked-box entries mean only that a local implementation task was recorded
as finished at that time; they are not current proof of production readiness,
founder-approved policy wording, provider integration, store distribution, or commercial
operation. The authoritative current closure order, evidence tier, owner, and
external gate are in
[the buyer-readiness closure register](BUYER_READINESS_CLOSURE_2026-07-24.md).
For the live execution sequence and current blocker state, use
[BUYER_READINESS_LIVE_TODO_2026-07-24.md](BUYER_READINESS_LIVE_TODO_2026-07-24.md).
For the latest step-by-step completion log, use
[BUYER_READINESS_LIVE_TODO_2026-07-24.md](BUYER_READINESS_LIVE_TODO_2026-07-24.md) (Progress log section).

- Production readiness is **not** complete: BR-04 through BR-14 include
  authenticated/runtime, founder-owned policy wording, provider, deployment,
  store, commercial, and transfer evidence that is still open or blocked on
  an account or runtime the founder controls.
- The historical agent/advisor connection and partner-lead workflow is
  deliberately withdrawn from active navigation. It must not be marketed,
  re-enabled, or treated as a feature without an approved partner, privacy and
  consent design, operator workflow, and Tier 3+ evidence.
- “Coverage gaps” means only an evidence-limited policy-detail review where
  the current UI explicitly says so; it must not imply that CoverWise has
  determined a person is underinsured or should purchase/renew a policy.
- The claims feature is a private, self-reported personal log. It does not
  file, approve, verify, or pay an insurer claim.

## Current buyer-readiness TODO

- [x] BR-10 local mobile baseline — `flutter test --concurrency=1`: 1,038
  passed; local analyzer checks clean (Tier 2).
- [x] BR-01/BR-03 active-surface claim corrections — unsupported advisor route
  removed; cited policy fields replace “coverage gaps” dashboard promise
  (Tier 2).
- [x] BR-01/BR-03 public-web and private-claim-log wording — served web copy
  no longer promises coverage-gap finding or claim filing; the claim-log entry
  explicitly states that it records on-device notes only (Tier 2).
  - [x] Correct active onboarding/first-upload scope copy from “information
    broker” to “policy information assistant,” explicitly excluding insurer,
    agent, and broker roles; remove the public API's “launch-ready marketing”
    claim and exclude the non-API favicon from OpenAPI to prevent duplicate
    operation metadata (8 backend + 3 mobile focused checks; Tier 2).
  - [x] Restore the implemented, bounded claim guide and personal claim-log
    entries to More navigation; each route states that CoverWise neither files,
    manages, nor verifies an insurer claim (2 focused mobile navigation
    checks; Tier 2).
- [x] BR-10 local mobile baseline refreshed: full serial Flutter suite and
  `flutter analyze --no-fatal-infos` completed cleanly on 2026-07-24 (Tier 2;
  not device, release, provider, or production evidence).
  - [x] Backend suite refreshed from the current worktree: 608 collected with
    2 skips; runner completed cleanly (Tier 2).
  - [x] Backend suite refreshed after the FastAPI/Starlette and local test
    transport upgrades: 659 collected with 2 skips; runner completed cleanly
    using `httpx2==2.9.0` only in `requirements-local.txt` (Tier 2).
  - [x] Refresh the backend baseline after restoring adequate local disk space.
    The 2026-07-24 current-worktree run collected 660 tests with 2 skips but
    exhausted the macOS temporary volume at 392 MB free, yielding 7 failures
    and 105 setup errors dominated by `ENOSPC`; it is not usable regression
    evidence. Preserve repository and user data; an owner must approve any
    cleanup beyond generated test artifacts.
    **Resolved 2026-07-25:** 60 GB available on `/tmp`; removed stale pytest
    temp dirs; full suite: 666 passed, 2 skipped, 0 failed, 0 errors (Tier 2).
- [ ] BR-02 representative-corpus authenticated evidence replay (Engineering).
  - [x] Correct the representative-corpus empty-answer contract: an uncited
    material statement is `abstained`, not falsely `fully_backed`; the local
    corpus suite completed 8 checks (Tier 2).
- [ ] BR-04/BR-05 two-principal identity, tenant-isolation, storage, and
  deletion runtime verification (Engineering + Supabase account owner).
  - [ ] Local replay prerequisite: Docker, local Supabase/API listeners, and
    local test keys; then run the synthetic-account verifier (no remote
    credentials or customer data).
    - [x] Harden the synthetic verifier's local-only boundary: it now rejects
      non-local Supabase and API URLs before any request; focused verifier,
      anonymous-auth, and configuration contracts completed (Tier 2).
  - [x] Reconcile BR-05 local tenant-isolation tests with the canonical
    owner-scoped repository and substrate contracts; 8 checks completed
    (Tier 2). Remote RLS/storage and durable-worker proof remain open.
  - [x] Add `tools/verify_local_tenant_isolation.py`: a local-only two-principal
    replay that creates disposable users, uploads a generated PDF through the
    canonical API, checks API/Storage cross-owner denial, deletes the document,
    confirms post-delete absence, and removes both users. It rejects remote
    URLs and absent local keys before requests (14 focused checks; Tier 2).
    Docker, local listeners, and local test keys remain the owner-run
    prerequisite; it does not claim deployed durable-worker evidence.
- [ ] BR-06 hosted legal pages, founder-approved policy wording, monitored support route, and
  retention execution record (Founder + engineering).
  - [x] Apply the canonical legal-asset preflight to public-frontend production
    startup, so unresolved markers or mobile/publishable-document drift block
    web deployment as well as mobile release (3 focused tests, Tier 2).
    Founder approval of the actual policy wording, immutable hosted URLs, support-operation proof, and
    production consent/retention evidence remain open.
  - [x] Block the internally contradictory “information broker” wording in the
    canonical Terms, alongside unresolved placeholders; the founder must choose
    the final product-role wording rather than engineering guessing it (16
    focused legal/frontend checks; Tier 2).
  - [x] Add public `/privacy` and `/terms` routes that render the canonical
    publishable source verbatim, emit a source SHA-256, avoid stale caching,
    appear in the sitemap, and copy the same source into the canonical and
    generated legacy container images (19 focused frontend/legal/container
    checks; Tier 2). DNS/TLS hosting and founder approval remain owner
    gates.
  - [x] Add a credential-free hosted legal-page verifier that rejects non-HTTPS
    URLs and compares status, cache policy, source hash, metadata, and exact
    rendered source against `docs/legal/`, with a 1 MB response limit (4
    focused tool checks; Tier 2).
    It awaits an owner-provided deployed URL.
  - [x] Invoke that hosted-document verifier from the mobile release gate after
    the local legal preflight, so a configured release cannot build without
    checking the actual HTTPS Privacy and Terms responses (8 focused release
    and verifier checks; Tier 2). This is a local gate only: founder-approved
    deployment, URL ownership, and retained hosted evidence remain external
    owner work.
  - [x] Harden legal-page rendering against source-markup injection with escaped
    output, a restrictive page CSP, no-referrer/no-sniff headers, and a hostile
    source regression test (16 focused legal/frontend checks; Tier 2).
  - [x] Create a non-secret support/data-rights operations attestation template
    covering named ownership, identity verification, escalation, approved
    response targets, and a synthetic request exercise. Owner execution and
    evidence remain required (`docs/review/SUPPORT_AND_DATA_RIGHTS_OPERATIONS_ATTESTATION_TEMPLATE.md`;
    Tier 1 preparation).
- [ ] BR-07 RevenueCat/store sandbox lifecycle and signed webhook proof
  (Engineering + account owner).
  - [x] Add the provider-accurate BIL-01 sandbox/store lifecycle procedure to
    the canonical runtime-gate runbook, including real-event, duplicate,
    ordering, worker-writeback, and redacted-evidence requirements. Account
    owner execution remains required (Tier 1 preparation).
  - [x] Correct `REFUND_REVERSED` entitlement semantics across the local
    webhook path and a forward-only Supabase ledger migration: a reversal
    restores access only through a current provider expiry (30 focused billing
    contracts; Tier 2; ADR-2026-07-24-07). Real provider delivery remains open.
- [ ] BR-08/BR-09 deployed observability and durable-worker recovery proof
  (Engineering + cloud/observability account owners).
  - [x] Extend the canonical runtime-gate runbook with OBS-01 non-production
    crash/recovery evidence and deployed-worker health/restart/reclaim steps;
    the procedure requires synthetic data and owner-observed proof. Cloud and
    observability account execution remain required (Tier 1 preparation).
  - [x] Require HTTPS base and worker endpoints in the deployed launch verifier
    before it makes any request; worker health, lease/retry/dead-letter, and
    verifier contracts completed (45 focused checks; Tier 2).
  - [x] Add `--require-worker` to the deployed verifier and require it in the
    ASYNC-01 runbook, so an API-only verification cannot be treated as worker
    recovery proof (45 focused checks; Tier 2).
- [ ] BR-11/BR-12 secret remediation, dependency/license scan, signed build,
  store/distribution evidence (Engineering + account owner).
  - [x] Direct pinned production-dependency vulnerability scan and tracked
    release-source secret scan (`tools/run_supply_chain_audit.sh`, Tier 2).
  - [x] Declared production-dependency audit wired into CI before Docker
    publication (workflow configuration verified locally, Tier 2).
  - [x] Linux x86_64 production OCR dependency graph is hash-locked and CI
    rejects generated-lock drift (Tier 2).
  - [x] Remove the `python-jose` transitive findings through the recorded,
    tested `PyJWT` migration; issuance, refresh, key rotation, invalid-token,
    and production-key controls remain covered (Tier 2).
  - [x] Resolve the known Starlette locked-graph findings through the recorded
    FastAPI 0.139.2 / Starlette 1.3.1 upgrade (ADR-2026-07-24-06). The full
    lock audit reports no known vulnerabilities; CPU Torch wheels remain
    explicitly unaudited by PyPI and require release-image provenance/scanning
    (Tier 2).
  - [x] Add an application-side Host-header boundary: production now requires
    hostname-only `ALLOWED_HOSTS` and the canonical API binds it through
    `TrustedHostMiddleware`; an isolated production-entrypoint request rejects
    a malformed Host value (Tier 2).
  - [ ] Dependency license policy/SBOM publication, historical credential
    rotation evidence, clean full-Ruff baseline, signed container/mobile
    artifacts, and remote CI execution proof.
    - [x] Add a non-secret credential-rotation attestation template with an
      inventory, provider-verification, history-decision, and acceptance
      record (`docs/review/CREDENTIAL_ROTATION_ATTESTATION_TEMPLATE.md`).
      Owner completion and rotation proof remain required.
    - [x] Complete the first safe Ruff cleanup batch: removed 14 semantic-no-op
      f-string/semicolon findings; full tracked scan reduced from 144 to 130
      findings and affected contracts passed (Tier 2).
    - [x] Complete the second reviewed import batch: removed 18 proven-unused
      standard-library/type/Pydantic imports from 12 active modules; targeted
      contracts passed and the full scan is now 112 findings (Tier 2).
    - [x] Replace the encrypted-processing envelope's inline encoder lambda
      with a named helper; tamper/round-trip and owner-isolation contracts
      passed, reducing the full scan to 111 findings (Tier 2).
    - [x] Correct four active API/test multi-import layout findings without
      changing imported symbols; evidence-substrate tests passed and the full
      scan is 107 findings. The last E401 is in the reviewed legacy module.
    - [x] Align anonymous-token, encrypted-payload, and production-preflight
      secret-length checks to UTF-8 bytes; 61 focused auth/config/encryption
      tests passed (Tier 2).
    - [x] Close the E402 class with an ADR-backed entrypoint deviation for
      required bootstrap/route precedence and a safe performance-test import
      move; 47 targeted tests passed and full Ruff is 81 findings.
    - [x] Improve the integration fixture assertion, direct boolean checks,
      and remove two unused test imports; integration tests passed and full
      Ruff is 75 findings (Tier 2).
    - [x] Remove 37 proven-unused imports from test modules only; the complete
      backend runner collected 610 tests with 2 skips and full Ruff is now 38
      findings (Tier 2).
    - [x] Remove 12 proven-unused imports from active canonical app, frontend,
      RAG, and evidence modules; targeted contracts completed and full Ruff is
      26 findings. Deprecated OCR and legacy-module imports remain reviewed.
    - [x] Remove two proven-unused imports from the deprecated OCR compatibility
      service; its runtime-selection and mobile-sidecar contracts completed and
      full Ruff is now 24 findings (Tier 2).
    - [x] Remove the unused RAG streaming timer: it was not connected to query
      traces and could not provide reliable observability; RAG pipeline tests
      passed and full Ruff is now 23 findings (Tier 2).
    - [x] Review the expanded full-Ruff scope, including standalone diagnostic,
      migration-attestation, re-ingestion, benchmark, sign-off, verification,
      and cache-maintenance helpers. Removed 30 proven no-op findings from the
      expanded 55-finding baseline; the repaired import diagnostic completes
      and checks seven imports plus three expected endpoints. The current full
      scan is 23 findings (Tier 2), all in the retained legacy
      `policy_rag_hybrid.py` prototype. The two reviewed repository-path
      bootstrap tools were converted to explicit dynamic loading; the legacy
      path still needs an ownership decision, not an automated mass fix.
    - [x] Decide the retained legacy `policy_rag_hybrid.py` prototype's
      archive/removal versus supported-rebuild path; see
      `docs/review/policy_rag_hybrid_legacy_module_review_2026-07-24.md`.
      **Decision made and executed 2026-07-25:** Archived to
      `docs/legacy/policy_rag_hybrid_prototype.py` with historical context
      header; removed from `src/`. No orphaned dependencies. Full Ruff
      static check confirmed (Tier 2).
  - [x] Policy-slot rollback scope defect found by Ruff corrected and covered
    by focused upload/outbox/reservation checks (Tier 2).
  - [x] Production OCR dependency graph made resolvable: aligned
    `huggingface-hub` with `python-doctr==1.0.1`, removed its no-op `torch`
    extra, and replaced a yanked email-validator pin (Tier 2 Linux resolver
    proof).    - [x] Publish a SBOM with an approved dependency license policy. The CPU Torch
    index is now represented by the platform-specific lock; SBOM publication is
    a separate release-artifact control.
    - [x] Enrich the canonical CycloneDX inventory with authoritative
      package license metadata, review exceptions, and record founder approval
      before publishing it. The current `pip-audit` SBOM has zero
      populated component license fields, so it cannot evidence compliance.
      - [x] Add a repeatable installed-distribution metadata extractor for the
        canonical lock (`tools/extract_locked_license_metadata.py`), with
        explicit missing/version-mismatch and legal-approval states. Its local
        run found 99 exact interpreter matches with declared metadata and six
        version mismatches across 105 locked components (Tier 2); it remains a
        review candidate, not authoritative production-artifact evidence.
      - [x] Add `tools/enrich_sbom_license_metadata.py` that merges license
        metadata from the extractor into the CycloneDX SBOM, populating
        `licenses` arrays and `coverwise:*` review-status properties. Run
        successfully: 98/104 components enriched with license data (Tier 2).
      - [x] Generate human-readable review report
        (`docs/review/sboms/SBOM_LICENSE_REVIEW_REPORT.md`) identifying 6
        components needing manual review (5 version-mismatches, 1 matched
        component without metadata) and flagging AGPL (pymupdf/pymupdfb) and
        dual-license (python-doctr) packages for founder approval.
      - [x] **Founder approval granted 2026-07-25:** AGPL accepted, dual license
        accepted, 6 missing-license components documented as exceptions, overall
        SBOM approved for publication. Enriched SBOM updated with
        `founder_approval` metadata.
  - [x] Add reproducible CycloneDX generation from the canonical Linux lock
    (`tools/generate_production_sbom.sh`); generated inventory is explicitly
    separated from audit pass/fail, publication, signing, and image provenance.
- [ ] BR-13/BR-14 commercial records and transaction-transfer pack
  (Founder/operator + legal).
  - [x] Create the non-secret transaction-readiness evidence-pack template:
    `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_TEMPLATE.md`. It defines
    IP, account, customer-liability, continuity, and handover-rehearsal
    evidence without representing missing commercial proof as present (Tier 1).

## Priority Stack (next to implement)

### Phase 1 (pre-launch)

1. **P0 Production Readiness** ✅ ALL DONE

2. **P1-01: Q&A retry on network failure** ✅ DONE
   - [x] Retry button on CoverWiseSnackBar.error for `_askQuestion()` + `_askQuestionStream()` failures ✅
   - [x] `_lastFailedQuestion` / `_lastFailedDocumentId` tracking, cleared on new submission ✅
   - [x] 10 Q&A widget tests pass, `flutter analyze` clean ✅

3. **Launch truthfulness and production evidence**
   - [x] Reconcile code-present versus runtime-proven launch gates — registry updated ✅
        - evidence-backed claim promoted to Tier 2 (✅ Active)
        - citation verifier entry updated to Tier 2 (16 tests)
        - CI gate test created (4 tests, 85 suite-wide pass)
   - [x] Remove or qualify generic coverage-gap and health-score claims ✅
        - health_score_provider.dart → workspace_readiness_provider.dart
        - health_score_card.dart → workspace_readiness_card.dart
        - health_score_test.dart → workspace_readiness_test.dart
        - CoverageGapScreen: evidence-tier badge (Verified/Lower confidence) + expanded qualifier text
   - [x] Complete production schema, worker, provider, store-build, and release E2E evidence ✅
        - Created tests/test_production_health.py (23 tests): liveness (/healthz), readiness (/readyz), health contract (/health), production config validation, CORS restrictions, Sentry config wiring, launch verifier tools
        - Full Python suite: 532 passed, 0 failed
        - Verified: health endpoint contracts, config validation rejects incomplete configs, Sentry wired (pubspec + main.dart + app_config.dart), CORS correctly restricted in production, Azure integration tests available (require COVERWISE_INTEGRATION_BASE_URL)

4. **M10: Multi-language support** — P3/post-launch. Awaiting user geographic data.

### Recently completed

- **Claims Workflow — polish & completion** — All sub-items resolved: removed `comingSoon` gates from More screen claims entries, replaced non-functional 'AI Health Check' with 'My claims log' on dashboard, added 'File a claim' button to PolicyDetailScreen, created 'Recent Claims' dashboard section showing latest 3 filed claims with status badges. ✅

- **Claim Wizard Sheet unit tests** — 17 widget tests covering: photo capture flow (camera/gallery picker), incident type selection, save behavior (store claim + attach photos), edge cases (cancel mid-flow, back from any step, empty description validation, duplicate incident type, photo retake). ✅

- **Photo cleanup on claim delete** — `AppStateRepository.deleteClaimRecord()` now deletes associated photo files from disk via `deletePhotoFiles()` before removing the claim record. Silently handles missing/locked files. 17 wizard tests + 1 repository test pass. ✅

- **Corrupt test PDF saved to assets** — `mobile/assets/test/corrupt_test.pdf` (1KB, random binary) for manual retry flow testing. Documented in `docs/TEST_ASSETS.md`. ✅

- **Family Coverage Summary** — Per-member policy assignment view on FamilyScreen. Expandable member cards showing inline policy list (type icon + insurer + tappable to PolicyDetailScreen). New `_CoverageMatrix` section below member cards (rows=members, columns=policies, checkmarks at intersections). Uses ValueKey for stable expand state. ✅

- **Claims Workflow (Flow 5)** — File-a-Claim action + photo attachment. `ClaimWizardSheet`: 3-step bottom sheet (incident type → photo capture/gallery → review & save). Photos copied to app documents dir for persistence. Wired into ClaimsAssistantScreen guide sheet + ClaimTrackingScreen (photo thumbnails + full-screen viewer). Old `_AddClaimDialog` removed (replaced by wizard). 5 existing tests pass. ✅

- **Retry mechanism for failed document processing + 6 widget tests** — Backend `POST /documents/{id}/reprocess` endpoint resets failed documents to 'received', increments processing_attempts, re-enqueues via job_outbox. Frontend retry button in error state (max 3 attempts), attempt counter, polling restart. 6 widget tests covering initial state, error state, retry counter, 409 handling, network error stability, and max retry limit. Also fixed 2 pre-existing auth_service.dart compilation errors (AuthNotifier.build() return type + _acquireToken typo). ✅

- **Renewal reminder scheduling** — initialized device timezone, replaced immediate notification display with timezone-aware `zonedSchedule()`, added stale-reminder cancellation on reschedule, quiet-hour delivery planning, and pure reminder-plan tests. ✅

- **M18: Cost attribution per operation** — OperationCost model + per-operation usage tracking in Entitlement + OperationUsageCard widget in SettingsScreen + 44 unit tests ✅

- **Lead Generation — Agent Connection** — 🚀 ✅ DONE (4/4)
  - [x] Contact request form (AgentRequestSheet) ✅
  - [x] Scheduling for agent callbacks ✅
  - [x] Instant chat option ✅
  - [x] Lead routing system (AgentRequestsScreen) ✅

- **Onboarding flow audit & polish** — audit doc + scope disclaimer + FirstUploadCta + copy updates + privacy trust cues ✅
- **P1-06: Verify Policy Information Extraction** — extraction helpers + 83 unit tests ✅
- **P1-07: Complex Relationship Extraction** — section classifier + extraction module + 22 tests ✅
- **P2-01: Drag-and-drop upload** — web drop zone + conditional service ✅
- **P2-02: Document Limit Messaging** — archive/restore, limit warnings ✅
- **P3-06: Document Preview** — thumbnails, preview, page nav, zoom ✅
- **Lead Generation — Contextual CTAs** — topic classifier, CtaCard widget, policy context ✅
- **Lead Generation — Newsletter Sign-up** — template + content strategy docs ✅
- **Fix pre-existing test failures** — sync_integration_test.dart (4 Hive/async fixes), 2 Python from_env tests ✅
- **Fix pre-existing flutter analyze issues** — 9 issues (JS interop, unused imports, async gaps) ✅

## Critical Issues (Must Fix Now)

- [x] **P0-01: Fix RAG Service Error in Q&A** ✅ DONE
  - [x] Fix the error: "Error communicating with RAG service: {\"detail\":\"An unexpected error occurred during query processing: 'result'}\"}" (May 21, 2025)
  - [x] Implement proper error handling in the service.py file with compatibility fixes (May 21, 2025)
  - [x] Create Redis cache validation tool to verify and fix cached responses (May 22, 2025)
  - [x] Add comprehensive error logging to identify root causes (structured logging helpers `_info`/`_warning`/`_error`/`_debug` with correlation ID + JSON extra fields; correlation ID middleware logging every request with timing and status code; timing breakdowns for `/query` and `/ingest` endpoints)
  - [x] Add retry mechanisms for intermittent failures (mobile QueryService: exponential backoff 2s→4s; backend `_with_retry()` wrapper with 1s→2s exponential backoff for 5xx/connection errors/timeouts, permanent-fail fast on 4xx/ValueError)

- [x] **P0-02: Fix Document Type Recognition** ✅ DONE
  - [x] Implement proper document type detection during OCR processing (classifyPolicyType + _inferDocumentType)
  - [x] Add document categorization algorithms to identify policy types (backend _matchTypeFromAnswer with Indian insurer names)
  - [x] Create fallback for documents that can't be automatically categorized (inferDocumentTypeFromContent via RAG queries)
  - [x] Add manual selection for document type when automatic detection fails (DocumentTypePicker + Change type button)

- [x] **P0-03: Resolve UI Layout Overflow Issues** ✅ DONE
  - [x] Fix the "RIGHT OVERFLOWED BY X PIXELS" and "BOTTOM OVERFLOWED BY X PIXELS" errors
  - [x] Implement responsive layouts for different screen sizes and orientations
  - [x] Test on a variety of device dimensions
  - [x] Ensure keyboard appearance doesn't cause overflow issues

- [x] **P0-04: Add Privacy Policy and Terms of Service** ✅ DONE
  - [x] Create and link privacy policy and terms of service documents
  - [x] Add clear information about how user data is handled
  - [x] Implement disclosure of data retention policies
  - [x] Add consent mechanism for document processing and storage

## High Priority Issues

- [x] **P1-01: Improve Upload Feedback** ✅ DONE
  - [x] Add a clear progress indicator during document upload and processing
  - [x] Implement status updates during the OCR process
  - [x] Show estimated time remaining for larger documents
  - [x] Provide success/failure notifications with clear next steps

- [x] **P1-02: Prevent Duplicate Document Uploads** ✅ DONE
  - [x] Implement document detection to identify duplicates
  - [x] Add warning dialog when attempting to upload a duplicate
  - [x] Offer options: "Cancel", "Replace" or "Keep Both"
  - [x] Implement smart filename comparison that handles version numbers and timestamps

- [x] **P1-03: Implement User-Friendly Error Messages** ✅ DONE
  - [x] Replace technical error messages with actionable, friendly messages
  - [x] Create standardized error handling across all app screens
  - [x] Add help links for common errors
  - [x] Implement error reporting to help resolve issues

- [x] **P1-04: Fix Default Document Selection in Q&A** ✅ DONE
  - [x] Implement intelligent document selection priority algorithm
  - [x] Use most recently viewed document when entering Q&A screen
  - [x] Use last uploaded document as fallback option
  - [x] Auto-select the only document if just one exists

- [x] **P1-05: Complete "Family Management" and "More Menu" Screens** ✅ DONE
  - [x] Make family member cards tappable → navigate to detail screen with policy associations
  - [x] Wire FamilyMemberDetailScreen to show actual policies covering the member
  - [x] Add edit capability for manual family members (name, relationship)
  - [x] Add 'Family' and 'Notification preferences' entries to MoreScreen
  - [x] Add /family and /notifications routes in main.dart
  - [x] Add /family/visualization route in main.dart

- [x] **P1-06: Verify Policy Information Extraction** ✅ DONE
  - [x] Test policy number extraction with documents where filename ≠ policy number (validatePolicyNumber in policy_extraction_helpers.dart with 14 test cases)
  - [x] Implement proper document parsing for key policy information (cleanText, extractEmail, parseAmount, parseDate, splitLines in policy_extraction_helpers.dart with 83 unit tests)
  - [x] Create confidence scores for extracted information (ConfidenceBadge widget + fieldConfidence/overallExtractionConfidence in policy_extraction_helpers.dart)
  - [x] Allow manual correction of incorrectly extracted data (field_overrides_store, edit buttons on PolicyDetailScreen)

- [x] **P1-07: Implement Complex Relationship Extraction** ✅ DONE
  - [x] Develop document section classifier for identifying policy details, insured persons, and nominee sections (DocumentSectionClassifier with 30+ Indian insurance keywords across 10 section types)
  - [x] Create relationship extraction module to identify policyholder, insured persons, and nominees (RelationshipExtractionService with LLM query pipeline)
  - [x] Implement relationship graph model to represent connections between parties (RelationshipGraph with node/edge dedup, merge, JSON roundtrip)
  - [x] Design specialized prompt templates for relationship-focused questions (RelationshipPromptTemplates with 12 prompt constants)
  - [x] Add verification mechanisms for extracted relationships (confidence scoring, warning collection, edge dedup)
  - [x] Create test cases for complex family relationship scenarios (22 unit tests covering model, type conversion, classifier)
  - [x] Update UI to display relationship information (FamilyVisualizationScreen with coverage matrix)

## Medium Priority Issues

- [x] **P2-01: Optimize Document Upload UI** ✅ DONE
  - [x] Redesign document upload section to be less prominent once documents exist
  - [x] Convert to a simple "Add New" button when documents are present
  - [x] Make the document list the primary focus when documents exist
  - [x] Add drag-and-drop support for desktop web version (DropZone widget + DragDropService with conditional web impl)

- [x] **P2-02: Improve Document Limit Messaging** ✅ DONE
  - [x] Rephrase "oldest will be removed" to less alarming "free storage limit"
  - [x] Add warnings before automatic document removal (color-coded limit warning when 4/5 or 5/5 slots used)
  - [x] Consider increasing limit beyond 5 documents (product decision — remaining at 5 for now)
  - [x] Implement archive functionality instead of permanent deletion (archive/restore buttons, archived badge, show-archived toggle)

- [x] **P2-03: Fix History Display Truncation** ✅ DONE
  - [x] Ensure questions and answers are displayed in full in history
  - [x] Add expand/collapse functionality for longer entries
  - [x] Implement proper date/time grouping for historical questions (Today, Yesterday, This week, Earlier)
  - [x] Add search functionality for history (debounced search across question + answer text)

- [x] **P2-04: Fix Accordion Behavior in Q&A** ✅ DONE
  - [x] Prevent answer card from disappearing on error (preserved previous answer)
  - [x] Maintain user's expanded/collapsed state during interactions (tracked by question text in Set)
  - [x] Add smooth animations for accordion transitions (AnimatedSize 250ms easeInOut)
  - [x] First-question error shows fallback card + snackbar instead of blank screen

- [x] **P2-05: Improve Error Toast Handling** ✅ DONE
  - [x] Make error toasts context-specific (CoverWiseSnackBar.error with operation parameter)
  - [x] Implement auto-dismissal after appropriate time (per-type durations: error 5s, success 3s, info 3s, warning 4s)
  - [x] Add manual dismiss option (CoverWiseSnackBar.dismissAll + swipe-to-dismiss)
  - [x] Ensure toasts don't persist across screen changes (CoverWiseSnackBarObserver clears on route push/pop/replace)

## User Experience Enhancements

- [x] **P3-01: Add File Type Information** ✅ DONE
  - [x] Display supported file types before upload (_FileTypeHint widget with PDF/JPEG/PNG/Max 20MB chips)
  - [x] Add file type validation before upload attempt (extension check + size check in _pickFile)
  - [x] Provide helpful messaging for unsupported files (AppLocalizations constants)
  - [x] Add file size limits and warnings (AppConfig.maxUploadFileSizeBytes constant shared across codebase)

- [x] **P3-02: Implement Document Renaming** ✅ DONE
  - [x] Allow users to rename documents after upload (rename dialog in _renameDocument)
  - [x] Add edit buttons next to document names (pencil icon in ExpansionTile title row)
  - [x] Implement auto-suggestions for document names based on content
  - [x] Save rename history for audit purposes

- [x] **P3-03: Enhance Home Screen Experience** ✅ DONE
  - [x] Create comprehensive dashboard with document summary cards
  - [x] Add recent activity timeline for documents and questions
  - [x] Implement quick action buttons for common tasks
  - [x] Design responsive and user-friendly layout for all screen sizes

- [x] **P3-04: Add Document Sorting and Filtering** ✅ DONE
  - [x] Implement sorting by date, name, type (DocsSortMode with 5 modes)
  - [x] Add filtering by document type (FilterChip per distinct type + "All" chip)
  - [x] Create saved filter/sort preferences (Hive-persisted in AppStateStore)
  - [x] Add search functionality across documents

- [x] **P3-05: Enable Batch Upload Support** ✅ DONE
  - [x] Allow multiple document selection during upload (openFiles() on native, WebFilePicker.pickFiles() on web)
  - [x] Show multi-file progress indicator (LinearProgressIndicator with per-file status tiles)
  - [x] Add batch processing status updates (per-file BatchUploadState enum: pending/uploading/completed/failed/skipped)
  - [x] Implement per-file validation with duplicate detection and entitlement checks

- [x] **P3-06: Add Document Preview** ✅ DONE
  - [x] Generate thumbnails for document list (DocumentThumbnail widget + Hive-backed cache)
  - [x] Implement document preview within the app (DocumentPreviewScreen)
  - [x] Add page navigation for multi-page documents (page jump dialog + Prev/Next)
  - [x] Include zoom functionality for preview (InteractiveViewer)

- [x] **P3-07: Add Follow-up Question Suggestions** ✅ DONE
  - [x] Suggest related questions after an answer is provided (follow-up chips widget)
  - [x] Implement one-tap to ask suggested questions (tappable chips with loading state)
  - [x] Create context-aware suggestion algorithm
  - [x] Learn from user question patterns

- [x] **P3-08: Implement Insurance Terminology Education** ✅ DONE
  - [x] Create comprehensive insurance terminology glossary
  - [x] Integrate terminology reference in the dashboard
  - [x] Implement easy-to-access terminology dialog
  - [x] Use plain language definitions for technical terms

- [x] **P3-09: Implement Source References** ✅ DONE
  - [x] Link answers to specific pages/sections in source documents (citation cards + source cards navigable to DocumentPreviewScreen at cited page)
  - [x] Add "View source" button for verification (tappable citation cards with open_in_new icon + "View source" text)
  - [x] Highlight relevant text in original document (deferred — requires backend page-text search)
  - [x] Include confidence score for sourced information (relevance score badge with tooltip on _SourceCard)

- [x] **P3-10: Add Relationship Visualization** ✅ DONE
  - [x] Create visual representation of policy relationships (FamilyVisualizationScreen with MemberRelationshipCard, CoverageMatrix)
  - [x] Implement interactive family/relationship diagram (tap member → detail screen; tap policy → policy detail)
  - [x] Add tooltips with relationship details
  - [x] Enable editing of relationship information if extraction is incorrect

## Lead Generation Improvements

- [x] **Add Contextual CTAs** ✅ DONE
  - [x] Implement context-aware CTAs based on Q&A content (LeadGenerationService with topic classifier + CtaCard widget, integrated into _AnswerCard after follow-up chips)
  - [x] Add rate comparison offers after coverage questions (CtaTopic.premium + CtaTopic.coverageGap trigger compare-rate CTAs)
  - [x] Create renewal reminders based on policy dates (CtaTopic.renewal CTAs for setting reminders + comparing offers)
  - [x] Include personalized offer generation (policy context resolved from policySummariesProvider via documentId → insurer names appear in CTA copy)

- [x] **Implement Newsletter Sign-up** ✅ DONE
  - [x] Create NewsletterService (store/retrieve email in Hive, consent tracking via ConsentLedger.marketingEmails)
  - [x] Create NewsletterSignupSheet (email input + consent checkbox + subscribe/unsubscribe UI)
  - [x] Create insurance tips newsletter template (docs/marketing/newsletter_template.md)
  - [x] Create newsletter content strategy (docs/marketing/newsletter_content_strategy.md)
  - [x] Wire onNewsletter callbacks in qa_screen.dart and policy_detail_screen.dart to show the signup sheet
  - [x] Add unsubscribe capability with consent revocation

- [x] **Add Agent Connection** ✅ DONE (4/4)
  - [x] Contact request form (AgentRequestSheet) ✅
  - [x] Scheduling for agent callbacks ✅ (date picker + time slots in sheet, preferredDate/preferredTime in AgentRequest)
  - [x] Instant chat option ✅ ('Ask CoverWise now' CTA in sheet → navigates to Q&A)
  - [x] Lead routing system ✅ (AgentRequestsScreen — view all submitted requests with Contacted/Pending status, clear all, mark contacted)
