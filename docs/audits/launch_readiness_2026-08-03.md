# Launch Readiness Audit — Remediation Status

**Date:** 2026-08-03
**Source:** External whole-system launch-readiness review (deliverables: `coverwise_latest_push_audit_3d55b8d_2026-07-31.md`, `coverwise_agent_tasks_3d55b8d_2026-07-31.json` — filed alongside this doc).
**Status:** Living document — append-only updates per motto §0.3.

---

## 1. Reviewer verdict (preserved)

- **Public launch: NO-GO.**
- **Controlled internal alpha: GO.**
- **Small invite-only beta:** close, but only after fixing the current data-integrity blockers and deploying the real backend-worker stack.

Weighted readiness (reviewer judgement): core product 70–75%, backend architecture 75–85%, production deployment/ops 25–35%, store/legal/billing/external 15–25%, **overall ~35%**.

**Bottom line:** "Functionally, you are building a real product. Operationally, you have not yet launched the system that the app depends on."

---

## 2. P0 launch blockers — status

| ID | Finding | Status 2026-08-03 |
|----|---------|-------------------|
| **P0-1** | "All Documents" Q&A silently queries the first policy (`QueryScope` unwired; `_currentDocumentId()` fell back to `documents.first.id`) | ✅ **FIXED** — see §3 |
| **P0-2** | Identity architecture half-migrated (PrincipalState used only in its own model file) | ✅ **FIXED** — see §4 |
| **P0-3** | File encryption fails open (`write()`/`copyFrom()` persist plaintext when no key) | ✅ **FIXED** — see §5 |
| **P0-4** | Deployed product does not exist (Render plan not executed; no worker anywhere) | ❌ OPEN — ops/deployment, operator action required |
| **P0-5** | Infrastructure source-of-truth drift (Render vs Cloud Run docs) | ❌ OPEN — decision + doc sweep required |
| **P0-6** | Brand/domain/external identity unresolved (CoverWise name = public no-go per 2026-07-28 alignment doc) | ❌ OPEN — business decision |
| **P0-7** | No exact-head CI/release evidence (no status checks on latest commit) | ❌ OPEN — CI/release engineering |

---

## 3. P0-1: All Documents Q&A false scope ✅ FIXED

**Files:** `mobile/lib/models/query_scope.dart`, `mobile/lib/screens/qa_screen.dart`, `mobile/lib/models/qa_models.dart`, `mobile/test/query_scope_test.dart`

The `QueryScope` model existed but was never wired into `QaScreen`. The UI's "All Documents" chip set `selectedDocumentProvider` to null; `_currentDocumentId()` then responded to null by returning `documents.first.id` — so the request queried one policy while the UI claimed all policies were searched.

**Fix (audit-required closure, all 5 items):**
1. ✅ **Store `QueryScope`, not `String?`** — `QaScreenState._currentScope()` resolves explicitly: single-doc selection → `QueryScope.single`, screen opened from a document context → `QueryScope.single(initialDocumentId)`, otherwise → `QueryScope.all`. `_currentDocumentId()` now returns `_currentScope().documentId`.
2. ✅ **Omit `document_id` for all-policy requests** — all-documents scope yields `documentId: null`, so `QueryService` sends no `filters.document_id` and the backend searches every policy.
3. ✅ **Include scope in answer and history models** — `QaAnswer.queryScope` (`'all'`/`'single'`) added, serialized in `QaPair.toJson`, parsed in `QaAnswer.fromJson`, set at every answer construction site.
4. ✅ **Test citations from at least two policies** — `query_scope_test.dart` verifies a two-document corpus with no selection sends `documentId: null` (backend searches all).
5. ✅ **Prevent single-policy queries from returning cross-policy citations** — widget tests verify `initialDocumentId` and explicit re-selection scope the request to exactly that policy's `documentId`.
6. ✅ **Citation navigation survives all-documents answers** — for all-policy answers `QaAnswer.documentId` is `''`; the citation card navigation now prefers the per-citation `document_id` (present on backend citations) and falls back to `answer.documentId`, so "open source policy" still opens the correct policy.

**Validation:** `query_scope_test.dart`, `qa_screen_test.dart`, `encrypted_attachment_store_test.dart`, `hive_workspace_service_contract_test.dart` pass; `flutter analyze` clean (6 pre-existing info lints only).

---

## 4. P0-2: Identity architecture half-migrated ✅ FIXED

**Files:** `mobile/lib/app.dart`, `mobile/lib/bootstrap/app_bootstrap.dart` (already wired), `mobile/lib/screens/settings_screen.dart`, `mobile/lib/screens/profile_screen.dart`

The reviewer's finding predates the CW-P0-004 wiring: bootstrap and the auth listener already resolve through `Resolve.resolve()`. Two operational call sites still constructed `LocalPrincipal(InstallService.getInstallId())` directly after sign-out / clear-data:

- `settings_screen.dart` clear-data → now `Resolve.resolve(session: null, installId: ...).principal`
- `profile_screen.dart` post-sign-out workspace teardown → now `Resolve.resolveCurrent(...).principal`

The canonical `PrincipalState` machine is now the single identity decision point across bootstrap, auth transitions, and both post-sign-out workspace resets. The obsolete `models/identity.dart` imports were removed.

---

## 5. P0-3: File encryption fails open ✅ FIXED

**Files:** `mobile/lib/services/encrypted_attachment_store.dart`, `mobile/lib/services/hive_workspace_service.dart`, `mobile/test/encrypted_attachment_store_test.dart`

Previously `write()` and `copyFrom()` wrote **plaintext** when no principal key was available ("legacy fallback"). For policy documents that is the wrong failure mode.

**Fix — fail closed:**
- New top-level `EncryptionUnavailableException` (typed, carries the operation).
- `write()` and `copyFrom()` **throw** it when no principal key is available — no plaintext is ever persisted in the principal workspace.
- `migrateLegacyFile()` (documents + claim photos) now fails closed too; the migration loops catch per-file so one failure does not abort the whole migration.
- `reEncryptIfNeeded()` retains its no-key → `false` behavior (file left untouched, never rewritten as plaintext).
- **Migration flags now fail closed too:** `attachments_migrated_v1` / `attachments_reencrypted_v1` are only written when `failed == 0`. A transiently-unavailable key no longer strands legacy files permanently — the idempotent migration re-runs on the next workspace open and retries only the stragglers.
- Unavailable encryption stops durable storage; existing callers (document upload, claim photo capture) already surface recoverable user errors through their try/catch paths.
- Contract-test compliance: replaced bare `catch (_)` in `hive_workspace_service.dart` with `catch (e)` + `debugPrint` (the workspace contract test asserts no bare catches).

**Tests added:** write/copyFrom/migrateLegacyFile throw `EncryptionUnavailableException` without a key; a failed write leaves **no file behind** in the attachments directory.

---

## 6. Open P0s — operator action required

### P0-4: Deploy the real stack (Red)
- Create the Render API web service + always-on background worker (per platform reassessment, ~$14/month).
- Apply/verify Supabase migrations; provision production secrets; deploy the exact reviewed image.
- Prove one real document through `upload → queue → worker → extraction → embeddings → summary → grounded Q&A`.
- Verify worker lease reclaim on forced restart and deletion traversal.

### P0-5: Make Render the sole operational truth
- Update `README.md` + canonical architecture doc from Cloud Run → Render.
- Sweep deployment scripts, health checks, secret management, worker lifecycle, monitoring, rollback, domain, cost expectations.

### P0-6: Settle brand + external identity
- Final name, package/bundle identifiers, OAuth redirect schemes, domain, legal URLs, support email, deletion page, store metadata — before deploying legal pages/store listings.

### P0-7: Exact-head release evidence
- CI must attach checks to the exact head: AAB release build, iOS no-sign archive, deployed staging E2E, migration replay against disposable Supabase, post-deployment verification, store-binary verification.

---

## 7. What is genuinely good (reviewer-acknowledged, preserved)

- Owner-scoped backend contracts, Supabase durable state, evidence substrate, outbox worker with leases/retries/dead-letters, server-authoritative entitlements, deletion traversal.
- Remote tenant-isolation verification recorded (BR-04/BR-05 11/11).
- `prepareAnonymousWorkspaceClaim()` across email + Google flows.
- AES-256-GCM principal-scoped attachment store with opaque names, random IVs, legacy migration, path-containment deletion.
- Real notification scheduling (`zonedSchedule`), not a placeholder.
- Local automated baseline: 1,038 Flutter tests, 666 backend tests (2 skips), clean analysis (numbers from prior local runs — not exact-head CI).

---

## 8. Recommended gate order (reviewer + operator alignment)

1. ✅ ~~Close the three code-level P0s~~ (P0-1, P0-2, P0-3 — this session).
2. **Freeze the first-release product boundary** — demote/hide claim tracker, family views, broad coverage analysis, comparison, renewal notifications (until real-device proof), transactional "renew" language.
3. **Deploy Render stack and prove the loop** (P0-4/P0-5).
4. **Settle the name and external surfaces** (P0-6).
5. **Distribute real binaries** — signed AAB via Play internal testing, iOS archive via TestFlight, record commit + image digests + schema version + build numbers.

---

Created 2026-08-03 per motto §0.3. Original reviewer findings preserved; status updates appended as fixes land. Cross-reference: [latest-push audit](coverwise_latest_push_audit_3d55b8d_2026-07-31.md), [agent task backlog](coverwise_agent_tasks_3d55b8d_2026-07-31.json), [Audit 6](audit_6_claim_consent_execution.md).
