import asyncio
import logging
from typing import Optional
from dataclasses import dataclass, field
from openai import AsyncOpenAI
from src.config.settings import settings

logger = logging.getLogger(__name__)

MODEL_PRICING = {
    "gpt-4.1-nano":     {"input": 0.10, "output": 0.40},
    "gpt-4o-mini":      {"input": 0.15, "output": 0.60},
    "gpt-4o":            {"input": 2.50, "output": 10.00},
    "gpt-5-nano":        {"input": 0.05, "output": 0.40},
    "gpt-5.4-nano":      {"input": 0.20, "output": 0.40},
}

# Models that support "json_schema" response format (structured outputs)
JSON_SCHEMA_MODELS = {
    "gpt-4o", "gpt-4.1-nano", "gpt-5-nano", "gpt-5.4-nano",
}


@dataclass
class UsageRecord:
    model: str
    input_tokens: int
    output_tokens: int
    input_cost: float
    output_cost: float

    @property
    def total_cost(self) -> float:
        return self.input_cost + self.output_cost


@dataclass
class CostTracker:
    records: list[UsageRecord] = field(default_factory=list)
    _total_input_tokens: int = 0
    _total_output_tokens: int = 0
    _total_cost: float = 0.0

    def record(
        self,
        model: str,
        input_tokens: int,
        output_tokens: int,
    ):
        pricing = MODEL_PRICING.get(model, {"input": 0.0, "output": 0.0})
        input_cost = (input_tokens / 1_000_000) * pricing["input"]
        output_cost = (output_tokens / 1_000_000) * pricing["output"]
        rec = UsageRecord(model, input_tokens, output_tokens, input_cost, output_cost)
        self.records.append(rec)
        self._total_input_tokens += input_tokens
        self._total_output_tokens += output_tokens
        self._total_cost += rec.total_cost

    @property
    def summary(self) -> dict:
        return {
            "total_input_tokens": self._total_input_tokens,
            "total_output_tokens": self._total_output_tokens,
            "total_cost": round(self._total_cost, 6),
            "total_calls": len(self.records),
        }


class LLMClient:
    def __init__(self):
        self.model = settings.openai_chat_model
        self.client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.cost_tracker = CostTracker()
        self._semaphore = asyncio.Semaphore(5)

        # Ollama client (local fallback)
        self._ollama_client: Optional[AsyncOpenAI] = None
        self._ollama_enabled = bool(settings.ollama_base_url and settings.ollama_chat_model)

        # MLX client (Apple Silicon local LLM)
        self._mlx_client: Optional[AsyncOpenAI] = None
        self._mlx_enabled = settings.mlx_enabled

    def _get_ollama_client(self) -> AsyncOpenAI:
        """Lazy-initialize Ollama client."""
        if self._ollama_client is None and self._ollama_enabled:
            self._ollama_client = AsyncOpenAI(
                base_url=settings.ollama_base_url,
                api_key=settings.ollama_api_key,
            )
        return self._ollama_client

    def _get_mlx_client(self) -> Optional[AsyncOpenAI]:
        """Lazy-initialize MLX client."""
        if self._mlx_client is None and self._mlx_enabled:
            self._mlx_client = AsyncOpenAI(
                base_url=settings.mlx_base_url,
                api_key="mlx",
            )
        return self._mlx_client

    def _is_permanent_error(self, error: Exception) -> bool:
        err_str = str(error).lower()
        return any(k in err_str for k in ["insufficient_quota", "quota", "invalid_api_key", "invalid_api_key"])

    def _supports_json_schema(self, model: str) -> bool:
        """Check if model supports json_schema response format."""
        if model in JSON_SCHEMA_MODELS:
            return True
        # Local models (Ollama, MLX) don't support json_schema yet
        if model.startswith("ollama/") or "llama" in model.lower() or "mistral" in model.lower() or "qwen" in model.lower() or "phi" in model.lower() or "gemma" in model.lower():
            return False
        if model.startswith("mlx-community/") or model == settings.mlx_model:
            return False
        return False

    def _adapt_response_format(
        self, rf: Optional[dict], model: str, messages: list[dict]
    ) -> tuple[Optional[dict], list[dict]]:
        """Adapt response_format for models that don't support json_schema."""
        if rf is None or rf.get("type") != "json_schema":
            return rf, messages
        if self._supports_json_schema(model):
            return rf, messages
        adapted_messages = list(messages)
        if adapted_messages and adapted_messages[0].get("role") == "system":
            adapted_messages[0] = {
                **adapted_messages[0],
                "content": adapted_messages[0]["content"]
                + "\n\nYou MUST respond with valid JSON matching the requested schema. No markdown, no explanation.",
            }
        return {"type": "json_object"}, adapted_messages

    def _select_client(self, model: str):
        """Select the appropriate client based on model name."""
        if self._ollama_enabled and (model in (settings.ollama_chat_model, settings.ollama_alt_model) or model.startswith("ollama/")):
            return self._get_ollama_client()
        if self._mlx_enabled and (model == settings.mlx_model or model.startswith("mlx-community/")):
            return self._get_mlx_client()
        return self.client

    async def generate(
        self,
        messages: list[dict],
        temperature: float = 0.2,
        max_tokens: Optional[int] = None,
        response_format: Optional[dict] = None,
        max_retries: int = 3,
        fallback_models: Optional[list[str]] = None,
    ) -> str:
        models_to_try = [self.model] + (fallback_models or [])
        if self._ollama_enabled:
            if settings.ollama_chat_model not in models_to_try:
                models_to_try.append(settings.ollama_chat_model)
            if settings.ollama_alt_model not in models_to_try:
                models_to_try.append(settings.ollama_alt_model)
        if self._mlx_enabled and settings.mlx_model not in models_to_try:
            models_to_try.append(settings.mlx_model)
        last_error = None

        for model in models_to_try:
            client = self._select_client(model)
            adapted_rf, adapted_messages = self._adapt_response_format(
                response_format, model, messages
            )
            for attempt in range(1, max_retries + 1):
                try:
                    kwargs = dict(
                        model=model,
                        messages=adapted_messages,
                        temperature=temperature,
                    )
                    if max_tokens is not None:
                        kwargs["max_tokens"] = max_tokens
                    if adapted_rf is not None:
                        kwargs["response_format"] = adapted_rf

                    async with self._semaphore:
                        response = await client.chat.completions.create(**kwargs)

                    usage = response.usage
                    if usage:
                        self.cost_tracker.record(
                            model=model,
                            input_tokens=usage.prompt_tokens,
                            output_tokens=usage.completion_tokens,
                        )

                    if model != self.model:
                        logger.info("LLM fallback: %s → %s", self.model, model)
                    if adapted_rf != response_format:
                        logger.info("LLM response_format adapted for %s: json_schema → json_object", model)

                    return response.choices[0].message.content or ""

                except Exception as e:
                    last_error = e
                    if self._is_permanent_error(e):
                        logger.error("Permanent error on %s, trying next model: %s", model, e)
                        break
                    logger.warning(
                        "LLM call %s attempt %d/%d failed: %s", model, attempt, max_retries, e
                    )
                    if attempt < max_retries:
                        wait = min(2 ** attempt, 30)
                        await asyncio.sleep(wait)

        logger.error("All LLM models failed (last model: %s), last error: %s", model, last_error)
        raise last_error or RuntimeError("No LLM models available")

    async def generate_structured(
        self,
        messages: list[dict],
        response_model: type,
        temperature: float = 0.2,
        max_retries: int = 3,
        fallback_models: Optional[list[str]] = None,
    ):
        """Generate structured output. Only passes fallback models that support json_schema format."""
        json_schema = response_model.model_json_schema()
        response_format = {
            "type": "json_schema",
            "json_schema": {
                "name": response_model.__name__,
                "strict": True,
                "schema": json_schema,
            },
        }
        # Only use OpenAI models that support json_schema for structured output
        schema_models = [m for m in [self.model] + (fallback_models or []) if self._supports_json_schema(m)]
        if not schema_models:
            logger.warning("No models support json_schema; using json_object fallback")
            schema_models = [self.model] + (fallback_models or [])
        result = await self.generate(
            messages=messages,
            temperature=temperature,
            response_format=response_format,
            max_retries=max_retries,
            fallback_models=schema_models,
        )
        return response_model.model_validate_json(result)

    def get_cost_summary(self) -> dict:
        return self.cost_tracker.summary