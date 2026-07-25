#!/usr/bin/env python3
"""Run a small, synthetic-only structured-output smoke evaluation.

This intentionally never reads the CoverWise policy corpus.  It is for checking
whether a configured hosted provider can follow the app's minimum contract:
valid JSON, refusal to invent an absent field, and source-id grounding.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


SYNTHETIC_DOCUMENT = """SOURCE A (page 1)
Example Assurance Policy SYN-2026-001
Policyholder: Alex Example
Sum insured: INR 500,000
Coverage starts: 2026-01-01

SOURCE B (page 2)
The annual premium is INR 12,000. Claims phone: 1800-000-000.
"""

TASKS = (
    {
        "name": "structured_extraction",
        "instruction": "Return exactly one JSON object with policy_number, sum_insured_inr, and source_ids. source_ids must contain only SOURCE A or SOURCE B.",
        "checks": {"policy_number": "SYN-2026-001", "sum_insured_inr": 500000, "source_ids": ["SOURCE A"]},
    },
    {
        "name": "unsupported_field",
        "instruction": "Return exactly one JSON object with insurer_branch_address. The address is not in the sources, so its value must be null. Include source_ids as an empty array.",
        "checks": {"insurer_branch_address": None, "source_ids": []},
    },
    {
        "name": "grounded_answer",
        "instruction": "Return exactly one JSON object with annual_premium_inr and source_ids. Use only the sources.",
        "checks": {"annual_premium_inr": 12000, "source_ids": ["SOURCE B"]},
    },
)


@dataclass
class TaskResult:
    name: str
    latency_ms: int
    valid_json: bool
    passed: bool
    error_kind: str | None = None


def load_dotenv(path: Path) -> dict[str, str]:
    """Parse simple KEY=value dotenv entries without executing their contents."""
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip().removeprefix("export ").strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        if key:
            values[key] = value
    return values


def api_config(provider: str, env: dict[str, str], model_overrides: dict[str, str]) -> tuple[str, str, str]:
    configs = {
        "openai": ("OPENAI_API_KEY", "https://api.openai.com/v1/chat/completions", "gpt-5-nano"),
        "openrouter": ("OPENROUTER_API_KEY", "https://openrouter.ai/api/v1/chat/completions", "google/gemini-2.5-flash-lite"),
        "groq": ("GROQ_API_KEY", "https://api.groq.com/openai/v1/chat/completions", "llama-3.3-70b-versatile"),
        "hf": ("HF_TOKEN", "https://router.huggingface.co/v1/chat/completions", "Qwen/Qwen3-4B-Instruct-2507"),
    }
    key_name, endpoint, default_model = configs[provider]
    key = env.get(key_name) or (env.get("HUGGINGFACE_API_KEY") if provider == "hf" else None)
    if not key:
        raise RuntimeError(f"missing credential key name: {key_name}")
    return key, endpoint, model_overrides.get(provider, default_model)


def extract_json(text: str) -> dict[str, Any]:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1].rsplit("```", 1)[0].strip()
    return json.loads(text)


def invoke_openai_compatible(provider: str, endpoint: str, key: str, model: str, task: dict[str, Any]) -> tuple[dict[str, Any], int, str | None]:
    prompt = f"""You are a precise insurance-document extraction component. Do not add facts.\n\n{SYNTHETIC_DOCUMENT}\n\nTASK: {task['instruction']}"""
    body: dict[str, Any] = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "response_format": {"type": "json_object"},
    }
    if provider != "openai":
        body["temperature"] = 0
    # GPT-5 chat-completions rejects the deprecated max_tokens field; the other
    # OpenAI-compatible gateways used here retain max_tokens compatibility.
    if provider == "openai":
        # GPT-5 can spend completion tokens on internal reasoning before text;
        # 220 yielded empty visible content in a live synthetic probe.
        body["reasoning_effort"] = "minimal"
        body["max_completion_tokens"] = 1000
    else:
        body["max_tokens"] = 220
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    started = time.perf_counter()
    with urllib.request.urlopen(request, timeout=45) as response:
        payload = json.loads(response.read().decode("utf-8"))
    latency_ms = round((time.perf_counter() - started) * 1000)
    choice = payload["choices"][0]["message"]["content"]
    reported_model = payload.get("model")
    return extract_json(choice), latency_ms, reported_model


def matches_checks(result: dict[str, Any], checks: dict[str, Any]) -> bool:
    for key, expected in checks.items():
        actual = result.get(key)
        if key == "source_ids":
            if sorted(actual or []) != sorted(expected):
                return False
        elif actual != expected:
            return False
    return True


def safe_error(error: Exception) -> str:
    if isinstance(error, urllib.error.HTTPError):
        return f"http_{error.code}"
    if isinstance(error, urllib.error.URLError):
        return "network_error"
    if isinstance(error, json.JSONDecodeError):
        return "invalid_json"
    message = str(error).lower()
    if "missing credential" in message:
        return "missing_credential"
    return "request_error"


def evaluate(provider: str, env: dict[str, str], overrides: dict[str, str]) -> dict[str, Any]:
    key, endpoint, model = api_config(provider, env, overrides)
    results: list[TaskResult] = []
    reported_model: str | None = None
    for task in TASKS:
        started = time.perf_counter()
        try:
            answer, latency_ms, observed_model = invoke_openai_compatible(provider, endpoint, key, model, task)
            reported_model = observed_model or reported_model
            results.append(TaskResult(task["name"], latency_ms, True, matches_checks(answer, task["checks"])))
        except Exception as error:  # result intentionally records category only, never provider body
            results.append(TaskResult(task["name"], round((time.perf_counter() - started) * 1000), False, False, safe_error(error)))
    passed = sum(item.passed for item in results)
    return {
        "provider": provider,
        "requested_model": model,
        "reported_model": reported_model,
        "endpoint_family": "openai_compatible_chat_completions",
        "synthetic_only": True,
        "task_count": len(results),
        "passed_count": passed,
        "schema_and_grounding_pass_rate": round(passed / len(results), 3),
        "median_latency_ms": sorted(item.latency_ms for item in results)[len(results) // 2],
        "tasks": [asdict(item) for item in results],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provider", action="append", choices=("openai", "openrouter", "groq", "hf"), required=True)
    parser.add_argument("--dotenv", action="append", type=Path, default=[], help="Optional dotenv file; parsed but never executed.")
    parser.add_argument("--model", action="append", default=[], metavar="PROVIDER=MODEL")
    parser.add_argument("--output", type=Path, help="Write a sanitized JSON result; refuses to overwrite.")
    args = parser.parse_args()

    overrides: dict[str, str] = {}
    for item in args.model:
        if "=" not in item:
            parser.error("--model must be PROVIDER=MODEL")
        provider, model = item.split("=", 1)
        overrides[provider] = model
    env = dict(os.environ)
    for dotenv_path in args.dotenv:
        if not dotenv_path.is_file():
            parser.error(f"dotenv path does not exist: {dotenv_path}")
        env.update(load_dotenv(dotenv_path))

    report = {
        "evaluation": "provider_smoke_v1",
        "run_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "fixture_sha256": hashlib.sha256(SYNTHETIC_DOCUMENT.encode("utf-8")).hexdigest(),
        "results": [evaluate(provider, env, overrides) for provider in args.provider],
    }
    output = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        if args.output.exists():
            parser.error(f"refusing to overwrite existing output: {args.output}")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
    print(output, end="")
    return 0 if all(result["passed_count"] == result["task_count"] for result in report["results"]) else 1


if __name__ == "__main__":
    sys.exit(main())
