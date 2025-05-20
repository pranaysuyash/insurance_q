"""
Configuration settings for the RAG pipeline.
"""
from typing import Dict, Any
import os
from dataclasses import dataclass

@dataclass
class RAGConfig:
    # Embedding settings
    embedding_model: str = os.getenv("RAG_EMBEDDING_MODEL", "intfloat/e5-large-v2")
    
    # Vector store settings
    vector_store_host: str = os.getenv("QDRANT_HOST", "localhost")
    vector_store_port: int = int(os.getenv("QDRANT_PORT", "6333"))
    collection_name: str = os.getenv("QDRANT_COLLECTION", "insurance_policies")
    
    # Cache settings
    redis_host: str = os.getenv("REDIS_HOST", "localhost")
    redis_port: int = int(os.getenv("REDIS_PORT", "6379"))
    cache_ttl: int = int(os.getenv("CACHE_TTL", "3600"))  # 1 hour default
    
    # LLM settings
    llm_model: str = os.getenv("LLM_MODEL", "mistralai/Mixtral-8x7B-v0.1")
    temperature: float = float(os.getenv("LLM_TEMPERATURE", "0.7"))
    top_p: float = float(os.getenv("LLM_TOP_P", "0.9"))
    max_length: int = int(os.getenv("LLM_MAX_LENGTH", "512"))
    
    # Chunking settings
    chunk_size: int = int(os.getenv("CHUNK_SIZE", "500"))
    chunk_overlap: int = int(os.getenv("CHUNK_OVERLAP", "50"))
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert config to dictionary."""
        return {
            "embedding": {
                "model": self.embedding_model
            },
            "vector_store": {
                "host": self.vector_store_host,
                "port": self.vector_store_port,
                "collection": self.collection_name
            },
            "cache": {
                "host": self.redis_host,
                "port": self.redis_port,
                "ttl": self.cache_ttl
            },
            "llm": {
                "model": self.llm_model,
                "temperature": self.temperature,
                "top_p": self.top_p,
                "max_length": self.max_length
            },
            "chunking": {
                "size": self.chunk_size,
                "overlap": self.chunk_overlap
            }
        } 