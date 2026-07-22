# Local document intelligence evaluation — 2026-07-12

## Decision

CoverWise will retain a deterministic **PyMuPDF-first** path for digital PDFs.
No vision model is a replacement for it: on the local launch machine it is
instant and exact for embedded policy text, while the tested VLMs take 19–77
seconds per simple page. OCR/VLM use is a conditional recovery path for
image-only or quality-gated failures, never the default path.

This review covers candidates released or materially updated from June 2025
onward, plus Gemma 3 because it was explicitly requested and is installed.
It distinguishes source claims, installed-machine tests, and untested
candidates. It does not claim field-level insurance accuracy from a one-page
synthetic fixture.

## Current machine inventory

| Component | Present | Role | Launch status |
| --- | --- | --- | --- |
| PyMuPDF | Yes | Embedded-text extraction | Keep as primary fast path |
| doctr | Yes | Existing server OCR fallback | Keep until a benchmark justifies replacement |
| Google ML Kit | Mobile dependency | Offline, on-device image/PDF fallback | Keep as mobile recovery option |
| Docling / PaddleOCR / RapidOCR | No | Layout/OCR candidates | Do not add to production image before benchmark |
| Surya 2 | Isolated local tool environment | OCR, layout, reading order, tables | Apple-Silicon run completed; leading local scan candidate pending corpus benchmark |
| DeepSeek-OCR | Ollama, 3.3B | OCR-VLM | Requires provider-specific adapter evaluation |
| Gemma 3 4B / 12B | Ollama, multimodal | Extraction reviewer / image fallback candidate | 4B is the only local Gemma candidate worth a second evaluation round |
| Qwen2.5-VL 7B | Ollama, multimodal | OCR/VLM baseline | Too slow as a default OCR path |
| Unlimited-OCR / olmOCR / PaddleOCR-VL | Not installed | Long-document/document-parsing candidates | Benchmark separately; only PaddleOCR has an Apple-local traditional OCR option |

## Direct local evaluation

Fixture: `tests/test_data/sample_insurance.pdf` (one synthetic page, SHA-256
`04ce43931d0d8af97b6c81499d17ed192f1191463297be016452bca612082af2`).
The evaluator rendered the page at 150 DPI and required both `Insurance
Policy` and `#12345`. It stored no document text.

| Engine / model | Both tokens found | Measured elapsed time | Interpretation |
| --- | ---: | ---: | --- |
| PyMuPDF embedded text | Yes | <0.001s | Correct canonical fast path |
| Gemma 3 4B (Ollama Q4) | Yes | 19.027s | Viable *candidate* only after quality-gated scan benchmark |
| Gemma 3 12B (Ollama Q4) | Yes | 40.217s | No accuracy advantage on this fixture; do not make default |
| Qwen2.5-VL 7B (Ollama Q4) | Yes | 77.441s | Far too slow for routine policy ingestion on this machine |
| DeepSeek-OCR 3.3B (Ollama) | No, empty output | 65.321s | Generic `/api/generate` image prompt is not a compatible adapter; do not interpret as model-quality failure |

Evidence reports:

- `docs/review/evidence/local-model-eval/sample-policy-vlm-2026-07-12.json`
- `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json`
- `docs/review/evidence/local-model-eval/deepseek-ocr-diagnostic-2026-07-12.json`

The reusable runner is `tools/evaluate_local_document_models.py`. It records
timing and expected-token checks by default; `--include-text` is deliberately
opt-in and must only be used with synthetic or explicitly authorized policy
documents.

## Candidate landscape and deployment reality

The machine is an Apple M3 Max with 96 GB unified memory.  That makes local
Metal/llama.cpp inference viable, but does **not** make CUDA/vLLM-only recipes
Apple-native.  A Hugging Face credential was checked without sending a policy;
it can download public weights but is not consent to send a customer's policy
to any hosted endpoint.

| Candidate | Evidence | Fit for this product | Decision |
| --- | --- | --- | --- |
| **PyMuPDF** | Installed; direct local evaluation succeeds in under 1 ms on embedded text | Exact digital-PDF text with page provenance | Canonical primary path. No OCR/VLM may replace it. |
| **Surya 2** | Installed in `.local-tools/surya-eval`; native llama.cpp/Metal run recovered both required synthetic-policy tokens | Single 650M document OCR/layout/table model; Apple Silicon backend is officially supported | First local scan-parser candidate. Benchmark on the corpus before wiring into the server. Code Apache-2; weights OpenRAIL-M requires business/license check. |
| **Docling** | Officially supports macOS arm64, local execution, PDF layout/reading order/tables/OCR; MIT code | Best open, structured conversion candidate and can yield lossless JSON/Markdown | Second local candidate. Install/evaluate in the same isolated tool lane, not the API image. Check each bundled model's licence separately. |
| **PaddleOCR 3.7 / PP-OCRv6** | Official project supports macOS and CPU; current tiny/small/medium traditional OCR models are designed for edge/server deployment | Good deterministic multilingual OCR fallback; 0.9B PaddleOCR-VL adds structure but is a separate heavier model | Benchmark PP-OCRv6 first locally. Treat PaddleOCR-VL as a benchmark candidate, not a default server dependency. |
| **MinerU** | Structured Markdown/JSON, scans and multi-column/table support | Serious parser candidate, but operational/model licensing and dependency surface need review | GPU/isolated benchmark lane only until licence and Mac runtime are validated. |
| **olmOCR 2** | 7B document VLM; official benchmark covers 7,000+ tests/1,400 docs | Strong Markdown and complex-layout candidate | Not local-Mac launch software: official local recipe requires a recent NVIDIA GPU with 12 GB+ VRAM and 30 GB disk. Use only on an approved private GPU later. |
| **Unlimited-OCR** | Current Baidu project targets one-shot long-horizon parsing | Appropriate research comparison for long multipage schedules | CUDA 12.9/NVIDIA Transformers, CUDA Docker vLLM, or SGLang recipe only. It is not a valid M3 local implementation today. |
| **DeepSeek-OCR / OCR2** | Installed Ollama wrapper returned empty output; upstream DeepSeek-OCR requires CUDA/vLLM/Transformers-native template | Potential GPU OCR research candidate, not a generic chat endpoint | Do not mislabel the failed generic adapter as a model result. Native evaluation belongs on an approved CUDA worker. |
| **Qwen3-VL 2B/4B/8B** | Current Apache-2 Qwen series; 2B/4B/8B releases exist | Flexible visual reviewer / schema extraction after OCR | Benchmark a quantized 4B variant as a reviewer, not as first-pass OCR. Existing Qwen2.5-VL 7B timing (77 s/page) rules it out as default. |
| **Gemma 3 4B** | Installed; 19 s synthetic page result | Bounded post-OCR structured review | Retain as one reviewer baseline only. It is not the OCR architecture. |
| **Marker** | Works on MPS and can use Surya; GPL-3 code and OpenRAIL-M weights | Technically capable | Exclude from product default pending commercial licence decision. Its optional LLM mode must never default to Gemini for a sensitive policy. |

### What was actually tested locally

In addition to the earlier Ollama timing evaluation, Surya 2 was installed in
an isolated `.local-tools/surya-eval` environment. Its official 650M GGUF
weights were downloaded through the authenticated local Hugging Face account,
then it used the already-installed `llama-server` with Metal acceleration. It
processed only `tests/test_data/sample_insurance.pdf`; the check stored no
fixture text and confirmed that `Insurance Policy` and `#12345` were both in
the resulting JSON. The temporary llama-server was stopped after the run.

This is Tier 2 evidence (targeted local test), not a claim of insurance-field
accuracy or a production benchmark. The encrypted real policy has deliberately
not been sent to any model or OCR service.

## Architecture: model, pipeline, and data layer

```
Encrypted PDF ──> request-scoped password gate ──> decrypt in memory only
                                                  │
Digital PDF ─────────────────────────────────────┴─> PyMuPDF text quality gate
                                                            │
                    empty/low-quality scanned pages ───────┴─> selected local OCR parser
                                                                    │
                                                                    ├─> source-grounded field validation
                                                                    ├─> page/block provenance + confidence
                                                                    └─> RAG index / conditional summary
```

- **Model:** OCR converts pages; a VLM can only propose structured fields.
  Never accept either output as a policy fact without source/page validation.
- **Pipeline:** retain per-page source coordinates, page number, model version,
  runtime, duration, failure/retry state, and a content hash. Avoid a second
  shadow OCR service. The API needs one `DocumentProcessor` profile selection,
  not separate Surya/Paddle/Docling upload routes.
- **Data/config:** version the fixture manifest, truth labels, insurer
  normalization table, validation rules, prompt version, thresholds, and model
  profile. Customer policy text must not be copied into benchmark reports.

## Launch recommendation

1. Ship the deterministic digital-PDF path only once identity, durable storage,
   deletion, and deployed API gates are complete.
2. Treat image-only uploads as a clearly labelled beta/recovery flow until the
   next benchmark passes; never silently claim equivalent accuracy.
3. Benchmark **Surya 2, Docling, and PP-OCRv6** locally against the same
   30-document, consented-or-synthetic corpus. Measure exact field accuracy,
   false positives, provenance/page accuracy, p50/p95 latency, memory, and
   refusal/timeout behavior. Select one canonical local scan profile.
4. Run Gemma 3 4B and Qwen3-VL 4B only as post-extraction structured reviewers
   against that corpus; neither may fill a missing value without evidence.
5. Build a separate approved-GPU benchmark lane for olmOCR, PaddleOCR-VL,
   DeepSeek-OCR-native, MinerU, and Unlimited-OCR. It must not delay the
   privacy-safe local launch path or be merged into the production container
   without results and a data-residency decision.

## Evaluation acceptance contract

No local parser becomes a production default until it passes, on a versioned
Indian-policy corpus with expected values and page references:

- policy number exact match >= 99%; dates/amounts >= 98%; insurer canonical
  match >= 99%; and no ungrounded value may overwrite a source value;
- image-only scans, digital PDFs, rotated/low-quality pages, multi-column
  schedules, tables, Hindi/English pages, and blank pages represented;
- p95 end-to-end ingestion under the agreed product budget, with no unbounded
  retry; timeout and partial-success outcomes retained for the operator;
- model outputs carry page provenance and confidence; low-confidence fields
  are marked unknown rather than guessed;
- benchmark artifacts contain hashes and labels, not customer source text;
- license, model terms, weights, operational GPU/RAM, and data residency have
  explicit owner approval.

## Primary sources

- [Google / Hugging Face: Gemma 3n](https://huggingface.co/blog/gemma3n)
- [Google / Hugging Face: Gemma 3](https://huggingface.co/blog/gemma3)
- [AllenAI: olmOCR repository and benchmark](https://github.com/allenai/olmocr)
- [PaddleOCR repository](https://github.com/PaddlePaddle/PaddleOCR)
- [Surya repository and Apple-Silicon backend](https://github.com/VikParuchuri/surya)
- [Qwen3-VL repository](https://github.com/QwenLM/Qwen3-VL)
- [DeepSeek-OCR technical report](https://arxiv.org/abs/2510.18234)
- [Baidu: Unlimited-OCR repository](https://github.com/baidu/Unlimited-OCR)
- [Baidu: Unlimited-OCR technical report](https://arxiv.org/abs/2606.23050)
- [Docling repository](https://github.com/docling-project/docling)

## Addendum (2026-07-21) — catalog reconciliation and capability-router decision

The attached local catalog was inspected on 2026-07-21: 149 entries across
full parsers, OCR/layout/table specialists, forms/KVP, formulas, office/web
formats, recent document models, and a separate general-VLM list. This expands
the candidate map without changing the local evidence boundary. The only
CoverWise model results in this file remain the explicitly measured synthetic
fixture results; workbook/vendor scores are research claims until reproduced on
the versioned CoverWise corpus.

The capability conclusion is broader than the current launch baseline but more
disciplined than “pick the best VLM”: retain PyMuPDF/native parsing for digital
inputs, use OCR/layout recovery for quality-gated scans, add dedicated table,
form, formula, figure, and handwriting profiles, and normalize all outputs to
one source-preserving CIR before policy extraction. Docling is the first broad
local CIR candidate; Surya and PaddleOCR/PP-Structure are scan/layout
benchmarks; MinerU, Marker, managed providers, and GPU-first VLMs remain
isolated profiles pending evidence and license/privacy/runtime review.

This addendum also corrects two stale assumptions found during code review:
`src/ocr/pipeline.py` already performs image preprocessing, and its optional
Docling/MinerU branches do not yet constitute a full table/figure/formula/
provenance contract. The same file imports doctr eagerly even though the
surrounding configuration describes OCR as optional; this is an explicit
hardening item before claiming that missing OCR dependencies cannot prevent API
startup.

See `docs/technical/document_intelligence_capability_matrix_2026-07-21.md` for
the capability matrix and
`docs/decisions/ADR-2026-07-21-05-document-intelligence-router-and-evidence-contract.md`
for the derived architecture decision.

## Addendum (2026-07-21) — correction to optional-import status

The earlier sentence in this addendum describing an eager doctr import is now
historical. `src/ocr/pipeline.py` defers the doctr import until
`OCRPipeline` construction; module import was verified without doctr, while
actual scan execution still requires the local OCR dependency or the mobile
sidecar. The remaining evidence gap is runtime scan behavior, not API module
startup.

## Addendum (2026-07-21) — CIR/runtime implementation evidence

The first implementation slice is now present in
`src/models/document_intelligence.py`. Native text, mobile sidecar, Docling,
and local OCR results can carry a versioned page/text/artifact CIR while legacy
keys remain available to existing callers. The doctr import is deferred until
OCR construction, so a slim API can import the pipeline module and return a
truthful OCR-unavailable state only when a scan actually needs it.

Targeted backend verification passed the CIR/runtime, OCR, mobile, and evidence
paths. This is Tier 2 evidence. Persisted CIR-to-source-span resolution,
real multi-page Docling output, and specialist table/formula/form adapters
remain Tier 3 gates.

The reusable capability manifest subsequently ran its generated doctr scan
case successfully: `Health Policy`, `500000`, and `POLICY-TEST-001` were all
recovered in 2.314 seconds. The report is
`docs/review/evidence/local-model-eval/document-capability-manifest-2026-07-21.json`;
it contains hashes and metrics, not source text. This remains Tier 2 synthetic
evidence, not an insurance-corpus accuracy claim.

## Addendum (2026-07-12) — current model discovery and encrypted inputs

An authenticated Hugging Face credential was validated from the local machine
without sending a customer document. Current registry discovery confirms newer
document/OCR candidates including PaddleOCR-VL 1.5/1.6 and Qwen3-VL variants.
They remain scan-recovery candidates to benchmark against a consented corpus;
they do not replace PyMuPDF for digital PDFs and cannot decrypt a
password-protected policy.

The upload pipeline now accepts a request-scoped PDF password. It validates the
encrypted PDF before object or metadata persistence, does not retain the
password, and uses it only while PyMuPDF extracts text. This makes a real
encrypted policy test possible once its owner supplies the password, while
keeping the benchmark/report contract free of policy text.

## Addendum (2026-07-12) — mobile-first OCR boundary

The deployment target is the Android/iOS application, not the developer's
Apple-Silicon laptop. The mobile product baseline is therefore **Google ML Kit
on Android and iOS through native platform SDKs**, not Surya, Unlimited-OCR,
or a desktop-hosted VLM.

The app now exposes an explicit `Read scanned pages on this device` control
for native uploads. When selected, it creates an in-memory ML Kit text
sidecar and uploads it **alongside the unchanged original PDF or image**. The
server keeps direct PDF text authoritative. It uses the mobile sidecar only
when the original contains no embedded text, labels the extraction method and
provenance, and never stores OCR text in upload metadata. The password path
remains server-side: encrypted PDFs are not rendered on device before the
user's request-scoped password is validated.

This prevents the old incorrect behavior where every PDF was OCR-rendered and
the original source was silently replaced with a `.txt` upload. It also makes
the product limitation explicit: mobile text recognition is an OCR recovery
feature, not a table/layout parser or an insurance decision model. Advanced
document VLMs (Surya, PaddleOCR-VL, olmOCR, Unlimited-OCR) remain optional
server/GPU benchmark candidates and must not be implied to run inside a
standard Android or iOS app binary. The native control currently offers
English/Latin and Hindi/Devanagari recognizers; the user selects the document
script so the app does not silently apply an English-only model to a Hindi
policy.
