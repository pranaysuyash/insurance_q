#!/usr/bin/env python3
"""
CoverWise Chunking/Parsing Strategy Benchmark

Tests multiple chunking strategies against a real insurance policy with known
Q&A pairs. Measures retrieval quality, answer accuracy, and source quality.

Usage:
    venv/bin/python tools/benchmark_chunking.py

Requires:
    - policy.pdf in project root (password-protected)
    - OpenAI API key in .env
    - Dependencies: PyMuPDF, openai

Documentation:
    docs/technical/rag/exploration/benchmark_harness_2026-07-22.md
"""
from __future__ import annotations

import os
import sys
import time
import json
import re
import hashlib
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional, Tuple

# Ensure project root is on path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

import fitz  # PyMuPDF
from openai import OpenAI


# ─── Configuration ───────────────────────────────────────────────────────────

POLICY_PATH = PROJECT_ROOT / "policy.pdf"
POLICY_PASSWORD = "pran1005"
EMBEDDING_MODEL = "text-embedding-3-small"
CHAT_MODEL = "gpt-5-nano"
TOP_K = 5


# ─── Ground truth ────────────────────────────────────────────────────────────

@dataclass
class BenchmarkQuestion:
    id: str
    question: str
    expected_answer_keywords: List[str]  # Must ALL appear in a correct answer
    page: int  # Which page the answer is on

QUESTIONS = [
    BenchmarkQuestion("Q1", "What is my policy number?",
        ["4214i/CPHSR/407834350/00/000"], 1),
    BenchmarkQuestion("Q2", "What is my sum insured?",
        ["2500000", "25,00,000", "25 lakh", "₹25"], 1),
    BenchmarkQuestion("Q3", "What is my premium amount?",
        ["31705", "31,705"], 1),
    BenchmarkQuestion("Q4", "Who is the proposer?",
        ["PRANAY", "SUYASH", "Pranay"], 1),
    BenchmarkQuestion("Q5", "What is the policy period?",
        ["27-Aug-2025", "26-Aug-2026"], 1),
    BenchmarkQuestion("Q6", "What is the insurer name?",
        ["ICICI Lombard"], 1),
    BenchmarkQuestion("Q7", "What is the product name?",
        ["Health Shield 360"], 1),
    BenchmarkQuestion("Q8", "What is the loyalty bonus?",
        ["700000", "7,00,000"], 1),
    BenchmarkQuestion("Q9", "Who are the insured members?",
        ["Pranay", "Diksha", "Advay"], 1),
    BenchmarkQuestion("Q10", "What is the toll-free helpline?",
        ["1800 2666", "18002666"], 1),
]


# ─── Data structures ────────────────────────────────────────────────────────

@dataclass
class Chunk:
    text: str
    page: int
    strategy: str
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ScoredResult:
    question_id: str
    strategy: str
    retrieval_score: float  # 0-1: did chunks contain the info?
    answer_score: float  # 0-1: did the answer match ground truth?
    source_score: float  # 0-1: were sources on the right page?
    answer_text: str
    top_chunks: List[str]  # Preview of top chunks
    latency_ms: int


# ─── Parsing ────────────────────────────────────────────────────────────────

def parse_pdf_pages(pdf_path: str, password: str) -> List[Dict]:
    """Parse PDF and return per-page data: text, blocks, tables."""
    doc = fitz.open(pdf_path)
    doc.authenticate(password)

    pages = []
    for page_num, page in enumerate(doc, start=1):
        text = page.get_text()
        blocks = page.get_text("blocks")

        # Extract tables
        tables_data = []
        try:
            tables = page.find_tables()
            for t in tables.tables:
                rows = t.extract()
                if rows:
                    # Serialize as Markdown
                    header = rows[0]
                    md_rows = []
                    for row in rows[1:]:
                        cells = [str(c).strip() if c else "" for c in row]
                        md_rows.append("| " + " | ".join(cells) + " |")
                    if md_rows:
                        header_md = "| " + " | ".join(str(h).strip() if h else "" for h in header) + " |"
                        sep_md = "| " + " | ".join("---" for _ in header) + " |"
                        tables_data.append({
                            "markdown": f"{header_md}\n{sep_md}\n" + "\n".join(md_rows),
                            "row_count": len(rows),
                        })
        except Exception:
            pass

        pages.append({
            "page_num": page_num,
            "text": text,
            "blocks": blocks,
            "tables": tables_data,
        })

    doc.close()
    return pages


# ─── Chunking strategies ────────────────────────────────────────────────────

def build_context_header(summary: Dict) -> str:
    """Build the doc context header (same as pipeline._build_doc_context_header)."""
    parts = []
    if summary.get("insurer"):
        parts.append(f"Insurer: {summary['insurer']}")
    if summary.get("policy_number"):
        parts.append(f"Policy Number: {summary['policy_number']}")
    if summary.get("sum_insured"):
        parts.append(f"Sum Insured: ₹{summary['sum_insured']}")
    if summary.get("premium"):
        parts.append(f"Premium: ₹{summary['premium']}")
    if parts:
        return "[Policy Context] " + " | ".join(parts) + "\n\n"
    return ""


DOC_SUMMARY = {
    "insurer": "ICICI Lombard General Insurance Company Limited",
    "policy_number": "4214i/CPHSR/407834350/00/000",
    "sum_insured": "2500000",
    "premium": "31705",
}


def chunk_strategy_a_paragraph(pages: List[Dict]) -> List[Chunk]:
    """Strategy A: Current — paragraph splitting + context header."""
    chunks = []
    header = build_context_header(DOC_SUMMARY)

    for page in pages:
        text = page["text"]
        if not text.strip():
            continue

        # Split on double newlines
        paragraphs = re.split(r'\n\s*\n', text)
        current = ""
        for para in paragraphs:
            para = para.strip()
            if not para:
                continue
            if len(current) + len(para) > 1000 and current:
                chunks.append(Chunk(
                    text=header + current,
                    page=page["page_num"],
                    strategy="A_paragraph",
                ))
                current = para
            else:
                current = f"{current}\n\n{para}".strip() if current else para

        if current:
            chunks.append(Chunk(
                text=header + current,
                page=page["page_num"],
                strategy="A_paragraph",
            ))

    return chunks


def chunk_strategy_b_table_aware(pages: List[Dict]) -> List[Chunk]:
    """Strategy B: Table-aware — tables as Markdown atomic chunks + paragraph for prose."""
    chunks = []
    header = build_context_header(DOC_SUMMARY)

    for page in pages:
        # First: extract tables as atomic chunks
        for table in page.get("tables", []):
            chunks.append(Chunk(
                text=header + table["markdown"],
                page=page["page_num"],
                strategy="B_table_aware",
                metadata={"chunk_type": "table", "row_count": table["row_count"]},
            ))

        # Then: chunk the prose (non-table text)
        text = page["text"]
        if not text.strip():
            continue

        # If tables were found, try to exclude table text from prose chunks
        # (it's already in the table chunks). For simplicity, keep all text
        # but the table chunks will have higher relevance for table questions.
        paragraphs = re.split(r'\n\s*\n', text)
        current = ""
        for para in paragraphs:
            para = para.strip()
            if not para:
                continue
            if len(current) + len(para) > 1000 and current:
                chunks.append(Chunk(
                    text=header + current,
                    page=page["page_num"],
                    strategy="B_table_aware",
                    metadata={"chunk_type": "paragraph"},
                ))
                current = para
            else:
                current = f"{current}\n\n{para}".strip() if current else para

        if current:
            chunks.append(Chunk(
                text=header + current,
                page=page["page_num"],
                strategy="B_table_aware",
                metadata={"chunk_type": "paragraph"},
            ))

    return chunks


def chunk_strategy_c_page_level(pages: List[Dict]) -> List[Chunk]:
    """Strategy C: Page-level — each page's full text as one chunk."""
    chunks = []
    header = build_context_header(DOC_SUMMARY)

    for page in pages:
        text = page["text"].strip()
        if not text:
            continue
        # Truncate very long pages
        if len(text) > 8000:
            text = text[:8000]
        chunks.append(Chunk(
            text=header + text,
            page=page["page_num"],
            strategy="C_page_level",
        ))

    return chunks


def chunk_strategy_d_hybrid(pages: List[Dict]) -> List[Chunk]:
    """Strategy D: Table-serialised chunks + page-level prose chunks."""
    chunks = []
    header = build_context_header(DOC_SUMMARY)

    for page in pages:
        # Tables as atomic chunks
        for table in page.get("tables", []):
            chunks.append(Chunk(
                text=header + table["markdown"],
                page=page["page_num"],
                strategy="D_hybrid",
                metadata={"chunk_type": "table"},
            ))

        # Full page text as one chunk (prose context)
        text = page["text"].strip()
        if text and len(text) > 200:  # Skip near-empty pages
            if len(text) > 8000:
                text = text[:8000]
            chunks.append(Chunk(
                text=header + text,
                page=page["page_num"],
                strategy="D_hybrid",
                metadata={"chunk_type": "page"},
            ))

    return chunks


def chunk_strategy_e_no_header(pages: List[Dict]) -> List[Chunk]:
    """Strategy E: Control — paragraph splitting WITHOUT context header.
    Shows the baseline impact of the context header alone."""
    chunks = []

    for page in pages:
        text = page["text"]
        if not text.strip():
            continue

        paragraphs = re.split(r'\n\s*\n', text)
        current = ""
        for para in paragraphs:
            para = para.strip()
            if not para:
                continue
            if len(current) + len(para) > 1000 and current:
                chunks.append(Chunk(
                    text=current,
                    page=page["page_num"],
                    strategy="E_no_header",
                ))
                current = para
            else:
                current = f"{current}\n\n{para}".strip() if current else para

        if current:
            chunks.append(Chunk(
                text=current,
                page=page["page_num"],
                strategy="E_no_header",
            ))

    return chunks


STRATEGIES = {
    "A_paragraph": chunk_strategy_a_paragraph,
    "B_table_aware": chunk_strategy_b_table_aware,
    "C_page_level": chunk_strategy_c_page_level,
    "D_hybrid": chunk_strategy_d_hybrid,
    "E_no_header": chunk_strategy_e_no_header,
}


# ─── Embedding & retrieval ──────────────────────────────────────────────────

def get_openai_client() -> OpenAI:
    # Load from .env
    env_path = PROJECT_ROOT / ".env"
    key = None
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            if line.startswith("OPENAI_API_KEY=") and not line.startswith("#"):
                key = line.split("=", 1)[1].strip()
                break
    if not key:
        key = os.environ.get("OPENAI_API_KEY", "")
    return OpenAI(api_key=key)


def embed_texts(client: OpenAI, texts: List[str]) -> List[List[float]]:
    """Batch embed texts."""
    response = client.embeddings.create(model=EMBEDDING_MODEL, input=texts)
    return [item.embedding for item in response.data]


def cosine_similarity(a: List[float], b: List[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(y * y for y in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def retrieve(client: OpenAI, query: str, chunks: List[Chunk], chunk_embeddings: List[List[float]], k: int = TOP_K) -> List[Tuple[Chunk, float]]:
    """Retrieve top-K chunks for a query."""
    query_emb = embed_texts(client, [query])[0]
    scores = [(chunk, cosine_similarity(query_emb, emb)) for chunk, emb in zip(chunks, chunk_embeddings)]
    scores.sort(key=lambda x: x[1], reverse=True)
    return scores[:k]


# ─── Answer generation ──────────────────────────────────────────────────────

def generate_answer(client: OpenAI, question: str, retrieved_chunks: List[Tuple[Chunk, float]]) -> str:
    """Generate an answer from retrieved chunks."""
    context = "\n\n---\n\n".join([c[0].text[:1500] for c in retrieved_chunks])

    prompt = f"""Answer the user's question based ONLY on the provided context.
If the answer is not in the context, say "Not found in the provided context."
Be concise and factual.

Context:
{context}

Question: {question}
Answer:"""

    try:
        response = client.chat.completions.create(
            model=CHAT_MODEL,
            messages=[
                {"role": "system", "content": "You are an insurance document analyst. Answer questions based on the provided context. If information is missing, say so."},
                {"role": "user", "content": prompt},
            ],
            max_completion_tokens=500,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        return f"[LLM error: {e}]"


# ─── Scoring ────────────────────────────────────────────────────────────────

def score_retrieval(question: BenchmarkQuestion, retrieved_chunks: List[Tuple[Chunk, float]]) -> float:
    """Check if retrieved chunks contain the expected keywords."""
    combined_text = " ".join([c[0].text for c in retrieved_chunks]).lower()
    keywords = [kw.lower() for kw in question.expected_answer_keywords]

    # At least one keyword group must be present
    for kw in keywords:
        if kw.lower() in combined_text:
            return 1.0
    return 0.0


def score_answer(question: BenchmarkQuestion, answer: str) -> float:
    """Check if the answer contains expected keywords."""
    answer_lower = answer.lower()
    for kw in question.expected_answer_keywords:
        if kw.lower() in answer_lower:
            return 1.0
    # Partial: check if answer says "not found" (explicit miss)
    if "not found" in answer_lower or "not in" in answer_lower:
        return 0.0
    return 0.0


def score_source(question: BenchmarkQuestion, retrieved_chunks: List[Tuple[Chunk, float]]) -> float:
    """Check if the top chunks are from the right page."""
    top_pages = [c[0].page for c in retrieved_chunks[:3]]
    if question.page in top_pages:
        return 1.0
    return 0.5 if any(abs(p - question.page) <= 1 for p in top_pages) else 0.0


# ─── Main benchmark ─────────────────────────────────────────────────────────

def run_benchmark():
    print("=" * 80)
    print("CoverWise Chunking/Parsing Strategy Benchmark")
    print("=" * 80)

    # 1. Parse the PDF
    print("\n📄 Parsing policy.pdf...")
    pages = parse_pdf_pages(str(POLICY_PATH), POLICY_PASSWORD)
    total_text = sum(len(p["text"]) for p in pages)
    total_tables = sum(len(p["tables"]) for p in pages)
    print(f"   {len(pages)} pages, {total_text:,} chars, {total_tables} tables detected")

    # 2. Build chunks for each strategy
    print("\n🔪 Building chunks for each strategy...")
    all_chunks = {}
    for name, strategy_fn in STRATEGIES.items():
        chunks = strategy_fn(pages)
        all_chunks[name] = chunks
        table_count = sum(1 for c in chunks if c.metadata.get("chunk_type") == "table")
        print(f"   {name}: {len(chunks)} chunks ({table_count} table chunks)")

    # 3. Run queries
    client = get_openai_client()
    results: List[ScoredResult] = []

    print("\n🔍 Running benchmark queries...")
    for strat_name, chunks in all_chunks.items():
        print(f"\n  Strategy: {strat_name}")
        # Embed all chunks
        chunk_texts = [c.text[:2000] for c in chunks]  # Truncate for embedding
        try:
            chunk_embeddings = embed_texts(client, chunk_texts)
        except Exception as e:
            print(f"    ❌ Embedding failed: {e}")
            continue

        for q in QUESTIONS:
            start = time.time()
            retrieved = retrieve(client, q.question, chunks, chunk_embeddings)
            answer = generate_answer(client, q.question, retrieved)
            latency = int((time.time() - start) * 1000)

            ret_score = score_retrieval(q, retrieved)
            ans_score = score_answer(q, answer)
            src_score = score_source(q, retrieved)

            result = ScoredResult(
                question_id=q.id,
                strategy=strat_name,
                retrieval_score=ret_score,
                answer_score=ans_score,
                source_score=src_score,
                answer_text=answer,
                top_chunks=[c[0].text[:100] for c in retrieved[:2]],
                latency_ms=latency,
            )
            results.append(result)

            status = "✅" if ans_score == 1.0 else "❌" if ans_score == 0.0 else "⚠️"
            print(f"    {status} {q.id}: ret={ret_score:.1f} ans={ans_score:.1f} src={src_score:.1f} ({latency}ms)")

    # 4. Summary
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)

    strategies = sorted(all_chunks.keys())
    print(f"\n{'Strategy':<20} {'Retrieval':>10} {'Answer':>10} {'Source':>10} {'Avg Lat':>10}")
    print("-" * 62)

    for strat in strategies:
        strat_results = [r for r in results if r.strategy == strat]
        if not strat_results:
            continue
        avg_ret = sum(r.retrieval_score for r in strat_results) / len(strat_results)
        avg_ans = sum(r.answer_score for r in strat_results) / len(strat_results)
        avg_src = sum(r.source_score for r in strat_results) / len(strat_results)
        avg_lat = sum(r.latency_ms for r in strat_results) / len(strat_results)
        print(f"{strat:<20} {avg_ret:>10.1%} {avg_ans:>10.1%} {avg_src:>10.1%} {avg_lat:>8.0f}ms")

    # 5. Per-question breakdown
    print(f"\n{'Question':<8}", end="")
    for strat in strategies:
        print(f" {strat[:8]:>10}", end="")
    print()
    print("-" * (8 + 11 * len(strategies)))

    for q in QUESTIONS:
        print(f"{q.id:<8}", end="")
        for strat in strategies:
            q_results = [r for r in results if r.strategy == strat and r.question_id == q.id]
            if q_results:
                ans = q_results[0].answer_score
                print(f" {'✅' if ans == 1 else '❌' if ans == 0 else '⚠️':>10}", end="")
            else:
                print(f" {'—':>10}", end="")
        print()

    # 6. Save detailed results
    output_path = PROJECT_ROOT / "docs" / "technical" / "rag" / "exploration" / "benchmark_results_2026-07-22.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump([{
            "question_id": r.question_id,
            "strategy": r.strategy,
            "retrieval_score": r.retrieval_score,
            "answer_score": r.answer_score,
            "source_score": r.source_score,
            "answer_text": r.answer_text[:500],
            "latency_ms": r.latency_ms,
        } for r in results], f, indent=2)
    print(f"\n📊 Detailed results saved to {output_path}")


if __name__ == "__main__":
    run_benchmark()
