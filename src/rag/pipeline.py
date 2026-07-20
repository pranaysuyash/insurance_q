"""
Core RAG pipeline — Settings-backed, async OpenAI, structured output support.
"""
import asyncio
import json
import logging
import os
import re
import sqlite3
import uuid
from datetime import datetime
from collections import Counter
from types import SimpleNamespace
from typing import Dict, List, Optional, Any

from openai import AsyncOpenAI
from qdrant_client import QdrantClient, models as qdrant_models

from src.config.settings import settings
from src.llm.client import LLMClient
from src.models.rag import RAGAnswer, RAGCitation
from src.services.supabase_vector_store import SupabaseVectorStore

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
    CACHE_VERSION_KEY = "rag:query:version"

    def __init__(self):
        if not settings.openai_api_key:
            raise ValueError("OPENAI_API_KEY is not set")

        self.openai_client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.llm = LLMClient()
        self.openai_chat_model = settings.openai_chat_model
        self.openai_embedding_model = settings.openai_embedding_model
        self.hf_embedding_model = settings.hf_embedding_model

        # Phase 0 P0-0.6 (trust audit, 2026-07-18): contextual retrieval
        # contamination. The trust audit's NO-GO verdict says
        # `_contextualize_chunks` prepends model-generated text to stored
        # source chunks, contaminating citations. Default is OFF in
        # production until the evidence substrate separates
        # `source_text` (immutable, citable) from `retrieval_text` (may
        # include generated context, never directly citable). Flip to
        # true ONLY after Trust Phase 1 lands.
        self._contextual_retrieval_enabled = os.getenv(
            "CONTEXTUAL_RETRIEVAL_ENABLED", "false"
        ).lower() == "true"

        self.openai_embedding_dimensions = EMBEDDING_DIMENSIONS.get(
            self.openai_embedding_model, 1536
        )
        self.embedding_dimensions = self.openai_embedding_dimensions
        self.active_embedding_model = self.openai_embedding_model

        self._init_hf_client()
        self.vector_backend = os.getenv(
            "RAG_VECTOR_BACKEND",
            "supabase" if os.getenv("ENVIRONMENT", "development").lower() == "production" else "qdrant",
        ).lower()
        if self.vector_backend == "supabase":
            self.vector_store = SupabaseVectorStore(
                os.getenv("SUPABASE_URL", "").strip(),
                os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip(),
            )
        else:
            self._init_qdrant()
        self._init_redis()
        if self.vector_backend != "supabase":
            self._init_hybrid_index()
        self._init_reranker()

        self.openai_failure_count = 0
        self.hf_failure_count = 0

        logger.info(
            "Pipeline: chat=%s embed=%s (%dd) vector_backend=%s redis=%s",
            self.openai_chat_model, self.active_embedding_model,
                self.embedding_dimensions, self.vector_backend,
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

    def _init_reranker(self):
        """Initialize cross-encoder reranker if sentence-transformers is available."""
        self.reranker = None
        try:
            from sentence_transformers import CrossEncoder
            self.reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")
            logger.info("Cross-encoder reranker loaded (cross-encoder/ms-marco-MiniLM-L-6-v2)")
        except Exception as e:
            logger.info("Cross-encoder reranker unavailable, will use lexical scoring: %s", e)

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
        try:
            import redis as redis_lib
            redis_kwargs = dict(
                host=settings.redis_host, port=settings.redis_port,
                decode_responses=True,
            )
            if settings.redis_password:
                redis_kwargs["password"] = settings.redis_password
            self.cache = redis_lib.Redis(**redis_kwargs)
            self.cache.ping()
        except Exception as e:
            logger.warning("Redis unavailable: %s", e)
            self.cache = None

    def _query_cache_key(self, user_query: str, top_k: int, filters: Optional[Dict[str, Any]]) -> str:
        payload = {
            "query": user_query.strip(),
            "top_k": top_k,
            "filters": self._normalize_cache_value(filters or {}),
            "collection": getattr(self, "collection_name", ""),
            "chat_model": getattr(self, "openai_chat_model", ""),
            "embedding_model": getattr(self, "active_embedding_model", ""),
            "retrieval_strategy": "dense_plus_local_fts",
            "version": self._get_query_cache_version(),
        }
        return "rag:query:" + json.dumps(payload, sort_keys=True, separators=(",", ":"))

    def _normalize_cache_value(self, value: Any) -> Any:
        if isinstance(value, dict):
            return {str(key): self._normalize_cache_value(val) for key, val in sorted(value.items(), key=lambda item: str(item[0]))}
        if isinstance(value, (list, tuple)):
            return [self._normalize_cache_value(item) for item in value]
        if isinstance(value, set):
            return [self._normalize_cache_value(item) for item in sorted(value, key=lambda item: str(item))]
        if isinstance(value, (str, int, float, bool)) or value is None:
            return value
        return str(value)

    def _get_query_cache_version(self) -> str:
        if not getattr(self, "cache", None):
            return "0"

        try:
            version = self.cache.get(self.CACHE_VERSION_KEY)
            if version is None:
                self.cache.set(self.CACHE_VERSION_KEY, "1")
                return "1"
            return str(version)
        except Exception as e:
            logger.warning("Query cache version lookup failed: %s", e)
            return "0"

    def _bump_query_cache_version(self) -> None:
        if not getattr(self, "cache", None):
            return

        try:
            self.cache.incr(self.CACHE_VERSION_KEY)
        except Exception as e:
            logger.warning("Query cache version bump failed: %s", e)

    def _load_cached_query_result(self, cache_key: str) -> Optional[Dict[str, Any]]:
        if not getattr(self, "cache", None):
            return None

        try:
            cached = self.cache.get(cache_key)
            if not cached:
                return None
            parsed = json.loads(cached)
            if isinstance(parsed, dict):
                return parsed
        except Exception as e:
            logger.warning("Query cache read failed: %s", e)
        return None

    def _store_cached_query_result(self, cache_key: str, response: Dict[str, Any]) -> None:
        if not getattr(self, "cache", None):
            return

        try:
            self.cache.setex(cache_key, settings.cache_ttl_seconds, json.dumps(response, ensure_ascii=False))
        except Exception as e:
            logger.warning("Query cache write failed: %s", e)

    def _init_hybrid_index(self):
        self.hybrid_index_enabled = False
        self.hybrid_index_path = os.path.join("storage", "rag_hybrid_index.db")
        try:
            os.makedirs(os.path.dirname(self.hybrid_index_path), exist_ok=True)
            self.hybrid_index = sqlite3.connect(self.hybrid_index_path, check_same_thread=False)
            self.hybrid_index.row_factory = sqlite3.Row
            self.hybrid_index.execute("PRAGMA journal_mode=WAL")
            self.hybrid_index.execute("PRAGMA synchronous=NORMAL")
            self.hybrid_index.execute(
                """
                CREATE TABLE IF NOT EXISTS rag_chunks (
                    lex_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    point_id TEXT UNIQUE,
                    document_id TEXT,
                    filename TEXT,
                    page_number INTEGER,
                    section TEXT,
                    text_content TEXT NOT NULL,
                    embedding_model TEXT,
                    updated_at TEXT
                )
                """
            )
            self.hybrid_index.execute(
                """
                CREATE VIRTUAL TABLE IF NOT EXISTS rag_chunks_fts USING fts5(
                    point_id UNINDEXED,
                    search_text
                )
                """
            )
            self.hybrid_index.commit()
            self.hybrid_index_enabled = True
            logger.info("Local FTS hybrid index ready at %s", self.hybrid_index_path)
        except Exception as e:
            self.hybrid_index = None
            self.hybrid_index_enabled = False
            logger.warning("Local FTS hybrid index unavailable: %s", e)

        # Cross-encoder reranker (optional — improves precision)
        self.reranker = None
        try:
            from sentence_transformers import CrossEncoder
            self.reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")
            logger.info("Cross-encoder reranker loaded (ms-marco-MiniLM-L-6-v2)")
        except Exception as e:
            logger.info("Cross-encoder reranker unavailable (optional): %s", e)

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
    #  Ingestion with Contextual Retrieval
    # ------------------------------------------------------------------

    async def ingest_document_data(
        self,
        document_id: str,
        text_blocks: List[Dict[str, Any]],
        document_metadata: Optional[Dict[str, Any]] = None,
        page_artifact_id_map: Optional[Dict[int, str]] = None,
    ) -> Dict[str, Any]:
        """Ingest text blocks into the vector store.

        Per ADR-2026-07-19-11 Layer 4: every chunk must have a
        page_artifact_id so the "open page" action can find the source
        page. The `page_artifact_id_map` is {page_number: page_artifact_id}
        for the document. Chunks with a `page` field get the corresponding
        page_artifact_id; chunks without a `page` get None.
        """
        if not text_blocks:
            return {"status": "success", "message": "No text blocks to ingest.", "points_added": 0}

        # Per ADR-2026-07-19-11 Layer 4: enforce page_artifact_id on every
        # chunk. Chunks with a page number get the corresponding id from
        # the map; chunks without a page get None (the verifier will
        # reject the citation if the chunk is cited without a page).
        if page_artifact_id_map is not None:
            for i, block in enumerate(text_blocks):
                page_num = block.get("page")
                if page_num is not None and int(page_num) in page_artifact_id_map:
                    text_blocks[i] = {**block, "page_artifact_id": page_artifact_id_map[int(page_num)]}

        filtered = []
        for block in text_blocks:
            # Backward compat: if a chunk only has `text` (legacy), treat
            # it as `source_text` and initialize `retrieval_text` from it.
            if "source_text" not in block:
                block = {**block, "source_text": block.get("text", "")}
            if "retrieval_text" not in block:
                block = {**block, "retrieval_text": block["source_text"]}
            # Embedding uses retrieval_text (the LLM-augmented version, when
            # contextual retrieval is enabled). source_text is preserved for
            # citation (per ADR-2026-07-19-11).
            text = block.get("retrieval_text", "")
            if not text:
                continue
            if len(text) > 2000:
                text = text[:2000]
            filtered.append({**block, "retrieval_text": text})
        text_blocks = filtered

        # Contextual Retrieval: prepend chunk-specific context to each block
        # before embedding (Anthropic technique, 35% reduction in retrieval failures).
        #
        # Phase 0 P0-0.6 (trust audit, 2026-07-18): disabled by default in
        # production. The trust audit says contextualization contaminates
        # source evidence with model-generated text. Re-enable only after
        # Trust Phase 1 separates source_text and retrieval_text.
        contextualized = False
        if getattr(self, "llm", None) and getattr(self, "_contextual_retrieval_enabled", False):
            text_blocks = await self._contextualize_chunks(text_blocks, document_metadata or {})
            contextualized = True

        # Embedding uses retrieval_text (the LLM-augmented version when
        # contextual retrieval is enabled; otherwise equal to source_text).
        # Per ADR-2026-07-19-11.
        texts = [b.get("retrieval_text", b.get("source_text", "")) for b in text_blocks]
        if not texts:
            return {"status": "success", "message": "No text content.", "points_added": 0}

        try:
            embeddings = await self._generate_embeddings_with_fallback(texts)
        except Exception as e:
            logger.error("Embedding failed for %s: %s", document_id, e)
            return {"status": "error", "error": f"Embedding failed: {e}"}

        if getattr(self, "vector_backend", "qdrant") == "supabase":
            points_added = await self.vector_store.upsert(
                document_id,
                text_blocks,
                embeddings,
                owner_id=(document_metadata or {}).get("owner_id"),
            )
            self._bump_query_cache_version()
            return {
                "status": "success",
                "document_id": document_id,
                "points_added": points_added,
                "embedding_model_used": self.active_embedding_model,
                "contextualized": contextualized,  # P0-0.6: report actual state
            }

        points = []
        for i, block in enumerate(text_blocks):
            payload = {
                "document_id": document_id,
                # Embedding uses retrieval_text (the LLM-augmented version);
                # source_text is preserved separately for citation
                # (per ADR-2026-07-19-11).
                "text_content": block.get("retrieval_text", block.get("source_text", "")),
                "page_number": block.get("page"),
                "block_id": block.get("id", str(uuid.uuid4())),
                "bbox": block.get("bbox"),
                "embedding_model": self.active_embedding_model,
                "embedding_timestamp": datetime.now().isoformat(),
                # Per ADR-2026-07-19-11 Layer 4: every chunk must have a
                # page_artifact_id so the "open page" action can find the page.
                "page_artifact_id": block.get("page_artifact_id"),
                # Per ADR-2026-07-19-11: source_text is preserved untouched.
                "source_text": block.get("source_text", ""),
            }
            for key in ("page", "section", "source", "filename"):
                if key in block and key not in payload:
                    payload[key] = block[key]
            if document_metadata:
                payload.update(document_metadata)
            points.append(
                qdrant_models.PointStruct(
                    id=block.get("id", str(uuid.uuid4())),
                    vector=embeddings[i],
                    payload=payload,
                )
            )
            self._upsert_hybrid_index(
                point_id=str(block.get("id", points[-1].id)),
                payload=payload,
            )

        if points:
            self.qdrant_client.upsert(
                collection_name=self.collection_name,
                points=points,
                wait=True,
            )
            self._bump_query_cache_version()
            logger.info("Upserted %d points for doc %s", len(points), document_id)
            return {
                "status": "success",
                "document_id": document_id,
                "points_added": len(points),
                "embedding_model_used": self.active_embedding_model,
                "contextualized": contextualized,  # P0-0.6: report actual state
            }

        return {"status": "success", "message": "No valid points.", "points_added": 0}

    async def _generate_hyde_query(self, user_query: str) -> str:
        """Generate a hypothetical answer document to embed instead of the raw query.

        HyDE (Hypothetical Document Embeddings) closes the vocabulary gap
        between short user queries and long insurance documents by generating
        a hypothetical answer that would match the document semantically.

        If LLM is unavailable or fails, return empty string (graceful fallback
        to embedding the raw query).
        """
        if not self.llm:
            return ""

        try:
            hyp = await self.llm.generate(
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are an insurance document analyst. "
                            "Given a question about an insurance policy, "
                            "generate a brief hypothetical answer (2-3 sentences) "
                            "that would appear in the policy document. "
                            "Be specific and factual. Do not hedge."
                        ),
                    },
                    {
                        "role": "user",
                        "content": f"Question: {user_query}\n\nHypothetical answer from policy:",
                    },
                ],
                temperature=0.0,
                max_tokens=150,
            )

            if hyp and len(hyp.strip()) > 20:
                logger.info("HyDE generated hypothetical doc for query")
                return hyp.strip()
        except Exception as e:
            logger.warning("HyDE generation failed, using raw query: %s", e)

        return ""

    def _classify_query(self, query: str) -> str:
        """Adaptive RAG: classify query to route to the appropriate retrieval path."""
        query_lower = query.lower().strip()

        # Exact lookup: policy numbers, IDs, specific names — FTS only, no embedding
        if re.search(r'policy number|policy no|policy id|policy ref|find.*\b[A-Z0-9/\-]{5,}\b', query_lower):
            return "exact_lookup"

        # Multi-step: comparison, cross-document analysis — needs multiple queries
        if any(w in query_lower for w in ['compare', 'versus', 'difference between', 'gap', 'across all', 'all policies', 'which policies']):
            return "multi_step"

        # Broad: summaries, overviews — wider retrieval
        if any(w in query_lower for w in ['summar', 'overview', 'what does the', 'what is the policy', 'list all']):
            return "broad"

        # Default: single-step semantic retrieval
        return "single_step"

    async def _generate_query_variants(self, user_query: str) -> List[str]:
        """RAG Fusion: generate alternative phrasings for broader retrieval coverage."""
        if not self.llm:
            return [user_query]

        try:
            result = await self.llm.generate(
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You rephrase insurance questions to improve search retrieval. "
                            "Generate 2 alternative phrasings of the question. "
                            "One per line. No numbering. No preamble."
                        ),
                    },
                    {"role": "user", "content": user_query},
                ],
                temperature=0.3,
                max_tokens=150,
            )

            if result:
                variants = [v.strip() for v in result.strip().split('\n') if v.strip() and len(v.strip()) > 10]
                if variants:
                    logger.info("RAG Fusion generated %d variants", len(variants))
                    return [user_query] + variants[:2]
        except Exception as e:
            logger.warning("RAG Fusion query variant generation failed: %s", e)

        return [user_query]

    def _evaluate_retrieval_quality(self, user_query: str, results: List[Any]) -> bool:
        """Retrieval Evaluator: check if retrieved results are good enough to answer.

        Prevents hallucination by returning 'not found' when retrieval quality is too low.
        """
        if not results:
            return False

        top_score = float(results[0].score or 0.0)

        # RRF scores are small (sum of 1/(k+rank) values, k=20)
        # A score > 0.03 means at least one result appeared in top-3 of one retrieval path
        if top_score < 0.01:
            return False

        # Check lexical overlap of top result with the query
        top_payload = results[0].payload or {}
        top_text = top_payload.get("text_content", "")
        overlap = self._lexical_overlap(self._tokenize(user_query), top_text)

        # If both score and overlap are very low, retrieval likely failed
        if top_score < 0.02 and overlap < 0.05:
            return False

        return True

    def _split_into_sentences(self, text: str) -> List[Dict[str, Any]]:
        """Split text into sentence-level chunks with position metadata for sentence window retrieval.

        Per ADR-2026-07-19-11 (substrate as primary deliverable), every chunk
        has a `source_text` field (immutable, OCR'd page text) and a
        `retrieval_text` field (initially equal to `source_text`; the
        `_contextualize_chunks` method may overwrite `retrieval_text` with
        LLM-generated context). Citations quote only `source_text`.
        """
        sentences = re.split(r'(?<=[.!?])\s+', text)
        return [
            {
                "source_text": s.strip(),
                "retrieval_text": s.strip(),
                "id": str(uuid.uuid4()),
                "sentence_index": i,
                "chunk_type": "sentence",
            }
            for i, s in enumerate(sentences) if s.strip() and len(s.strip()) > 20
        ]

    async def _contextualize_chunks(
        self, text_blocks: List[Dict[str, Any]], document_metadata: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """Prepend LLM-generated context to each chunk (Anthropic Contextual Retrieval).

        For each chunk, ask the LLM to generate a 1-2 sentence context that situates
        the chunk within the overall document. This context is written to
        `retrieval_text`; the original `source_text` is preserved untouched.

        Per ADR-2026-07-19-11 (substrate as primary deliverable), citations may
        quote only `source_text`. The `retrieval_text` is used for embedding
        (improving retrieval accuracy) but never for citation.

        If LLM fails, `retrieval_text` is left equal to `source_text` (graceful
        degradation).
        """
        if not self.llm:
            return text_blocks

        doc_context = " ".join(
            str(v) for v in [
                document_metadata.get("filename"),
                document_metadata.get("document_type"),
                document_metadata.get("insurer"),
            ] if v
        )

        contextualized = []
        for block in text_blocks:
            # Backward compat: if a chunk only has `text` (legacy), treat
            # it as `source_text` and initialize `retrieval_text` from it.
            if "source_text" not in block:
                block = {**block, "source_text": block.get("text", "")}
            if "retrieval_text" not in block:
                block = {**block, "retrieval_text": block["source_text"]}

            source_text = block.get("source_text", "")
            if not source_text or len(source_text) < 50:
                contextualized.append(block)
                continue

            try:
                context = await self.llm.generate(
                    messages=[
                        {
                            "role": "system",
                            "content": (
                                "You provide concise document context for search retrieval. "
                                "Given a chunk from an insurance document, output a 1-2 sentence "
                                "context that situates this chunk within the document. "
                                "Be factual. Do not add information not in the chunk or document context."
                            ),
                        },
                        {
                            "role": "user",
                            "content": (
                                f"Document context: {doc_context}\n\n"
                                f"Chunk:\n{source_text[:800]}\n\n"
                                "Provide a short, factual context to situate this chunk "
                                "within the document for search retrieval purposes."
                            ),
                        },
                    ],
                    temperature=0.0,
                    max_tokens=100,
                )

                if context and len(context.strip()) > 10:
                    # Write to retrieval_text ONLY. source_text is preserved.
                    # Per ADR-2026-07-19-11, citations may quote only source_text.
                    block = {**block, "retrieval_text": f"{context.strip()}\n\n{source_text}"}
            except Exception as e:
                logger.warning("Contextualization failed for one chunk: %s", e)

            contextualized.append(block)

        return contextualized

    async def delete_document_data(self, document_id: str, owner_id: str) -> Dict[str, Any]:
        """Delete vector and lexical chunks for one verified owner/document pair."""
        if getattr(self, "vector_backend", "qdrant") == "supabase":
            try:
                deleted = await self.vector_store.delete(document_id, owner_id)
                self._bump_query_cache_version()
                return {"status": "success", "document_id": document_id, "deleted": deleted}
            except Exception as error:
                logger.error("Failed to delete Supabase RAG data for %s: %s", document_id, error)
                return {"status": "error", "error": str(error)}

        ownership_filter = qdrant_models.Filter(
            must=[
                qdrant_models.FieldCondition(
                    key="document_id", match=qdrant_models.MatchValue(value=document_id)
                ),
                qdrant_models.FieldCondition(
                    key="owner_id", match=qdrant_models.MatchValue(value=owner_id)
                ),
            ]
        )
        try:
            self.qdrant_client.delete(
                collection_name=self.collection_name,
                points_selector=qdrant_models.FilterSelector(filter=ownership_filter),
                wait=True,
            )
            if getattr(self, "hybrid_index_enabled", False) and getattr(self, "hybrid_index", None):
                self.hybrid_index.execute("DELETE FROM rag_chunks WHERE document_id = ?", (document_id,))
                self.hybrid_index.commit()
            self._bump_query_cache_version()
            return {"status": "success", "document_id": document_id}
        except Exception as error:
            logger.error("Failed to delete RAG data for %s: %s", document_id, error)
            return {"status": "error", "error": str(error)}

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

        cache_key = self._query_cache_key(user_query, top_k, filters)
        cached_response = self._load_cached_query_result(cache_key)
        if cached_response:
            logger.info("Returning cached RAG response for query")
            return cached_response

        # Adaptive RAG: classify query and adjust retrieval strategy
        query_type = self._classify_query(user_query)
        logger.info("Query classified as: %s", query_type)

        # RAG Fusion: generate query variants for broader coverage
        query_variants = await self._generate_query_variants(user_query)
        logger.info("RAG Fusion: %d query variants", len(query_variants))

        # HyDE: Generate a hypothetical answer to embed instead of the raw query
        hyde_query = await self._generate_hyde_query(user_query)
        embed_query = hyde_query if hyde_query else user_query

        # For exact_lookup queries, skip embedding and use FTS only (faster)
        if query_type == "exact_lookup":
            local_results = self._query_hybrid_index(user_query, limit=max(top_k * 3, top_k), filters=filters)
            results = local_results
            dense_results = []
        else:
            try:
                emb = await self._generate_embeddings_with_fallback([embed_query])
                query_vector = emb[0]
            except Exception as e:
                logger.error("Query embedding failed: %s", e)
                return {"status": "error", "error": f"Query embedding failed: {e}"}

            dense_results = []
            dense_error = None
            try:
                if getattr(self, "vector_backend", "qdrant") == "supabase":
                    dense_results = await self.vector_store.search(
                        query_vector, max(top_k * 3, top_k), filters
                    )
                else:
                    qdrant_filter = self._build_qdrant_filter(filters)
                    dense_results = self.qdrant_client.search(
                        collection_name=self.collection_name,
                        query_vector=query_vector,
                        limit=max(top_k * 3, top_k),
                        with_payload=True,
                        query_filter=qdrant_filter,
                    )
            except Exception as e:
                dense_error = e
                logger.error("Vector search failed: %s", e)

            local_results = self._query_hybrid_index(user_query, limit=max(top_k * 3, top_k), filters=filters)

            # RAG Fusion: also search for each query variant and merge all results
            if len(query_variants) > 1:
                for variant in query_variants[1:]:  # Skip original (already searched)
                    try:
                        variant_emb = await self._generate_embeddings_with_fallback([variant])
                        variant_vector = variant_emb[0]
                        if getattr(self, "vector_backend", "qdrant") == "supabase":
                            variant_dense = await self.vector_store.search(
                                variant_vector, max(top_k * 2, top_k), filters
                            )
                        else:
                            qdrant_filter = self._build_qdrant_filter(filters)
                            variant_dense = self.qdrant_client.search(
                                collection_name=self.collection_name,
                                query_vector=variant_vector,
                                limit=max(top_k * 2, top_k),
                                with_payload=True,
                                query_filter=qdrant_filter,
                            )
                        # Merge variant results with existing dense results via RRF
                        dense_results = self._merge_hybrid_results(dense_results, variant_dense)
                    except Exception as e:
                        logger.warning("RAG Fusion variant search failed: %s", e)

            results = self._merge_hybrid_results(dense_results, local_results)

        if not results:
            if dense_error is not None and not local_results:
                return {"status": "error", "error": f"Vector search failed: {dense_error}"}
            response = {
                "status": "success",
                "result": {
                    "answer": "No relevant information found in documents.",
                    "sources": [],
                    "query": user_query,
                    "embedding_model_used": self.active_embedding_model,
                    "llm_used": False,
                    "confidence": 0.0,
                    "retrieval_confidence": 0.0,
                    "citations": [],
                    "missing_information": ["No relevant context was retrieved."],
                    "follow_up_questions": [],
                    "retrieval_strategy": "adaptive_rag_fusion_hyde",
                },
            }
            self._store_cached_query_result(cache_key, response)
            return response

        ranked_results = self._rank_results(user_query, results)
        ranked_results = ranked_results[:top_k]

        # Retrieval Evaluator: quality gate — if retrieval is too weak, don't hallucinate
        if not self._evaluate_retrieval_quality(user_query, ranked_results):
            logger.info("Retrieval quality too low, returning honest 'not found'")
            response = {
                "status": "success",
                "result": {
                    "answer": "I could not find relevant information in your documents to answer this question. Please try rephrasing or upload the relevant policy document.",
                    "sources": [],
                    "query": user_query,
                    "embedding_model_used": self.active_embedding_model,
                    "llm_used": False,
                    "confidence": 0.0,
                    "retrieval_confidence": 0.0,
                    "citations": [],
                    "missing_information": ["No relevant context was retrieved with sufficient confidence."],
                    "follow_up_questions": [],
                    "retrieval_strategy": "adaptive_rag_fusion_hyde",
                },
            }
            self._store_cached_query_result(cache_key, response)
            return response

        contexts = []
        sources = []
        for i, hit in enumerate(ranked_results):
            payload = hit.payload or {}
            text = payload.get("text_content", "")
            contexts.append(self._format_context_block(i + 1, hit, text))
            sources.append(self._format_source(hit, i + 1, text))

        context_str = "\n\n".join(contexts)

        answer_payload: Optional[RAGAnswer] = None
        llm_unavailable = False
        try:
            answer_payload = await self.llm.generate_structured(
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are a careful insurance-document assistant. Answer only from the "
                            "provided context. Cite the source indices that support each claim. "
                            "If the context does not contain the answer, say so explicitly instead "
                            "of guessing. Keep the answer concise and practical."
                        ),
                    },
                    {
                        "role": "user",
                        "content": (
                            f"Retrieved context:\n{context_str}\n\n"
                            f"Question: {user_query}\n\n"
                            "Return a grounded answer with citations, confidence, missing "
                            "information, and helpful follow-up questions."
                        ),
                    },
                ],
                response_model=RAGAnswer,
                temperature=0.1,
                fallback_models=["gpt-4o-mini"],
            )
        except Exception as e:
            logger.warning("LLM unavailable, using context-only mode: %s", e)
            llm_unavailable = True

        if llm_unavailable or not answer_payload:
            # Context-only fallback: extract best match from sources
            top = sources[0] if sources else {}
            answer = (
                f"[LLM unavailable — showing raw context]\n\n"
                f"Best match (score: {top.get('score', 0):.3f}): "
                f"{top.get('text', 'No relevant content found.')}"
            )
            answer_payload = RAGAnswer(
                answer=answer,
                citations=[RAGCitation(source_index=1, quote=top.get("text", ""))] if top else [],
                confidence=0.0,
                missing_information=["LLM response unavailable"],
                follow_up_questions=[],
            )

        retrieval_confidence = self._estimate_retrieval_confidence(ranked_results, user_query)
        answer_payload.confidence = max(answer_payload.confidence, retrieval_confidence)
        response = {
            "status": "success",
            "result": {
                "answer": answer_payload.answer,
                "sources": sources,
                "query": user_query,
                "embedding_model_used": self.active_embedding_model,
                "llm_used": not llm_unavailable,
                "confidence": round(answer_payload.confidence, 3),
                "retrieval_confidence": round(retrieval_confidence, 3),
                "citations": [citation.model_dump() for citation in answer_payload.citations],
                "missing_information": answer_payload.missing_information,
                "follow_up_questions": answer_payload.follow_up_questions,
                "retrieval_strategy": "dense_plus_local_fts",
            },
        }
        self._store_cached_query_result(cache_key, response)
        return response

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

    def _build_qdrant_filter(self, filters: Optional[Dict[str, Any]]):
        if not filters:
            return None

        conditions = []
        for key, value in filters.items():
            if value is None:
                continue
            if key == "document_id" and isinstance(value, str):
                conditions.append(
                    qdrant_models.FieldCondition(
                        key="document_id",
                        match=qdrant_models.MatchValue(value=value),
                    )
                )
                continue
            if key == "document_ids" and isinstance(value, (list, tuple, set)):
                conditions.append(
                    qdrant_models.FieldCondition(
                        key="document_id",
                        match=qdrant_models.MatchAny(any=list(value)),
                    )
                )
                continue
            if isinstance(value, (list, tuple, set)):
                conditions.append(
                    qdrant_models.FieldCondition(
                        key=key,
                        match=qdrant_models.MatchAny(any=list(value)),
                    )
                )
            elif isinstance(value, dict):
                if "equals" in value:
                    conditions.append(
                        qdrant_models.FieldCondition(
                            key=key,
                            match=qdrant_models.MatchValue(value=value["equals"]),
                        )
                    )
                elif "in" in value and isinstance(value["in"], (list, tuple, set)):
                    conditions.append(
                        qdrant_models.FieldCondition(
                            key=key,
                            match=qdrant_models.MatchAny(any=list(value["in"])),
                        )
                    )
            else:
                conditions.append(
                    qdrant_models.FieldCondition(
                        key=key,
                        match=qdrant_models.MatchValue(value=value),
                    )
                )

        if not conditions:
            return None
        return qdrant_models.Filter(must=conditions)

    def _upsert_hybrid_index(self, point_id: str, payload: Dict[str, Any]):
        if not getattr(self, "hybrid_index_enabled", False) or not getattr(self, "hybrid_index", None):
            return

        try:
            text = payload.get("text_content", "")
            if not text:
                return
            search_text = " ".join(
                str(value)
                for value in [
                    payload.get("document_id"),
                    payload.get("filename"),
                    payload.get("section"),
                    payload.get("page_number"),
                    text,
                ]
                if value not in (None, "")
            )
            self.hybrid_index.execute(
                """
                INSERT INTO rag_chunks (
                    point_id, document_id, filename, page_number, section,
                    text_content, embedding_model, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(point_id) DO UPDATE SET
                    document_id=excluded.document_id,
                    filename=excluded.filename,
                    page_number=excluded.page_number,
                    section=excluded.section,
                    text_content=excluded.text_content,
                    embedding_model=excluded.embedding_model,
                    updated_at=excluded.updated_at
                """,
                (
                    point_id,
                    payload.get("document_id"),
                    payload.get("filename"),
                    payload.get("page_number"),
                    payload.get("section"),
                    text,
                    payload.get("embedding_model"),
                    payload.get("embedding_timestamp"),
                ),
            )
            lex_id_row = self.hybrid_index.execute(
                "SELECT lex_id FROM rag_chunks WHERE point_id = ?",
                (point_id,),
            ).fetchone()
            if not lex_id_row:
                return
            lex_id = int(lex_id_row["lex_id"])
            self.hybrid_index.execute(
                """
                INSERT OR REPLACE INTO rag_chunks_fts (rowid, point_id, search_text)
                VALUES (?, ?, ?)
                """,
                (lex_id, point_id, search_text),
            )
            self.hybrid_index.commit()
        except Exception as e:
            logger.warning("Hybrid index upsert failed for %s: %s", point_id, e)

    def _query_hybrid_index(
        self,
        user_query: str,
        limit: int = 10,
        filters: Optional[Dict[str, Any]] = None,
    ) -> List[Any]:
        if not getattr(self, "hybrid_index_enabled", False) or not getattr(self, "hybrid_index", None):
            return []

        terms = [token for token in self._tokenize(user_query) if len(token) > 1]
        if not terms:
            return []

        fts_query = " OR ".join(
            f'"{term}"' if " " in term else f"{term}*" if len(term) >= 4 else term
            for term in terms
        )
        sql_filters = []
        sql_params: List[Any] = [fts_query, limit]
        if filters:
            for key, value in filters.items():
                if value is None:
                    continue
                if key == "document_id" and isinstance(value, str):
                    sql_filters.append("c.document_id = ?")
                    sql_params.append(value)
                elif key == "document_ids" and isinstance(value, (list, tuple, set)):
                    sql_filters.append(f"c.document_id IN ({','.join('?' for _ in value)})")
                    sql_params.extend(list(value))
                elif key in {"filename", "section"} and isinstance(value, str):
                    sql_filters.append(f"c.{key} = ?")
                    sql_params.append(value)

        where_clause = ""
        if sql_filters:
            where_clause = " AND " + " AND ".join(sql_filters)

        try:
            rows = self.hybrid_index.execute(
                """
                SELECT f.point_id, f.search_text, bm25(rag_chunks_fts) AS bm25_score,
                       c.document_id, c.filename, c.page_number, c.section,
                       c.text_content, c.embedding_model, c.updated_at
                FROM rag_chunks_fts f
                JOIN rag_chunks c ON c.lex_id = f.rowid
                WHERE rag_chunks_fts MATCH ?
                {where_clause}
                ORDER BY bm25_score
                LIMIT ?
                """.format(where_clause=where_clause),
                sql_params,
            ).fetchall()
        except Exception as e:
            logger.warning("Hybrid index search failed: %s", e)
            return []

        if not rows:
            like_filters = []
            like_params: List[Any] = []
            for key, value in (filters or {}).items():
                if value is None:
                    continue
                if key == "document_id" and isinstance(value, str):
                    like_filters.append("c.document_id = ?")
                    like_params.append(value)
                elif key == "document_ids" and isinstance(value, (list, tuple, set)):
                    like_filters.append(f"c.document_id IN ({','.join('?' for _ in value)})")
                    like_params.extend(list(value))
                elif key in {"filename", "section"} and isinstance(value, str):
                    like_filters.append(f"c.{key} = ?")
                    like_params.append(value)

            like_clause = ""
            if like_filters:
                like_clause = " AND " + " AND ".join(like_filters)

            term_params = [
                value
                for term in terms
                for value in (f"%{term}%",) * 5
            ]
            try:
                rows = self.hybrid_index.execute(
                    """
                    SELECT f.point_id, f.search_text, 0.0 AS bm25_score,
                           c.document_id, c.filename, c.page_number, c.section,
                           c.text_content, c.embedding_model, c.updated_at
                    FROM rag_chunks_fts f
                    JOIN rag_chunks c ON c.lex_id = f.rowid
                    WHERE (
                        {term_clause}
                    )
                    {where_clause}
                    LIMIT ?
                    """.format(
                        term_clause=" OR ".join(
                            "LOWER(f.search_text) LIKE ? OR LOWER(c.text_content) LIKE ? "
                            "OR LOWER(COALESCE(c.filename, '')) LIKE ? "
                            "OR LOWER(COALESCE(c.section, '')) LIKE ? "
                            "OR LOWER(COALESCE(c.document_id, '')) LIKE ?"
                            for _ in terms
                        ),
                        where_clause=like_clause,
                    ),
                    term_params + like_params + [limit],
                ).fetchall()
            except Exception as e:
                logger.warning("Hybrid index fallback search failed: %s", e)
                return []

        hits = []
        for row in rows:
            lexical_score = 1.0 / (1.0 + abs(float(row["bm25_score"] or 0.0)))
            hits.append(
                SimpleNamespace(
                    id=row["point_id"],
                    score=lexical_score,
                    payload={
                        "document_id": row["document_id"],
                        "filename": row["filename"],
                        "page_number": row["page_number"],
                        "section": row["section"],
                        "text_content": row["text_content"],
                        "embedding_model": row["embedding_model"],
                        "embedding_timestamp": row["updated_at"],
                    },
                )
            )
        return hits

    def _merge_hybrid_results(self, dense_results: List[Any], local_results: List[Any]) -> List[Any]:
        """Merge dense and sparse results using Reciprocal Rank Fusion (RRF).

        RRF is rank-based, not score-based, which makes it more robust than
        score interpolation — especially for small corpora where score
        distributions are unreliable. k=20 is tuned for small corpora (<200 docs).
        """
        k = 20  # RRF constant — small corpus tuning (default 60 is for large corpora)
        rrf_scores: Dict[str, float] = {}
        point_store: Dict[str, Any] = {}

        for rank, hit in enumerate(dense_results, 1):
            point_id = str(getattr(hit, "id", ""))
            score = 1.0 / (k + rank)
            rrf_scores[point_id] = rrf_scores.get(point_id, 0.0) + score
            if point_id not in point_store:
                point_store[point_id] = SimpleNamespace(
                    id=point_id,
                    score=0.0,
                    payload=dict(getattr(hit, "payload", {}) or {}),
                )

        for rank, hit in enumerate(local_results, 1):
            point_id = str(getattr(hit, "id", ""))
            score = 1.0 / (k + rank)
            rrf_scores[point_id] = rrf_scores.get(point_id, 0.0) + score
            if point_id not in point_store:
                point_store[point_id] = SimpleNamespace(
                    id=point_id,
                    score=0.0,
                    payload=dict(getattr(hit, "payload", {}) or {}),
                )
            elif not point_store[point_id].payload:
                point_store[point_id].payload = dict(getattr(hit, "payload", {}) or {})

        # Update scores with RRF values and sort
        for point_id, rrf_score in rrf_scores.items():
            point_store[point_id].score = round(rrf_score, 6)

        return sorted(point_store.values(), key=lambda x: x.score, reverse=True)

    def _rank_results(self, user_query: str, results: List[Any]) -> List[Any]:
        """Rank results using cross-encoder reranking if available, falling back to lexical scoring."""
        if not results:
            return []

        # If cross-encoder is available, use it for precise reranking
        if getattr(self, "reranker", None) is not None and len(results) > 1:
            try:
                pairs = []
                for hit in results:
                    text = (hit.payload or {}).get("text_content", "")
                    pairs.append((user_query, text[:512]))  # truncate for reranker

                rerank_scores = self.reranker.predict(pairs)
                ranked = list(zip(rerank_scores, results))
                ranked.sort(key=lambda x: x[0], reverse=True)
                return [hit for _, hit in ranked]
            except Exception as e:
                logger.warning("Cross-encoder reranking failed, falling back to lexical: %s", e)

        # Fallback: lexical + exact match scoring
        query_tokens = self._tokenize(user_query)
        ranked = []
        for hit in results:
            payload = hit.payload or {}
            text = payload.get("text_content", "")
            lexical = self._lexical_overlap(query_tokens, text)
            exact_boost = self._exact_match_boost(user_query, text, payload)
            score = float(hit.score or 0.0)
            combined = round((score * 0.7) + (lexical * 0.2) + (exact_boost * 0.1), 6)
            ranked.append((combined, lexical, exact_boost, hit))

        ranked.sort(key=lambda item: (item[0], item[1], item[2]), reverse=True)
        return [item[3] for item in ranked]

    def _tokenize(self, text: str) -> List[str]:
        return re.findall(r"[a-z0-9]+", (text or "").lower())

    def _lexical_overlap(self, query_tokens: List[str], text: str) -> float:
        if not query_tokens or not text:
            return 0.0
        text_tokens = self._tokenize(text)
        if not text_tokens:
            return 0.0
        query_counter = Counter(query_tokens)
        text_counter = Counter(text_tokens)
        overlap = sum(min(query_counter[token], text_counter[token]) for token in query_counter)
        return overlap / max(len(query_tokens), 1)

    def _exact_match_boost(self, user_query: str, text: str, payload: Dict[str, Any]) -> float:
        haystacks = [user_query.lower(), text.lower()]
        for key in ("document_id", "filename", "policy_number", "block_id"):
            value = payload.get(key)
            if value:
                haystacks.append(str(value).lower())
        boost = 0.0
        for query_token in self._tokenize(user_query):
            if len(query_token) >= 4 and any(query_token in haystack for haystack in haystacks[1:]):
                boost += 0.1
        return min(boost, 1.0)

    def _format_context_block(self, index: int, hit: Any, text: str) -> str:
        payload = hit.payload or {}
        parts = [
            f"Source {index}:",
            f"document_id={payload.get('document_id')}",
        ]
        if payload.get("filename"):
            parts.append(f"filename={payload.get('filename')}")
        if payload.get("page_number") is not None:
            parts.append(f"page={payload.get('page_number')}")
        if payload.get("section"):
            parts.append(f"section={payload.get('section')}")
        parts.append(f"score={float(hit.score or 0.0):.3f}")
        parts.append(f"text={text}")
        return " | ".join(parts)

    def _format_source(self, hit: Any, index: int, text: str) -> Dict[str, Any]:
        payload = hit.payload or {}
        excerpt = text[:240] + "..." if len(text) > 240 else text
        return {
            "index": index,
            "id": str(hit.id),
            "score": float(hit.score or 0.0),
            "document_id": payload.get("document_id"),
            "filename": payload.get("filename"),
            "page_number": payload.get("page_number"),
            "section": payload.get("section"),
            "text": excerpt,
        }

    def _estimate_retrieval_confidence(self, ranked_results: List[Any], user_query: str) -> float:
        if not ranked_results:
            return 0.0
        top = ranked_results[0]
        top_score = float(top.score or 0.0)
        top_payload = top.payload or {}
        top_text = top_payload.get("text_content", "")
        lexical = self._lexical_overlap(self._tokenize(user_query), top_text)
        return min(1.0, (top_score * 0.75) + (lexical * 0.25))
