# AGENTS.md — CoverWise / insurance_app

**Canonical agent onboarding document.**  
All agents reading this file must treat it as the primary context source for this project.  
**Last updated:** 2026-10-09 | **Author:** Portfolio orchestration — generated-doctrine provenance correction  
**Doctrine:** Shared Operating Doctrine v8.2, canonical at `/Users/pranay/Projects/agent-start/doctrines/OPERATING_DOCTRINE.md`; this project-local `OPERATING_DOCTRINE.md` is a generated copy and is not authoritative.

---

## 1. What CoverWise is

CoverWise is a Flutter mobile + FastAPI + Supabase product for Indian insurance policyholders. It reads uploaded policy PDFs, extracts structured evidence, answers grounded questions in plain language, and surfaces renewal/claim utility.

### The product wedge (canonical — all features must anchor here)

```
owned policy → evidence summary → verified Q&A → coverage check-in
                  → coverage adequacy → family coverage map
                  → claim document vault → renewal/contact utility
```

Every feature must answer: **what role does it play in the wedge?** If none, it is cut. If a thin slice, it is scoped down. If core, it is finished properly.

### What the product refuses to do
- Fabricate premium estimates (ADR-2026-07-19-13)
- Act as an actuary, underwriter, or claims adjudicator
- Show a "health score" or suitability rating (cut — ADR-2026-07-19-08 §1)
- Provide investment advice or insurance recommendations

---

## 2. Canonical architecture paths

| Layer | Path | Notes |
|-------|------|-------|
| FastAPI backend | `src/` | Entry: `src/app/main.py` |
| RAG pipeline (live) | `src/rag/pipeline.py` | `query_rag`, `query_rag_stream` |
| ~~`src/rag/service.py`~~ | `src/archive/` | ARCHIVED 2026-09-07 — second unmounted service |
| Evidence pipeline | `src/services/evidence_pipeline.py` | Runs 6 deterministic + 1 LLM extractor |
| Outbox worker | `src/workers/outbox_worker.py` | Dispatches durable async jobs |
| Mobile Flutter app | `mobile/` | Entry: `mobile/lib/main.dart` |
| App state storage | `mobile/lib/services/app_state_repository.dart` | **All Hive reads/writes go here** |
| Box lifecycle | `mobile/lib/services/hive_workspace_service.dart` | Owns open/close |
| Box names | `mobile/lib/services/hive_box_names.dart` | Constants — never raw strings |
| Family sync | `mobile/lib/services/family_sync_service.dart` | Offline-first; uses `/api/v1/family` |
| Offline upload retry | `mobile/lib/services/upload_retry_service.dart` | Connectivity-triggered backoff retry |
| Supabase migrations | `supabase/migrations/` | Applied in sequence by filename |
| Deployment IaC | `render.yaml` | **Canonical deployment spec** |

---

## 3. Stack & defaults

| Concern | Value |
|---------|-------|
| **Deployment platform** | **Render** (Singapore) — two services: `coverwise-api` (web) + `coverwise-worker` (worker). IaC: `render.yaml`. NOT Cloud Run, App Runner, or Railway (those are historical). |
| **Database** | Supabase Postgres + pgvector (prod). All migrations in `supabase/migrations/`. |
| **AI model (primary)** | `gpt-5-nano` (2026 OpenAI release, fast, cost-efficient) |
| **AI model (fallback)** | `gpt-4o-mini` (configured in `rag/pipeline.py:fallback_models`) |
| **Embedding model** | `text-embedding-3-small` (1536-dim, configured in `src/config/settings.py`) |
| **fast_path default** | `True` (set 2026-08-13 — HyDE+RAG-Fusion parallel; was `False`, caused ~37s latency) |
| **Flutter SDK path** | `/Users/pranay/Projects/adhoc_resources/flutter/bin/flutter` |
| **Python venv** | `./venv/bin/python` / `./venv/bin/pytest` (from project root) |
| **Test define** | `--dart-define-from-file=.dartdefine.env` (required for all mobile tests) |

---

## 4. Test commands

```bash
# Backend — from project root
./venv/bin/pytest -v                              # full suite (must be 0 failed)
./venv/bin/pytest tests/test_foo.py -v            # targeted

# Mobile (Tier 1: Headless unit, widget, contract tests) — from mobile/ directory
PATH="/Users/pranay/Projects/adhoc_resources/flutter/bin:$PATH" \
  flutter test --dart-define-from-file=.dartdefine.env --concurrency=1

# Mobile — static analysis (must be 0 errors)
PATH="/Users/pranay/Projects/adhoc_resources/flutter/bin:$PATH" flutter analyze
```

### On-Device E2E & Autonomous Testing (Tier 2: ARTEMIS)

CoverWise uses **Google ARTEMIS** (`https://github.com/google/artemis`) for on-device autonomous Android testing, bridging the gap between headless widget tests and real device/emulator runtime verification.

- **Why ARTEMIS is needed**: Flutter widget tests run headless and cannot verify native Android plugins (`camera`, `image_picker`, `file_selector`, `google_mlkit_text_recognition`, `flutter_local_notifications`), system permission dialogs, real screen rendering/overflows, back navigation gestures, and Logcat crash traces.
- **Execution profiles**:
  - `flash`: Fast reactive loop (3–5s/step) for smoke tests and direct UI flows.
  - `pro`: LangGraph multi-agent loop (Planner → Operator → Safety Net → Checker) for exploratory navigation, edge cases, and structured audit reports.
- **Local installation & toolchain**:
  - Toolchain: Python >= 3.12, `uv`, Android SDK `platform-tools/adb`, and connected device or running AVD (e.g. `coverwise_api35_arm64`).
  - Disk requirement: Host machine must have >= 10GB free disk headroom before launching emulator snapshots and compiling APKs (check `df -h /`).
  - Installation: `git clone https://github.com/google/artemis.git && cd artemis && uv venv && uv pip install -e .`
  - Integration with Antigravity / AI IDEs: Native MCP server exposing `mobile_run_task`, `mobile_manage_task`, `mobile_get_device_state`, and `mobile_inspect_trace`.
- **Flutter-specific testing rules**:
  - Wrap key interactive widgets with explicit `Semantics(label: ...)` for robust UIAutomator XML element targeting, or rely on Artemis's multimodal visual/OCR fallback.
  - Compile debug test APK: `flutter build apk --debug --dart-define-from-file=.dartdefine.env`.
  - Execute test scenario: `uv run artemis run "Open CoverWise, verify dashboard loads, tap upload policy" --profile flash`.

---

## 5. Open technical debt (by ID)

Track status in `docs/debt_register.md`. Items resolved as of 2026-09-07 batch:

| ID | Item | Status |
|----|------|--------|
| C-01 | Server-side Q&A entitlement | ✅ RESOLVED 2026-09-07 |
| C-02 | Supabase auth boundary tests | ✅ RESOLVED 2026-08-13 |
| H-01 | Outbox 5 async paths | ✅ RESOLVED (4/5 pre-existing + QA_RESPONSE wired 2026-09-07) |
| H-03 | Offline upload retry worker | ✅ RESOLVED 2026-09-07 |
| H-04 | Half-built features (ADR-2026-07-19-08) | ✅ Health Score + What-If already removed; Claims routing confirmed |
| H-05 | Policy extraction NameError | ✅ RESOLVED 2026-08-13 |
| H-06 | Rate limiting fail-closed | ✅ RESOLVED 2026-08-13 |
| H-07 | pgvector path untested | ✅ RESOLVED 2026-08-13 |
| H-08 | `/query` latency ~37s | ✅ RESOLVED 2026-08-13 (code-only; CI probe follow-up) |
| M-01 | 53 Hive.box() scattered calls | ✅ RESOLVED 2026-09-07 (full AppStateRepository migration) |
| M-11 | In-memory QA reports | ✅ RESOLVED 2026-09-07 (Supabase persistence) |
| M-12 | Cost ledger always zero | ✅ RESOLVED 2026-09-07 |
| M-13 | Second unmounted RAG service | ✅ ARCHIVED 2026-09-07 to src/archive/ |
| M-14 | Orphaned QA_RESPONSE JobType | ✅ RESOLVED 2026-09-07 (handler wired) |
| M-15 | Deployment doc contradiction | ✅ RESOLVED 2026-09-07 (README + AGENTS.md) |
| M-16 | Model drift settings/docs | ✅ RESOLVED 2026-09-07 (settings.py docstring + README) |
| L-09 | Route screens lack ErrorBoundary | ✅ RESOLVED 2026-09-07 |
| **H-02** | Migration ledger mismatch | **OPEN** — needs Supabase CLI (L3 action) |
| **M-02** | Deprecated OCR microservice | **OPEN** — archive on next major release |
| **M-03** | Deprecated `/documents/query` | **OPEN** — set deprecation deadline |
| **M-05** | Principal key migration gaps | **OPEN** (partially mitigated by M-01 resolution) |
| **M-06** | Consent ledger cache-first | **OPEN** |
| **M-07** | Performance budgets not in CI | **OPEN** |
| **M-08** | 16 `as dynamic` / `.cast<>()` | **OPEN** |
| **M-09** | Localization incomplete | **OPEN** |
| **M-10** | Analytics schema not enforced | **OPEN** |

---

## 6. What NOT to do

- **Never create a second RAG service.** `src/rag/pipeline.py` is the live path. `src/rag/service.py` is archived.
- **Never add client-only entitlement gates.** All plan limits (upload, Q&A budget) must be enforced server-side via Supabase ledger.
- **Never access Hive boxes with raw string literals.** Use `HiveBoxNames` constants + `AppStateRepository` / `HiveWorkspaceService` methods.
- **Never add `Hive.box("string")` in screens or providers.** Go through the repository layer.
- **Never swallow exceptions on prod-critical paths.** Log and re-raise or return an explicit error.
- **Never reference `src/archive/` as a live path.** Archived modules are documentation, not active code.
- **Never commit or push without explicit user instruction in the current conversation.**
- **Never add `const` to a `CoverWiseIconBadge(color: CoverWiseColors.xxx)` constructor** — not const-compatible.
- `CoverWiseColors` is in `mobile/lib/theme/coverwise_theme.dart` — NOT re-exported by `coverwise_components.dart`. Import it directly.

---

## 7. Git policy

- **No staging, commit, push, fetch, checkout, reset, or branch changes** without explicit instruction in the current conversation.
- No agent co-author trailers.
- Every material change is written to the working tree and documented in `DECISION_LOG.md`.

---

## 8. Key ADRs (reference before touching these areas)

| ADR | Area | Decision |
|-----|------|----------|
| ADR-2026-07-19-01 | Async work queue | Supabase outbox pattern (not Cloud Tasks) |
| ADR-2026-07-19-08 | Half-built features | Finish-properly; Health Score + What-If removed |
| ADR-2026-07-19-11 | Evidence substrate | Every surface must be substrate-grounded with page citations |
| ADR-2026-07-19-13 | What-If Premium | Refused — link to insurer calculator; no fabricated estimates |
| ADR-2026-07-20-26 | RAG excellence | Pipeline quality gates, eval cadence |
| ADR-2026-07-29-02 | Doctrine reconciliation | Master reconciliation of all competing product docs |

---

## 9. Documentation directory

| Topic | File |
|-------|------|
| Open debt | `docs/debt_register.md` |
| Decision history | `DECISION_LOG.md` |
| Technical decisions | `docs/decisions/` |
| Family workspace architecture | `docs/technical/family_workspace_architecture.md` |
| Global eval sweep (pws-v4) | `docs/eval/2026-08-24-pws-v4-global-sweep.md` |
| Legal copy audit | `docs/legal_risk_copy_audit_2026-07-24.md` |
| Backlog (2026-08-12) | `docs/planning/backlog_missing_partial_work_and_expansion_2026-08-12.md` |
