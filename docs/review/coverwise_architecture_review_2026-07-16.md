# CoverWise Architecture Review

**Date:** 2026-07-16  
**Scope:** full app architecture across backend, mobile, frontend, storage, auth, docs, and long-term product boundary  
**Evidence tier:** Tier 1 static inspection with live repo-state review  
**Review intent:** good, bad, ugly, from a first-principles and `motto_v3` long-term perspective

## Executive Summary

CoverWise is not a blank-slate prototype anymore. The repo now contains a real cross-platform product shape:

- a consolidated FastAPI backend for document ownership, upload, processing, retrieval, and analytics;
- a Flutter mobile app with a distinct design system, onboarding, auth, and multi-screen product shell;
- a separate public-facing FastAPI marketing/frontend service;
- durable repository/object-store/vector-store boundaries;
- a clear product decision trail that now favors a solo, non-regulated policy-understanding wedge.

That is the good news. The bad news is that the codebase still carries several legacy or transitional surfaces that can become architecture drift if they are not kept intentionally separate:

- multiple app entrypoints still exist;
- old OCR/RAG service files remain in-tree;
- the frontend service still proxies to older service names and keeps compatibility fallbacks;
- the mobile app still exposes some product areas that the current exploration map says should be reduced or removed;
- some docs are ahead of the code, while some code is ahead of the docs.

The ugly part is not a single bug. It is the presence of multiple overlapping “truth sources” at different layers. The repo is strongest when it has one canonical path and weaker when compatibility surfaces are left to linger without a clear retirement plan.

## What Is Good

### 1. The top-level product boundary is now explicit

The exploration map and platform decision docs are unusually clear for a solo product:

- CoverWise is a personal-information product, not an insurer/broker/marketplace.
- The canonical platform direction is a single Cloud Run FastAPI service plus Supabase Postgres/Storage.
- The auth decision now cleanly separates anonymous first-launch compatibility from account ownership.

That is a strong long-term move because it aligns product, data, and operational boundaries instead of making each screen or service invent its own assumptions.

### 2. Ownership and storage are becoming real architecture, not just app state

The backend is doing the right kind of work:

- `DocumentRepository` is the ownership boundary.
- `DocumentObjectStore` is the source-document boundary.
- `RAGPipeline` is the retrieval boundary.
- `DocumentProcessingService` is the orchestrator for file storage, OCR, extraction, and ingestion.

That separation is durable and first-principles aligned. It also makes retries, deletion, and future migrations possible without rewriting the whole app.

### 3. The mobile shell is coherent and product-shaped

The Flutter app has moved beyond a generic shell into a deliberate consumer product layout:

- branded theme and motion tokens;
- splash + onboarding + main navigation flow;
- bottom-nav product compartments;
- global error boundary;
- auth bootstrap and anonymous-session warmup;
- deep-link routing for important flows.

This is a real app architecture, not a demo scaffold pretending to be one.

### 4. The docs now express a clear long-term direction

The documentation is finally doing architectural work rather than just listing features:

- `docs/README.md` points to a canonical platform decision and auth decision;
- `docs/planning/coverwise_long_term_platform_decision_2026-07-12.md` prefers one runtime and one Supabase project;
- `docs/planning/coverwise_auth_architecture_2026-07-16.md` makes anonymous-first compatibility explicit instead of pretending accounts already exist;
- `docs/review/exploration_map.md` sets a permanent non-regulated consumer boundary.

That matters because docs are not decoration here; they are part of the product contract.

## What Is Bad

### 1. The app still has more than one backend surface

The live repo has:

- the consolidated main FastAPI backend;
- a separate frontend FastAPI service;
- standalone OCR and RAG services still present in the tree;
- older mobile compatibility endpoints and fallback routes.

The canonical decision says “one backend runtime,” but the codebase still contains multiple runnable patterns. Even when some are legacy or compatibility-only, they create mental overhead and make it harder to know which path is truly authoritative.

Relevant evidence:

- `docs/planning/coverwise_long_term_platform_decision_2026-07-12.md:19-27`
- `docs/review/exploration_map.md:127-180`
- `src/app/main.py:252-254`
- `src/frontend/app.py:164-187`
- `src/api/document.py:71-178`
- `src/ocr/service.py` and `src/rag/service.py` still exist as separate service files

### 2. The frontend service is still half transition layer, half product surface

`src/frontend/app.py` is not just a marketing site. It is still proxying upload to OCR processing and then backfilling old cache-shaped response payloads. That means the public surface remains coupled to backend transition states rather than just consuming one stable contract.

The long-term architecture wants one canonical API shape. The current frontend still carries compatibility logic for older response formats, which is understandable in migration, but risky if it becomes permanent.

Relevant evidence:

- `src/frontend/app.py:164-239`
- `docs/review/exploration_map.md:161-176`

### 3. The mobile navigation contains a likely bug in deep-link handling

The deep-link switch in `mobile/lib/main.dart` has no `break` statements between cases.
That is a structural smell at best and likely incorrect control flow at worst.

Even if this compiles in the current form due to language rules or a later edit not captured here, it is not a good long-term navigation contract. Deep links should be explicit and boring.

Relevant evidence:

- `mobile/lib/main.dart:136-157`

### 4. The mobile product surface still contains features the product boundary says to remove or neutralize

The exploration map says certain surfaces should be re-framed or removed:

- coverage-gap language should become factual “not found in uploaded documents” language;
- what-if pricing should be removed;
- renewal language should be neutral reminder language;
- claim/advice language should not overstate what the app does.

But the current app still ships screens and routes for those areas.

That is not automatically wrong during transition, but it is a mismatch between product doctrine and shipped surface. It needs a decision: either retire these screens or clearly reframe them under the new boundary.

Relevant evidence:

- `docs/review/exploration_map.md:18-30`
- `mobile/lib/main.dart:202-227`
- `mobile/lib/screens/dashboard_screen.dart:1-60` and related screens in `mobile/lib/screens/`

### 5. Some docs are still behind the code, and some code is ahead of the docs

Examples:

- `docs/technical/architecture/current_system_architecture.md` and `docs/technical/system_architecture/comprehensive_architecture.md` still talk in older service terms and older stack assumptions.
- `docs/README.md` now points to the canonical decision set, which is better.
- `src/config/settings.py` and `src/rag/pipeline.py` show a multi-provider, compatibility-rich runtime that is more advanced than the older docs.

This is normal during active migration, but it means readers can still get a misleading picture unless they follow the newer decision docs first.

Relevant evidence:

- `docs/technical/architecture/current_system_architecture.md`
- `docs/technical/system_architecture/comprehensive_architecture.md`
- `docs/README.md:7-17`
- `src/config/settings.py`
- `src/rag/pipeline.py`

## What Is Ugly

### 1. There are still multiple “source of truth” narratives in the tree

The repo now has a better canonical narrative, but the implementation still spreads truth across:

- legacy service files,
- compatibility endpoints,
- frontend proxy fallbacks,
- backend runtime composition,
- docs that describe older architecture,
- docs that describe the new architecture.

That is the classic drift hazard for a healthy-but-growing app: the code is not broken in one place, it is simply no longer singular.

### 2. Analytics and consent are still partly policy-by-convention

The exploration map itself calls out that analytics safety is caller-enforced rather than schema-enforced and that consent is not yet a reusable ledger. That is the right diagnosis.

In first-principles terms, if a product handles policy documents and future contribution or monetization flows, then consent, provenance, and deletion need canonical storage and enforcement, not just “remember to do the right thing.”

Relevant evidence:

- `docs/review/exploration_map.md:85-105`
- `src/api/analytics.py:1-80`
- `src/api/document.py:231-250`

### 3. The frontend still exposes a permissive CORS posture

The public frontend service currently uses wildcard origins with credentials enabled. Even if this is meant to be local/development-only, it is a poor long-term default for a public surface because it invites accidental carryover into environments where it should not live.

Relevant evidence:

- `src/frontend/app.py:46-53`

### 4. The backend still mixes canonical logic with legacy operational convenience

The main backend is strong, but it still contains startup scanning, health probes, fallback behaviors, and compatibility paths that are useful now and risky if left unbounded:

- startup doc scanning in local dev;
- cached probe logic in health;
- alternate storage backends;
- local-vs-production branches;
- fallback model/provider behavior.

None of those are inherently bad. They are only ugly if they outlive the migration and become hidden policy instead of explicit temporary compatibility.

Relevant evidence:

- `src/app/main.py:73-155`
- `src/app/main.py:165-250`
- `src/config/settings.py`
- `src/services/document_repository.py`
- `src/services/document_object_store.py`
- `src/rag/pipeline.py`

## Long-Term Architecture Judgment

### Canonical direction

The best long-term shape is the one already described in the newer docs:

- one backend runtime;
- one account/auth boundary;
- one ownership repository boundary;
- one durable object-store boundary;
- one retrieval boundary;
- one mobile product surface;
- one canonical product scope.

### What should remain

- Repository/object-store abstraction boundaries.
- The consolidated FastAPI backend path.
- The Flutter theme, motion, onboarding, and global error boundary work.
- Anonymous-to-account migration as a compatibility bridge until Supabase Auth is fully live.
- Compatibility code only where it has a clearly documented retirement trigger.

### What should be retired or collapsed

- Standalone OCR/RAG service paths once their last compatibility dependency is gone.
- Frontend response-format compatibility when the backend contract has stabilized.
- Product surfaces that conflict with the current permanent boundary, unless they are explicitly reframed.
- Old architecture docs that describe an obsolete deployment picture without a dated addendum pointing to the canonical decision.

## Recommended Follow-Through

1. Keep the canonical platform decision as the first doc anyone reads.
2. Move legacy service files into a clearly labeled historical/compatibility section if they still need to stay in-tree.
3. Decide each conflicting mobile surface explicitly: neutralize, remove, or reframe.
4. Turn consent/provenance/deletion into first-class canonical data, not just conventions in handlers.
5. Replace older architecture docs with dated addenda rather than silent rewrites.
6. Re-run an integration-quality validation pass after the next migration step so the architecture review can graduate from Tier 1 to higher evidence.

## Bottom Line

CoverWise is in the healthy-but-dangerous middle zone:

- strong enough to be a real product;
- coherent enough to have a canonical direction;
- messy enough that it still needs disciplined consolidation before the architecture is truly singular.

That is a good place to be if the team keeps pulling it toward one backend, one auth boundary, one data plane, and one honest product scope. It is a bad place to stay if compatibility surfaces quietly become permanent truth.
