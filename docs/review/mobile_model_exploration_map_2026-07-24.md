# Mobile model exploration map — decision register

**Status:** active research; this is not an implementation-complete claim.  
**Question:** what can a CoverWise Android/iOS user run locally, what needs a
hosted provider, and what must be proven before either path may influence a
source-grounded insurance explanation?

Current authoritative inventory snapshot (2026-07-25):  
[mobile_model_evaluation_inventory_2026-07-25.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_evaluation_inventory_2026-07-25.md)
[mobile_model_truth_inventory_2026-07-25.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_truth_inventory_2026-07-25.md)
[mobile_model_execution_ledger_2026-07-25.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_execution_ledger_2026-07-25.md)
[mobile_model_shortlist_truth_and_gaps_2026-07-26.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_shortlist_truth_and_gaps_2026-07-26.md)
[mobile_model_evaluated_vs_not_authority_2026-07-26.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_evaluated_vs_not_authority_2026-07-26.md)
[mobile_model_paid_keys_inventory_2026-07-26.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_paid_keys_inventory_2026-07-26.md)
[mobile_model_execution_readiness_matrix_2026-07-26.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_execution_readiness_matrix_2026-07-26.md)
[mobile_model_full_evaluation_compendium_2026-07-26.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_full_evaluation_compendium_2026-07-26.md)


## 2026-07-26 continuity update — what was actually explored vs only listed

This pass confirms three explicit buckets for the mobile product lane:

- **EVAL (reproducible output in target lane):** only hosted/remote providers and local-control seam tests
- **Catalog-only:** model/stack is shortlisted but no on-device artifact install/load/ask evidence
- **No-path/Not-applicable:** not wired to CoverWise mobile flow in this repo

### July 26 addendum: execution-readiness matrix updated

The latest, consolidated status of "evaluated vs catalog-only vs scaffold vs context-only" is now documented in:

- [mobile_model_execution_readiness_matrix_2026-07-26.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_execution_readiness_matrix_2026-07-26.md)


### A) Android/iOS mobile-native lane (actual proof in repo)

| Candidate | Stage | Mobile path | Status | Why |
|---|---|---|---|---|
| `flutter_gemma` seam (`flutter_gemma`, `flutter_gemma_mediapipe`) | on-device generation infra | Android + iOS Flutter bridge | **SCaffold** | Feature flags/tests exist (`ON_DEVICE_*` controls), but no `.task` install/load/ask run has been attached to a device trace in this pass. |
| Gemma 3n E2B / E4B `.task` | shared local generation | Android + iOS native inference | **Catalog-only** | Candidate priority is correct, but no exported/mobile artifact, no install/load telemetry, no answer trace. |
| Gemma 3 270M / 1B | compact local generation/classification | Android + iOS planned bridge | **Catalog-only** | No pipeline run for this model family in mobile runtime. |
| Qwen3 0.6B / 1.7B / 4B | local generation (portable) | Android + iOS planned bridge | **Catalog-only** | No export/benchmark on-device run in this pass. |
| Phi-4-mini / SmolLM3 / Ministral 3B | local generation alternatives | Android + iOS planned bridge | **Catalog-only** | No export/asset/version proof in repo. |
| Qwen3-VL 2B / 4B | visual fallback stage | Android + iOS planned bridge | **Catalog-only** | No visual-stage mobile benchmark collected. |
| EmbeddingGemma 308M / Qwen3-Embedding family | local embedding for RAG retrieval | Android + iOS planned bridge | **Catalog-only** | No model artifact + on-device embed/eviction test. |
| Gemini Nano / AICore | managed Android path | Android managed API | **Not-applicable in this pass** | Not yet probed in-app on supported/unsupported Android SKUs.
| Apple Foundation Models | managed iOS path | iOS managed OS-level model | **Not-applicable in this pass** | No iOS OS-model probe + fallback telemetry captured yet.
| Transformers.js / ONNX Web | web/mobile-web bridge | Browser path (not native Flutter) | **No-path** | No native bridge runtime claims in CoverWise path.

### B) Hosted comparison lanes (evaluated, not mobile-offline)

| Lane | Stage | Status | Evidence in repo |
|---|---|---|---|
| OpenAI `gpt-5-nano` | hosted generation + policy corpus | **EVAL** | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`, `continuation-smoke-2026-07-25.json`, `policy-corpus-ragas-2026-07-24.json` |
| OpenRouter (`google/gemini-2.5-flash-lite`) | hosted generation comparator | **EVAL (partial)** | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json`, `continuation-openrouter-2026-07-25.json` |
| OpenRouter (`google/gemma-3-4b-it`) | hosted generation comparator | **EVAL (partial)** | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` |
| HF Pro via Inference (`Qwen/Qwen3-4B-Instruct-2507`) | hosted generation comparator | **EVAL (partial)** | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json`, `continuation-hf-2026-07-25.json` |
| Modal Labs private GPU endpoints | private benchmark infrastructure | **Context-only** | `comfy/.env` has active `MODAL_TOKEN_*`; no CoverWise mobile routing path exists.

### C) Frontier parser/OCR/layout systems from `document_parsers_extractors_catalog_2026_v2.xlsx`

- Scope file was ingested as `workbook_class_summary_2026-07-22.json` / `workbook_2024plus_inventory.json`; the authoritative stage list is `docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json` (77 entries) and mapped in
  [mobile_model_frontier_appendix_2026_07_25.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_frontier_appendix_2026_07_25.md).
- These are all currently **Catalog-only** for CoverWise mobile because no device-side execution contracts/artifacts exist yet.
- Current shortlist relevance for RAG-stage correction (beyond parse-only coverage):
  - **High-value stage fit today:** `Docling`-style structured parsers, `Marker`, `MinerU*`, `RT-DocLayout`, `Unlimited-OCR`, `AgenticOCR`, `Logics-Parsing`, `Qwen3-VL`, `Dolphin-*`.
  - These are still at evaluation-planning status because the pipeline break for current policy QA is structural reconstruction + mobile runtime not yet proven.

### D) Fine-tune / adapter reality (for the asked shortlist)

- No mobile-ready fine-tune/LoRA/adapter artifact has been found in the app’s runnable path.
- The current request for “fine-tuned” in this lane therefore remains **asset-state pending** (needs base model + tokenizer + merge rule + quantization target + export manifest + provenance + rollback path).

### E) Required gate update (July 26)

No additional model is upgraded to **mobile-evaluated** in this pass without all three proofs:

1) versioned mobile artifact in supported format,
2) Android+iOS install/load/ask telemetry,
3) evidence bundle with latency, memory/thermal, fallback, refusal and schema validation.

Until these are satisfied, all candidate families above remain either **Catalog-only** or **No-path**.

## Reality checkpoint

- The Flutter app targets Android API 36 and iOS 15.5, and declares an opt-in local
  generative runtime via `flutter_gemma` + `flutter_gemma_mediapipe` with explicit
  config gating.
- In the latest run, Flutter discovered **iPhone 17 (simulator), macOS, and Chrome**.
  There was no attached physical Android device or physical AICore/Apple-Intelligence
  hardware for this run. Therefore: **no Android/iOS physical-device model execution
  evidence exists yet** in this repository pass.

### 2026-07-25 execution checks (applied this pass)

- Device discovery check: `flutter devices` shows the iPhone 17 simulator, macOS, and
  Chrome.
- On-device seam checks:
- `flutter test test/on_device_inference_service_test.dart` passed (`3/3`) for default-config guard behavior.
  - `flutter test -d F5AC13E5-FDAF-4877-B7FF-4265A3180931 --dart-define=ON_DEVICE_TEST_INSTALL_ATTEMPT=true --dart-define=ON_DEVICE_INFERENCE_ENABLED=true --dart-define=ON_DEVICE_MODEL_URL=https://example.com/model.task test/on_device_inference_service_test.dart` currently passes (`3/3`) for control-path reachability under configured flags; this remains **control-path-only** (no real `.task` install/load/ask success trace yet).
- Artifact presence check: no `.task`, `.gguf`, `.onnx`, `.safetensors`, `.tflite`,
  or other mobile-executable model artifacts were found in this repo.
- Provider benchmark continuity check:
  - `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json` (OpenAI `3/3`)
  - `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json` (OpenRouter `2/3`)
  - `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json` (HF Pro `2/3`).
  - Earlier `2026-07-24` provider runs remain in place for historical context.
- Provider/benchmark context: model execution for policy/doc-rag remains in hosted or
  desktop lanes until a mobile artifact + install path + on-device benchmark manifest
  are added.
- Dependency check: `python -m src.eval.ragas_eval` is currently blocked in this
  environment because `openai` is not installed, so no new RAGAS rerun was added.

Current truth consequence: `flutter_gemma` is still scaffolded and config-gated; no
Android/iOS `.task` model install/load/ask execution has been completed yet.

## Direct 2026-07-25 answer snapshot (your requested "evaluated vs not" view)

### 1) Model/runtime status (mobile-scope truth, not marketing claim)

| Area | Status now | Evidence class | What it means for Android/iOS users |
|---|---|---|---|
| **Flutter on-device path** (`flutter_gemma` + `flutter_gemma_mediapipe`) | ⚠️ **Code exists, no on-device run** | seam + tests + manifest flags + runtime checks only | Feature is not production-available as mobile-only inference yet |
| **Android + iOS runtime models** | ❌ **Not executed in this repo pass** | no `.task`/model artifact + no install/load/ask pass | Not runnable as local-offline inference today |
| **Hosted API generation** (OpenAI / OpenRouter / HF Pro) | ✅ **Executed (hosted)** | reproducible synthetic/probes | Valid as cloud fallback/research lanes only |
| **Transformers.js / browser bridge** | ❌ not used for Flutter native app runtime | no in-app Flutter bridge run in this turn | Not Android/iOS native inference evidence |
| **Modal Labs / private GPU inference** | ⚠️ infra exists outside CoverWise but not wired as mobile lane | URLs/tokens in separate project | Good private-lab benchmark path, not mobile runtime |

### 2) Android/iOS specific candidate list + status

| Candidate | Platform | Status | Why selected or blocked |
|---|---|---|---|
| Gemma 3n E2B/E4B | shared mobile (LiteRT/MediaPipe) | **Run-first candidate, not yet evaluated** | explicit seam exists; no `.task` execution proof |
| Gemini Nano / AICore | Android managed | **Blocked** (no device probe) | available docs only; no hardware validation in app |
| Apple Foundation Models | iOS managed | **Blocked** (no managed probe) | docs only; no iOS runtime integration proved |
| Gemma 3 270M / 1B | shared/local portability | **Later** | no mobile export/execute trace yet |
| Qwen3 (portable stack) | cross-platform exports | **Later** | no exported artifact + benchmark trace in this pass |
| Phi-4-mini / SmolLM3 / Ministral / Qwen3-VL | cross-platform fallback candidates | **Later** | catalog/research only in this pass |

### 3) Provider lanes with key-bearing config and role (covered vs unsupported claims)

| Lane | Key/source presence checked | Role in this product now | Local/offline claim |
|---|---|---|---|
| OpenAI (`gpt-5-nano`) | `/medpiper/insurance_app/.env` has `OPENAI_API_KEY` | production-grounded cloud baseline for policy answers | ❌ not local |
| OpenRouter (e.g., Gemini/ Gemma-3, `openrouter`) | `OPENROUTER_API_KEY` present in `orbitcover-d2c` env set, not wired into CoverWise mobile runtime | comparison lane / paid cloud fallback context | ❌ not local |
| HF Pro / HF Inference (`Qwen3-4B`) | HF tokens present in project family; no active token usage in mobile runtime path | hosted benchmark and comparison lane | ❌ not local |
| Ollama (`OLLAMA_BASE_URL`) | present in `medpiper/insurance_app/.env` | local-server benchmark path for desktop, not phone | ❌ not Android/iOS |
| Modal Labs | present via `comfy` env in separate project | private GPU benchmark, endpoint-based | ❌ not mobile runtime |

### 4) Evaluated vs not (strictly by runtime proof in this mobile decision pass)

- **Evaluated today (reproducible, target-aware evidence):**  
  `gpt-5-nano` (`3/3`, synthetic pass), OpenRouter Gemini (`2/3`), HF Qwen3-4B (`2/3`), OpenAI `policy-corpus-ragas` (`52Q`, accuracy `0.5577`, citation_rate `0.9615`, hallucination `0.3333`).
- **Not yet evaluated for mobile execution:**  
  all Android/iOS-native candidates (Gemma 3n/3, Gemini Nano, Apple Foundation Models, Qwen/Phi/SmolLM/Ministral/Qwen3-VL), all `transformers.js` native-bridge claims, all managed-runtime fallbacks, and all on-device embedding/reranker/mobile OCR alternatives.
- **Shortlist rationale now:**  
  1) finish `Gemma 3n` end-to-end mobile run on both Android+iOS tiers,  
  2) then compare with managed fallbacks (Nano/Foundation),  
  3) only then expand to portable alternatives (Qwen/phi/smollm) behind quality + resource gates.

Also see the consolidated decision sheet for a project-key and model feasibility ledger:

- [mobile_model_decision_sheet_2026-07-24.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_decision_sheet_2026-07-24.md)
- [mobile_model_strict_matrix_2026-07-24.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_strict_matrix_2026-07-24.md)
- [mobile_model_decision_onepager_2026-07-24.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_decision_onepager_2026-07-24.md)
- [mobile_model_execution_ledger_2026-07-24.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_execution_ledger_2026-07-24.md)
- [mobile_model_catalog_2025_2026_2026-07-24.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_catalog_2025_2026_2026-07-24.md)
- [mobile_model_general_vlm_frontier_2026-07-24.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_general_vlm_frontier_2026-07-24.md)
- The existing server evidence pipeline is canonical for policy facts. A local
  model may classify, extract into a schema, or draft an explanation, but a
  field/answer must still carry source evidence or become `not verified`.

## Architecture lanes — first-principles selection

| Lane | User benefit | Ownership | Selected role | Hard boundary |
|---|---|---|---|---|
| Platform-managed Android | Fast, private short offline assistance | Android/AICore manages model and availability | Gemini Nano capability path | No availability assumption; no use for unsupported devices |
| Platform-managed iOS | Fast, private short offline assistance | Apple Intelligence manages model and changes it with OS | Foundation Models capability path | Prompt regression is required per OS/model update |
| Shared packaged model | Same constrained workflow across platforms | CoverWise owns asset, tokenizer, bridge, updates, and telemetry | Gemma 3n E2B first; E4B only if high-end devices pass | Download/thermal/memory/cancellation are product requirements |
| Portable packaged model | Avoid lock-in; compare quality/latency | CoverWise owns exported artifacts per backend | Qwen3 1.7B first via ExecuTorch | Android and iOS exports are separate artifacts and must each pass |
| Hosted evidence path | Higher-quality grounded policy assistance | CoverWise server controls validation, auditing, and fallback | OpenAI baseline | Never expose provider keys in mobile; do not bypass evidence gates |
| Private GPU research | Compare larger/VLM/fine-tuned models | Modal benchmark environment | Offline benchmark/training only | It is not a user’s local model and cannot silently become production traffic |

## Candidate register

| Candidate | Released/updated | Intended task | Runtime | Android/iOS suitability | Evidence | Next decision gate |
|---|---|---|---|---|---|---|
| Gemini Nano/AICore | current platform family | concise offline classify/summarize | Android native | Android only; device gated | Tier 1 docs | capability probe on supported Pixel + unsupported Android fallback |
| Apple Foundation Models | current platform family | concise offline extraction/summarize/tool calls | Apple native | iOS only; Apple Intelligence gated | Tier 1 docs | supported + unsupported iPhone regression, OS-model version captured |
| Gemma 3n E2B | 2025 | shared offline text-first assist | MediaPipe/LiteRT | leading shared candidate | Tier 1 docs | package size, cold/warm latency, RSS, thermal, source-ID contract |
| Gemma 3n E4B | 2025 | high-end shared offline assist | MediaPipe/LiteRT | conditional high-end tier | Tier 1 docs | prove benefit over E2B outweighs download/thermal cost |
| Gemma 3 270M/1B | 2025 | local routing/classification | LiteRT/MediaPipe where supported | likely small-task candidate | Tier 1 docs | classifier/review corpus; not policy-Q&A replacement |
| Qwen3 0.6B | 2025 | latency floor | ExecuTorch/MLC/GGUF | both after export | Tier 1 docs | establish minimum usable schema/grounding quality |
| Qwen3 1.7B | 2025 | portable local extraction comparison | ExecuTorch first | both after distinct exports | Tier 1 docs | first portable benchmark candidate |
| Qwen3 4B | 2025 | quality ceiling comparison | ExecuTorch/MLC/GGUF | high-end only until proved | Tier 1 docs + hosted smoke 2/3 for another Qwen3 4B variant | memory/thermal and citation gate |
| Phi-4-mini-instruct | Feb 2025 | compact reasoning comparison | ExecuTorch/ONNX after export | high-end candidate | Tier 1 docs | export reproducibility and device benchmark |
| SmolLM3 3B | 2025 | small-model comparison | ONNX/other export after validation | candidate only | Tier 1 docs | artifact/licence/runtime validation |
| Ministral 3 3B | Dec 2025 | edge VLM comparison | only after native export proof | high-end candidate | Tier 1 docs | image-page task must outperform OCR+text path |
| Qwen3-VL 2B/4B | 2025 | visual reviewer after OCR failure | export-specific | second-stage only | Tier 1 docs | visual corpus and source-coordinate grounding |

## Decision matrix (selected now vs later)

This matrix is the actionable "what to run next" ledger. `Decision` is about the current project state, not model quality alone.

| Candidate | Stage | Evidence currently available | Decision (proceed now?) | Why | What is required before moving from this state |
|---|---|---|---|---|---|
| Gemini Nano/AICore | generation (platform-managed) | Tier-1 capability docs + no in-app device run | **Later** | Candidate exists but needs hardware capability probing and fallback policy | Run on-device capability probe on supported/unsupported Android SKUs |
| Apple Foundation Models | generation (platform-managed) | Tier-1 capability docs + no in-app device run | **Later** | Same reason: no iOS probe data and no OS-model regression baseline | Run supported + unsupported iPhone matrix with refusal behavior |
| Gemma 3n E2B | shared offline generation + RAG | `flutter_gemma` seam exists, no runtime run | **Run first** | Best single cross-platform default for first local-lane because of explicit mobile-first runtime path | Add capability contract, ship signed asset + measure cold/warm latency, RSS, thermal, download resume |
| Gemma 3n E4B | shared offline generation + RAG | design docs only | **Later** | Potentially useful only if E2B fails recall/latency gates | Compare only if E2B fails quality gate and thermal margin is acceptable |
| Gemma 3 270M/1B | routing/classification | design docs only | **Later** | Good baseline but lower-priority than first-party shared candidate | Validate once shared lane contract is stable and evidence exists for doc routing gains |
| Qwen3 0.6B | offline text generation | design docs only | **Later** | Useful latency floor, but not the primary first candidate | Evaluate after first shared lane baseline is in place |
| Qwen3 1.7B | offline text generation | design docs only | **Later** | Useful comparison candidate after E2B baseline | Evaluate portable export path only if first lane passes baseline gate |
| Qwen3 4B | offline generation ceiling | design docs + hosted smoke context only | **Later** | Too expensive for first mobile release without baseline proof | Re-evaluate only for high-end lane with strong memory/thermal budget |
| Phi-4-mini-instruct | offline compact reasoning | design docs only | **Later** | No export/run evidence in project yet | Export and compare only in controlled portability lane |
| SmolLM3 3B | offline compact reasoning | design docs only | **Later** | Not first in insurance-task order | Evaluate only after capability pipeline and gating are proven |
| Ministral 3 3B | mobile VLM fallback | design docs only | **Later** | VLM fallback only; image-stage quality still unknown | Evaluate only against OCR+text baseline on visual-failure pages |
| Qwen3-VL 2B/4B | visual recovery | docs + no run | **Later** | Useful second-stage only after OCR/layout baseline is stable | Evaluate only on visual-failure page set and source-coordinate accuracy |

### Candidate-specific outcome for your question

- **For Android/iOS users:** move to one runtime now: **Gemma 3n E2B shared lane** (candidate-first).
- **For managed-platform assistance:** defer `Gemma 3n E2B` integration until on-device contract and fallback telemetry are in place; do not start with platform-only Nano/Foundation models without hardware probe data.
- **For non-local/offline claims:** treat `Ollama`, `MLX`, `HF/Modal/OpenRouter/OpenAI` as hosted lanes and never list them as mobile offline.

## Execution ticket matrix (ready-to-run)

Use this as a direct work ticket backlog. Each ticket should produce an artifact (log + metrics + evidence bundle) before the next ticket depends on it.

### Android/iOS execution backlog

| Ticket | Candidate / path | Goal | Required run setup | Must collect | Pass criteria | Blocked by |
|---|---|---|---|---|---|---|
| T1 | Capability contract + seam validation | Define and validate one mobile capability model schema for any local path | `MobileModelCapability` data model + on-device feature flag off default | `model_capability` object dump and event logs for unsupported-device fallback | Contract serializes, resolves to host-only for unsupported devices, no hard-coded provider key leakage | Existing service contract changes |
| T2 | Gemma 3n E2B shared baseline (Android + iOS) | Produce first mobile local benchmark for one shared path | Signed `.task` artifact reference, staged download path, cold/warm benchmark mode | Latency p50/p95, RSS, temp trend, download/fetch retries, timeout and cancellation events, output schema pass rate, citation pass rate | T1 completed, artifact hash available |
| T3 | Retrieval + grounding smoke on mobile | Verify local path can keep citation quality stable vs hosted baseline | 52Q policy fixture subset + synthetic refusal + negative pages | Citation rate, field completeness, unsupported field refusals, provenance fidelity | T2 passes baseline gate for non-fatal telemetry collection |
| T4 | Android platform-managed probe (Nano/AICore) | Collect evidence whether Nano path is usable fallback or not | Supported Android + unsupported Android SKUs, minimal corpus | Capability probe pass/fail, refusal consistency, crash rate, battery step delta | T1 and T3 logging readiness |
| T5 | iOS managed fallback probe (Foundation Models) | Collect evidence whether iOS managed path is available where advertised | Supported iPhone + unsupported iPhone SKUs, same policy fixture | Model availability map by OS, refusal behavior, citation quality, restart/relaunch behavior | T1 and T3 logging readiness |
| T6 | Optional second-stage comparators | Evaluate non-selected candidates only if T2 passes | Exported artifacts + same benchmark manifest | Delta metrics vs T2 on latency, citation, schema validity, battery/thermal deltas | T2 and T3 approved by quality gate |

### Benchmark manifest checklist (required for every ticket above)

- Dataset split: 20 policy-aligned question probes + 8 visual-layout failures + 6 negative/abuse prompts + 6 refusal-only prompts.
- Context controls: fixed policy source set; source/page references; deterministic seeds.
- Logging schema: model id/runtime/asset hash, device/tier, temperature, timeout, cancellation, fallback reason, latency, memory, RSS, thermal, network.
- Output controls: schema-valid answer rate, unsupported-field refusal rate, citation completeness, citation correctness sample audit.
- Evidence artifacts: signed run manifest, telemetry export, model/runtime hash list, gate outcome table.

### Immediate run-order recommendation

1. T1 → 2 → 3 (baseline local viability gate)  
2. If baseline passes, run T4 and T5 in parallel for managed fallback map  
3. If baseline fails on quality or reliability, stop at remediation before any T6 launch

## RAG model-system register — not just chat models

| RAG layer | Candidate set | Mobile/local role | Hosted/private-GPU role | Decision posture |
|---|---|---|---|---|
| Native text and layout | Existing PyMuPDF; Surya 2; PP-Structure/PaddleOCR family | Prefer native text first; run bounded OCR only when needed | Modal benchmark for complex scans | Existing pipeline remains canonical; no LLM substitutes for deterministic text extraction |
| Document VLM / complex page recovery | PaddleOCR-VL 0.9B/1.5, Qwen3-VL 2B/4B, Ministral 3 3B | Research only; no first-release phone claim | Primary research lane because document pages are memory/thermal heavy | Compare only on visual-layout failures, with element/page provenance |
| Embeddings — phone-local | **EmbeddingGemma 308M**; optional Qwen3-Embedding 0.6B after export proof | Leading local RAG retrieval candidate; multilingual, quantized, reduced output dimension | Server vector index may remain canonical for cross-device corpus | EmbeddingGemma + Gemma 3n is the first real local-RAG stack to evaluate, not Gemma 3n alone |
| Embeddings — server | OpenAI `text-embedding-3-small` (current); Qwen3-Embedding 0.6B/4B/8B comparison | not a local default | Quality/cost/region comparison | Preserve vector-space/version migration and owner-scoped retrieval contract |
| Reranking | Qwen3-Reranker 0.6B/4B/8B; existing lexical/dense hybrid baseline | 0.6B research only; likely defer from first phone release | Suitable for server/Modal comparison | Add only if retrieval error analysis proves dense retrieval is the bottleneck |
| Grounded generation | Gemma 3n E2B/E4B, Qwen3 1.7B, platform-managed Nano/Foundation | Bounded explanation over retrieved local snippets | GPT-5 Nano baseline; hosted Qwen/Gemma comparison routes | Generated facts must cite retrieved source IDs; no local answer bypass |
| Guardrails/classification | Gemma 3 270M/1B; embedding similarity/rules | Device capability, doc type, “needs review,” injection risk routing | Server validation is authoritative | Cheap deterministic/rule path first; model only where it improves a measured error |

**New first local-RAG experiment:** EmbeddingGemma for on-device retrieval plus
Gemma 3n E2B for a constrained answer over the retrieved snippets. Google
explicitly positions the pair for mobile-first RAG; this is more relevant than
shipping a standalone chat LLM. Qwen3 Embedding/Reranker 0.6B is the main
portable comparator; the 4B/8B variants are server/private-GPU comparison
models until phone measurements prove otherwise.

### Pipeline-stage truth matrix (explored vs not explored for this project)

| Stage | Candidate or lane | Execution class | What has been explored | What has **not** been explored | Evidence notes |
|---|---|---|---|---|---|
| Parse/digital-text | PyMuPDF (baseline) | canonical server | ✅ `local` evidence against policy fixtures; used in 52Q corpus path | ❌ mobile-native replacement in-app | No on-device parse path exists; parser quality still bounded by backend OCR choices |
| OCR/vision layout | Pytesseract, Surya-2 | server + desktop | ✅ targeted synthetic checks (`surya2` local run) | ❌ Mobile OCR stacks on device; OCR candidates from 2025–26 frontier not run | Surya-2 recovered limited token classes; not enough for device policy claims |
| Structured layout frontier | Docling, MinerU, Marker, PaddleOCR-PP, RT-DocLayout, Unlimited-OCR, AgenticOCR, Logics-Parsing, Qwen3-VL | research / private GPU | ❌ only catalog/selection evidence | ❌ no repo execution; no mobile or Modal run in this decision pass | Explicitly shortlisted because they map to table/header/KVP failure patterns |
| Chunking/reconstruction | paragraph/entity/entity+adjacent | server pipeline | ✅ active implementation and corpus-aware experiments | ❌ no mobile-only route tuning yet | Recovery currently limited by table cell reconstruction rather than model class |
| Embedding local | none deployed; current server `text-embedding-3-small` | hosted baseline + planned local | ✅ server embedding path exists in policy run | ❌ on-device embedding lane in shipped mobile path | EmbeddingGemma/quantized Qwen3 embedding remain “planned comparators” only |
| Embedding frontier | EmbeddingGemma 308M; Qwen3-Embedding 0.6B/4B/8B | server/private-GPU; local plan | ❌ not evaluated in mobile runtime yet | ❌ no on-device execution yet, no export validation | Planned to evaluate only after capability contract and artifact lineage exist |
| Retrieval/rerank | Hybrid dense+fts, reranker baseline | server | ✅ mixed corpus checks | ❌ mobile-only retrieval stress (low-resource pages, cache pressure, cancellation) | Retrieval errors currently dominate some misses; not model-only |
| Generation hosted | OpenAI (gpt-5-nano), OpenRouter family, HF-hosted Qwen3-4B, GROQ candidate classes | paid cloud | ✅ synthetic and corpus smoke + held-out policy baseline (`gpt-5-nano`) | ❌ no cross-provider cost/latency/citation stress on-device | This remains production-safe path while mobile offline is not proven |
| Generation local/offline | Gemma 3n, Gemma 3, Qwen3, Phi-4-mini, SmolLM3, Ministral | mobile-local candidate set + managed platform | ⚠️ `flutter_gemma` feature plumbing exists; no Android/iOS execution | ❌ no Android/iOS model runtime, no warm/cold benchmarks, no failure telemetry | This is the explicit reason why "mobile local decision" is still open |
| Platform-managed generation | Gemini Nano, Apple Foundation Models | on-device managed | ❌ no integrated/validated run in CoverWise | ❌ no hardware-device probe matrix | Must be integrated as capability-gated branches with fallback policy |
| Transport fallback | Ollama, MLX, Modal Labs, HF Inference, OpenRouter | host/private endpoint | ✅ reachable/local code paths tested in prior work | ❌ no direct use in mobile path; no on-device claim | These are not offline-on-device even when private |

## Authoritative execution ledger (evaluated vs not) by pipeline stage

This matrix uses one strict rule: **Evaluated** requires reproducible output in the
target stage/runtime for this product lane; **Catalog-only** or **hosted-only** evidence
does not count as mobile proof.

| Stage | Candidate / stack | Execution class | Evaluated (evidence in repo) | Why this is the status |
|---|---|---|---|---|
| Parse/digital-text baseline | PyMuPDF | server/local canonical | ✅ `local` policy fixture evidence + 52Q run | Canonical text path in current pipeline. |
| OCR/vision layout | Surya-2 (desktop), docTR, pytesseract | server + desktop | ✅ targeted synthetic checks (desktop/local) | Not equivalent to Android/iOS runtime proof. |
| OCR/vision layout | Docling, MinerU, Marker, PaddleOCR-PP, RT-DocLayout, Unlimited-OCR, AgenticOCR, Logics-Parsing, Qwen3-VL, etc. | catalog shortlist | ❌ catalog/selection only | High-priority frontier for table/header/KVP; no repo/mobile execution. |
| Chunking / reconstruction | paragraph/entity/entity+adjacent | server | ✅ implemented + corpus-aware | No mobile-only tuning yet; structural reconstruction still limits quality on some pages. |
| Embedding | `text-embedding-3-small` | hosted baseline | ✅ policy-corpus run present (`policy-corpus-ragas-2026-07-24.json`) | Not a local/mobile embedding path. |
| Embedding frontier | EmbeddingGemma 308M; Qwen3-Embedding 0.6B/4B/8B | planned local/mobile | ❌ not run in mobile runtime | Requires export/lifecycle validation before any benchmark claim. |
| Retrieval/rerank | dense + FTS + rerank baseline | server | ✅ mixed corpus checks | Needs mobile-only retrieval stress and cancellation/eviction tests next. |
| Hosted generation | OpenAI `gpt-5-nano` (`gpt-5-nano-2025-08-07`) | hosted API | ✅ synthetic 3/3; policy-corpus held-out 29/52 | Production fallback baseline; no on-device claim. |
| Hosted generation | OpenRouter `google/gemini-2.5-flash-lite` | hosted API | ✅ synthetic 2/3 | Useful routing comparison only. |
| Hosted generation | OpenRouter `google/gemma-3-4b-it` | hosted API | ✅ synthetic 1/3 | Not mobile candidate evidence. |
| Hosted generation | HF hosted Qwen3-4B (`Qwen/Qwen3-4B-Instruct-2507`) | hosted API | ✅ synthetic 2/3 | Useful for comparison; no mobile path. |
| Hosted generation | Groq/Grok families (historical mentions) | hosted API | ⚠️ previously discussed, not newly run in this pass | No live claim for mobile in this revision. |
| Desktop/local generation | Ollama `gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`; deepseek-ocr adapter | desktop local | ✅ synthetic-page transcribe checks | Local desktop only; does not satisfy Android/iOS. |
| Local/on-device seam | `flutter_gemma` + MediaPipe (`on_device_inference_service.dart`) | mobile feature flag path | ⚠️ code/integration present, no Android/iOS run | Controlled local lane exists but unproven at runtime. |
| Managed Android native | Gemini Nano / AICore | Android platform-managed | ❌ not integrated in CoverWise yet | Requires device capability probes and prompt/version regression. |
| Managed iOS native | Apple Foundation Models | iOS platform-managed | ❌ not integrated in CoverWise yet | Requires supported + unsupported-device probe and OS-model regression. |
| Cross-platform mobile generation | Gemma 3n E2B/E4B | MediaPipe/LiteRT path proposal | ❌ no eval run | Primary first mobile candidate pending capability contract + device proof. |
| Cross-platform mobile generation | Gemma 3 270M / 1B | LiteRT/ONNX/ExecuTorch proposal | ❌ no eval run | Small-footprint baseline candidate. |
| Cross-platform mobile generation | Qwen3 1.7B / 4B | ExecuTorch/MLC/LiteRT proposal | ❌ no eval run | Secondary quality/comparison candidate. |
| Cross-platform mobile generation | Phi-4-mini-instruct | ExecuTorch/ONNX/MLC proposal | ❌ no eval run | Desktop `phi3:mini` checks are not Phi-4 evidence. |
| Cross-platform mobile generation | SmolLM3 3B | ONNX/llama.cpp/MLC proposal | ❌ no eval run | Candidate for compact edge baseline. |
| Cross-platform mobile generation | Ministral 3 3B | ONNX/llama.cpp/MLC proposal | ❌ no eval run | Candidate for compact edge generation only. |
| Visual-stage mobile generation | Qwen3-VL 2B/4B | portable VLM stack proposal | ❌ no eval run | Keep second-stage for OCR/layout failures. |
| Mobile web/runtime experiments | Transformers.js (WebGPU/WASM cached ONNX) | browser/WebView experiment | ❌ no native Flutter runtime use | Web experiments do not equal native Android/iOS on-device app runtime. |
| Provider infra | HF Pro / HF Inference Providers / HF tokens | hosted tokens + API routing | ❌ no mobile/offline claim | Tokens are valid for hosted workflows only; not local execution. |
| Provider infra | Modal Labs / OpenRouter / OpenAI keys | hosted credentials discovered | ✅ cloud endpoint/ping + synthetic smoke evidence | Useful for comparison/fallback; not device-offline. |
| Fine-tune assets | LoRA/adapters/merged checkpoints | not in this lane | ❌ no production-ready fine-tune asset with mobile lineage | Fine-tune remains an asset and exportability problem, not a candidate alone. |

## "Evaluated vs not" model register (2025–2026 models)

The columns below are from this workspace's policy-doc exploration:

### Evaluated **for repo logic** (but not Android/iOS execution)

- **Gemma**: Gemma 3 4B/12B (desktop/Ollama), Gemma 3n family via `flutter_gemma` seam (feature plumbing only), plus on-disk `.task` delivery patterns.
- **Qwen**: Qwen2.5-VL 7B (desktop/Ollama smoke), Qwen3-4B (HF Hosted smoke only), Qwen3-VL (docs only).
- **Phi family**: no Phi-4 mobile run; `phi3:mini` desktop checks are not Phi-4 evidence.
- **Ministral**: no run for mobile/local in this pass; only planned/companion candidate.
- **OCR/Doc parsing frontier**: Surya-2 desktop; DeepSeek/OCR adapter smoke mismatch.
- **Runners**: OpenAI, OpenRouter, HF Inference Providers, Modal Labs (transport/infrastructure), Ollama/MLX (private local benchmark infra).

### Not yet evaluated on mobile (explicitly open)

- Android/iOS: Android Gemini Nano, Apple Foundation Models, Gemma 3n E2B/E4B, Gemma 3 270M/1B, Qwen3 1.7B/4B, Phi-4-mini, SmolLM3 3B, Ministral 3 3B.
- Frontier OCR/layout: Docling 2.x, MinerU 2.5-Pro/Popo, Marker, RT-DocLayout, Unlimited-OCR, PaddleOCR-VL-1.6, PP-OCRv6, Dolphin 1.5/2.0, AgenticOCR, Logics-Parsing, Qianfan/OCR.
- Embeddings: EmbeddingGemma 308M and Qwen3-Embedding family.
- Runtime/stacks: Transformers.js mobile-bridge mode, ExecuTorch, ONNX Runtime Mobile, MLC LLM, llama.cpp, LiteRT/TensorFlow Lite in policy path.

### Fine-tune status

- No fine-tune is production-integrated in this mobile model lane yet.
- "Fine-tuned" is treated as an **asset-state question** only: corpus, merge method,
  LoRA rank/adapter format, tokenizer, quantization, and exportability must be proven per platform and version.
- Any fine-tune work is therefore blocked behind the same runtime contract gates as
  untuned models (artifact lineage + mobile execution proof + gated rollout).

## Provider lanes requested in one-line summary

| Lane | What to treat as local/mobile? | What we currently have |
|---|---|---|
| **Transformers.js** | **Not mobile-native**; browser/WebView cached-ONNX experiment only | Not used for Flutter-native runtime; no mobile benchmark |
| **HF Pro / HF Inference Providers** | **Not local/offline** even with token credits | Used as hosted comparison lane in prior smoke; no on-device deployment claim |
| **OpenRouter** | Hosted aggregator with paid fallback routing | Key-name exists in OrbitCover; no CoverWise runtime wiring in this pass |
| **Modal Labs** | Private GPU server benchmark path (good for heavy VLM/layout tests) | No CoverWise endpoint for mobile benchmark yet |
| **OpenAI direct** | Hosted baseline | Production-anchored generation fallback with existing metrics and policy controls |

## Required correction to "explored"

The current state is: **no local-on-device Android/iOS model execution evidence exists yet**.
The only true mobile path with code today is a **controlled local-seam**
`flutter_gemma` feature flag. That means exploration is currently at the
**candidate/selection stage**, not a validated execution stage.

## 2026-07-25 Key-surface verification addendum

- **What was checked now:** provider keys and mobile-relevant model routing variables in project env files for active lanes.
- **Coverage app (`medpiper/insurance_app`):** `OPENAI_API_KEY`, `OPENAI_EMBEDDING_MODEL`, `OPENAI_CHAT_MODEL`, and `OLLAMA_BASE_URL` are present in `.env`; no OpenRouter/OpenAI router keys tied to mobile on-device seam were found.
- **OrbitCover lane (`orbitcover-d2c/.env*`):** `OPENROUTER_API_KEY` and `OPENROUTER_BASE_URL/TIER` are present for cloud API experimentation, but this project is not wired into CoverWise mobile runtime.
- **Other paid/experimental lanes present elsewhere:** Modal tokens were confirmed in `comfy` project env, plus HF credentials in multiple non-CoverWise projects; these remain cloud/offsite research/infrastructure lanes, not runtime mobile lanes.
- **Hard blocker:** No Android/iOS `.task` model artifact, no downloadable/installable on-device model package, and no successful app runtime install/load/ask trace in this pass.
- **Consequences for `evaluated vs not`:** hosted evaluations can remain in the comparison lane; `evaluated` status is upgraded only when a model has:
  1) architecture-compatible mobile artifact,
  2) install/load trace on at least one Android/iOS device, and
  3) answer trace + failure taxonomy logged in `docs/review/evidence/`.

## Explicit non-candidates for the first mobile release

- Desktop Ollama, MLX, and llama-server: benchmark/server infrastructure only.
- Transformers.js: WebView/PWA experiment only; it is not a Flutter-native
  model runtime.
- Qwen2.5-VL 7B, Qwen3-VL 8B, Gemma 3 4B/12B and Llama 4: hosted/private-GPU
  comparison lanes unless a real device package and thermal proof changes that.
- “Fine-tuned” is not a model choice. It is an asset lineage state that needs a
  governed corpus, base-model/version, adapter/merge method, tokenizer,
  quantization, export backend, licence, evaluation run, and rollback asset.

## Evaluation ledger

| Surface | What was run | Result | Evidence tier | What it does **not** establish |
|---|---|---:|---:|---|
| OpenAI direct `gpt-5-nano` on held-out policy corpus | full `policy_qa_v1` (52) with real `policy.pdf` | **29/52**, `accuracy=0.5577`, `citation_rate=0.9615`, `source_coverage=1.0`, `context_coverage=1.0`, `hallucination_rate=0.3333`, `ragas: faithfulness=0.8717/context_precision=0.4324/answer_relevancy=0.6954` | 4 | Mobile runtime, per-model comparison, battery/thermal, grounding failure-root-cause by stage, and final production readiness. |
| OpenAI direct `gpt-5-nano` | synthetic JSON/refusal/source-ID fixture | 3/3 | 2 | policy accuracy, production capacity, mobile execution |
| OpenRouter Gemini Flash Lite | same fixture | 2/3 | 2 | safe automatic grounding fallback |
| OpenRouter Gemma 3 4B | same fixture | 1/3 | 2 | CoverWise accuracy or local Gemma performance |
| HF Providers Qwen3 4B | same fixture | 2/3 | 2 | safe automatic grounding fallback or local Qwen performance |
| Modal | existing remote Python smoke | pass | 3 | model inference, policy quality, phone execution |
| Gemma 3 4B/12B; Qwen2.5-VL7B; Surya 2 | historical desktop synthetic runs | mixed/pass | 2 | any Android/iOS property |
| Android/iOS local runtime | none | not run | 0 | nothing |

## Required implementation sequence

1. Introduce one canonical `MobileModelCapability` contract: platform,
   availability, runtime, asset hash, model version, tokenizer, quantization,
   task, source mode, timeout, cancellation state, and failure reason.
2. Add capability detection plus a transparent server/unavailable fallback;
   no local model asset is loaded until it is selected through that contract.
3. Build a Flutter bridge for **one** lane only: Gemma 3n E2B through
   MediaPipe/LiteRT, with a feature flag and downloadable versioned asset.
4. Add an approved synthetic/de-identified benchmark manifest containing field
   values, source IDs/page references, negative cases, injection cases, and
   cancellation/eviction cases. Use the existing model lineage/dataset services
   to attach run metadata rather than a new shadow evaluation pipeline.
5. Run Android low/mid/high + AICore-capable device, and iOS unsupported +
   supported Apple Intelligence device. Measure cold/warm p50/p95, RSS,
   download/resume, battery/thermal, app background/kill/relaunch, network
   trace, schema, citation, and unsupported-field refusal.
6. Only then compare Qwen3 1.7B ExecuTorch and platform-managed routes against
   Gemma 3n. Fine-tune only when the versioned baseline shows a persistent
   model error rather than OCR/retrieval/schema/prompt defects.

## Decision gates and owners

| Gate | Pass condition | Current state | Owner/next action |
|---|---|---|---|
| G1 architecture | one canonical capability/lineage path, no mobile keys | open | implement bridge contract |
| G2 asset | reproducible signed/versioned model and tokenizer asset | open | choose Gemma 3n E2B artifact |
| G3 data | approved synthetic/consented evaluation release | open | use dataset registry; do not repurpose uploads |
| G4 Android | supported + unsupported capability and reliability runs | open | acquire/connect devices |
| G5 iOS | supported + unsupported capability and reliability runs | open | acquire/connect devices |
| G6 quality | grounded fields/Q&A meet declared held-out gates | open | run corpus evaluator |
| G7 operations | download/eviction/fallback visible to user and operator | open | telemetry/recovery tests |

## Recent corpus-level re-entry

Coverage now includes one production-corpus-style policy run:

- `policy.pdf` + `policy_qa_v1.json`, all 52 questions.
- Final metrics above (accuracy/citation/ragas) are now available and should be used as the baseline before changing parsing/chunking/reranking stages.
- Current run used the corrected retrieval path after the `QdrantClient.search` compatibility fix, with a mixed local retrieval configuration in the run state (`dense_plus_local_fts` in the query traces).
- This **does not** change the mobile status: no Android/iOS local LLM execution has been performed yet.

## Source and related artifacts

- Detailed source links and provider-key-name inventory:
  [`mobile_local_model_evaluation_2026-07-24.md`](../technical/mobile_local_model_evaluation_2026-07-24.md)
- Sanitized provider output: `docs/review/evidence/provider-smoke/`
- Canonical evaluated-vs-not summary used for this request:
  [mobile_model_evaluated_vs_not_authority_2026-07-24.md](mobile_model_evaluated_vs_not_authority_2026-07-24.md)
- Existing governed lineage/dataset path: `src/services/model_lineage_service.py`,
  `src/services/dataset_execution_service.py`, and `docs/MODEL_TRAINING_PLAN.md`.
