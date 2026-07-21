"""Execution boundary for approved evaluation manifests.

The registry governs what may run; this service governs how a run is recorded.
It deliberately accepts an injected evaluator so model/provider routing stays
outside the data and lineage layer. Raw prompts, answers, and customer source
text are never written to the results table.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any, Awaitable, Callable, Optional
from uuid import UUID

from src.services.dataset_registry import DatasetRegistry
from src.services.model_lineage_service import ModelLineageService


class DatasetExecutionError(RuntimeError):
    pass


EvaluationResult = dict[str, Any]
Evaluator = Callable[[dict[str, Any]], Awaitable[EvaluationResult]]


def _bounded_metrics(value: Any) -> dict[str, Any]:
    """Keep evaluator telemetry structured and free of raw model content."""
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise DatasetExecutionError("evaluator metrics must be an object")
    safe: dict[str, Any] = {}
    for key, item in value.items():
        name = str(key)[:80]
        if isinstance(item, (bool, int, float)) or item is None:
            safe[name] = item
        elif isinstance(item, str):
            safe[name] = item[:256]
        elif isinstance(item, list) and len(item) <= 20 and all(
            isinstance(entry, (bool, int, float, str)) or entry is None
            for entry in item
        ):
            safe[name] = [entry[:256] if isinstance(entry, str) else entry for entry in item]
        else:
            raise DatasetExecutionError("evaluator metrics contain unsupported content")
    return safe


class DatasetExecutionService:
    def __init__(
        self,
        registry: DatasetRegistry,
        lineage: ModelLineageService,
        client: Optional[Any] = None,
    ):
        self._registry = registry
        self._lineage = lineage
        self._client = client or getattr(lineage, "_client", None)
        if self._client is None:
            raise DatasetExecutionError("a service-role client is required")

    async def execute_evaluation(
        self,
        release_id: UUID,
        *,
        provider: str,
        model_name: str,
        config: dict[str, Any],
        created_by: str,
        evaluator: Evaluator,
        model_version: Optional[str] = None,
    ) -> dict[str, Any]:
        manifest = await self._registry.materialize_manifest(release_id)
        run_id = await self._lineage.start_run(
            release_id,
            "evaluation",
            provider,
            model_name,
            config,
            created_by,
            model_version=model_version,
        )
        try:
            manifest_bytes = json.dumps(
                manifest, sort_keys=True, separators=(",", ":"), default=str
            ).encode("utf-8")
            await self._lineage.record_artifact(
                run_id,
                "manifest",
                f"manifest:{manifest['manifest_hash']}",
                manifest_bytes,
                metrics={"item_count": len(manifest["items"])},
            )

            counts = {"passed": 0, "failed": 0, "error": 0}
            scores: list[float] = []
            for item in manifest["items"]:
                try:
                    result = await evaluator(item)
                    status = str(result.get("status", "error"))
                    if status not in counts:
                        raise DatasetExecutionError("evaluator returned invalid status")
                    score = result.get("score")
                    if score is not None:
                        score = float(score)
                        if not 0 <= score <= 1:
                            raise DatasetExecutionError("evaluator score must be between 0 and 1")
                        scores.append(score)
                    output_hash = result.get("output_hash")
                    if output_hash is None and result.get("output") is not None:
                        output_hash = hashlib.sha256(
                            str(result["output"]).encode("utf-8")
                        ).hexdigest()
                    self._client.table("model_run_results").upsert({
                        "model_run_id": str(run_id),
                        "dataset_item_id": str(item["id"]),
                        "status": status,
                        "score": score,
                        "output_hash": output_hash,
                        "metrics": _bounded_metrics(result.get("metrics")),
                        "error_class": result.get("error_class"),
                    }, on_conflict="model_run_id,dataset_item_id").execute()
                    counts[status] += 1
                except Exception as error:
                    self._client.table("model_run_results").upsert({
                        "model_run_id": str(run_id),
                        "dataset_item_id": str(item["id"]),
                        "status": "error",
                        "error_class": type(error).__name__,
                    }, on_conflict="model_run_id,dataset_item_id").execute()
                    counts["error"] += 1

            metrics = {
                "item_count": len(manifest["items"]),
                "passed": counts["passed"],
                "failed": counts["failed"],
                "errors": counts["error"],
                "mean_score": sum(scores) / len(scores) if scores else None,
                "manifest_hash": manifest["manifest_hash"],
            }
            await self._lineage.finish_run(run_id, "completed", metrics)
            return {"run_id": str(run_id), **metrics}
        except Exception as error:
            await self._lineage.finish_run(
                run_id, "failed", {"error_class": type(error).__name__}
            )
            raise
