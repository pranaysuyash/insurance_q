# Embedding model benchmark — 2026-07-19T03:35:29.348342+00:00

- Policies sampled: 50
- Queries per policy: 20
- Decision: **STRONG_KEEP_SMALL**

## Rationale

small recall@3 (0.583) exceeds voyage_3 recall@3 (0.417) by 0.167. Recommend keeping small.

## Results

| Model | Dimensions | recall@3 | Queries hit | Total | Duration |
|---|---|---|---|---|---|
| openai_text_embedding_3_small | 1536 | 0.583 | 7 | 12 | 0.0s |
| voyage_3 | 1024 | 0.417 | 5 | 12 | 0.0s |

## Files

- `summary.json`: the decision-grade numbers (machine-readable)
- `per_query.jsonl`: per-(policy, query) results
- `per_chunk_predictions/`: the top-3 predictions per model

## Next steps

1. Review the rationale. If the decision is SWITCH_TO_VOYAGE_3, follow the migration plan in docs/decisions/ADR-2026-07-19-03.
2. If the decision is KEEP_SMALL or STRONG_KEEP_SMALL, no action is needed; the default stays text-embedding-3-small.
3. Re-run the benchmark every 6 months, or whenever the model lineup changes.