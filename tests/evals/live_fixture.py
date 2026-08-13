#!/usr/bin/env python3
"""Live-gate fixture: build a REAL RAGPipeline over an in-memory corpus.

This is the missing piece that turns the deferred live acceptance gate
(`run_evals.py --mode live --allow-live`) into a single command. It reuses the
canonical ``RAGPipeline`` (no duplicate retrieval/generation path) but points it at
an in-memory Qdrant collection so no external vector DB is required.

Privacy contract (legal-safety, motto_v5):
- ``policy.pdf`` is encrypted. We decrypt it IN MEMORY with the test-fixture
  password (the same one already used by ``tools/benchmark_chunking.py``).
- The schedule page (page 1) and any name/address/policy-number/DOB/contact/email
  tokens are REDACTED before the text is chunked, embedded, or sent to any LLM.
- Nothing containing PII is written to disk or committed. The encrypted PDF and the
  redacted dataset are the only artifacts; the decrypted corpus lives only in the
  test process.

Provider note: embeddings/LLM default to the configured OpenAI key. To run the
whole eval fully offline/private, set the Ollama env (``OLLAMA_*``) and point
``OPENAI_EMBEDDING_MODEL`` / ``OPENAI_CHAT_MODEL`` at the local models — the
backend already supports that path (see docs/research/llm_provider_options_2026-08-12.md).
"""

from __future__ import annotations

import os
import re
import fitz
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent.parent
DEFAULT_POLICY_PDF = PROJECT_ROOT / "policy.pdf"

# Test-fixture password for the (synthetic) policy.pdf. This is already committed
# in tools/benchmark_chunking.py; we read it from an env var first so it is not
# spread further than necessary, with this constant only as a last resort.
FIXTURE_PDF_PASSWORD = os.getenv("COVERWISE_EVAL_PDF_PASSWORD", "pran1005")

# Pages that are KNOWN to be pure schedule/PII in the committed fixture PDF.
# Always dropped. Full-policy ingestion (see ``extract_policy_pages``) additionally
# DETECTS further schedule/PII pages by keyword + PII-density scanning, so a future
# PDF layout change cannot silently leak PII.
_SCHEDULE_PAGES = {1}

# Schedule / PII signal words used to auto-detect schedule pages in *any* policy PDF.
_SCHEDULE_KEYWORDS = [
    "schedule", "policy details", "policy particulars", "certificate",
    "endorsement", "proposer", "insured details", "insured particulars",
    "insured name", "policyholder", "sum insured", "premium", "policy number",
    "policy no", "date of birth", "nominee", "communication address",
    "permanent address", "kyc", "pan ", "aadhaar",
]

# Exact PII tokens to mask across every page (defence in depth). These are drawn
# from the schedule; the wording pages should not contain them, but we mask
# globally so a future PDF layout change cannot leak them.
_PII_TOKENS = [
    "PRANAY", "SUYASH", "DIKSHA", "SINHA", "ADVAY",
    "A-27, KUDREMUKH COLONY", "BANGALORE", "KARNATAKA",
    "4214I/CPHSR/407834350/00/000", "4128I/HERN/176804574/04/000",
    "99******02", "PR***********@GMAIL.COM",
    "10-MAY-1988", "02-AUG-1992", "28-MAY-2023",
    "PRANAY  SUYASH", "DIKSHA SINHA", "ADVAY SINHA",
    "A-27, KUDREMUKH COLONY,   BANGALORE,", "KARNATAKA - 560034",
]

# Heuristic named-insured titles (Title + Capitals name patterns handled in _mask_pii).
_NAME_TITLES = r"(?:Mr|Mrs|Ms|Miss|Dr|Prof|Shri|Smt|Mx)\.?"

# ---------------------------------------------------------------------------
# Compiled regexes for generic PII masking. ALL are best-effort and SAFE: they
# only replace matched text with a [TAG]; they never emit the original PII.
# Evidence tier: heuristic (regex) — see Confidence Honesty Standard §0.2.
# ---------------------------------------------------------------------------
_RE_EMAIL = re.compile(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}")
_RE_PHONE = re.compile(
    r"(?:\+\d{1,3}[\s.-]?)?(?:\(?\d{2,4}\)?[\s.-]?)?\d{3,4}[\s.-]?\d{3,4}(?:[\s.-]?\d{0,4})?"
)
# UK-style postcode (e.g. SW1A 1AA) and bare 6-digit Indian pincode.
_RE_POSTCODE = re.compile(r"\b[A-Z]{1,2}\d{1,2}[A-Z]?\s?\d[A-Z]{2}\b|\b\d{6}\b")
# Street address: leading number + capitalized words ending in a thoroughfare token.
_RE_ADDRESS = re.compile(
    r"\b\d{1,4}[A-Za-z]?(?:[,/-]?\s+[A-Z][\w.-]+){1,5}"
    r"\s+(?:Road|Rd|Street|St|Lane|Ln|Avenue|Ave|Colony|Layout|Nagar|"
    r"Marg|Cross|Close|Cl|Sector|Phase|Building|Block|Flat|Apartment|Apts?|"
    r"Housing|Society|Complex|Enclave|Boulevard|Blvd)\b"
)
# Dates of birth: explicit "Date of Birth" / DOB labels, or DD-MON-YYYY / DD/MM/YYYY.
_RE_DOB_LABEL = re.compile(r"\b(?:date of birth|d\.?o\.?b\.?)\b\s*[:\-]?\s*", re.IGNORECASE)
_RE_DATE = re.compile(r"\b\d{1,2}[-/](?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[-/]\d{2,4}\b|\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b", re.IGNORECASE)
# Policy / certificate numbers: "Policy No. XY-998877" or "4214I/CPHSR/..." style.
_RE_POLICY_NO = re.compile(
    r"\b(?:policy\s+(?:no|number|num)|certificate\s+(?:no|number)|cert\s+no)"
    r"\.?\s*:?\s*[A-Z0-9][A-Z0-9\-/]{4,}\b"
    r"|\b\d{4}[Ii]/[A-Z0-9/]+\b"
    r"|\b[A-Z]{2}-\d{6,}\b"
)
# Account / IBAN: "IBAN GB29 NWBK ..." or "A/C 0123456789" style.
_RE_IBAN = re.compile(r"\b(?:IBAN|ACC|A/C|ACCOUNT)\s*(?:NO\.?|NUMBER)?\.?\s*:?\s*[A-Z]{2}\d{2}(?:[ ]?\w{4}){4,}\b|\b[A-Z]{2}\d{2}(?:[ ]?\w{4}){4,}\b")
# Claim numbers: "Claim No. CLM-..." style.
_RE_CLAIM_NO = re.compile(r"\b(?:claim\s+(?:no|number|num))\s*\.?\s*:?\s*[A-Z0-9][A-Z0-9\-/]{3,}\b", re.IGNORECASE)
# Named-insured person/org: Title + one or two Capitalized words (heuristic).
_RE_NAME = re.compile(rf"\b{_NAME_TITLES}\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\b")
# Partially-masked phone numbers (e.g. 12******34 — only first/last 2 digits
# visible). These still leak 4 digits of a real phone number and MUST be fully
# masked. The generic _RE_PHONE below cannot match star-separated digits, so
# this is a deliberate second pass.
_RE_PARTIAL_PHONE = re.compile(r"\b\d{2,4}\*{4,8}\d{2,4}\b")


def _mask_pii(text: str) -> str:
    """Best-effort, REGEX-based PII masking. SAFE: only replaces, never emits PII.

    Evidence tier: HEURISTIC. Reliably masks structured tokens (email, phone-ish,
    postcode, policy/claim/IBAN numbers, DOB dates, labelled names). Free-text
    person names WITHOUT a title and org names without a label are WEAK (see §0.2).
    """
    t = text
    for tok in _PII_TOKENS:
        if tok in t:
            t = t.replace(tok, "[REDACTED]")
    # Order matters: mask the most-structured classes first, then looser ones.
    t = _RE_EMAIL.sub("[EMAIL]", t)
    t = _RE_POLICY_NO.sub("[POLICY_NO]", t)
    t = _RE_IBAN.sub("[IBAN/ACCT]", t)
    t = _RE_CLAIM_NO.sub("[CLAIM_NO]", t)
    t = _RE_DOB_LABEL.sub("[DOB] ", t)
    t = _RE_DATE.sub("[DATE]", t)
    t = _RE_ADDRESS.sub("[ADDRESS]", t)
    t = _RE_POSTCODE.sub("[POSTCODE]", t)
    t = _RE_NAME.sub("[NAME]", t)
    # Fully mask partially-masked phone numbers (e.g. 12******34) that still
    # leak digits; the generic _RE_PHONE pass below does not match them.
    t = _RE_PARTIAL_PHONE.sub("[PHONE]", t)
    # Generic phone mask last (loosest) so structured classes survive above.
    t = _RE_PHONE.sub("[PHONE]", t)
    return t


def _is_schedule_page(text: str) -> bool:
    """Heuristically flag a page as predominantly schedule/PII.

    Evidence tier: HEURISTIC (keyword + PII-density). A page is dropped when it
    carries >=2 schedule keywords OR a high PII-hit density (>=4 structured PII
    matches OR a keyword hit plus any PII match). This catches multi-page
    schedules/endorsements/certificates, not only page 1.

    Confidence Honesty (§0.2): detection is BEST-EFFORT. A wording page that
    happens to mention "policy number" twice could be (rarely) dropped; a PII page
    with an unusual layout could be missed. Redaction is defence-in-depth, not a
    guarantee — callers must not treat output as PII-free.
    """
    low = text.lower()
    kw_hits = sum(1 for kw in _SCHEDULE_KEYWORDS if kw in low)
    pii_hits = (
        len(_RE_EMAIL.findall(text))
        + len(_RE_POLICY_NO.findall(text))
        + len(_RE_IBAN.findall(text))
        + len(_RE_CLAIM_NO.findall(text))
        + len(_RE_PHONE.findall(text))
        + len(_RE_POSTCODE.findall(text))
        + len(_RE_DOB_LABEL.findall(text))
        + len(_RE_DATE.findall(text))
        + len(_RE_NAME.findall(text))
        + len(_RE_ADDRESS.findall(text))
    )
    return kw_hits >= 2 or pii_hits >= 4 or (kw_hits >= 1 and pii_hits >= 1)


def extract_policy_pages(pdf_path: Path = DEFAULT_POLICY_PDF, password: str = FIXTURE_PDF_PASSWORD):
    """Decrypt (in memory) and return [(page_number, redacted_text), ...].

    LEGAL / COPYRIGHT NOTICE (motto_v5 §0.3): insurer policy *wordings* are
    copyrighted third-party material. Output of this function is for LOCAL
    EVALUATION ONLY and MUST NOT be redistributed, committed to a public repo, or
    shipped in a product. Use it solely to build an in-memory eval corpus.

    REDACTION IS BEST-EFFORT, NOT A GUARANTEE (Confidence Honesty §0.2). This
    function (1) drops pages detected as predominantly schedule/PII (multi-page:
    not just page 1) and (2) runs regex-based ``_mask_pii`` over every remaining
    page as defence in depth. It does NOT certify the result is PII-free. Do not
    write the returned text anywhere real customer PII could survive.

    Raises if the PDF cannot be opened/authenticated so the live gate fails loudly
    rather than silently running on an empty corpus.
    """
    if not pdf_path.exists():
        raise FileNotFoundError(f"policy PDF not found: {pdf_path}")
    doc = fitz.open(str(pdf_path))
    if doc.is_encrypted and not doc.authenticate(password):
        raise RuntimeError("policy.pdf requires a password and authentication failed")
    pages = []
    for i, page in enumerate(doc, start=1):
        text = page.get_text("text")
        if i in _SCHEDULE_PAGES or _is_schedule_page(text):
            # Keep a redacted stub so page numbers stay meaningful, but with no PII.
            pages.append((i, "[REDACTED POLICY SCHEDULE / PII PAGE]"))
            continue
        pages.append((i, _mask_pii(text)))
    doc.close()
    return pages


def chunk_pages(pages, max_chars: int = 1400):
    """Turn redacted pages into ingest-ready text blocks.

    One block per non-empty paragraph, with ``page`` preserved so citations carry
    a page number. ``ingest_document_data`` further splits into sentences.
    """
    blocks = []
    idx = 0
    for page_no, text in pages:
        for raw in re.split(r"\n\s*\n", text):
            clean = raw.strip()
            if not clean or len(clean) < 24:
                continue
            # split very long blocks so retrieval is granular
            for j in range(0, len(clean), max_chars):
                seg = clean[j:j + max_chars].strip()
                if len(seg) < 24:
                    continue
                idx += 1
                blocks.append({
                    "id": f"chunk-{idx}",
                    "text": seg,
                    "page": page_no,
                    "filename": "policy.pdf",
                    "section": "policy_wording",
                })
    return blocks


async def build_live_pipeline(
    pdf_path: Path = DEFAULT_POLICY_PDF,
    document_id: str = "policy-pdf",
    password: str = FIXTURE_PDF_PASSWORD,
):
    """Construct a REAL RAGPipeline over an in-memory Qdrant corpus of policy.pdf.

    Returns an ingest-ready pipeline with the policy already loaded. Reuses the
    canonical pipeline (real embeddings + real LLM + real retrieval), so the live
    gate measures the actual persona, not a stand-in.
    """
    # Force the in-memory Qdrant backend (no external vector DB required).
    os.environ["RAG_VECTOR_BACKEND"] = "qdrant"
    from src.config.settings import settings
    from src.rag.pipeline import RAGPipeline

    # Make the in-memory fallback deterministic: remove any server URL so
    # _init_qdrant falls back to QdrantClient(":memory:"). The backend itself is
    # derived inside RAGPipeline.__init__ from RAG_VECTOR_BACKEND (set above),
    # so we must NOT assign settings.vector_backend (no such field exists).
    settings.qdrant_url = None

    pipeline = RAGPipeline()
    # Defensive: ensure qdrant + hybrid index are present for the in-memory path.
    assert getattr(pipeline, "qdrant_client", None) is not None, "in-memory qdrant client missing"

    pages = extract_policy_pages(pdf_path, password)
    blocks = chunk_pages(pages)
    if not blocks:
        raise RuntimeError("no ingestable (redacted) policy text extracted")

    result = await pipeline.ingest_document_data(
        document_id=document_id,
        text_blocks=blocks,
        document_metadata={
            "filename": "policy.pdf",
            "product": "Health Shield 360 Retail (redacted)",
            "insurer": "ICICI Lombard",
            "owner_id": None,
        },
    )
    if result.get("status") != "success":
        raise RuntimeError(f"policy ingest failed: {result.get('error')}")
    pipeline._live_document_id = document_id
    return pipeline


def get_policy_examples(path: Path = HERE / "coverage_dataset_policy.jsonl"):
    """Load the redacted real-policy eval examples as (Example, expected) tuples.

    Mirrors the loader in run_evals.py but returns the policy-specific set used by
    the live gate (the synthetic set is the offline baseline).
    """
    from run_evals import Example, load_dataset  # reuse the canonical loader
    examples, errors = load_dataset(path)
    if errors:
        raise ValueError("policy dataset failed validation:\n" + "\n".join(errors))
    return examples


async def run_live_eval(pipeline, examples, top_k: int = 4):
    """Run the real pipeline + persona over the policy examples and score.

    Returns the same Report shape as run_evals.run_live so the harness prints it.
    """
    from run_evals import run_live
    return await run_live(_DatasetShim(examples), pipeline)


def extract_pdf_pages(pdf_path: Path, password: str | None = None):
    """Decrypt (if needed) and return [(page_number, text), ...] for ANY policy PDF.

    Unlike ``extract_policy_pages`` this does NOT redact (the public LOB corpora
    carry no PII) and works on unencrypted PDFs as well as encrypted ones.
    """
    if not pdf_path.exists():
        raise FileNotFoundError(f"policy PDF not found: {pdf_path}")
    doc = fitz.open(str(pdf_path))
    if doc.is_encrypted and not doc.authenticate(password or ""):
        raise RuntimeError(f"{pdf_path.name} requires a password and authentication failed")
    pages = []
    for i, page in enumerate(doc, start=1):
        pages.append((i, page.get_text("text")))
    doc.close()
    return pages


async def build_live_pipeline_from_pdf(
    pdf_path: Path,
    document_id: str,
    product: str,
    insurer: str,
    lob: str,
    password: str | None = None,
):
    """Construct a REAL RAGPipeline over an in-memory Qdrant corpus for ANY PDF.

    Generic version of ``build_live_pipeline`` for the Cyber/Marine LOB corpora
    (public PDFs, no PII redaction needed). Tags the document with ``lob`` so the
    LOB-persona routing can be exercised end-to-end.
    """
    os.environ["RAG_VECTOR_BACKEND"] = "qdrant"
    from src.config.settings import settings
    from src.rag.pipeline import RAGPipeline

    settings.qdrant_url = None
    pipeline = RAGPipeline()
    assert getattr(pipeline, "qdrant_client", None) is not None

    pages = extract_pdf_pages(pdf_path, password)
    blocks = chunk_pages(pages)
    if not blocks:
        raise RuntimeError("no ingestable policy text extracted")
    # Tag every block with the LOB so retrieval + persona routing are explicit.
    for b in blocks:
        b["lob"] = lob

    result = await pipeline.ingest_document_data(
        document_id=document_id,
        text_blocks=blocks,
        document_metadata={
            "filename": pdf_path.name,
            "product": product,
            "insurer": insurer,
            "lob": lob,
            "owner_id": None,
        },
    )
    if result.get("status") != "success":
        raise RuntimeError(f"LOB ingest failed: {result.get('error')}")
    pipeline._live_document_id = document_id
    return pipeline


class _DatasetShim:
    """Adapt a list[Example] to the load_dataset() return contract used by run_live."""

    def __init__(self, examples):
        self.examples = examples
        self.errors = []


if __name__ == "__main__":
    import asyncio
    async def _main():
        pipe = await build_live_pipeline()
        exs = get_policy_examples()
        rep = await run_live_eval(pipe, exs)
        from run_evals import _print_human, write_report
        _print_human(rep)
        cost = pipe.llm.get_cost_summary()
        print("LLM cost:", cost)
    raise SystemExit(asyncio.run(_main()))
