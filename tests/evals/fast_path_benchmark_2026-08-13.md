# fast_path Latency Benchmark (#47) — 2026-08-13

**Scope.** This benchmark measures the **retrieval-augmentation orchestration
step only** (`RAGPipeline._augment_query_augmentation`), with the discretionary
generators stubbed to run instantly. It does **not** measure end-to-end
`query_rag` latency, because that also depends on the embedding model and the
answer LLM, which require a network/local embedder we cannot run offline in this
session.

**Evidence tier:** MEASURED for the orchestration step (real timings, `ITER=300`
per side, venv `python`); INFERRED for end-to-end (not run — see limitation).

## Result

| metric | fast_path | default | difference |
|---|---|---|---|
| discretionary chat completions | 0 | 2 | **-2** |
| p50 augmentation latency (offline, stubbed) | 0.000 ms | 0.050 ms | ~0.05 ms |

Measured with `python -m pytest tests/bench_fast_path.py -q -s` (300 iterations
per side, after a warm-up call). fast_path p50 rounds to ~0 ms because it returns
the raw query with no generator/LLM work; default does Fusion+HyDE list building
+ `asyncio.gather` overhead, hence ~0.05 ms.

## What this proves

- **VERIFIED:** fast_path makes strictly fewer chat completions (0 vs 2) — the
  latency root cause identified in #35/#47 (3 serial completions/query → 1).
- **VERIFIED:** at the orchestration level, fast_path is faster by construction
  (it skips both discretionary completions).

## Honest limitation (Confidence Honesty Standard)

- The 0.05 ms default number is **orchestration-only**. Real Fusion/HyDE calls
  are LLM round-trips (tens–hundreds of ms each), so the *true* default
  end-to-end latency is dominated by those network calls, not by the ~0.05 ms
  Python orchestration. A faithful end-to-end p50 requires an **offline embedder
  + local LLM** (e.g. Ollama path already supported by the backend) so no network
  is touched. That benchmark was deliberately **not faked** here.
- To get real end-to-end numbers, point `OPENAI_EMBEDDING_MODEL` /
  `OPENAI_CHAT_MODEL` at Ollama and extend `bench_fast_path.py` to time
  `query_rag(..., fast_path=True/False)` over a tiny in-memory corpus
  (reuse `live_fixture.build_live_pipeline_from_pdf`).

## Anything else?

The headline regression guarantee (fast_path skips the two discretionary chat
completions) is already locked by `tests/test_fast_path_augmentation.py`; this
file adds the latency measurement on top. No code under
tools/scrape_policy_corpus.py, tests/evals/live_fixture.py,
tools/author_global_dataset.py, or tools/global_dataset_specs.json was modified.
