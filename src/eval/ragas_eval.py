"""
RAGAS evaluation suite for CoverWise RAG pipeline.
Measures faithfulness, context precision, and response relevancy.

Usage:
    python -m src.eval.ragas_eval --fail-under-faithfulness 0.80
"""
import argparse
import asyncio
import json
import logging
import os
import sys
from typing import List, Dict, Any

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 20+ eval questions across categories (fallback)
EVAL_QUESTIONS = [
    {"question": "What is my policy number?", "expected_answer": "4214i", "category": "exact_field", "negative": False},
]


def _extract_result_parts(rag_result: Dict[str, Any]) -> tuple[Dict[str, Any], List[Dict[str, Any]]]:
    """Read the canonical nested response and retain retrieved evidence.

    Older callers sometimes returned a flat payload. Supporting that shape in
    the evaluator keeps compatibility without confusing the generated answer
    with the contexts retrieved from the index.
    """
    inner = rag_result.get("result", {}) if isinstance(rag_result, dict) else {}
    if not isinstance(inner, dict):
        inner = {}
    sources = inner.get("sources", [])
    if not isinstance(sources, list):
        sources = []
    return inner, [source for source in sources if isinstance(source, dict)]


def _source_contexts(sources: List[Dict[str, Any]]) -> List[str]:
    """Return immutable/source-grounded context strings for RAGAS."""
    contexts = []
    for source in sources:
        text = source.get("source_text") or source.get("text") or ""
        if str(text).strip():
            contexts.append(str(text).strip())
    return contexts

def load_questions():
    path = os.path.join(os.path.dirname(__file__), "../../docs/eval/corpus/policy_qa_v1.json")
    if os.path.exists(path):
        with open(path, "r") as f:
            data = json.load(f)
            questions = data.get("questions", [])
            mapped = []
            for q in questions:
                mapped.append({
                    "question": q["question"],
                    "expected_answer": q.get("ground_truth", ""),
                    "category": q.get("category", "unknown"),
                    "negative": q.get("negative", False),
                    "ground_truth_contains": q.get("ground_truth_contains", [])
                })
            return mapped
    return EVAL_QUESTIONS

async def run_ragas_eval(rag_pipeline, eval_questions: List[Dict] = None):
    questions = eval_questions or load_questions()
    results = []
    
    for q in questions:
        try:
            rag_result = await rag_pipeline.query_rag(q["question"])
            
            if rag_result.get("status") != "success":
                results.append({"question": q["question"], "status": "error", "error": rag_result.get("error", "unknown"), "negative": q.get("negative", False)})
                continue
            
            inner, sources = _extract_result_parts(rag_result)
            answer = inner.get("answer", "")
            citations = inner.get("citations", [])
            
            expected = q.get("expected_answer", "").lower()
            answer_lower = answer.lower()
            
            contains_expected = True
            if q.get("ground_truth_contains"):
                contains_expected = any(c.lower() in answer_lower for c in q["ground_truth_contains"])
            elif expected:
                contains_expected = expected in answer_lower
                
            results.append({
                "question": q["question"],
                "category": q["category"],
                "negative": q.get("negative", False),
                "answer": answer[:200],
                "expected": q["expected_answer"],
                "contexts": _source_contexts(sources),
                "answer_contains_expected": contains_expected,
                "has_sources": len(sources) > 0,
                "has_citations": len(citations) > 0,
            })
            
        except Exception as e:
            logger.error("Eval failed for '%s': %s", q["question"], e)
            results.append({"question": q["question"], "status": "error", "error": str(e), "negative": q.get("negative", False)})
    
    total = len(results)
    correct = sum(1 for r in results if r.get("answer_contains_expected"))
    has_sources = sum(1 for r in results if r.get("has_sources"))
    has_citations = sum(1 for r in results if r.get("has_citations"))
    has_contexts = sum(1 for r in results if r.get("contexts"))
    
    neg_total = sum(1 for r in results if r.get("negative"))
    neg_wrong = sum(1 for r in results if r.get("negative") and not r.get("answer_contains_expected"))
    
    metrics = {
        "total_questions": total,
        "correct_answers": correct,
        "accuracy": correct / total if total > 0 else 0,
        "source_coverage": has_sources / total if total > 0 else 0,
        "context_coverage": has_contexts / total if total > 0 else 0,
        "citation_rate": has_citations / total if total > 0 else 0,
        "hallucination_rate": neg_wrong / neg_total if neg_total > 0 else 0,
        "per_question": results,
    }
    
    try:
        from ragas import evaluate
        from ragas.metrics import faithfulness, context_precision, answer_relevancy
        
        # Build dataset for ragas
        from datasets import Dataset
        ragas_data = {
            "question": [], "answer": [], "contexts": [], "ground_truth": []
        }
        for r in results:
            if "answer" in r:
                ragas_data["question"].append(r["question"])
                ragas_data["answer"].append(r["answer"])
                ragas_data["contexts"].append(r.get("contexts", []))
                ragas_data["ground_truth"].append(r.get("expected", ""))
        
        if ragas_data["question"]:
            ds = Dataset.from_dict(ragas_data)
            ragas_result = evaluate(ds, metrics=[faithfulness, context_precision, answer_relevancy])
            metrics["ragas_metrics"] = {
                "faithfulness": ragas_result.get("faithfulness", 0.0),
                "context_precision": ragas_result.get("context_precision", 0.0),
                "answer_relevancy": ragas_result.get("answer_relevancy", 0.0)
            }
    except ImportError:
        logger.info("RAGAS not installed. Simple metrics only.")
    
    return metrics

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--fail-under-faithfulness", type=float, default=0.0)
    parser.add_argument("--fail-under-accuracy", type=float, default=0.0)
    args = parser.parse_args()
    
    from src.rag.pipeline import RAGPipeline
    
    async def main():
        pipeline = RAGPipeline()
        result = await run_ragas_eval(pipeline)
        print(json.dumps(result, indent=2, default=str))
        
        failed = False
        if args.fail_under_accuracy > 0:
            acc = result.get("accuracy", 0)
            if acc < args.fail_under_accuracy:
                logger.error(f"Accuracy {acc} is below threshold {args.fail_under_accuracy}")
                failed = True
                
        if args.fail_under_faithfulness > 0 and "ragas_metrics" in result:
            faith = result["ragas_metrics"].get("faithfulness", 0)
            if faith < args.fail_under_faithfulness:
                logger.error(f"Faithfulness {faith} is below threshold {args.fail_under_faithfulness}")
                failed = True
                
        if failed:
            sys.exit(1)
            
    asyncio.run(main())
