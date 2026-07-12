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
| DeepSeek-OCR | Ollama, 3.3B | OCR-VLM | Requires provider-specific adapter evaluation |
| Gemma 3 4B / 12B | Ollama, multimodal | Extraction reviewer / image fallback candidate | 4B is the only local Gemma candidate worth a second evaluation round |
| Qwen2.5-VL 7B | Ollama, multimodal | OCR/VLM baseline | Too slow as a default OCR path |
| Unlimited-OCR / olmOCR / PaddleOCR-VL | Not installed | GPU-oriented long-document/document-parsing candidates | Research only; not compatible with the launch machine as a drop-in service |

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

## Candidate landscape

| Candidate | Relevant update | What it is good at | Constraint / decision |
| --- | --- | --- | --- |
| Gemma 3 / Gemma 3n | Gemma 3n became available June 26, 2025 | Multimodal review, multilingual extraction, on-device oriented variants | Not a dedicated OCR engine. Keep Gemma 3 4B for a bounded post-OCR field-review experiment, not raw document parsing. |
| OLM OCR | July/August 2025 releases improved speed, retries, rotation, and blank-page hallucinations | Clean Markdown, reading order, headers/footers, tables | Official local inference requires recent NVIDIA GPU, 12GB+ VRAM and ~30GB disk. Not an Apple Silicon launch service. |
| PaddleOCR 3.1 / PaddleOCR-VL | PP-OCRv5 arrived July 2025; later VL releases add document parsing | Traditional OCR plus layout/table parsing | Benchmark in an isolated environment only. The full VL serving image is large; known reading-order issues must be part of acceptance tests. |
| DeepSeek-OCR | October 2025 | OCR and visual-text compression research | The installed Ollama wrapper is not a drop-in transcription API. Evaluate only with the model's supported prompt/template and a realistic scan corpus. |
| Unlimited-OCR | June 2026; official project June 22, 2026 | One-shot long-document parsing, multi-page work | Official inference recipe targets CUDA/NVIDIA/vLLM or SGLang and pins a modern CUDA/PyTorch stack. Do not place it in the App Runner image or declare it launch-ready on this Mac. |
| Docling | Ongoing actively maintained parser | Commercially friendly layout/table conversion | Best first parser experiment because it is MIT and already has an opt-in seam. Its actual package is not installed here. |
| Marker / Surya / MinerU | Ongoing 2025–26 updates | Complex PDF structure / OCR | Licensing and dependency weight require legal and operational review before product use; no selection without a corpus benchmark. |

## Architecture: model, pipeline, and data layer

```
Digital PDF ──> PyMuPDF text quality gate ──> canonical extraction + validation
                       │
                       └── empty/low-quality only ──> mobile ML Kit (offline)
                                                   or server OCR parser benchmark winner
                                                        │
                                                        └── field validation + provenance
                                                             └── RAG index / summary
```

- **Model:** choose OCR/VLM only after benchmark evidence; never accept its
  answer as a policy fact.
- **Pipeline:** retain per-page source coordinates, page number, model version,
  runtime, duration, failure/retry state, and a content hash. Avoid a second
  shadow OCR service.
- **Data/config:** version the fixture manifest, truth labels, insurer
  normalization table, validation rules, prompt version, thresholds, and model
  profile. Customer policy text must not be copied into benchmark reports.

## Launch recommendation

1. Ship the deterministic digital-PDF path only once identity, durable storage,
   deletion, and deployed API gates are complete.
2. Treat image-only uploads as a clearly labelled beta/recovery flow until the
   next benchmark passes; never silently claim equivalent accuracy.
3. Run Gemma 3 4B as a **post-extraction structured reviewer** against a
   30-document, consented or synthetic corpus. Measure exact field accuracy,
   false positives, provenance/page accuracy, p50/p95 latency, RAM, and
   refusal/timeout behavior.
4. Build a separate GPU benchmark lane for OLM OCR, PaddleOCR-VL,
   DeepSeek-OCR-native, and Unlimited-OCR. It should not delay the privacy-safe
   launch path or be merged into the production container without results.

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
- [DeepSeek-OCR technical report](https://arxiv.org/abs/2510.18234)
- [Baidu: Unlimited-OCR repository](https://github.com/baidu/Unlimited-OCR)
- [Baidu: Unlimited-OCR technical report](https://arxiv.org/abs/2606.23050)
- [Docling repository](https://github.com/docling-project/docling)
