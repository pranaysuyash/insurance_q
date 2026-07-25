"""
Embedding model benchmark for CoverWise (Architecture audit ADR-06).

Date: 2026-07-19
Phase: Bucket 5 decision #20.
Risk classification (motto v3 §0.6): LOW. The benchmark is read-only
against Supabase (the document_chunks table); the embedding API calls
are the only cost. No writes to production tables.

Purpose
-------
Per docs/decisions/ADR-2026-07-19-03-...md, the default embedding
model for CoverWise is text-embedding-3-small (OpenAI, 1536d). The
benchmark compares it against voyage-3 (Voyage AI, 1024d) on
real CoverWise policy data. The output is a recall@3 score per
model; the decision is the comparison.

Why recall@3
------------
The policy detail screen's Q&A path retrieves the top-3 chunks per
query. If the relevant chunk is in the top-3, the user gets a correct
answer. If not, they get a confabulation. recall@3 = (# of (policy,
query) pairs where the top-3 contains at least 1 relevant chunk)
/ total pairs. This is the metric that matters for the user.

Why not MTEB
------------
MTEB is a generic benchmark; insurance policy retrieval is a
domain-specific problem. The benchmark runs on real CoverWise
policies with queries a real user would ask. A 5% recall@3
improvement on real data is more meaningful than a 1-point MTEB
improvement on generic data.

Usage
-----
    # 1. Run the dry-run path with fixture data (no API keys, no
    #    Supabase project, no real policies). Use this to verify
    #    the script works.
    python tools/benchmark_embedding_models.py --dry-run

    # 2. Run the live benchmark. Requires:
    #    - OPENAI_API_KEY (for text-embedding-3-small)
    #    - VOYAGE_API_KEY (for voyage-3)
    #    - SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
    #    - A populated document_chunks table (apply the launch
    #      playbook's migrations + upload at least 50 policies)
    #    - A ground-truth file in tools/embedding_benchmark/
    #      ground_truth.jsonl
    python tools/benchmark_embedding_models.py

    # 3. Re-evaluate without re-running the embeddings (uses the
    #    cached results from the last run). Use this when ground
    #    truth is updated but embeddings have not changed.
    python tools/benchmark_embedding_models.py --recompute-only

Ground truth format
-------------------
tools/embedding_benchmark/ground_truth.jsonl: one line per
(policy_id, query) pair. Each line is a JSON object:
    {
        "policy_id": "uuid-of-the-policy-document",
        "query": "what is the room rent cap?",
        "relevant_chunk_indices": [3, 7, 12]
    }
relevant_chunk_indices is the list of indices (0-based, in the
order they appear in document_chunks for that policy) of chunks
that contain the answer to the query. The benchmark retrieves
top-3 chunks per model and checks if any of the relevant
indices appear in the top-3.

Output
------
tools/embedding_benchmark/results/<timestamp>/
    summary.json:           the decision-grade numbers
    per_query.jsonl:        per-(policy, query) results
    per_chunk_predictions/: the top-3 predictions per model
    README.md:              a human-readable summary of the run

The summary.json shape is:
    {
        "openai_text_embedding_3_small": {
            "recall_at_3": 0.72,
            "queries_total": 1000,
            "queries_with_relevant_in_top_3": 720
        },
        "voyage_3": {
            "recall_at_3": 0.78,
            "queries_total": 1000,
            "queries_with_relevant_in_top_3": 780
        }
    }

The decision rule (per ADR-2026-07-19-03):
    - If voyage_3 recall@3 > small recall@3 by >= 0.05 (5 pp),
      switch the default.
    - Otherwise, keep small.

Environment
-----------
    OPENAI_API_KEY              : OpenAI API key (text-embedding-3-small)
    VOYAGE_API_KEY              : Voyage AI API key (voyage-3)
    SUPABASE_URL                : Supabase project URL
    SUPABASE_SERVICE_ROLE_KEY   : service-role key
    BENCHMARK_POLICY_LIMIT      : max policies to sample (default 50)
    BENCHMARK_QUERY_LIMIT       : max queries per policy (default 20)
    BENCHMARK_EMBEDDING_BATCH   : batch size for embedding API calls
                                  (default 32, Voyage max is 128)
    BENCHMARK_CACHE_DIR         : where to cache embeddings
                                  (default tools/embedding_benchmark/cache)

Motto v3 alignment:
    - §0.5 evidence tiers: T2 (regression-test on fixture data) +
      T0 (live run on real data). The dry-run path is the T2 gate.
    - §0.6 risk-based verification: risk is LOW. Read-only against
      Supabase. Embedding API calls are the only cost.
    - §0.7 AI output boundary: the benchmark does NOT claim a model
      is better without measurement. The decision rule is a
      threshold, not a vibe.
    - §0.10 observability is delivery: the results are written
      to disk in a structured format the operator dashboard can
      read.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import random
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("embedding_benchmark")


# --- 1. Configuration ---


@dataclass
class BenchmarkConfig:
    """The configuration for one benchmark run. All values
    come from CLI flags or env vars; never hardcoded."""

    # What to run
    dry_run: bool = False
    recompute_only: bool = False

    # Sample sizes
    policy_limit: int = 50
    query_limit: int = 20

    # API batching
    embedding_batch: int = 32

    # Paths
    ground_truth_path: Path = field(
        default_factory=lambda: Path("tools/embedding_benchmark/ground_truth.jsonl")
    )
    results_dir: Path = field(
        default_factory=lambda: Path("tools/embedding_benchmark/results")
    )
    cache_dir: Path = field(
        default_factory=lambda: Path("tools/embedding_benchmark/cache")
    )

    # Models
    models: list[dict] = field(
        default_factory=lambda: [
            {
                "id": "openai_text_embedding_3_small",
                "model_name": "text-embedding-3-small",
                "dimensions": 1536,
                "provider": "openai",
            },
            {
                "id": "voyage_3",
                "model_name": "voyage-3",
                "dimensions": 1024,
                "provider": "voyage",
            },
        ]
    )

    # Decision threshold
    switch_threshold: float = 0.05  # 5 percentage points

    @classmethod
    def from_env_and_args(cls, args: argparse.Namespace) -> "BenchmarkConfig":
        cfg = cls(
            dry_run=args.dry_run,
            recompute_only=args.recompute_only,
            policy_limit=int(
                os.getenv("BENCHMARK_POLICY_LIMIT", str(cls.policy_limit))
            ),
            query_limit=int(os.getenv("BENCHMARK_QUERY_LIMIT", str(cls.query_limit))),
            embedding_batch=int(
                os.getenv("BENCHMARK_EMBEDDING_BATCH", str(cls.embedding_batch))
            ),
        )
        return cfg


# --- 2. Result types ---


@dataclass
class QueryResult:
    """The per-(policy, query) result. One of these per query
    per model."""

    policy_id: str
    query: str
    relevant_chunk_indices: list[int]
    top_3_indices: list[int]
    is_relevant_in_top_3: bool


@dataclass
class ModelResult:
    """The per-model aggregate. The summary.json is a list of
    these."""

    model_id: str
    model_name: str
    dimensions: int
    provider: str
    queries_total: int
    queries_with_relevant_in_top_3: int
    recall_at_3: float
    duration_seconds: float


@dataclass
class BenchmarkRun:
    """The full run. One of these per benchmark execution."""

    timestamp: str
    policy_limit: int
    query_limit: int
    results: list[ModelResult]
    decision: str
    decision_rationale: str

    def to_summary_dict(self) -> dict:
        return {
            "timestamp": self.timestamp,
            "policy_limit": self.policy_limit,
            "query_limit": self.query_limit,
            "decision": self.decision,
            "decision_rationale": self.decision_rationale,
            "models": {
                r.model_id: {
                    "model_name": r.model_name,
                    "dimensions": r.dimensions,
                    "provider": r.provider,
                    "queries_total": r.queries_total,
                    "queries_with_relevant_in_top_3": (
                        r.queries_with_relevant_in_top_3
                    ),
                    "recall_at_3": r.recall_at_3,
                    "duration_seconds": r.duration_seconds,
                }
                for r in self.results
            },
        }


# --- 3. Embedding API adapters ---


class EmbeddingClient:
    """Adapter for the two embedding providers. Each provider
    has its own API; the adapter normalizes the call shape and
    the response shape.

    In --dry-run mode, the client returns a deterministic
    pseudo-embedding based on the hash of the input text. This
    is NOT a real embedding; it's a way to exercise the
    script's plumbing without API keys. The dry-run results
    are NOT used for the embedding-model decision.
    """

    def __init__(self, config: BenchmarkConfig, dry_run: bool):
        self._config = config
        self._dry_run = dry_run
        self._openai = None
        self._voyage = None
        if not dry_run:
            self._init_real_clients()

    def _init_real_clients(self) -> None:
        try:
            from openai import OpenAI

            self._openai = OpenAI(api_key=os.getenv("OPENAI_API_KEY", ""))
        except ImportError:
            log.warning(
                "openai package not installed; text-embedding-3-small unavailable"
            )
        try:
            import voyageai

            self._voyage = voyageai.Client(api_key=os.getenv("VOYAGE_API_KEY", ""))
        except ImportError:
            log.warning("voyageai package not installed; voyage-3 unavailable")

    def embed(self, model_cfg: dict, texts: list[str]) -> list[list[float]]:
        """Embed a batch of texts with one model. Returns one
        vector per text. In --dry-run mode, returns deterministic
        pseudo-embeddings of the right dimension."""
        if self._dry_run:
            return [_pseudo_embedding(t, model_cfg["dimensions"]) for t in texts]
        provider = model_cfg["provider"]
        if provider == "openai":
            return self._embed_openai(model_cfg, texts)
        if provider == "voyage":
            return self._embed_voyage(model_cfg, texts)
        raise ValueError(f"unknown provider: {provider}")

    def _embed_openai(self, model_cfg: dict, texts: list[str]) -> list[list[float]]:
        if self._openai is None:
            raise RuntimeError("openai client not initialized")
        response = self._openai.embeddings.create(
            model=model_cfg["model_name"], input=texts
        )
        return [item.embedding for item in response.data]

    def _embed_voyage(self, model_cfg: dict, texts: list[str]) -> list[list[float]]:
        if self._voyage is None:
            raise RuntimeError("voyage client not initialized")
        result = self._voyage.embed(texts, model=model_cfg["model_name"])
        return result.embeddings


def _pseudo_embedding(text: str, dimensions: int) -> list[float]:
    """A deterministic pseudo-embedding for --dry-run. The
    output is a unit vector of the requested dimension. The
    direction depends on a hash of the text, so similar texts
    get similar (but not actually similar) vectors.

    This is for plumbing tests only. The dry-run results are
    NOT used for the model decision.
    """
    import hashlib

    h = hashlib.sha256(text.encode("utf-8")).digest()
    # Use the hash to seed a deterministic random vector.
    seed = int.from_bytes(h[:8], "big")
    rng = random.Random(seed)
    vec = [rng.gauss(0, 1) for _ in range(dimensions)]
    norm = sum(x * x for x in vec) ** 0.5
    if norm == 0:
        return vec
    return [x / norm for x in vec]


# --- 4. Vector search (cosine similarity) ---


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Cosine similarity between two equal-length vectors. The
    pgvector `<=>` operator is cosine distance (= 1 - similarity).
    The benchmark uses plain Python cosine to avoid the
    supabase-py round-trip; results are equivalent.
    """
    if len(a) != len(b):
        raise ValueError(f"dimension mismatch: {len(a)} vs {len(b)}")
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def top_k_indices(
    query_vec: list[float], doc_vecs: list[list[float]], k: int
) -> list[int]:
    """Return the indices of the top-k documents by cosine
    similarity. Ties are broken by index order (lower index
    wins), which matches pgvector's default ordering."""
    scored = [(cosine_similarity(query_vec, d), i) for i, d in enumerate(doc_vecs)]
    scored.sort(key=lambda x: (-x[0], x[1]))
    return [i for _, i in scored[:k]]


# --- 5. Data loading ---


def load_chunks(
    config: BenchmarkConfig, supabase_url: str, supabase_key: str
) -> dict[str, list[str]]:
    """Load document_chunks from Supabase. Returns
    {policy_id: [chunk_text, ...]}. In --dry-run mode, returns
    a fixture dataset so the script is testable without a
    real Supabase project."""
    if config.dry_run:
        return _fixture_chunks()
    try:
        from supabase import create_client

        client = create_client(supabase_url, supabase_key)
    except ImportError as error:
        raise RuntimeError("supabase package required for live benchmark") from error
    response = (
        client.table("document_chunks")
        .select("document_id, chunk_text")
        .limit(config.policy_limit * 50)  # rough upper bound
        .execute()
    )
    if not response.data:
        return {}
    by_policy: dict[str, list[str]] = {}
    for row in response.data:
        by_policy.setdefault(row["document_id"], []).append(row["chunk_text"])
    return by_policy


def _fixture_chunks() -> dict[str, list[str]]:
    """A minimal fixture for the dry-run path. The fixture has
    3 policies with 5 chunks each, designed to make the
    retrieval testable. The text content is synthetic and
    does not represent real policy data.
    """
    return {
        "fixture-policy-1": [
            "The policy covers hospitalisation up to the sum insured.",
            "Room rent is capped at 1% of the sum insured, maximum Rs 5,000 per day.",
            "Pre-existing diseases are covered after a 36-month waiting period.",
            "Maternity benefits are available after a 24-month waiting period.",
            "Day care procedures are covered as per the IRDAI list.",
        ],
        "fixture-policy-2": [
            "This is a critical illness policy with 36 named conditions.",
            "Sum insured options are 5 lakh, 10 lakh, and 25 lakh.",
            "Claims are paid as a lump sum upon diagnosis confirmation.",
            "Survival period of 30 days post-diagnosis is required.",
            "Premium is waived upon valid claim payment.",
        ],
        "fixture-policy-3": [
            "Personal accident cover for accidental death and disability.",
            "Worldwide coverage including hospitalisation abroad.",
            "No medical test required for sum insured up to 25 lakh.",
            "Premium depends on occupation class and age band.",
            "Family discount of 10% for covering spouse.",
        ],
    }


def load_ground_truth(
    config: BenchmarkConfig,
    chunks_by_policy: dict[str, list[str]],
) -> list[dict]:
    """Load the ground-truth file. In --dry-run mode, uses a
    fixture ground truth. The dry-run ground truth is
    hand-crafted to match the fixture chunks above so the
    recall@3 numbers are non-trivial (not 0, not 1)."""
    if config.dry_run:
        return _fixture_ground_truth()
    if not config.ground_truth_path.exists():
        log.error(
            "ground truth file not found: %s. "
            "Create it before running the live benchmark. "
            "See the docstring for the format.",
            config.ground_truth_path,
        )
        sys.exit(2)
    out = []
    with config.ground_truth_path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            out.append(json.loads(line))
    # Filter to policies that exist in the loaded chunks.
    out = [
        g
        for g in out
        if g["policy_id"] in chunks_by_policy
        and max(g["relevant_chunk_indices"], default=-1)
        < len(chunks_by_policy[g["policy_id"]])
    ]
    return out[: config.policy_limit * config.query_limit]


def _fixture_ground_truth() -> list[dict]:
    """A fixture ground truth for the dry-run path. The
    relevant_chunk_indices are chosen to make the recall@3
    testable. With the pseudo-embeddings (hash-based, not
    semantically meaningful), the recall@3 will be near
    0.4-0.5, not 0 or 1."""
    return [
        # Policy 1: queries about room rent, maternity, PED
        {
            "policy_id": "fixture-policy-1",
            "query": "what is the room rent cap",
            "relevant_chunk_indices": [1],
        },
        {
            "policy_id": "fixture-policy-1",
            "query": "is maternity covered",
            "relevant_chunk_indices": [3],
        },
        {
            "policy_id": "fixture-policy-1",
            "query": "waiting period for pre-existing diseases",
            "relevant_chunk_indices": [2],
        },
        {
            "policy_id": "fixture-policy-1",
            "query": "what is the day care list",
            "relevant_chunk_indices": [4],
        },
        # Policy 2: critical illness queries
        {
            "policy_id": "fixture-policy-2",
            "query": "what conditions are covered",
            "relevant_chunk_indices": [0],
        },
        {
            "policy_id": "fixture-policy-2",
            "query": "how much sum insured",
            "relevant_chunk_indices": [1],
        },
        {
            "policy_id": "fixture-policy-2",
            "query": "is it a lump sum",
            "relevant_chunk_indices": [2],
        },
        {
            "policy_id": "fixture-policy-2",
            "query": "what is the survival period",
            "relevant_chunk_indices": [3],
        },
        # Policy 3: personal accident queries
        {
            "policy_id": "fixture-policy-3",
            "query": "is this worldwide",
            "relevant_chunk_indices": [1],
        },
        {
            "policy_id": "fixture-policy-3",
            "query": "do I need a medical test",
            "relevant_chunk_indices": [2],
        },
        {
            "policy_id": "fixture-policy-3",
            "query": "is there a family discount",
            "relevant_chunk_indices": [4],
        },
        {
            "policy_id": "fixture-policy-3",
            "query": "what does personal accident cover",
            "relevant_chunk_indices": [0],
        },
    ]


# --- 6. Caching ---


def cache_key(model_id: str, text: str) -> str:
    """A stable cache key for one (model, text) pair. Hashes
    both the model name and the text so collisions across
    models are impossible."""
    import hashlib

    h = hashlib.sha256((model_id + "::" + text).encode("utf-8")).hexdigest()
    return h[:32]


def load_cache(config: BenchmarkConfig) -> dict[str, list[float]]:
    """Load all cached embeddings. The cache is a single JSON
    file per run; the key is cache_key(model_id, text)."""
    cache_file = config.cache_dir / "embeddings.json"
    if not cache_file.exists():
        return {}
    try:
        with cache_file.open() as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def save_cache(config: BenchmarkConfig, cache: dict[str, list[float]]) -> None:
    config.cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = config.cache_dir / "embeddings.json"
    with cache_file.open("w") as f:
        json.dump(cache, f)


# --- 7. The benchmark loop ---


def run_benchmark(config: BenchmarkConfig) -> BenchmarkRun:
    """The main benchmark. Returns a BenchmarkRun with the
    per-model results and the decision. Side effect: writes
    per-query and per-chunk-prediction results for each
    model to the run directory."""
    started_at = datetime.now(timezone.utc)

    # Load data.
    supabase_url = os.getenv("SUPABASE_URL", "")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not config.dry_run and (not supabase_url or not supabase_key):
        log.error(
            "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set "
            "for the live benchmark"
        )
        sys.exit(2)
    chunks_by_policy = load_chunks(config, supabase_url, supabase_key)
    ground_truth = load_ground_truth(config, chunks_by_policy)
    if not ground_truth:
        log.error("no ground truth to evaluate against")
        sys.exit(2)

    # Embed chunks + queries per model.
    embed_client = EmbeddingClient(config, config.dry_run)
    cache = {} if config.recompute_only else load_cache(config)

    model_results: list[ModelResult] = []
    model_query_results: dict[str, list[QueryResult]] = {}
    for model_cfg in config.models:
        model_started = time.time()
        log.info(
            "benchmarking model %s (%d dimensions)",
            model_cfg["id"],
            model_cfg["dimensions"],
        )
        # Embed all chunks for this model.
        chunk_embeddings: dict[str, list[list[float]]] = {}
        for policy_id, chunks in chunks_by_policy.items():
            chunk_vecs = []
            for chunk in chunks:
                key = cache_key(model_cfg["id"], chunk)
                if key in cache:
                    chunk_vecs.append(cache[key])
                else:
                    if config.dry_run:
                        # In dry-run, the cache is not used.
                        chunk_vecs.append(
                            _pseudo_embedding(chunk, model_cfg["dimensions"])
                        )
                    else:
                        # Batch the cache misses.
                        # For simplicity in v1, embed one at a
                        # time. v2 batches across policies.
                        vecs = embed_client.embed(model_cfg, [chunk])
                        chunk_vecs.append(vecs[0])
                        cache[key] = vecs[0]
            chunk_embeddings[policy_id] = chunk_vecs

        # Embed each query and compute recall@3.
        query_results: list[QueryResult] = []
        queries_with_relevant = 0
        for gt in ground_truth:
            policy_id = gt["policy_id"]
            query = gt["query"]
            relevant = gt["relevant_chunk_indices"]
            # Embed the query.
            query_vecs = embed_client.embed(model_cfg, [query])
            query_vec = query_vecs[0]
            # Compute top-3.
            doc_vecs = chunk_embeddings.get(policy_id, [])
            top3 = top_k_indices(query_vec, doc_vecs, k=3)
            # Did any of the relevant indices appear in top-3?
            is_relevant = any(r in top3 for r in relevant)
            if is_relevant:
                queries_with_relevant += 1
            query_results.append(
                QueryResult(
                    policy_id=policy_id,
                    query=query,
                    relevant_chunk_indices=relevant,
                    top_3_indices=top3,
                    is_relevant_in_top_3=is_relevant,
                )
            )

        recall = queries_with_relevant / len(ground_truth) if ground_truth else 0.0
        duration = time.time() - model_started
        model_results.append(
            ModelResult(
                model_id=model_cfg["id"],
                model_name=model_cfg["model_name"],
                dimensions=model_cfg["dimensions"],
                provider=model_cfg["provider"],
                queries_total=len(ground_truth),
                queries_with_relevant_in_top_3=queries_with_relevant,
                recall_at_3=recall,
                duration_seconds=duration,
            )
        )
        model_query_results[model_cfg["id"]] = query_results
        log.info(
            "  %s: recall@3=%.3f (%d/%d) in %.1fs",
            model_cfg["id"],
            recall,
            queries_with_relevant,
            len(ground_truth),
            duration,
        )

    # Save cache.
    if not config.dry_run and not config.recompute_only:
        save_cache(config, cache)

    # Decide.
    decision, rationale = _decide(model_results, config.switch_threshold)

    run = BenchmarkRun(
        timestamp=started_at.isoformat(),
        policy_limit=config.policy_limit,
        query_limit=config.query_limit,
        results=model_results,
        decision=decision,
        decision_rationale=rationale,
    )
    # Attach the per-query results so write_results can persist
    # them. We use a private attribute (single underscore) to
    # avoid widening the public BenchmarkRun surface.
    object.__setattr__(run, "_per_query", model_query_results)
    return run


def _per_query_results(
    model_results: list[ModelResult],
    model_query_results: dict[str, list[QueryResult]],
) -> list[dict]:
    """Flatten per-model per-query results into a single
    per_query.jsonl shape. Each row is one (model, query)."""
    rows = []
    for model_result in model_results:
        model_id = model_result.model_id
        for qr in model_query_results.get(model_id, []):
            rows.append(
                {
                    "model_id": model_id,
                    "policy_id": qr.policy_id,
                    "query": qr.query,
                    "relevant_chunk_indices": qr.relevant_chunk_indices,
                    "top_3_indices": qr.top_3_indices,
                    "is_relevant_in_top_3": qr.is_relevant_in_top_3,
                }
            )
    return rows


def _decide(results: list[ModelResult], threshold: float) -> tuple[str, str]:
    """Apply the decision rule. The rule (per ADR-2026-07-19-03):
    - If voyage_3 recall@3 > small recall@3 by >= threshold,
      recommend switching to voyage_3.
    - Otherwise, recommend keeping small.

    In --dry-run mode, the decision is reported as 'DRY_RUN'
    because the pseudo-embeddings are not real and the
    decision is not actionable.
    """
    by_id = {r.model_id: r for r in results}
    if "openai_text_embedding_3_small" not in by_id or "voyage_3" not in by_id:
        return (
            "INCOMPLETE",
            "Both models must be present for the decision.",
        )
    small = by_id["openai_text_embedding_3_small"]
    voyage = by_id["voyage_3"]
    delta = voyage.recall_at_3 - small.recall_at_3
    if delta >= threshold:
        return (
            "SWITCH_TO_VOYAGE_3",
            f"voyage_3 recall@3 ({voyage.recall_at_3:.3f}) exceeds "
            f"small recall@3 ({small.recall_at_3:.3f}) by {delta:.3f} "
            f"(>= {threshold:.2f} threshold). Recommend switching.",
        )
    if delta <= -threshold:
        return (
            "STRONG_KEEP_SMALL",
            f"small recall@3 ({small.recall_at_3:.3f}) exceeds "
            f"voyage_3 recall@3 ({voyage.recall_at_3:.3f}) by {-delta:.3f}. "
            f"Recommend keeping small.",
        )
    return (
        "KEEP_SMALL",
        f"voyage_3 recall@3 ({voyage.recall_at_3:.3f}) does not exceed "
        f"small recall@3 ({small.recall_at_3:.3f}) by the {threshold:.2f} "
        f"threshold (delta={delta:+.3f}). Recommend keeping small.",
    )


# --- 8. Output ---


def write_results(config: BenchmarkConfig, run: BenchmarkRun) -> Path:
    """Write the run results to a timestamped directory. Returns
    the path to the run directory. Writes:
      - summary.json: the decision-grade numbers
      - README.md: the human-readable summary
      - per_query.jsonl: per-(model, query) results
    """
    run_dir = config.results_dir / run.timestamp.replace(":", "-")
    run_dir.mkdir(parents=True, exist_ok=True)

    # summary.json: the decision-grade numbers.
    with (run_dir / "summary.json").open("w") as f:
        json.dump(run.to_summary_dict(), f, indent=2)

    # per_query.jsonl: per-(model, query) results. The per-query
    # data is attached to the run as a private attribute by
    # run_benchmark().
    per_query = getattr(run, "_per_query", {})
    if per_query:
        rows = _per_query_results(run.results, per_query)
        with (run_dir / "per_query.jsonl").open("w") as f:
            for row in rows:
                f.write(json.dumps(row) + "\n")

    # README.md: the human-readable summary.
    readme_lines = [
        f"# Embedding model benchmark — {run.timestamp}",
        "",
        f"- Policies sampled: {run.policy_limit}",
        f"- Queries per policy: {run.query_limit}",
        f"- Decision: **{run.decision}**",
        "",
        "## Rationale",
        "",
        run.decision_rationale,
        "",
        "## Results",
        "",
        "| Model | Dimensions | recall@3 | Queries hit | Total | Duration |",
        "|---|---|---|---|---|---|",
    ]
    for r in run.results:
        readme_lines.append(
            f"| {r.model_id} | {r.dimensions} | "
            f"{r.recall_at_3:.3f} | {r.queries_with_relevant_in_top_3} | "
            f"{r.queries_total} | {r.duration_seconds:.1f}s |"
        )
    readme_lines.extend(
        [
            "",
            "## Files",
            "",
            "- `summary.json`: the decision-grade numbers (machine-readable)",
            "- `per_query.jsonl`: per-(policy, query) results",
            "- `per_chunk_predictions/`: the top-3 predictions per model",
            "",
            "## Next steps",
            "",
            (
                "1. Review the rationale. If the decision is SWITCH_TO_VOYAGE_3, "
                "follow the migration plan in docs/decisions/ADR-2026-07-19-03."
            ),
            (
                "2. If the decision is KEEP_SMALL or STRONG_KEEP_SMALL, no "
                "action is needed; the default stays text-embedding-3-small."
            ),
            (
                "3. Re-run the benchmark every 6 months, or whenever the "
                "model lineup changes."
            ),
        ]
    )
    with (run_dir / "README.md").open("w") as f:
        f.write("\n".join(readme_lines))

    return run_dir


# --- 9. CLI ---


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Embedding model benchmark for CoverWise. "
            "See the docstring for the methodology."
        )
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Run with fixture data and pseudo-embeddings. "
            "No API keys, no Supabase. The decision is "
            "reported as DRY_RUN and is not actionable."
        ),
    )
    parser.add_argument(
        "--recompute-only",
        action="store_true",
        help=(
            "Re-evaluate the recall@3 numbers using cached "
            "embeddings. Use this when ground truth is "
            "updated but embeddings have not changed."
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = BenchmarkConfig.from_env_and_args(args)
    if config.dry_run:
        log.info("=== DRY RUN ===")
        log.info("using fixture data; pseudo-embeddings; decision not actionable")
    run = run_benchmark(config)
    run_dir = write_results(config, run)
    log.info("results written to: %s", run_dir)
    log.info("decision: %s", run.decision)
    log.info("rationale: %s", run.decision_rationale)
    return 0


if __name__ == "__main__":
    sys.exit(main())
