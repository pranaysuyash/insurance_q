#!/usr/bin/env python3
"""Run a privacy-preserving local OCR/VLM comparison on a PDF fixture.

The report intentionally stores measurements and field-presence checks by
default, not document text. Pass --include-text only for a synthetic fixture or
when the operator has explicit authority to persist document content.
"""

from __future__ import annotations

import argparse
import base64
import json
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

import fitz

DEFAULT_PROMPT = (
    "Transcribe every visible word on this insurance-policy page exactly. "
    "Preserve numbers, dates, currency symbols, headings, and table rows. "
    "Return only the transcription, with no commentary or markdown fence."
)


def normalize(value: str) -> str:
    return "".join(value.casefold().split())


def evaluate_expected(text: str, expected: list[str]) -> dict[str, bool]:
    normalized = normalize(text)
    return {value: normalize(value) in normalized for value in expected}


def render_pdf_pages(pdf_path: Path, max_pages: int, dpi: int) -> list[bytes]:
    document = fitz.open(pdf_path)
    try:
        pages: list[bytes] = []
        scale = dpi / 72
        matrix = fitz.Matrix(scale, scale)
        for page_index in range(min(document.page_count, max_pages)):
            page = document.load_page(page_index)
            pages.append(page.get_pixmap(matrix=matrix, alpha=False).tobytes("png"))
        return pages
    finally:
        document.close()


def extract_embedded_text(pdf_path: Path, max_pages: int) -> str:
    document = fitz.open(pdf_path)
    try:
        return "\n".join(
            document.load_page(page_index).get_text()
            for page_index in range(min(document.page_count, max_pages))
        )
    finally:
        document.close()


def call_ollama(
    endpoint: str,
    model: str,
    pages: list[bytes],
    prompt: str,
    timeout_seconds: int,
) -> dict[str, Any]:
    payload = json.dumps(
        {
            "model": model,
            "prompt": prompt,
            "images": [base64.b64encode(page).decode("ascii") for page in pages],
            "stream": False,
            "options": {"temperature": 0},
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        f"{endpoint.rstrip('/')}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        parsed = json.loads(response.read())
    if not isinstance(parsed, dict):
        raise json.JSONDecodeError("Ollama response is not an object", "", 0)
    return parsed


def run(args: argparse.Namespace) -> dict[str, Any]:
    pdf_path = Path(args.pdf).resolve()
    if not pdf_path.is_file():
        raise FileNotFoundError(pdf_path)

    pages = render_pdf_pages(pdf_path, args.max_pages, args.dpi)
    expected = args.expected or []
    report: dict[str, Any] = {
        "fixture": pdf_path.name,
        "fixture_sha256": __import__("hashlib").sha256(pdf_path.read_bytes()).hexdigest(),
        "page_count_evaluated": len(pages),
        "dpi": args.dpi,
        "expected_tokens": expected,
        "prompt": args.prompt,
        "generated_at_epoch_seconds": time.time(),
        "results": [],
    }

    embedded = extract_embedded_text(pdf_path, args.max_pages)
    report["results"].append(
        {
            "engine": "pymupdf_embedded_text",
            "elapsed_seconds": 0.0,
            "output_characters": len(embedded),
            "expected_token_matches": evaluate_expected(embedded, expected),
            **({"output": embedded} if args.include_text else {}),
        }
    )

    for model in args.models:
        started = time.monotonic()
        try:
            response = call_ollama(
                endpoint=args.ollama_endpoint,
                model=model,
                pages=pages,
                prompt=args.prompt,
                timeout_seconds=args.timeout_seconds,
            )
            output = str(response.get("response", ""))
            result: dict[str, Any] = {
                "engine": "ollama",
                "model": model,
                "elapsed_seconds": round(time.monotonic() - started, 3),
                "output_characters": len(output),
                "expected_token_matches": evaluate_expected(output, expected),
                "ollama_completion": {
                    key: response[key]
                    for key in (
                        "done",
                        "done_reason",
                        "total_duration",
                        "load_duration",
                        "prompt_eval_count",
                        "eval_count",
                    )
                    if key in response
                },
            }
            if args.include_text:
                result["output"] = output
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            result = {
                "engine": "ollama",
                "model": model,
                "elapsed_seconds": round(time.monotonic() - started, 3),
                "error": str(error),
            }
        report["results"].append(result)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", help="PDF fixture to evaluate")
    parser.add_argument("--models", nargs="+", required=True, help="Ollama vision models")
    parser.add_argument("--expected", action="append", help="Exact token expected in output; repeatable")
    parser.add_argument("--max-pages", type=int, default=1)
    parser.add_argument("--dpi", type=int, default=150)
    parser.add_argument("--ollama-endpoint", default="http://127.0.0.1:11434")
    parser.add_argument("--timeout-seconds", type=int, default=600)
    parser.add_argument("--prompt", default=DEFAULT_PROMPT)
    parser.add_argument("--output", required=True, help="JSON report destination")
    parser.add_argument("--include-text", action="store_true")
    args = parser.parse_args()

    report = run(args)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
