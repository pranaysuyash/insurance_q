# Mobile-model decision shortlist (2026-07-25) — what is evaluated, scaffold-only, and catalog-only

Date: 2026-07-25
Scope: CoverWise policy-RAG path, Android/iOS users.

Use this file as the short, one-stop answer to your request:
- local/offline lanes vs hosted lanes
- evaluated vs not vs catalog-only
- transformers.js vs flutter-native
- HF Pro / OpenRouter / Modal vs mobile
- Android vs iOS feasibility
- fine-tune adapter readiness

## Evidence gate meaning

- **EVAL**: reproducible evidence file + run exists for this exact lane.
- **SCaffold**: integration code is present, but no real `.task` install/load/ask execution on Android/iOS in this repo.
- **Catalog-only**: researched/shortlisted only (no execution path in-repo).
- **Hosted-only**: cloud API lane (no phone-local execution).
- **Context-only**: key/token/infrastructure exists elsewhere, but no app-level execution proof here.

## 1) Canonically evaluated lanes (today)

| Lane | Stage | Runtime target | Eval status | Latest evidence | Why this status |
|---|---|---|---|---|---|
| OpenAI `gpt-5-nano` (`gpt-5-nano-2025-08-07`) | hosted generation / grounding | cloud API | **EVAL** | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`, `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json`, `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | 3/3 synthetic + held-out policy corpus metrics (52Q). This remains hosted baseline, not phone-local. |
| OpenRouter `google/gemini-2.5-flash-lite` | hosted generation compare | cloud API | **EVAL (limited)** | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json`, `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json` | Comparison lane; not on-device. |
| OpenRouter `google/gemma-3-4b-it` | hosted generation compare | cloud API | **EVAL (limited)** | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | Comparison lane; not on-device. |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | hosted generation compare | cloud API | **EVAL (limited)** | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json`, `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json` | Hosted/credits lane; no local phone artifact. |
| PyMuPDF + current parser/ingestion path | parse/chunk base | server pipeline | **EVAL** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` and docs referenced there | Canonical server pipeline only (not Android/iOS-local extraction lane). |
| Surya-2/docTR-based OCR/classic checks | OCR/layout fixture checks | server/local desktop | **EVAL (limited)** | `docs/review/evidence/local-model-eval/gemma3-4b-recheck-2026-07-12.json` and OCR companion checks | Useful benchmark, not device runtime. |
| On-device test harness flags and path reachability | on-device control-path contract | Flutter mobile bridge | **EVAL (control only)** | `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-25.json` and `mobile-ondevice-harness-2026-07-25b.json` | Verifies `ON_DEVICE_INFERENCE_ENABLED` + install-attempt path reachability; **not** install/load/ask with real `.task`. |

## 2) Mobile-native candidates by status

### 2.1 Flutter-native seam (first-party path)

| Candidate | Stage intent | Android | iOS | Status | Blocker |
|---|---|---:|---:|---|---|
| `flutter_gemma` + `flutter_gemma_mediapipe` (`ON_DEVICE_INFERENCE_ENABLED`, `ON_DEVICE_MODEL_URL`) | generation/offline assist + retrieval support | ✅ | ✅ | **SCaffold** | No real `.task` artifact install/load/ask on-device trace yet. |

### 2.2 Candidate families for mobile-offline execution

| Candidate | Stage intent | Android | iOS | Status | Why |
|---|---|---:|---:|---|---|
| Gemma 3n E2B / E4B (`.task`) | generation fallback | ✅ | ✅ | **Catalog-only** | No signed artifact hash + no real device trace.
| Gemma 3 270M / 1B | compact classifier/assistant lane | ✅ | ✅ | **Catalog-only** | No mobile export + no device benchmark.
| Qwen3 0.6B / 1.7B / 4B | generation compare lane | ✅ | ✅ | **Catalog-only** | No mobile export + no device benchmark.
| Phi-4-mini / SmolLM3 / Ministral 3B | compact generation compare | ✅ | ✅ | **Catalog-only** | No mobile export + no device benchmark.
| Qwen3-VL / PaddleOCR-VL / Dolphin / Unlimited-OCR / RT-DocLayout / MeDocVL / etc. | OCR/layout recovery (second-stage visual) | Candidate only | Candidate only | **Catalog-only** | No visual recovery implementation and run evidence in CoverWise app.
| Fine-tune / LoRA / adapter lanes | custom compact models | depends | depends | **Catalog-only (not wired)** | No tokenizer lock, artifact hash, export, deployment format, or metadata governance in app.

## 3) Transformers.js, managed-device, and hosted lanes (explicitly separated)

| Option | Runtime class | Status today | Reason |
|---|---|---|---|
| Transformers.js / WebGPU / ONNX-Web | web/mobile-web experiment | **Not Flutter-native Android/iOS runtime** | Separate browser path; no production Flutter bridge execution in this repo.
| Android Gemini Nano / AICore | managed native OS inference | **Catalog-only / not integrated** | No in-app capability probe and no supported/unsupported matrix.
| Apple Foundation Models | managed native iOS inference | **Catalog-only / not integrated** | No in-app capability probe and no OS-model fallback matrix.
| Modal Labs (`MODAL_TOKEN_ID/SECRET`) | private GPU benchmark/training infra | **Context-only** | No CoverWise mobile endpoint or app-run routing.

## 4) Provider key-surface (routing context only; values omitted)

From `.env` surfaces checked in the current workspace scan:
- `medpiper/insurance_app`: OpenAI + OLLAMA + Groq keys.
- `orbitcover-d2c`: OpenRouter keys.
- `comfy`: HF + Modal keys.
- `speech_experiments/model-lab`: HF keys.
- `invoice-intelligence`: OpenAI + OpenRouter.
- `edureka`, `bas5minute`, `learning_for_kids`, `EchoPanel`, `adshot`, `SentinelTwin`, `musicathon`, `notes` (various provider keys).

Interpretation: key presence is an **experiment surface**, not proof of Android/iOS local execution.

## 5) Required shortlisting outcome (what should be done next)

1. Keep hosted `OpenAI gpt-5-nano` as current policy production fallback (already evidenced).
2. Run one true mobile-local mile-stone first:
   - `flutter_gemma` with a valid `.task`, signed manifest, Android + iOS install + load + ask execution.
3. Capture manifest metrics at first run:
   - install/load success, infer latency (cold/warm), RSS/memory, timeout/retry/cancel class, thermal trend, unsupported-device behavior.
4. Only after mile-stone 2 pass, promote one compact comparator lane (`Gemma 3 270M/1B` or `Qwen3 1.7B`) under same telemetry contract.
5. Move managed-runtime probes (Gemini Nano/AICore, Foundation Models) to a later stage and only after in-app capability matrices exist.

## 6) Primary references (single source set)

- `docs/review/mobile_model_stage_truth_matrix_2026-07-25.md` (single matrix)
- `docs/review/mobile_model_full_evaluation_compendium_2026-07-25.md` (stage + provider + shortlist rationale)
- `docs/review/mobile_model_frontier_2024_plus_inventory_2026-07-25.md` (2025-2026 parser/OCR frontier)
- `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-25.json` (on-device harness)
- `mobile/lib/services/on_device_inference_service.dart` + `mobile/lib/config/app_config.dart` (mobile seam + flags)
