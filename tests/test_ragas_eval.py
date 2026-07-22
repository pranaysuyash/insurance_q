import pytest
from src.eval.ragas_eval import load_questions


def test_load_questions():
    questions = load_questions()
    assert len(questions) > 0
    if any(q["question"] == "What is my policy number?" for q in questions):
        question = next(
            q for q in questions if q["question"] == "What is my policy number?"
        )
        assert question["expected_answer"] == "4214i/CPHSR/407834350/00/000"


@pytest.mark.asyncio
async def test_ragas_eval_uses_retrieved_sources_as_contexts():
    from src.eval.ragas_eval import run_ragas_eval

    class FakePipeline:
        async def query_rag(self, question):
            return {
                "status": "success",
                "result": {
                    "answer": "The policy number is POL-123.",
                    "sources": [
                        {
                            "text": "Policy Number: POL-123",
                            "source_text": "Policy Number: POL-123",
                        }
                    ],
                    "citations": [{"source_index": 1}],
                },
            }

    result = await run_ragas_eval(
        FakePipeline(),
        [{
            "question": "What is the policy number?",
            "expected_answer": "POL-123",
            "category": "exact_field",
            "negative": False,
        }],
    )

    assert result["accuracy"] == 1.0
    assert result["source_coverage"] == 1.0
    assert result["context_coverage"] == 1.0
    assert result["per_question"][0]["contexts"] == ["Policy Number: POL-123"]
