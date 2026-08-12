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

import argparse
import json
import os
import re
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

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
    gold_reading: str
    gold_rationale: str
    expected_citation: str

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
        if ex.expected_citation.lower() not in ex.clause.lower():
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
    result = await pipeline.query_rag(ex.question, top_k=top_k, filters={"document_id": ex.id})
    latency_ms = (time.perf_counter() - t0) * 1000.0
    res = result.get("result", {})
    wa = res.get("wording_assessment") or {}
    pred = wa.get("reading")
    sources = " ".join(s.get("text", "") for s in res.get("sources", []))
    citations = " ".join(c.get("quote", "") for c in res.get("citations", []))
    grounded = ex.expected_citation.lower() in (sources + citations).lower()
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
    args = parser.parse_args(argv)

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
        # Build the real pipeline via the app's factory when available.
        try:
            from src.rag.pipeline import RAGPipeline
            pipeline = RAGPipeline.__new__(RAGPipeline)  # caller must fully configure
            # NOTE: full live wiring (vector store + embeddings + LLM) is supplied by
            # the deployment/test fixture that invokes this gate; see ADR.
            raise RuntimeError("live pipeline wiring must be injected by the caller fixture")
        except RuntimeError:
            print("LIVE pipeline wiring not provided in this context. Supply a configured "
                  "RAGPipeline to run_live(). (Deferred per user directive.)", file=sys.stderr)
            return 2

    rep = run_offline(args.dataset)
    write_report(rep, args.out)
    _print_human(rep)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
