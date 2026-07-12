import logging
from typing import Optional
from src.eval.dataset import EvalSample, INSURANCE_EVAL_SET

logger = logging.getLogger(__name__)


class EvalResult:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.errors = 0
        self.details: list[dict] = []

    @property
    def score(self) -> float:
        if self.total == 0:
            return 0.0
        return self.passed / self.total

    def summary(self) -> dict:
        return {
            "total": self.total,
            "passed": self.passed,
            "failed": self.failed,
            "errors": self.errors,
            "score": round(self.score, 3),
            "details": self.details,
        }


async def run_eval(
    rag_pipeline,
    eval_set: Optional[list[EvalSample]] = None,
) -> EvalResult:
    if eval_set is None:
        eval_set = INSURANCE_EVAL_SET

    result = EvalResult()
    logger.info("Starting eval on %d samples", len(eval_set))

    for sample in eval_set:
        result.total += 1
        try:
            # Query the canonical RAG path and evaluate answer + retrieval separately.
            query_result = await rag_pipeline.query_rag(
                user_query=sample.query,
            )

            if query_result.get("status") != "success":
                result.errors += 1
                result.details.append({
                    "query": sample.query,
                    "status": "error",
                    "message": query_result.get("error", "Unknown error"),
                })
                continue

            extracted = query_result.get("result", {})
            sources = query_result.get("sources", [])
            answer = extracted.get("answer", "") if isinstance(extracted, dict) else ""

            # Check expected fields
            all_ok = True
            field_checks = {}
            if sample.expected_fields:
                for field, expected in sample.expected_fields.items():
                    actual = extracted.get(field)
                    if expected is None:
                        ok = actual is None
                    else:
                        ok = actual is not None and (
                            expected.lower() in str(actual).lower()
                            or str(actual).lower() in expected.lower()
                        )
                    field_checks[field] = {"expected": expected, "actual": actual, "pass": ok}
                    if not ok:
                        all_ok = False

            # Check expected answer substrings
            answer_checks = []
            if answer:
                for substring in sample.expected_answer_contains:
                    match = substring.lower() in answer.lower()
                    answer_checks.append({"substring": substring, "pass": match})
                    if not match:
                        all_ok = False

            source_checks = []
            if sources:
                combined = " ".join(s.get("text", "") for s in sources if isinstance(s, dict))
                for substring in sample.required_source_contains:
                    match = substring.lower() in combined.lower()
                    source_checks.append({"substring": substring, "pass": match})
                    if not match:
                        all_ok = False

            citation_checks = []
            if sample.expected_citations:
                actual_citations = {
                    citation.get("source_index")
                    for citation in extracted.get("citations", [])
                    if isinstance(citation, dict)
                }
                for citation_index in sample.expected_citations:
                    match = citation_index in actual_citations
                    citation_checks.append({"source_index": citation_index, "pass": match})
                    if not match:
                        all_ok = False

            if all_ok:
                result.passed += 1
            else:
                result.failed += 1

            result.details.append({
                "query": sample.query,
                "status": "pass" if all_ok else "fail",
                "field_checks": field_checks,
                "answer_checks": answer_checks,
                "source_checks": source_checks,
                "citation_checks": citation_checks,
            })

        except Exception as e:
            result.errors += 1
            result.details.append({
                "query": sample.query,
                "status": "error",
                "message": str(e),
            })
            logger.warning("Eval error for '%s': %s", sample.query, e)

    logger.info(
        "Eval complete: %d/%d passed (%.0f%%)",
        result.passed, result.total, result.score * 100,
    )
    return result
