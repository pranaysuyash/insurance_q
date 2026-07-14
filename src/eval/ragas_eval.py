"""
RAGAS evaluation suite for CoverWise RAG pipeline.
Measures faithfulness, context precision, and response relevancy.

Usage:
    python -m src.eval.ragas_eval
"""
import asyncio
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)

# 20+ eval questions across categories
EVAL_QUESTIONS = [
    # Exact field lookup (5)
    {"question": "What is my policy number?", "expected_answer": "4214i/CPHSR/407834350/00/000", "category": "exact_field"},
    {"question": "What is the insurer name?", "expected_answer": "ICICI Lombard", "category": "exact_field"},
    {"question": "What is the claims helpline number?", "expected_answer": "1800 2666", "category": "exact_field"},
    {"question": "What is the customer care email?", "expected_answer": "ihealthcare@icicilombard.com", "category": "exact_field"},
    {"question": "What is the premium amount?", "expected_answer": "31705", "category": "exact_field"},
    
    # Numeric amounts (5)
    {"question": "What is the total coverage amount or sum insured?", "expected_answer": "2500000", "category": "numeric"},
    {"question": "What is the maternity coverage limit?", "expected_answer": "40000", "category": "numeric"},
    {"question": "How much is the deductible?", "expected_answer": "not applicable", "category": "numeric"},
    {"question": "What is the total premium paid?", "expected_answer": "31705", "category": "numeric"},
    {"question": "What is the annual sum insured?", "expected_answer": "2500000", "category": "numeric"},
    
    # Dates (5)
    {"question": "When does my policy start?", "expected_answer": "2025-08-27", "category": "date"},
    {"question": "When does my policy end or expire?", "expected_answer": "2026-08-26", "category": "date"},
    {"question": "What is the policy period?", "expected_answer": "27-Aug-2025", "category": "date"},
    {"question": "What is the effective date?", "expected_answer": "2025-08-27", "category": "date"},
    {"question": "What is the expiry date?", "expected_answer": "2026-08-26", "category": "date"},
    
    # Exclusions / semantic (3)
    {"question": "What is not covered by this policy?", "expected_answer": "pre-existing", "category": "semantic"},
    {"question": "Are there any waiting periods?", "expected_answer": "30 days", "category": "semantic"},
    {"question": "What are the exclusions?", "expected_answer": "cosmetic", "category": "semantic"},
    
    # Benefits / semantic (2)
    {"question": "Does this policy cover dental?", "expected_answer": "not", "category": "semantic"},
    {"question": "What is covered for hospital stays?", "expected_answer": "hospital", "category": "semantic"},
    
    # Comparison / cross-document (2)
    {"question": "Compare my health and auto coverage", "expected_answer": "", "category": "comparison"},
    {"question": "What coverage gaps do I have?", "expected_answer": "", "category": "comparison"},
]


async def run_ragas_eval(rag_pipeline, eval_questions: List[Dict] = None):
    """Run RAGAS evaluation on the RAG pipeline.
    
    Falls back to simple metrics if RAGAS is not installed.
    """
    questions = eval_questions or EVAL_QUESTIONS
    results = []
    
    for q in questions:
        try:
            rag_result = await rag_pipeline.query_rag(q["question"])
            
            if rag_result.get("status") != "success":
                results.append({"question": q["question"], "status": "error", "error": rag_result.get("error", "unknown")})
                continue
            
            inner = rag_result.get("result", {})
            answer = inner.get("answer", "")
            sources = inner.get("sources", [])
            confidence = inner.get("confidence", 0.0)
            
            # Simple metrics (fallback if RAGAS not installed)
            expected = q["expected_answer"].lower()
            answer_lower = answer.lower()
            
            answer_contains = expected in answer_lower if expected else True
            has_sources = len(sources) > 0
            has_citations = len(inner.get("citations", [])) > 0
            
            results.append({
                "question": q["question"],
                "category": q["category"],
                "answer": answer[:200],
                "expected": q["expected_answer"],
                "answer_contains_expected": answer_contains,
                "has_sources": has_sources,
                "has_citations": has_citations,
                "confidence": confidence,
                "retrieval_strategy": inner.get("retrieval_strategy", ""),
            })
            
        except Exception as e:
            logger.error("Eval failed for '%s': %s", q["question"], e)
            results.append({"question": q["question"], "status": "error", "error": str(e)})
    
    # Try RAGAS if installed
    try:
        from ragas import evaluate
        from ragas.metrics import faithfulness, context_precision, response_relevancy
        
        ragas_data = []
        for r in results:
            if "answer" in r:
                ragas_data.append({
                    "question": r["question"],
                    "answer": r["answer"],
                    "contexts": [r.get("answer", "")],
                    "ground_truth": r.get("expected", ""),
                })
        
        if ragas_data:
            ragas_result = evaluate(ragas_data, metrics=[faithfulness, context_precision, response_relevancy])
            return {"simple_metrics": results, "ragas_metrics": ragas_result}
    except ImportError:
        logger.info("RAGAS not installed. Using simple metrics only. Install with: pip install ragas")
    
    # Simple metrics summary
    total = len(results)
    correct = sum(1 for r in results if r.get("answer_contains_expected"))
    has_sources = sum(1 for r in results if r.get("has_sources"))
    
    return {
        "total_questions": total,
        "correct_answers": correct,
        "accuracy": correct / total if total > 0 else 0,
        "source_coverage": has_sources / total if total > 0 else 0,
        "per_question": results,
    }


if __name__ == "__main__":
    from src.rag.pipeline import RAGPipeline
    
    async def main():
        pipeline = RAGPipeline()
        result = await run_ragas_eval(pipeline)
        import json
        print(json.dumps(result, indent=2, default=str))
    
    asyncio.run(main())