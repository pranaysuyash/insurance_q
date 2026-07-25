# Mobile model gatebook (CoverWise, 2026-07-26)

Scope: CoverWise mobile (Android/iOS first), with current in-repo evidence. This is the single-file decision gatebook for:

- what has truly been evaluated vs what is catalog/scaffold only,
- pipeline-stage readiness,
- Android/iOS off-device vs on-device paths,
- paid/hosted/bench-only lanes (HF Pro, OpenRouter, Modal, OpenAI),
- and what would block saying “mobile-offline is available.”

## 0) Evidence status legend used

- **EVAL**: reproducible in-repo evidence for that exact stage/runtime.
- **SCaffold**: code/test/config exist but no phone-class artifact install/load/ask proof.
- **Catalog-only**: model appears in the frontier list/notes only, no mobile execution evidence in-repo.
- **No-path**: not part of CoverWise Flutter-native route in this repo pass.

---

## 1) In-repo status matrix (requested shortlist)

### 1A) Mobile runtime lanes

| Family / Lane | Stage | Android/iOS status | Evidence file | Why this matters |
|---|---|---|---|---|
| `flutter_gemma` + `flutter_gemma_mediapipe` | On-device generation contract | **SCaffold** | `mobile/lib/config/app_config.dart`, `mobile/lib/services/on_device_inference_service.dart`, `mobile/test/on_device_inference_service_test.dart`, `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json` | Correct seam exists; no real `.task` install/load/ask telemetry yet. |
| Gemma 3n E2B / E4B `.task` | On-device generation | **Catalog-only** | `docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json` | No mobile artifact + no install/load/ask run present in repo. |
| Gemma 3 270M / 1B | On-device generation | **Catalog-only** | same as above | No exported mobile artifact + no device execution trace. |
| Qwen3 (0.6B / 1.7B / 4B) | On-device generation | **Catalog-only** | same as above | No exported mobile artifact + no device execution trace. |
| Phi-4-mini / SmolLM3 / Ministral 3B | On-device generation | **Catalog-only** | same as above | No exported mobile artifact + no device execution trace. |
| Qwen3-VL / PaddleOCR-VL / LLaVA classes | Visual recovery / parser augmentation | **Catalog-only** | `docs/review/mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md` | Useful research candidates; not staged on-device in this pass. |
| Android managed (`Gemini Nano` / `AICore`) | Managed platform runtime | **No-path** | `docs/review/mobile_model_execution_readiness_matrix_2026-07-26.md` | No in-app capability/probe + no fallback behavior matrix in repo. |
| iOS managed (`Apple Foundation Models`) | Managed platform runtime | **No-path** | same as above | No in-app capability/probe + fallback matrix in repo. |

### 1B) Hosted / private benchmark lanes

| Lane | Stage | Evidence file | Status | Key boundary |
|---|---|---|---|---|
| OpenAI `gpt-5-nano` | Hosted generation benchmark | `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json` | **EVAL (3/3)** | Not mobile-offline; comparison and fallback candidate. |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted generation benchmark | `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json` | **EVAL (2/3)** | Not mobile-offline; comparison only. |
| OpenRouter `google/gemma-3-4b-it` | Hosted generation benchmark | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | **EVAL (1/3)** | Not mobile-offline; comparison only. |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | Hosted generation benchmark | `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json` | **EVAL (2/3)** | Not mobile-offline; comparison only. |
| Modal Labs (`comfy` token set) | Private GPU / exploration lane | `comfy/.env` | **Context-only** | Key presence confirmed elsewhere; no CoverWise mobile route/wire-in yet. |
| Ollama/DeepSeek desktop checks | Desktop/off-path | `docs/review/evidence/local-model-eval/*.json` | **Desktop-only** | Not Flutter Android/iOS app runtime. |

### 1C) Stage mapping for the core pipeline (current)

| Stage | In-repo truth status | Evidence basis |
|---|---|---|
| Parsing / extraction / OCR | **Catalog-only for frontier; EVAL for existing server path** | `docs/review/mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md`, `docs/technical/rag/exploration/chunking_parsing_embedding_exploration_2026-07-22.md` |
| Chunking / structure reconstruction | **EVAL (server-side path), no mobile on-device proof** | `docs/technical/rag/exploration/chunking_parsing_embedding_exploration_2026-07-22.md` |
| Embedding / retrieval / rerank | **EVAL (hosted/server path)** | policy corpus + RAG service evidence |
| Generation | **SCaffold + hosted EVAL** | on-device seam + provider smoke files listed above |
| Orchestration / fallback policy | **Partial EVAL + repo tests** | hosted smoke + mobile harness flags/tests |

---

## 2) Frontier set (2024+) and what it implies

- Source file: `docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json`
- Total frontier entries: **77**
- Stage split in this set: **2024=4, 2025=30, 2026=43**

Top examples requested previously (Baidu/2026 variants included):  
`Unlimited-OCR`, `RT-DocLayout`, `PaddleOCR-VL` family, `MinerU*`, `Logics-Parsing`, `Dolphin`, `Qwen3-VL`, `DAN*`, etc.  
All listed frontier entries are currently **Catalog-only** for Android/iOS execution.

---

## 3) Why previous gaps remain (explicit)

1. No signed/managed `.task` / mobile manifest is present for a real Android/iOS install/load/ask proof.
2. No Android/iOS sidecar telemetry pass exists yet for:
   - model download/install completion,
   - `load` success + warm-start behavior,
   - successful policy-grounded mobile answers,
   - timeout/cancel/retry classification.
3. Fine-tuned / adapter candidates are not represented as production-mobile decisions until a runnable artifact package + export manifest + runtime run exists for both Android and iOS.
4. Transformers.js is present only as web/bridge research context and is not the Android/iOS native route.

---

## 4) What is truly evaluated by this pass (not inferred)

- **Evaluated (repo EVAL):** hosted generation smoke + policy held-out corpus checks (pass/fail listed above).
- **Scaffold-only:** `flutter_gemma` local inference seam + install attempt reachability in tests.
- **Catalog-only:** all 77 frontier parser/OCR/GEMMA/QWEN/adapter candidates.
- **No-path:** managed platform managed lanes not integrated/ran in CoverWise mobile path.

---

## 5) Next gates to move to genuine mobile-offline evidence

For a candidate to move from Catalog/Scaffold to EVAL, all gates must pass:

1. Signed mobile artifact/manifest available per target (`.task`, quantization, tokenizer, version hash).
2. Android + iOS install or ready-state proof captured from instrumentation.
3. Android + iOS `load` and `ask` proof with schema-valid outputs.
4. Latency + memory/RSS + timeout/cancel/retry/failure-class telemetry captured.
5. Policy-stage fallback + unsupported hardware behavior documented.

Priority sequence (as already prepared in execution plan):  
1) `flutter_gemma` seam hardening + Gemma 3n `.task` first path, 2) compact fallback candidate (`Gemma 3` 270M/1B or `Qwen3` 1.7B), 3) managed runtime probes, 4) parser/OCR frontier stage candidates.

---

## 6) Cross-links (authoritative single place set)

- `mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md`
- `mobile_model_execution_readiness_matrix_2026-07-26.md`
- `mobile_model_shortlist_truth_and_gaps_2026-07-26.md`
- `mobile_model_evaluated_vs_not_authority_2026-07-26.md`
- `mobile_model_android_ios_execution_plan_2026-07-26.md`
- `mobile_model_full_evaluation_compendium_2026-07-26.md`
- `mobile_model_key_surface_inventory_2026-07-25.md`

