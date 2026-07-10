"""
Core RAG pipeline — Settings-backed, async OpenAI, structured output support.
"""
import asyncio
import json
import logging
import uuid
from datetime import datetime
from typing import Dict, List, Optional, Any

from openai import AsyncOpenAI
from qdrant_client import QdrantClient, models as qdrant_models

from src.config.settings import settings
from src.llm.client import LLMClient

logger = logging.getLogger(__name__)

EMBEDDING_DIMENSIONS = {
    "text-embedding-ada-002": 1536,
    "text-embedding-3-small": 1536,
    "text-embedding-3-large": 3072,
}

HF_EMBEDDING_DIMENSIONS = {
    "sentence-transformers/all-mpnet-base-v2": 768,
    "sentence-transformers/all-MiniLM-L6-v2": 384,
    "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2": 384,
    "sentence-transformers/multi-qa-mpnet-base-dot-v1": 768,
    "intfloat/e5-large-v2": 1024,
    "sentence-transformers/all-distilroberta-v1": 768,
    "BAAI/bge-base-en-v1.5": 768,
}

OLLAMA_EMBEDDING_DIMENSIONS = {
    "nomic-embed-text": 768,
    "mxbai-embed-large": 1024,
    "all-minilm": 384,
    "bge-m3": 1024,
    "snowflake-arctic-embed": 1024,
}


class RAGPipeline:
    def __init__(self):
        if not settings.openai_api_key:
            raise ValueError("OPENAI_API_KEY is not set")

        self.openai_client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.llm = LLMClient()
        self.openai_chat_model = settings.openai_chat_model
        self.openai_embedding_model = settings.openai_embedding_model
        self.hf_embedding_model = settings.hf_embedding_model

        self.openai_embedding_dimensions = EMBEDDING_DIMENSIONS.get(
            self.openai_embedding_model, 1536
        )
        self.embedding_dimensions = self.openai_embedding_dimensions
        self.active_embedding_model = self.openai_embedding_model

        self._init_hf_client()
        self._init_qdrant()
        self._init_redis()

        self.openai_failure_count = 0
        self.hf_failure_count = 0

        logger.info(
            "Pipeline: chat=%s embed=%s (%dd) qdrant=%s redis=%s",
            self.openai_chat_model, self.active_embedding_model,
            self.embedding_dimensions, settings.qdrant_collection,
            "enabled" if self.cache else "disabled",
        )

    # ------------------------------------------------------------------
    #  Init helpers
    # ------------------------------------------------------------------

    def _init_hf_client(self):
        self.hf_client = None
        self.local_embed_model = None
        self.ollama_embed_client = None
        try:
            from sentence_transformers import SentenceTransformer
            model_name = self.hf_embedding_model
            self.local_embed_model = SentenceTransformer(model_name)
            self.hf_embedding_dimension = HF_EMBEDDING_DIMENSIONS.get(model_name, 768)
            logger.info("Local embedding model loaded (%s, %dd)", model_name, self.hf_embedding_dimension)
        except Exception as e:
            logger.warning("Local sentence-transformers unavailable: %s", e)

        # Ollama embedding client (local, OpenAI-compatible)
        if settings.ollama_base_url and settings.ollama_embedding_model:
            try:
                self.ollama_embed_client = AsyncOpenAI(
                    base_url=settings.ollama_base_url,
                    api_key=settings.ollama_api_key,
                )
                self.ollama_embedding_model = settings.ollama_embedding_model
                self.ollama_embedding_dimension = OLLAMA_EMBEDDING_DIMENSIONS.get(
                    self.ollama_embedding_model, 768
                )
                logger.info(
                    "Ollama embedding client ready (%s, %dd)",
                    self.ollama_embedding_model, self.ollama_embedding_dimension,
                )
            except Exception as e:
                logger.warning("Ollama embedding client init failed: %s", e)
                self.ollama_embed_client = None

    def _init_qdrant(self):
        self.collection_name = settings.qdrant_collection

        if settings.qdrant_url and settings.qdrant_api_key:
            qdrant_kwargs = dict(url=settings.qdrant_url, api_key=settings.qdrant_api_key)
        else:
            qdrant_kwargs = dict(host=settings.qdrant_host, port=settings.qdrant_port)

        for use_memory in [False, True]:
            try:
                self.qdrant_client = QdrantClient(":memory:") if use_memory else QdrantClient(**qdrant_kwargs)
                self._ensure_collection_exists()
                return
            except Exception:
                if not use_memory:
                    logger.warning("Qdrant connection failed, using in-memory")
                    continue
                raise

    def _init_redis(self):
        self.cache = None
        if not settings.redis_password:
            logger.info("REDIS_PASSWORD not set, disabling cache")
            return
        try:
            import redis as redis_lib
            self.cache = redis_lib.Redis(
                host=settings.redis_host, port=settings.redis_port,
                password=settings.redis_password, decode_responses=True,
            )
            self.cache.ping()
        except Exception as e:
            logger.warning("Redis unavailable: %s", e)

    def _ensure_collection_exists(self):
        try:
            self.qdrant_client.get_collection(collection_name=self.collection_name)
        except Exception:
            logger.info("Creating Qdrant collection '%s' (%dd)", self.collection_name, self.embedding_dimensions)
            self.qdrant_client.recreate_collection(
                collection_name=self.collection_name,
                vectors_config=qdrant_models.VectorParams(
                    size=self.embedding_dimensions, distance=qdrant_models.Distance.COSINE
                ),
            )

    # ------------------------------------------------------------------
    #  Embeddings
    # ------------------------------------------------------------------

    async def _generate_openai_embeddings(
        self, texts: List[str], max_retries: int = 3
    ) -> List[List[float]]:
        if not texts:
            return []

        texts_to_embed = []
        for text in texts:
            cleaned = text.replace("\n", " ").strip()[:8191]
            texts_to_embed.append(cleaned)

        for attempt in range(1, max_retries + 1):
            try:
                response = await self.openai_client.embeddings.create(
                    input=texts_to_embed, model=self.openai_embedding_model
                )
                return [item.embedding for item in response.data]
            except Exception as e:
                error_str = str(e)
                # Don't retry quota errors — they won't resolve
                if "insufficient_quota" in error_str or "quota" in error_str.lower():
                    logger.error("OpenAI quota exhausted, aborting embedding")
                    raise
                self.openai_failure_count += 1
                logger.error("OpenAI embedding error (%d/%d): %s", attempt, max_retries, e)
                if attempt < max_retries:
                    await asyncio.sleep(min(2 ** attempt + 1, 30))
                else:
                    raise

    async def _generate_hf_embeddings(
        self, texts: List[str]
    ) -> List[List[float]]:
        if not self.local_embed_model:
            raise RuntimeError("Local embedding model unavailable")
        loop = asyncio.get_event_loop()
        vecs = await loop.run_in_executor(None, self.local_embed_model.encode, texts)
        return vecs.tolist()

    async def _generate_ollama_embeddings(
        self, texts: List[str]
    ) -> List[List[float]]:
        if not self.ollama_embed_client:
            raise RuntimeError("Ollama embedding client unavailable")
        response = await self.ollama_embed_client.embeddings.create(
            input=texts, model=self.ollama_embedding_model
        )
        return [item.embedding for item in response.data]

    async def _generate_embeddings_with_fallback(
        self, texts: List[str], max_retries: int = 3
    ) -> List[List[float]]:
        # 1. Try OpenAI
        try:
            return await self._generate_openai_embeddings(texts, max_retries)
        except Exception as e:
            logger.warning("OpenAI embedding failed: %s", e)

        # 2. Try Ollama (local, OpenAI-compatible)
        if self.ollama_embed_client:
            try:
                prev_dims = self.embedding_dimensions
                self.active_embedding_model = self.ollama_embedding_model
                self.embedding_dimensions = self.ollama_embedding_dimension
                if prev_dims != self.embedding_dimensions:
                    logger.warning("Embedding dims %d→%d, recreating Qdrant collection", prev_dims, self.embedding_dimensions)
                    self.qdrant_client.recreate_collection(
                        collection_name=self.collection_name,
                        vectors_config=qdrant_models.VectorParams(
                            size=self.embedding_dimensions, distance=qdrant_models.Distance.COSINE
                        ),
                    )
                return await self._generate_ollama_embeddings(texts)
            except Exception as e2:
                logger.warning("Ollama embedding failed: %s", e2)

        # 3. Try local sentence-transformers
        if not self.local_embed_model:
            raise RuntimeError("All embedding backends failed and no local fallback available")
        logger.warning("Falling back to local sentence-transformers")
        prev_dims = self.embedding_dimensions
        self.active_embedding_model = self.hf_embedding_model
        self.embedding_dimensions = self.hf_embedding_dimension
        if prev_dims != self.embedding_dimensions:
            logger.warning("Embedding dims %d→%d, recreating Qdrant collection", prev_dims, self.embedding_dimensions)
            self.qdrant_client.recreate_collection(
                collection_name=self.collection_name,
                vectors_config=qdrant_models.VectorParams(
                    size=self.embedding_dimensions, distance=qdrant_models.Distance.COSINE
                ),
            )
        return await self._generate_hf_embeddings(texts)

    # ------------------------------------------------------------------
    #  Ingestion
    # ------------------------------------------------------------------

    async def ingest_document_data(
        self,
        document_id: str,
        text_blocks: List[Dict[str, Any]],
        document_metadata: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        if not text_blocks:
            return {"status": "success", "message": "No text blocks to ingest.", "points_added": 0}

        filtered = []
        for block in text_blocks:
            text = block.get("text", "")
            if not text:
                continue
            if len(text) > 2000:
                text = text[:2000]
            filtered.append({**block, "text": text})
        text_blocks = filtered

        texts = [b["text"] for b in text_blocks]
        if not texts:
            return {"status": "success", "message": "No text content.", "points_added": 0}

        try:
            embeddings = await self._generate_embeddings_with_fallback(texts)
        except Exception as e:
            logger.error("Embedding failed for %s: %s", document_id, e)
            return {"status": "error", "error": f"Embedding failed: {e}"}

        points = []
        for i, block in enumerate(text_blocks):
            payload = {
                "document_id": document_id,
                "text_content": block["text"],
                "page_number": block.get("page"),
                "block_id": block.get("id", str(uuid.uuid4())),
                "bbox": block.get("bbox"),
                "embedding_model": self.active_embedding_model,
                "embedding_timestamp": datetime.now().isoformat(),
            }
            if document_metadata:
                payload.update(document_metadata)
            points.append(
                qdrant_models.PointStruct(
                    id=block.get("id", str(uuid.uuid4())),
                    vector=embeddings[i],
                    payload=payload,
                )
            )

        if points:
            self.qdrant_client.upsert(
                collection_name=self.collection_name,
                points=points,
                wait=True,
            )
            logger.info("Upserted %d points for doc %s", len(points), document_id)
            return {
                "status": "success",
                "document_id": document_id,
                "points_added": len(points),
                "embedding_model_used": self.active_embedding_model,
            }

        return {"status": "success", "message": "No valid points.", "points_added": 0}

    # ------------------------------------------------------------------
    #  Query
    # ------------------------------------------------------------------

    async def query_rag(
        self,
        user_query: str,
        top_k: int = 5,
        filters: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        logger.info("Query: '%s' top_k=%d", user_query, top_k)

        try:
            emb = await self._generate_embeddings_with_fallback([user_query])
            query_vector = emb[0]
        except Exception as e:
            logger.error("Query embedding failed: %s", e)
            return {"status": "error", "error": f"Query embedding failed: {e}"}

        try:
            results = self.qdrant_client.search(
                collection_name=self.collection_name,
                query_vector=query_vector,
                limit=top_k,
                with_payload=True,
            )
        except Exception as e:
            logger.error("Vector search failed: %s", e)
            return {"status": "error", "error": f"Vector search failed: {e}"}

        if not results:
            return {
                "status": "success",
                "result": {
                    "answer": "No relevant information found in documents.",
                    "sources": [],
                    "query": user_query,
                },
            }

        contexts = []
        sources = []
        for i, hit in enumerate(results):
            text = hit.payload.get("text_content", "")
            contexts.append(f"Context [{i+1}]: {text}")
            sources.append({
                "id": str(hit.id),
                "score": hit.score,
                "document_id": hit.payload.get("document_id"),
                "page_number": hit.payload.get("page_number"),
                "text": text[:200] + "..." if len(text) > 200 else text,
            })

        context_str = "\n\n".join(contexts)

        answer = None
        llm_unavailable = False
        try:
            answer = await self.llm.generate(
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are a helpful AI assistant. Based on the provided context from "
                            "insurance documents, answer the user's question. If the context does "
                            "not contain the answer, state that clearly. Be concise and stick to "
                            "the information in the context."
                        ),
                    },
                    {"role": "user", "content": f"Contexts:\n{context_str}\n\nQuestion: {user_query}\n\nAnswer:"},
                ],
                temperature=0.2,
                fallback_models=["gpt-4o-mini"],
            )
        except Exception as e:
            logger.warning("LLM unavailable, using context-only mode: %s", e)
            llm_unavailable = True

        if llm_unavailable or not answer:
            # Context-only fallback: extract best match from sources
            top = sources[0] if sources else {}
            answer = (
                f"[LLM unavailable — showing raw context]\n\n"
                f"Best match (score: {top.get('score', 0):.3f}): "
                f"{top.get('text', 'No relevant content found.')}"
            )

        return {
            "status": "success",
            "result": {
                "answer": answer,
                "sources": sources,
                "query": user_query,
                "embedding_model_used": self.active_embedding_model,
                "llm_used": not llm_unavailable,
            },
        }

    async def query_rag_structured(
        self,
        user_query: str,
        response_model: type,
        top_k: int = 5,
        filters: Optional[Dict[str, Any]] = None,
    ):
        """Query with structured output (typed Pydantic model)."""
        result = await self.query_rag(user_query, top_k=top_k, filters=filters)
        if result.get("status") != "success":
            return result

        inner = result["result"]
        system_prompt = (
            "Extract structured information from the provided context. "
            "If a field cannot be found, use null. Be precise and accurate."
        )
        context_str = "\n\n".join(
            f"Context [{i+1}]: {s['text']}" for i, s in enumerate(inner.get("sources", []))
        )
        user_prompt = f"{context_str}\n\nQuestion: {user_query}"

        try:
            structured = await self.llm.generate_structured(
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                response_model=response_model,
                temperature=0.1,
            )
            return {"status": "success", "result": structured, "sources": inner["sources"]}
        except Exception as e:
            logger.error("Structured extraction failed: %s", e)
            return {"status": "error", "error": f"Structured extraction failed: {e}"}

    # ------------------------------------------------------------------
    #  Stats
    # ------------------------------------------------------------------

    async def get_embedding_stats(self) -> Dict[str, Any]:
        cost = self.llm.get_cost_summary()
        return {
            "active_embedding_model": self.active_embedding_model,
            "embedding_dimensions": self.embedding_dimensions,
            "openai_embedding_failures": self.openai_failure_count,
            "hf_embedding_failures": self.hf_failure_count,
            "llm_cost": cost,
        }
