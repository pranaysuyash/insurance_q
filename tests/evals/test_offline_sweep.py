"""Offline regression guard for the global policy-corpus gold datasets.

Globs ``corpus_global/*/*/coverage.jsonl``, loads each via
``tests/evals/run_evals.py``'s ``load_dataset`` (schema validation) and runs the
offline judge (``run_offline``) to surface grounding failures. Asserts ZERO
schema errors and ZERO grounding failures across ALL datasets currently present.

Design choice (per task): do NOT hardcode a dataset count. The sweep must pass
for whatever datasets exist on disk. A non-empty guard prevents a silently-empty
sweep from reading as "passing".

Confidence: VERIFIED by execution. The offline judge (reference_judge /
is_grounded) uses no network -- it is a deterministic heuristic, so this is
CI-safe.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# run_evals.py lives in tests/evals; make it importable as a top-level module.
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import pytest

from run_evals import load_dataset, run_offline  # noqa: E402

GLOB = "corpus_global/*/*/coverage.jsonl"


def _datasets():
    return sorted(ROOT.glob(GLOB))


def test_global_corpus_sweep_has_zero_schema_and_grounding_errors():
    found = _datasets()
    assert found, f"no datasets matched {GLOB} under {ROOT}"

    total_examples = 0
    total_schema_errors = 0
    total_grounding_failures = 0
    per_dataset = []

    for path in found:
        examples, load_errors = load_dataset(path)
        # run_offline re-loads (and would raise on load_errors); calling it here
        # also exercises the offline grounding check for this dataset.
        rep = run_offline(path)

        assert load_errors == [], (
            f"{path.name}: schema errors: {load_errors}"
        )
        assert rep.grounding_failed == [], (
            f"{path.name}: grounding failures: {rep.grounding_failed}"
        )

        total_examples += len(examples)
        total_schema_errors += len(load_errors)
        total_grounding_failures += len(rep.grounding_failed)
        per_dataset.append((str(path.relative_to(ROOT)), len(examples)))

    # Aggregate guard (these are the headline regression assertions).
    assert total_schema_errors == 0, f"schema errors across sweep: {total_schema_errors}"
    assert total_grounding_failures == 0, (
        f"grounding failures across sweep: {total_grounding_failures}"
    )

    # Surface a summary for the human reader (does not affect pass/fail).
    print(f"\n[offline-sweep] datasets={len(found)} examples={total_examples} "
          f"schema_errors={total_schema_errors} grounding_failures={total_grounding_failures}")
    for rel, n in per_dataset:
        print(f"  - {rel}: {n} examples")
