#!/usr/bin/env python3
"""Coverage-interpretation eval harness for the Policy Wording Specialist persona.

Why this exists (per ADR-2026-08-12 + user directive "we need to be building
evals and versioning etc."):
- Give every future persona change a *reproducible* acceptance gate.
- Keep the labelled dataset, the judge, and the scoreboard in one place.
- Separate the cheap, always-on OFFLINE path from the costly, deferred LIVE path.

Legal-safety: the dataset is 100% synthetic ("Acme ... (synthetic)"). It contains
NO real customer policies or PII. The persona output is an INTERPRETATION of
wording, never a binding coverage/claim/legal decision.

Modes
-----
offline (default, CI-safe): validates the dataset schema, runs a deterministic
    *reference* (clause-only heuristic) judge against the gold labels, computes
    accuracy / per-class / confusion, and checks citation-grounding against the
    clause text. The reference judge is a smoke test of the harness mechanics;
    it is NOT a measure of the LLM persona's quality.

live (DEFERRED acceptance gate): requires OPENAI_API_KEY and an explicit
    --allow-live flag. It runs the REAL RAGPipeline.query_rag over each clause
    and compares the produced ``wording_assessment.reading`` to the gold label,
    plus latency/cost instrumentation. This is intentionally NOT run in CI and
    was explicitly deferred by the user pending a real policy corpus.

Usage
-----
    python tests/evals/run_evals.py --mode offline
    python tests/evals/run_evals.py --mode offline --out tests/evals/report_offline.json
    python tests/evals/run_evals.py --mode live --allow-live   # needs keys + corpus
"""

from __future__ import annotations

import sys
from pathlib import Path

# Make the harness runnable both via `python tests/evals/run_evals.py` and
# `python -m ...`; ensure the project root (the `src` package) is importable
# regardless of the current working directory.
_HERE = Path(__file__).resolve().parent
_PROJECT_ROOT = _HERE.parent.parent
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

import argparse
import asyncio
import json
import logging
import os
import re
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)

VALID_READINGS = ("likely_covered", "likely_not_covered", "conditional", "ambiguous")

HERE = Path(__file__).resolve().parent
DEFAULT_DATASET = HERE / "coverage_dataset.jsonl"


# ---------------------------------------------------------------------------
# Dataset loading + schema validation
# ---------------------------------------------------------------------------

@dataclass
class Example:
    id: str
    product: str
    clause: str
    question: str
    gold_reading: str          # the coverage LABEL (likely_covered / conditional / ...)
    gold_rationale: str
    expected_citation: str
    expected_page: Optional[int] = None
    lob: Optional[str] = None
    insurer: Optional[str] = None      # stamp for the live-fixture document metadata
    gold_answer: Optional[str] = None   # optional plain-language answer (informational)

    def validate(self) -> list[str]:
        errors = []
        if not self.id:
            errors.append("missing id")
        if self.gold_reading not in VALID_READINGS:
            errors.append(f"invalid gold_reading {self.gold_reading!r} (must be one of {VALID_READINGS})")
        for field_name in ("clause", "question", "expected_citation", "gold_rationale"):
            if not getattr(self, field_name):
                errors.append(f"missing {field_name}")
        return errors


def load_dataset(path: Path) -> tuple[list[Example], list[str]]:
    examples: list[Example] = []
    load_errors: list[str] = []
    if not path.exists():
        raise FileNotFoundError(f"dataset not found: {path}")
    with path.open("r", encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, 1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError as exc:
                load_errors.append(f"line {lineno}: bad JSON ({exc})")
                continue
            try:
                ex = Example(
                    id=obj.get("id", ""),
                    product=obj.get("product", ""),
                    clause=obj.get("clause", ""),
                    question=obj.get("question", ""),
                    gold_reading=obj.get("gold_reading", ""),
                    gold_rationale=obj.get("gold_rationale", ""),
                    expected_citation=obj.get("expected_citation", ""),
                    expected_page=obj.get("expected_page"),
                    lob=obj.get("lob"),
                    insurer=obj.get("insurer"),
                    gold_answer=obj.get("gold_answer"),
                )
            except Exception as exc:  # noqa: BLE001
                load_errors.append(f"line {lineno}: {exc}")
                continue
            schema_errors = ex.validate()
            if schema_errors:
                load_errors.append(f"{ex.id or f'line {lineno}'}: " + "; ".join(schema_errors))
            examples.append(ex)
    return examples, load_errors


# ---------------------------------------------------------------------------
# Reference (offline) judge — heuristic baseline, NOT the persona evaluation
# ---------------------------------------------------------------------------

# Baseline (OFFLINE) keyword sets. Phrased to avoid naive substring collisions
# (e.g. "covered" matching "not covered"). This is a smoke-test baseline only.
_GRANT_KW = ["we will pay", "we cover", "we will indemnify", "this policy covers",
             "cover is added", "cover applies", "cover for", "payable", "entitled", "benefit"]
_EXCLUSION_KW = ["not covered", "are excluded", "is excluded", "excluded", "exclusion",
                 "shall not", "does not cover", "do not cover", "not payable"]
_EXCEPTION_KW = ["exception to", "except that", "notwithstanding", "provided always",
                 "save that", "carve-back", "exception:"]
_CONDITION_KW = ["provided that", "subject to the condition", "condition precedent",
                 "warranty", "must notify", "waiting period"]
_WORD = re.compile(r"[a-z0-9]+")


def _has(text: str, keywords) -> bool:
    t = text.lower()
    return any(k in t for k in keywords)


def _has_word(text: str, words) -> bool:
    toks = set(_WORD.findall(text.lower()))
    return any(w in toks for w in words)


def _token_containment(needle: str, haystack: str) -> float:
    """Fraction of `needle`'s word-tokens present in `haystack` (0..1).

    Robust to paraphrasing / chunk-truncation / citation-excerpting, unlike
    exact substring. Returns 0.0 for an empty needle rather than dividing by 0.
    """
    n = set(_WORD.findall(needle.lower()))
    if not n:
        return 0.0
    h = set(_WORD.findall(haystack.lower()))
    return len(n & h) / len(n)


def is_grounded(example: "Example", sources: list, citations_text: str) -> bool:
    """Page-aware grounding (CI-safe) with a soft token-containment fallback.

    Primary signal: does at least one retrieved *source* carry the same
    ``page_number`` as the clause's ``expected_page``? Page membership is
    invariant to paraphrase, chunk truncation, and citation-excerpting, so it
    does not over-fire the way the old exact-substring check did.

    Fallback (rows without ``expected_page``): token containment of
    ``expected_citation`` in the retrieved text, at a 0.5 threshold. This keeps
    legacy rows working without silently resurrecting the over-firing substring
    equality.
    """
    if example.expected_page is not None:
        retrieved_pages = [
            s.get("page_number") for s in sources
            if s.get("page_number") is not None
        ]
        if example.expected_page in retrieved_pages:
            return True
        # Soft secondary so a correct answer is never penalised merely because
        # retrieval returned an adjacent page instead of the exact one.
        return _token_containment(example.expected_citation, citations_text) >= 0.5
    return _token_containment(example.expected_citation, citations_text) >= 0.5


def reference_judge(clause: str, question: str) -> str:
    """Deterministic clause+light-question heuristic (BASELINE only).

    This proves the harness loop works offline. It is explicitly NOT the Policy
    Wording Specialist persona and its accuracy is not a proxy for persona
    quality. The live judge (below) uses the real LLM + retrieval.
    """
    t = clause.lower()
    q = question.lower()
    # 'covered' is ambiguous with 'not covered'; only count it as a grant when not negated.
    has_grant = _has(t, _GRANT_KW) or (_has_word(t, {"covered"}) and "not covered" not in t)
    has_excl = _has(t, _EXCLUSION_KW)
    has_exc = _has(t, _EXCEPTION_KW)
    has_cond = _has(t, _CONDITION_KW)
    has_ambig = "ambiguous" in t

    if has_ambig:
        return "ambiguous"
    if has_excl and has_exc:
        # Carve-back present: cover depends on whether the exception is met.
        if any(w in q for w in ["before", "not ", "won't", "doesn't", "pre-existing", "without"]):
            return "likely_not_covered"
        return "conditional"
    if has_excl and not has_grant:
        return "likely_not_covered"
    if has_cond and has_grant:
        return "conditional"
    if has_grant and not has_excl:
        return "likely_covered"
    if has_excl and has_grant:
        return "ambiguous"  # grant + exclusion, no carve-back -> conflict
    return "ambiguous"


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

@dataclass
class Report:
    mode: str
    dataset: str
    n: int = 0
    correct: int = 0
    accuracy: float = 0.0
    per_class: dict = field(default_factory=dict)
    confusion: dict = field(default_factory=dict)
    mismatches: list = field(default_factory=list)
    grounding_checked: int = 0
    grounding_failed: list = field(default_factory=list)
    latencies_ms: list = field(default_factory=list)
    notes: list = field(default_factory=list)


def _score(pairs: list[tuple[Example, str]]) -> Report:
    rep = Report(mode="offline", dataset=str(DEFAULT_DATASET))
    rep.n = len(pairs)
    for ex, pred in pairs:
        ok = pred == ex.gold_reading
        if ok:
            rep.correct += 1
        else:
            rep.mismatches.append({
                "id": ex.id, "question": ex.question,
                "gold": ex.gold_reading, "pred": pred,
                "rationale": ex.gold_rationale,
            })
        rep.per_class.setdefault(ex.gold_reading, {"n": 0, "correct": 0})
        rep.per_class[ex.gold_reading]["n"] += 1
        if ok:
            rep.per_class[ex.gold_reading]["correct"] += 1
        rep.confusion.setdefault(ex.gold_reading, {})
        rep.confusion[ex.gold_reading][pred] = rep.confusion[ex.gold_reading].get(pred, 0) + 1
    rep.accuracy = (rep.correct / rep.n) if rep.n else 0.0
    return rep


# ---------------------------------------------------------------------------
# Offline run
# ---------------------------------------------------------------------------

def run_offline(dataset_path: Path) -> Report:
    examples, load_errors = load_dataset(dataset_path)
    if load_errors:
        raise ValueError("dataset failed validation:\n" + "\n".join(load_errors))
    if not examples:
        raise ValueError("dataset is empty")

    pairs: list[tuple[Example, str]] = []
    rep = Report(mode="offline", dataset=str(dataset_path), n=len(examples))
    for ex in examples:
        pred = reference_judge(ex.clause, ex.question)
        pairs.append((ex, pred))
        # Grounding sanity: the expected citation must at least appear in the
        # clause text (the clause is the source in offline mode).
        rep.grounding_checked += 1
        # Offline grounding is a sanity check that the citation string appears in
        # the clause. For page-anchored (real-policy) datasets the clause is a
        # page snippet and the real grounding happens in LIVE mode via page
        # membership, so skip the string check when expected_page is set.
        if ex.expected_page is None and ex.expected_citation.lower() not in ex.clause.lower():
            rep.grounding_failed.append({"id": ex.id, "expected": ex.expected_citation})

    scored = _score(pairs)
    rep.correct = scored.correct
    rep.accuracy = scored.accuracy
    rep.per_class = scored.per_class
    rep.confusion = scored.confusion
    rep.mismatches = scored.mismatches
    rep.notes.append(
        "Reference (heuristic) judge only. NOT the Policy Wording Specialist persona. "
        "Accuracy here validates the harness loop, not LLM quality."
    )
    return rep


# ---------------------------------------------------------------------------
# Live run (DEFERRED acceptance gate) — implemented, guarded, not run in CI
# ---------------------------------------------------------------------------

async def _llm_judge(pipeline, ex: Example, top_k: int = 4) -> tuple[str, float, bool]:
    """Run the REAL pipeline over a single clause and read its reading.

    Returns (predicted_reading, latency_ms, grounded). Implemented and ready, but
    only invoked when the user explicitly enables --allow-live with API keys.
    """
    t0 = time.perf_counter()
    # Filter to the single ingested document. Use the fixture's real document_id
    # (set on the pipeline) rather than ex.id, which is a row id and would never
    # match the ingested doc id and silently empty retrieval. With no fixture doc
    # id (shouldn't happen in the live gate) fall back to no document filter.
    doc_id = getattr(pipeline, "_live_document_id", None)
    filters = {"document_id": doc_id} if doc_id else None
    result = await pipeline.query_rag(ex.question, top_k=top_k, filters=filters, lob=ex.lob)
    latency_ms = (time.perf_counter() - t0) * 1000.0
    res = result.get("result", {})
    wa = res.get("wording_assessment") or {}
    pred = wa.get("reading")
    sources = res.get("sources", [])
    sources_text = " ".join(s.get("text", "") for s in sources)
    citations_text = " ".join(c.get("quote", "") for c in res.get("citations", []))
    grounded = is_grounded(ex, sources, sources_text + " " + citations_text)
    return pred, latency_ms, grounded


async def run_live(dataset_path: Path, pipeline) -> Report:
    examples, load_errors = load_dataset(dataset_path)
    if load_errors:
        raise ValueError("dataset failed validation:\n" + "\n".join(load_errors))
    rep = Report(mode="live", dataset=str(dataset_path), n=len(examples))
    pairs: list[tuple[Example, str]] = []
    for ex in examples:
        pred, latency_ms, grounded = await _llm_judge(pipeline, ex)
        rep.latencies_ms.append(latency_ms)
        if not grounded:
            rep.grounding_failed.append({"id": ex.id, "expected": ex.expected_citation})
        rep.grounding_checked += 1
        pairs.append((ex, pred or "ambiguous"))
    scored = _score(pairs)
    rep.correct = scored.correct
    rep.accuracy = scored.accuracy
    rep.per_class = scored.per_class
    rep.confusion = scored.confusion
    rep.mismatches = scored.mismatches
    rep.notes.append(
        "LIVE acceptance gate: real RAGPipeline + Policy Wording Specialist persona. "
        "Latency/cost measured here; this is the implementation-commit gate per ADR."
    )
    return rep


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def write_report(rep: Report, out_path: Path | None) -> None:
    payload = {
        "mode": rep.mode,
        "dataset": rep.dataset,
        "n": rep.n,
        "correct": rep.correct,
        "accuracy": round(rep.accuracy, 4),
        "per_class": rep.per_class,
        "confusion": rep.confusion,
        "mismatches": rep.mismatches,
        "grounding_checked": rep.grounding_checked,
        "grounding_failed": rep.grounding_failed,
        "latencies_ms": [round(x, 1) for x in rep.latencies_ms],
        "notes": rep.notes,
    }
    if out_path:
        out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    else:
        print(json.dumps(payload, indent=2))


def _print_human(rep: Report) -> None:
    print(f"\n=== Coverage-interpretation eval ({rep.mode}) ===")
    print(f"Examples: {rep.n}  Correct: {rep.correct}  Accuracy: {rep.accuracy:.1%}")
    print("Per-class (correct/n):")
    for cls, d in sorted(rep.per_class.items()):
        print(f"  {cls:20s} {d['correct']}/{d['n']}")
    if rep.mismatches:
        print("Mismatches:")
        for m in rep.mismatches:
            print(f"  [{m['id']}] gold={m['gold']} pred={m['pred']} :: {m['question']}")
    print(f"Grounding checked: {rep.grounding_checked}, failed: {len(rep.grounding_failed)}")
    for note in rep.notes:
        print(f"NOTE: {note}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Policy Wording Specialist eval harness")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--mode", choices=["offline", "live"], default="offline")
    parser.add_argument("--allow-live", action="store_true",
                        help="Required to actually run the deferred LIVE gate (needs OPENAI_API_KEY).")
    parser.add_argument("--out", type=Path, default=None, help="Write JSON report here.")
    parser.add_argument("--lob", default=None, metavar="LOB",
                        help="Line of business for the live gate. Accepts health/cyber/marine "
                             "plus any global LOB (motor/property/travel/liability/life). "
                             "With --market, auto-resolves corpus_global/<market>/<lob>/. "
                             "Without --market, health/cyber/marine use the built-in LOB corpus; "
                             "other LOBs require --market.")
    parser.add_argument("--market", default=None,
                        help="Run against corpus_global/<market>/<lob>/ (any global market). "
                             "Requires --lob. Auto-resolves the PDF + coverage.jsonl there.")
    parser.add_argument("--pdf", type=Path, default=None,
                        help="Path to the LOB corpus PDF (required for --lob cyber/marine unless default exists).")
    parser.add_argument("--product", type=str, default=None,
                        help="Product name stamped on the ingested LOB corpus (overrides the built-in default).")
    parser.add_argument("--insurer", type=str, default=None,
                        help="Insurer name stamped on the ingested LOB corpus (overrides the built-in default).")
    args = parser.parse_args(argv)

    # corpus_global resolution: --market + --lob auto-resolves coverage.jsonl
    if args.market and args.lob and args.dataset == DEFAULT_DATASET:
        cg = _PROJECT_ROOT / "corpus_global" / args.market / args.lob
        args.dataset = cg / "coverage.jsonl"

    if args.mode == "live" and not args.allow_live:
        print(
            "LIVE eval is the DEFERRED acceptance gate. It requires real API keys and a "
            "policy corpus, and incurs cost. Re-run with --allow-live after setting "
            "OPENAI_API_KEY. (See ADR-2026-08-12.)",
            file=sys.stderr,
        )
        return 2
    if args.mode == "live":
        if not os.environ.get("OPENAI_API_KEY"):
            print("OPENAI_API_KEY not set; cannot run LIVE eval.", file=sys.stderr)
            return 2
        # The deferred acceptance gate is now one command: the fixture builds a REAL
        # RAGPipeline over an in-memory Qdrant corpus of policy.pdf (redacted PII),
        # and runs the actual persona. The real-policy dataset is used unless the
        # caller overrides --dataset.
        dataset_path = args.dataset
        if dataset_path == DEFAULT_DATASET:
            dataset_path = HERE / "coverage_dataset_policy.jsonl"
        asyncio.run(_run_live_async(args))
        return 0

    rep = run_offline(args.dataset)
    write_report(rep, args.out)
    _print_human(rep)
    return 0


async def _run_live_async(args) -> None:
    """Build the in-memory live pipeline and run the real persona over the dataset.

    Resolution order:
      * ``--market <m> --lob <l>`` -> corpus_global/<m>/<l>/ (any global market).
        Auto-resolves the PDF + coverage.jsonl; product/insurer come from the
        dataset rows if not overridden.
      * ``--lob cyber`` / ``--lob marine`` -> the public LOB corpus PDF in
        corpus_lob/ + coverage_dataset_<lob>.jsonl.
      * default (health) -> the redacted policy.pdf fixture + coverage_dataset_policy.jsonl.
    """
    from live_fixture import build_live_pipeline, build_live_pipeline_from_pdf

    lob = args.lob
    market = args.market
    dataset_path = args.dataset
    if dataset_path == DEFAULT_DATASET:
        dataset_path = HERE / "coverage_dataset_policy.jsonl"

    pipeline = None

    if market and lob:
        # Generic GLOBAL market/LOB run — no code change needed for new markets.
        cg = _PROJECT_ROOT / "corpus_global" / market / lob
        pdfs = sorted(cg.glob("*.pdf"))
        pdf = args.pdf or (pdfs[0] if pdfs else None)
        if pdf is None or not Path(pdf).exists():
            print(f"no corpus PDF in {cg}", file=sys.stderr)
            raise SystemExit(2)
        product, insurer = args.product, args.insurer
        if not product or not insurer:
            rows, _ = load_dataset(cg / "coverage.jsonl")
            if rows:
                product = product or rows[0].product
                insurer = insurer or rows[0].insurer
        pipeline = await build_live_pipeline_from_pdf(
            Path(pdf), document_id=f"{market}-{lob}-pdf", product=product or "",
            insurer=insurer or "", lob=lob,
        )
        if args.dataset == DEFAULT_DATASET:
            dataset_path = cg / "coverage.jsonl"
        print(f"[live] market={market} lob={lob} corpus={Path(pdf).name} product={product!r}")
    elif lob and lob != "health":
        # LOB live run over a public corpus PDF.
        default_pdfs = {
            "cyber": _PROJECT_ROOT / "corpus_lob" / "cyber_liberty.pdf",
            "marine": _PROJECT_ROOT / "corpus_lob" / "marine_iffco_tokio.pdf",
        }
        pdf = args.pdf or default_pdfs.get(lob)
        if pdf is None or not Path(pdf).exists():
            print(f"--pdf required for --lob {lob}; not found: {pdf}", file=sys.stderr)
            raise SystemExit(2)
        default_product = {"cyber": "Liberty Cyber Safe Insurance Policy",
                           "marine": "IFFCO Tokio Marine Cargo Policy"}
        default_insurer = {"cyber": "Liberty General Insurance Limited",
                           "marine": "IFFCO Tokio General Insurance"}
        product = args.product or default_product.get(lob, "")
        insurer = args.insurer or default_insurer.get(lob, "")
        pipeline = await build_live_pipeline_from_pdf(
            Path(pdf), document_id=f"{lob}-pdf", product=product,
            insurer=insurer, lob=lob,
        )
        if args.dataset == DEFAULT_DATASET:
            dataset_path = HERE / f"coverage_dataset_{lob}.jsonl"
        print(f"[live] LOB={lob} corpus={pdf.name} product={product!r}")
    else:
        pipeline = await build_live_pipeline()
        if args.dataset == DEFAULT_DATASET:
            dataset_path = HERE / "coverage_dataset_policy.jsonl"

    rep = await run_live(dataset_path, pipeline)
    write_report(rep, args.out)
    _print_human(rep)
    cost = pipeline.llm.get_cost_summary()
    print(f"\nLLM cost summary: {json.dumps(cost)}")
    if rep.latencies_ms:
        avg = sum(rep.latencies_ms) / len(rep.latencies_ms)
        print(f"Avg latency/query: {avg:.0f} ms  (n={len(rep.latencies_ms)})")
    # Cost/latency monitoring: append a trend record so runs are comparable over
    # time (persona version, accuracy, latency, cost). The log is the lightweight
    # dashboard for the deferred acceptance gate.
    _log_live_metrics(rep, cost, dataset_path)


def _log_live_metrics(rep: "Report", cost: dict, dataset_path: Path) -> None:
    """Persist a one-line trend record and print the previous run for comparison."""
    from src.rag.persona import get_persona_version

    log_path = HERE / "live_metrics_log.jsonl"
    record = {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "persona_version": get_persona_version(),
        "dataset": Path(dataset_path).name,
        "n": rep.n,
        "accuracy": round(rep.accuracy, 4),
        "correct": rep.correct,
        "grounding_failed": len(rep.grounding_failed),
        "avg_latency_ms": round(sum(rep.latencies_ms) / len(rep.latencies_ms), 1) if rep.latencies_ms else None,
        "p50_latency_ms": round(sorted(rep.latencies_ms)[len(rep.latencies_ms) // 2], 1) if rep.latencies_ms else None,
        "total_cost": cost.get("total_cost"),
        "total_calls": cost.get("total_calls"),
    }
    try:
        prior = None
        if log_path.exists():
            lines = [ln for ln in log_path.read_text(encoding="utf-8").splitlines() if ln.strip()]
            if lines:
                prior = json.loads(lines[-1])
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record) + "\n")
        print(f"\n[monitoring] appended run to {log_path.name}")
        if prior:
            d_lat = record["avg_latency_ms"] - prior["avg_latency_ms"]
            d_acc = record["accuracy"] - prior["accuracy"]
            print(f"[monitoring] vs previous run: accuracy {d_acc:+.0%}, "
                  f"avg latency {d_lat:+.0f} ms (was {prior['avg_latency_ms']:.0f} ms)")
    except Exception as exc:  # never fail the gate on metrics logging
        logger.warning("live metrics log failed: %s", exc)


if __name__ == "__main__":
    raise SystemExit(main())
