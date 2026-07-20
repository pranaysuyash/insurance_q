import pytest
import os
import json
from src.eval.ragas_eval import load_questions

def test_load_questions():
    questions = load_questions()
    assert len(questions) > 0
    # ensure it loaded from json
    if any(q["question"] == "What is my policy number?" for q in questions):
        # find it
        q = next(q for q in questions if q["question"] == "What is my policy number?")
        assert q["expected_answer"] == "4214i/CPHSR/407834350/00/000"
