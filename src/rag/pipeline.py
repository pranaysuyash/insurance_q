"""
Core RAG pipeline implementation with fallback mechanism - OpenAI primary and Hugging Face fallback.
"""
import os
import json
from typing import List, Dict, Optional, Any
from openai import OpenAI
from qdrant_client import QdrantClient, models as qdrant_models
import redis
from datetime import datetime
import uuid
import time
import logging

# Configure logging
logger = logging.getLogger(__name__)
logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper())

class RAGPipeline:
    def __init__(
        self,
        qdrant_host: str = os.getenv("QDRANT_HOST", "qdrant"),
        qdrant_port: int = int(os.getenv("QDRANT_PORT", 6333)),
        collection_name: str = os.getenv("QDRANT_COLLECTION", "insurance_documents_v2"),
        redis_host: str = os.getenv("REDIS_HOST", "redis"),
        redis_port: int = int(os.getenv("REDIS_PORT", 6379)),
        cache_ttl: int = int(os.getenv("CACHE_TTL_SECONDS", 3600)),
        embedding_model: str = os.getenv("EMBEDDING_MODEL", "sentence-transformers/all-mpnet-base-v2"),
        openai_embedding_model: str = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-ada-002"),
        openai_chat_model: str = os.getenv("OPENAI_CHAT_MODEL", "gpt-3.5-turbo"),
        use_openai_first: bool = os.getenv("USE_OPENAI_FIRST", "true").lower() == "true"
    ):
        """Initialize the RAG pipeline with OpenAI (primary) and Hugging Face (fallback) embedding options."""
        # Initialize OpenAI client for embeddings and chat
        self.openai_api_key = os.getenv("OPENAI_API_KEY")
        if not self.openai_api_key:
            logger.error("OPENAI_API_KEY environment variable not set.")
            raise ValueError("OPENAI_API_KEY environment variable not set.")
        
        # Initialize OpenAI client with minimal parameters
        try:
            self.openai_client = OpenAI(api_key=self.openai_api_key)
            logger.info("✅ OpenAI client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize OpenAI client: {e}")
            raise
            
        self.openai_chat_model = openai_chat_model
        self.openai_embedding_model = openai_embedding_model
        
        # Initialize Hugging Face client for fallback embeddings
        self.hf_token = os.getenv("HF_TOKEN")
        if not self.hf_token:
            logger.warning("HF_TOKEN environment variable not set. Using Hugging Face model without authentication.")
        
        # Initialize HF client with minimal parameters to avoid compatibility issues
        try:
            from huggingface_hub import InferenceClient
            if self.hf_token:
                self.hf_client = InferenceClient(token=self.hf_token)
            else:
                self.hf_client = InferenceClient()
            logger.info("✅ HuggingFace client initialized successfully")
        except Exception as e:
            logger.warning(f"Failed to initialize HF client: {e}. HF fallback unavailable.")
            self.hf_client = None
            
        self.embedding_model = embedding_model
        
        # Set embedding strategy and dimensions
        self.use_openai_first = use_openai_first
        self.openai_embedding_dimensions = self._get_openai_dimensions(openai_embedding_model)
        self.hf_embedding_dimensions = self._get_hf_dimensions(embedding_model)
        
        # The dimensions actually used depend on which model is active
        self.active_embedding_model = openai_embedding_model if use_openai_first else embedding_model
        self.embedding_dimensions = self.openai_embedding_dimensions if use_openai_first else self.hf_embedding_dimensions
        
        logger.info(f"Clients initialized. Primary embedding: {'OpenAI ' + self.openai_embedding_model if use_openai_first else 'HF ' + self.embedding_model} ({self.embedding_dimensions}d)")
        logger.info(f"Fallback embedding: {'HF ' + self.embedding_model if use_openai_first else 'OpenAI ' + self.openai_embedding_model}")
        logger.info(f"OpenAI Chat model: {self.openai_chat_model}")

        # Initialize Qdrant vector store client - prioritize cloud over local
        qdrant_url = os.getenv("QDRANT_URL")
        qdrant_api_key = os.getenv("QDRANT_API_KEY")
        
        if qdrant_url and qdrant_api_key:
            # Use cloud Qdrant (for production/Azure)
            try:
                self.qdrant_client = QdrantClient(
                    url=qdrant_url,
                    api_key=qdrant_api_key
                )
                self.collection_name = collection_name
                self._ensure_collection_exists()
                logger.info(f"Qdrant Cloud client initialized. URL: {qdrant_url}, Collection: {self.collection_name}")
            except Exception as e:
                logger.error(f"Failed to connect to Qdrant Cloud at {qdrant_url}: {e}")
                logger.info("Falling back to in-memory Qdrant client")
                self.qdrant_client = QdrantClient(":memory:")
                self.collection_name = collection_name
                self._ensure_collection_exists()
                logger.info(f"In-memory Qdrant client initialized. Collection: {self.collection_name}")
        elif os.getenv("QDRANT_HOST"):
            # Use local Qdrant (for development)
            try:
                self.qdrant_client = QdrantClient(host=qdrant_host, port=qdrant_port)
                self.collection_name = collection_name
                self._ensure_collection_exists()
                logger.info(f"Local Qdrant client initialized. Host: {qdrant_host}, Port: {qdrant_port}, Collection: {self.collection_name}")
            except Exception as e:
                logger.warning(f"Failed to connect to local Qdrant at {qdrant_host}:{qdrant_port}: {e}")
                logger.info("Falling back to in-memory Qdrant client")
                self.qdrant_client = QdrantClient(":memory:")
                self.collection_name = collection_name
                self._ensure_collection_exists()
                logger.info(f"In-memory Qdrant client initialized. Collection: {self.collection_name}")
        else:
            # No Qdrant configured, use in-memory directly
            logger.info("No Qdrant configuration found, using in-memory vector store")
            self.qdrant_client = QdrantClient(":memory:")
            self.collection_name = collection_name
            self._ensure_collection_exists()
            logger.info(f"In-memory Qdrant client initialized. Collection: {self.collection_name}")

        # Initialize Redis cache with graceful fallback
        try:
            # For local development, try without SSL first
            redis_password = os.getenv("REDIS_PASSWORD")
            if not redis_password:
                logger.info("REDIS_PASSWORD not set. Disabling Redis cache.")
                self.cache = None
            else:
                # Try with SSL first (for Azure Redis Cache)
                try:
                    self.cache = redis.Redis(
                        host=redis_host, 
                        port=redis_port, 
                        password=redis_password,
                        ssl=True,
                        ssl_cert_reqs=None,
                        decode_responses=True
                    )
                    self.cache.ping()
                    logger.info(f"Redis cache initialized with SSL. Host: {redis_host}, Port: {redis_port}")
                except:
                    # Fallback to non-SSL connection
                    try:
                        self.cache = redis.Redis(
                            host=redis_host, 
                            port=redis_port, 
                            password=redis_password,
                            decode_responses=True
                        )
                        self.cache.ping()
                        logger.info(f"Redis cache initialized without SSL. Host: {redis_host}, Port: {redis_port}")
                    except Exception as e:
                        logger.warning(f"Redis connection failed: {e}. Cache will be unavailable.")
                        self.cache = None
        except Exception as e:
            logger.warning(f"Unexpected error connecting to Redis: {e}. Cache will be unavailable.")
            self.cache = None
        self.cache_ttl = cache_ttl
        
        # Track embedding failures to help with debugging
        self.openai_failure_count = 0
        self.hf_failure_count = 0
        
        # Track current embedding model for health checks
        self.current_embedding_model = self.openai_embedding_model if self.use_openai_first else self.embedding_model
        self.use_openai_embeddings = self.use_openai_first
        self.huggingface_model_name = self.embedding_model

    def _get_openai_dimensions(self, model_name: str) -> int:
        """Get embedding dimensions for OpenAI models."""
        dimensions_map = {
            "text-embedding-ada-002": 1536,
            "text-embedding-3-small": 1536,
            "text-embedding-3-large": 3072
        }
        return dimensions_map.get(model_name, 1536)  # Default to 1536 for unknown OpenAI models
    
    def _get_hf_dimensions(self, model_name: str) -> int:
        """Get embedding dimensions for HF models."""
        dimensions_map = {
            "sentence-transformers/all-mpnet-base-v2": 768,
            "sentence-transformers/all-MiniLM-L6-v2": 384,
            "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2": 384,
            "sentence-transformers/multi-qa-mpnet-base-dot-v1": 768,
            "intfloat/e5-large-v2": 1024
        }
        return dimensions_map.get(model_name, 768)  # Default to 768 for unknown HF models

    def _ensure_collection_exists(self):
        """Ensure the Qdrant collection exists with the correct configuration."""
        try:
            self.qdrant_client.get_collection(collection_name=self.collection_name)
            logger.info(f"Qdrant collection '{self.collection_name}' already exists.")
        except Exception as e:
            logger.info(f"Qdrant collection '{self.collection_name}' not found: {e}. Creating it.")
            self.qdrant_client.recreate_collection(
                collection_name=self.collection_name,
                vectors_config=qdrant_models.VectorParams(
                    size=self.embedding_dimensions,
                    distance=qdrant_models.Distance.COSINE
                )
            )
            logger.info(f"Qdrant collection '{self.collection_name}' created with vector size {self.embedding_dimensions}.")

    async def _generate_openai_embeddings(self, texts: List[str], max_retries=3) -> List[List[float]]:
        """Generate embeddings using OpenAI with detailed error logging and retry logic."""
        if not texts:
            return []
        
        # Clean and prepare texts
        max_chars = 8191  # OpenAI limit
        texts_to_embed = []
        for text in texts:
            cleaned_text = text.replace("\n", " ").strip()
            if len(cleaned_text) > max_chars:
                cleaned_text = cleaned_text[:max_chars]
                logger.warning(f"Text truncated to {max_chars} chars for OpenAI embedding")
            texts_to_embed.append(cleaned_text)
        
        retries = 0
        while retries <= max_retries:
            try:
                logger.debug(f"Generating OpenAI embeddings for {len(texts_to_embed)} texts using model {self.openai_embedding_model}")
                start_time = time.time()
                
                response = self.openai_client.embeddings.create(
                    input=texts_to_embed,
                    model=self.openai_embedding_model
                )
                embeddings = [item.embedding for item in response.data]
                
                # Log success
                logger.info(f"OpenAI embeddings completed in {time.time() - start_time:.2f}s")
                return embeddings
                    
            except Exception as e:
                retries += 1
                error_str = str(e)
                self.openai_failure_count += 1
                logger.error(f"OpenAI embedding error ({retries}/{max_retries}): {error_str}")
                
                if retries > max_retries:
                    logger.error(f"OpenAI embedding failed after {max_retries} retries. Error: {e}", exc_info=True)
                    raise
                
                wait_time = (2 ** retries) + 1  # Exponential backoff
                logger.warning(f"Retrying OpenAI embedding in {wait_time} seconds...")
                time.sleep(wait_time)

    async def _generate_embeddings_with_fallback(self, texts: List[str], max_retries=3) -> List[List[float]]:
        """Generate embeddings with OpenAI embedding models only (no fallback to HF)."""
        logger.info(f"Generating embeddings using OpenAI {self.openai_embedding_model}")
        
        try:
            # Always use OpenAI for embeddings (no fallback)
            embeddings = await self._generate_openai_embeddings(texts, max_retries)
            
            # Update active model info
            self.active_embedding_model = self.openai_embedding_model
            self.embedding_dimensions = self.openai_embedding_dimensions
            
            return embeddings
            
        except Exception as e:
            logger.error(f"OpenAI embedding failed: {str(e)}")
            raise Exception(f"OpenAI embedding failed: {str(e)}")

    async def ingest_document_data(self, document_id: str, text_blocks: List[Dict[str, Any]], document_metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Process document data, generate embeddings with fallback strategy, and store in Qdrant."""
        if not text_blocks:
            logger.warning(f"No text blocks provided for document_id: {document_id}. Nothing to ingest.")
            return {"status": "success", "message": "No text blocks to ingest.", "points_added": 0}
        
        logger.info(f"Starting ingestion for document_id: {document_id}, number of text blocks: {len(text_blocks)}")
        
        # Filter and truncate text blocks
        filtered_blocks = []
        for block in text_blocks:
            if not block.get("text"):
                continue
                
            # Limit text length
            max_chars = 2000  # Safe limit for embedding models
            if len(block["text"]) > max_chars:
                logger.warning(f"Truncating text block with {len(block['text'])} chars for document {document_id}")
                block["text"] = block["text"][:max_chars]
                
            filtered_blocks.append(block)
            
        text_blocks = filtered_blocks
        texts_for_embedding = [block["text"] for block in text_blocks]

        if not texts_for_embedding:
            logger.warning(f"All text blocks for document_id: {document_id} are empty. Nothing to embed.")
            return {"status": "success", "message": "No text content in blocks to ingest.", "points_added": 0}

        points_to_upsert = []
        try:
            # Use the fallback mechanism for embeddings
            embeddings = await self._generate_embeddings_with_fallback(texts_for_embedding)
            logger.info(f"Successfully generated embeddings for document {document_id} using model: {self.active_embedding_model}")
        except Exception as e:
            logger.error(f"Failed to generate embeddings for document_id: {document_id}. Error: {e}")
            return {"status": "error", "error": f"Embedding generation failed: {e}"}

        # Prepare points for Qdrant
        embedding_idx = 0
        for block in text_blocks:
            if not block.get("text"):
                continue
            
            payload = {
                "document_id": document_id,
                "text_content": block["text"],
                "page_number": block.get("page"),
                "block_id": block.get("id", str(uuid.uuid4())),
                "bbox": block.get("bbox"),
                "embedding_model": self.active_embedding_model,
                "embedding_timestamp": datetime.now().isoformat()
            }
            if document_metadata:
                payload.update(document_metadata)
            
            points_to_upsert.append(qdrant_models.PointStruct(
                id=block.get("id", str(uuid.uuid4())),
                vector=embeddings[embedding_idx],
                payload=payload
            ))
            embedding_idx += 1

        if points_to_upsert:
            try:
                self.qdrant_client.upsert(
                    collection_name=self.collection_name,
                    points=points_to_upsert,
                    wait=True
                )
                logger.info(f"Successfully upserted {len(points_to_upsert)} points for document_id: {document_id}")
                return {
                    "status": "success", 
                    "document_id": document_id, 
                    "points_added": len(points_to_upsert),
                    "embedding_model_used": self.active_embedding_model,
                    "embedding_dimensions": self.embedding_dimensions
                }
            except Exception as e:
                logger.error(f"Qdrant upsert failed for document_id: {document_id}. Error: {e}", exc_info=True)
                return {"status": "error", "error": f"Qdrant upsert failed: {e}"}
        else:
            logger.info(f"No points were prepared for upsert for document_id: {document_id}.")
            return {"status": "success", "message": "No valid points to upsert.", "points_added": 0}

    async def query_rag(self, user_query: str, top_k: int = 5, filters: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Process user query using embedding model for retrieval and OpenAI for generation."""
        logger.info(f"Received query: '{user_query}', top_k: {top_k}, filters: {filters}")
        
        try:
            # Generate query embedding
            query_embedding_list = await self._generate_embeddings_with_fallback([user_query])
            if not query_embedding_list:
                raise ValueError("Failed to generate query embedding.")
            query_embedding = query_embedding_list[0]
            logger.info(f"Query embedding generated successfully using {self.active_embedding_model}")
        except Exception as e:
            logger.error(f"Failed to generate embedding for query '{user_query}': {e}", exc_info=True)
            return {"status": "error", "error": f"Query embedding generation failed: {e}"}

        # Search in Qdrant
        try:
            search_results = self.qdrant_client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                limit=top_k,
                with_payload=True
            )
        except Exception as e:
            logger.error(f"Qdrant search failed for query '{user_query}': {e}", exc_info=True)
            return {"status": "error", "error": f"Vector search failed: {e}"}
        
        # Process search results
        logger.info(f"Found {len(search_results)} relevant contexts from Qdrant for query: '{user_query}'")
        
        if not search_results:
            logger.info(f"No relevant contexts found for query: '{user_query}'. Returning direct message.")
            final_response = {
                "answer": "I could not find any relevant information in the documents for your query.",
                "sources": [],
                "query": user_query
            }
            return {"status": "success", "result": final_response}

        # Build context from search results
        contexts = []
        retrieved_sources = []
        for i, hit in enumerate(search_results):
            context_text = hit.payload.get("text_content", "")
            contexts.append(f"Context [{i+1}]: {context_text}")
            retrieved_sources.append({
                "id": str(hit.id),
                "score": hit.score,
                "document_id": hit.payload.get("document_id"),
                "page_number": hit.payload.get("page_number"),
                "text": context_text[:200] + "..." if len(context_text) > 200 else context_text
            })

        # Generate response with OpenAI
        system_prompt = "You are a helpful AI assistant. Based on the provided context from insurance documents, answer the user's question. If the context does not contain the answer, state that clearly. Be concise and stick to the information in the context."
        context_str = "\n\n".join(contexts)
        user_prompt_template = f"Contexts:\n{context_str}\n\nQuestion: {user_query}\n\nAnswer:"

        try:
            chat_response = self.openai_client.chat.completions.create(
                model=self.openai_chat_model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt_template}
                ],
                temperature=0.2,
            )
            llm_answer = chat_response.choices[0].message.content.strip()
            logger.info(f"Received answer from LLM for query '{user_query}': '{llm_answer[:100]}...'")
        except Exception as e:
            logger.error(f"OpenAI chat completion failed for query '{user_query}': {e}", exc_info=True)
            return {"status": "error", "error": f"LLM response generation failed: {e}"}

        final_response = {
            "answer": llm_answer,
            "sources": retrieved_sources,
            "query": user_query,
            "embedding_model_used": self.active_embedding_model
        }

        return {"status": "success", "result": final_response}

    async def get_embedding_stats(self) -> Dict[str, Any]:
        """Return stats about embedding usage and failures."""
        return {
            "active_embedding_model": self.active_embedding_model,
            "primary_model": self.openai_embedding_model,
            "openai_embedding_failures": self.openai_failure_count,
            "hf_embedding_failures": self.hf_failure_count,
            "embedding_dimensions": self.embedding_dimensions,
        }
