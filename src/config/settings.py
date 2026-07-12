from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional


class Settings(BaseSettings):
    openai_api_key: str = ""
    openai_embedding_model: str = "text-embedding-3-small"
    openai_chat_model: str = "gpt-5-nano"

    # Ollama (local LLM/embeddings) - OpenAI-compatible API
    ollama_base_url: str = "http://localhost:11434/v1"
    ollama_chat_model: str = "gemma3:12b"
    ollama_alt_model: str = "qwen2.5:7b"
    ollama_embedding_model: str = "nomic-embed-text"
    ollama_api_key: str = "ollama"

    # Groq (cloud, LPU-accelerated, OpenAI-compatible) — free dev tier
    # See docs/technical/llm_provider_evaluation_2026-07-12.md
    groq_api_key: str = ""
    groq_base_url: str = "https://api.groq.com/openai/v1"
    groq_chat_model: str = "llama-3.3-70b-versatile"

    # MLX (Apple Silicon local LLM) - OpenAI-compatible API
    mlx_enabled: bool = False
    mlx_model: str = "mlx-community/Phi-3-mini-4k-instruct-4bit"
    mlx_base_url: str = "http://localhost:8080/v1"

    qdrant_host: str = "localhost"
    qdrant_port: int = 6333
    qdrant_url: Optional[str] = None
    qdrant_api_key: Optional[str] = None
    qdrant_collection: str = "insurance_documents_v2"

    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_password: Optional[str] = None
    cache_ttl_seconds: int = 3600

    hf_token: Optional[str] = None
    hf_embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"

    docling_enabled: bool = False

    log_level: str = "INFO"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
