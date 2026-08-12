"""CI-runnable test for the coverage-interpretation eval harness (offline path).

Verifies the harness can load + validate the labelled dataset and run the
offline scoreboard end-to-end with zero network access. The LIVE gate is
deliberately NOT executed here (deferred per ADR).
"""

from __future__ import annotations

from pathlib import Path

from tests.evals.run_evals import (
    DEFAULT_DATASET,
    load_dataset,
    run_offline,
    reference_judge,
    VALID_READINGS,
)


def test_dataset_loads_and_validates():
    examples, errors = load_dataset(DEFAULT_DATASET)
    assert not errors, f"dataset validation errors:\n" + "\n".join(errors)
    assert len(examples) >= 10  # a non-trivial labelled set
    # Gold labels must be within the legal-safe enum.
    assert all(ex.gold_reading in VALID_READINGS for ex in examples)
    # Spread across at least 3 of the 4 reading classes (not a single-label toy set).
    classes = {ex.gold_reading for ex in examples}
    assert len(classes) >= 3


def test_reference_judge_is_deterministic_and_enum_bounded():
    ex = load_dataset(DEFAULT_DATASET)[0][0]
    first = reference_judge(ex.clause, ex.question)
    second = reference_judge(ex.clause, ex.question)
    assert first == second
    assert first in VALID_READINGS


def test_offline_run_produces_scoreboard():
    rep = run_offline(DEFAULT_DATASET)
    assert rep.n == len(load_dataset(DEFAULT_DATASET)[0])
    assert 0.0 <= rep.accuracy <= 1.0
    # Every example got a prediction and a grounding check against clause text.
    assert rep.grounding_checked == rep.n
    # Offline grounding: expected citation must appear in its own clause.
    assert rep.grounding_failed == []
    # Confusion matrix is keyed by gold label and complete.
    assert set(rep.confusion.keys()) == {ex.gold_reading for ex in load_dataset(DEFAULT_DATASET)[0]}
