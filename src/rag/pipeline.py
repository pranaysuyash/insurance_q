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
from huggingface_hub import InferenceClient  # For HF embeddings fallback

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
        self.openai_client = OpenAI(api_key=self.openai_api_key)
        self.openai_chat_model = openai_chat_model
        self.openai_embedding_model = openai_embedding_model
        
        # Initialize Hugging Face client for fallback embeddings
        self.hf_token = os.getenv("HF_TOKEN")
        if not self.hf_token:
            logger.warning("HF_TOKEN environment variable not set. Using Hugging Face model without authentication.")
        self.hf_client = InferenceClient(token=self.hf_token) 
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

        # Initialize Qdrant vector store client
        self.qdrant_client = QdrantClient(host=qdrant_host, port=qdrant_port)
        self.collection_name = collection_name
        self._ensure_collection_exists()
        logger.info(f"Qdrant client initialized. Host: {qdrant_host}, Port: {qdrant_port}, Collection: {self.collection_name}")

        # Initialize Redis cache
        try:
            self.cache = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)
            self.cache.ping()
            logger.info(f"Redis cache initialized. Host: {redis_host}, Port: {redis_port}")
        except redis.exceptions.ConnectionError as e:
            logger.error(f"Redis connection failed: {e}. Cache will be unavailable.", exc_info=True)
            self.cache = None
        self.cache_ttl = cache_ttl
        
        # Track embedding failures to help with debugging
        self.openai_embedding_failures = 0
        self.hf_embedding_failures = 0

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
        
        # Track token usage for diagnostics
        total_tokens = sum(len(text.split()) for text in texts_to_embed)
        logger.info(f"Total approximate tokens for OpenAI embedding: {total_tokens}")
        
        retries = 0
        while retries <= max_retries:
            try:
                logger.debug(f"Generating OpenAI embeddings for {len(texts_to_embed)} texts using model {self.openai_embedding_model}")
                start_time = time.time()
                
                # Process in smaller batches to avoid rate limits
                max_chunk_size = 5  # Smaller batch size for OpenAI API
                if len(texts_to_embed) > max_chunk_size:
                    logger.info(f"Processing {len(texts_to_embed)} texts in chunks of {max_chunk_size} for OpenAI")
                    all_embeddings = []
                    for i in range(0, len(texts_to_embed), max_chunk_size):
                        chunk = texts_to_embed[i:i+max_chunk_size]
                        chunk_start = time.time()
                        logger.debug(f"Sending chunk {i//max_chunk_size + 1}/{(len(texts_to_embed)-1)//max_chunk_size + 1} to OpenAI API")
                        
                        try:
                            response = self.openai_client.embeddings.create(
                                input=chunk,
                                model=self.openai_embedding_model
                            )
                            chunk_embeddings = [item.embedding for item in response.data]
                            all_embeddings.extend(chunk_embeddings)
                            
                            # Log success with API response details
                            chunk_time = time.time() - chunk_start
                            usage_info = getattr(response, 'usage', None)
                            if usage_info:
                                logger.info(f"OpenAI chunk {i//max_chunk_size + 1} usage: {usage_info.total_tokens} tokens in {chunk_time:.2f}s")
                            else:
                                logger.info(f"OpenAI chunk {i//max_chunk_size + 1} completed in {chunk_time:.2f}s (no usage info)")
                                
                            # Add longer delay between chunks to avoid rate limits
                            if i + max_chunk_size < len(texts_to_embed):
                                wait_time = 2.0  # Longer pause for OpenAI rate limits
                                logger.debug(f"Waiting {wait_time}s before next chunk to respect rate limits")
                                time.sleep(wait_time)
                        
                        except Exception as chunk_err:
                            logger.error(f"Error processing chunk {i//max_chunk_size + 1}: {chunk_err}")
                            raise  # Re-raise to be caught by the outer try-except
                    
                    logger.info(f"OpenAI embeddings completed for all {len(texts_to_embed)} texts in {time.time() - start_time:.2f}s")
                    return all_embeddings
                else:
                    # Process all at once for small batches
                    response = self.openai_client.embeddings.create(
                        input=texts_to_embed,
                        model=self.openai_embedding_model
                    )
                    embeddings = [item.embedding for item in response.data]
                    
                    # Log success with API response details
                    usage_info = getattr(response, 'usage', None)
                    if usage_info:
                        logger.info(f"OpenAI embedding usage: {usage_info.total_tokens} tokens in {time.time() - start_time:.2f}s")
                    else:
                        logger.info(f"OpenAI embeddings completed in {time.time() - start_time:.2f}s (no usage info)")
                        
                    return embeddings
                    
            except Exception as e:
                retries += 1
                error_str = str(e)
                self.openai_embedding_failures += 1
                
                # Provide detailed error information
                logger.error(f"OpenAI embedding error ({retries}/{max_retries}): {error_str}")
                
                # Check for specific error types
                if "rate limit" in error_str.lower() or "ratelimit" in error_str.lower():
                    logger.error(f"OpenAI rate limit exceeded. This is attempt {retries}/{max_retries}")
                    # Try to extract the reset time if available
                    import re
                    reset_match = re.search(r'Please try again in (\d+\.\d+|\.?\d+)s', error_str)
                    if reset_match:
                        wait_time = float(reset_match.group(1)) + 1.0  # Add buffer
                        logger.warning(f"Rate limit resets in {wait_time}s. Waiting...")
                        time.sleep(wait_time)
                        continue  # Try again immediately after waiting
                elif "billing" in error_str.lower() or "payment" in error_str.lower():
                    logger.error("OpenAI billing issue detected. Check your OpenAI account.")
                elif "token" in error_str.lower() or "key" in error_str.lower():
                    logger.error("OpenAI API key issue detected. Check your environment variables.")
                elif "capacity" in error_str.lower() or "server" in error_str.lower():
                    logger.error("OpenAI server capacity issue detected. This is likely a temporary problem.")
                
                if retries > max_retries:
                    logger.error(f"OpenAI embedding failed after {max_retries} retries. Error: {e}", exc_info=True)
                    raise
                
                wait_time = (2 ** retries) + 1  # Exponential backoff with jitter
                logger.warning(f"Retrying OpenAI embedding in {wait_time} seconds...")
                time.sleep(wait_time)

    async def _generate_hf_embeddings(self, texts: List[str], max_retries=3) -> List[List[float]]:
        """Generate embeddings using Hugging Face with detailed error logging."""
        if not texts:
            return []
        
        # Clean and truncate text
        max_chars = 2000  # Safer limit for embedding models
        texts_to_embed = []
        for text in texts:
            cleaned_text = text.replace("\n", " ").strip()
            if len(cleaned_text) > max_chars:
                cleaned_text = cleaned_text[:max_chars] + "..."
                logger.warning(f"Text truncated to {max_chars} chars for HF embedding")
            texts_to_embed.append(cleaned_text)
        
        retries = 0
        while retries <= max_retries:
            try:
                logger.debug(f"Generating HF embeddings for {len(texts_to_embed)} texts using model {self.embedding_model}")
                start_time = time.time()
                
                # Process in smaller chunks to avoid memory issues
                max_chunk_size = 10  # HF can handle larger batches than OpenAI
                if len(texts_to_embed) > max_chunk_size:
                    logger.info(f"Processing {len(texts_to_embed)} texts in chunks of {max_chunk_size} for HF")
                    all_embeddings = []
                    for i in range(0, len(texts_to_embed), max_chunk_size):
                        chunk = texts_to_embed[i:i+max_chunk_size]
                        embeddings = self.hf_client.feature_extraction(
                            inputs=chunk,
                            model=self.embedding_model
                        )
                        all_embeddings.extend(embeddings)
                        
                        # Log success and add delay
                        logger.debug(f"HF embedding chunk {i//max_chunk_size + 1} succeeded in {time.time() - start_time:.2f}s")
                        if i + max_chunk_size < len(texts_to_embed):
                            time.sleep(0.5)  # Brief pause between chunks
                    
                    logger.info(f"HF embeddings completed for all {len(texts_to_embed)} texts in {time.time() - start_time:.2f}s")
                    return all_embeddings
                else:
                    # Process all at once for small batches
                    embeddings = self.hf_client.feature_extraction(
                        inputs=texts_to_embed,
                        model=self.embedding_model
                    )
                    logger.info(f"HF embeddings completed for {len(texts_to_embed)} texts in {time.time() - start_time:.2f}s")
                    return embeddings
                    
            except Exception as e:
                retries += 1
                error_str = str(e)
                self.hf_embedding_failures += 1
                
                # Provide detailed error information
                logger.error(f"HF embedding error ({retries}/{max_retries}): {error_str}")
                
                # Check for specific error types
                if "timeout" in error_str.lower() or "connection" in error_str.lower():
                    logger.error(f"HF API connection issue. This is attempt {retries}/{max_retries}")
                elif "token" in error_str.lower() or "key" in error_str.lower():
                    logger.error("HF token issue detected. Check your environment variables.")
                
                if retries > max_retries:
                    logger.error(f"HF embedding failed after {max_retries} retries. Error: {e}", exc_info=True)
                    raise
                
                wait_time = (2 ** retries)  # Exponential backoff
                logger.warning(f"Retrying HF embedding in {wait_time} seconds...")
                time.sleep(wait_time)

    async def _generate_embeddings_with_fallback(self, texts: List[str], max_retries=3) -> List[List[float]]:
        """Generate embeddings with fallback strategy - try primary first, then fallback if it fails."""
        if self.use_openai_first:
            primary_method = self._generate_openai_embeddings
            fallback_method = self._generate_hf_embeddings
            primary_name = f"OpenAI {self.openai_embedding_model}"
            fallback_name = f"HF {self.embedding_model}" 
        else:
            primary_method = self._generate_hf_embeddings
            fallback_method = self._generate_openai_embeddings
            primary_name = f"HF {self.embedding_model}"
            fallback_name = f"OpenAI {self.openai_embedding_model}"
        
        # Try primary embedding method
        try:
            logger.info(f"Attempting to generate embeddings using primary method: {primary_name}")
            embeddings = await primary_method(texts, max_retries)
            
            # Update active model info if successful
            if self.use_openai_first:
                self.active_embedding_model = self.openai_embedding_model
                self.embedding_dimensions = self.openai_embedding_dimensions
            else:
                self.active_embedding_model = self.embedding_model
                self.embedding_dimensions = self.hf_embedding_dimensions
                
            return embeddings
            
        except Exception as primary_error:
            logger.warning(f"Primary embedding method {primary_name} failed: {primary_error}")
            logger.info(f"Falling back to alternative embedding method: {fallback_name}")
            
            # Try fallback embedding method
            try:
                embeddings = await fallback_method(texts, max_retries)
                
                # Update active model info for fallback
                if self.use_openai_first:
                    self.active_embedding_model = self.embedding_model
                    self.embedding_dimensions = self.hf_embedding_dimensions
                else:
                    self.active_embedding_model = self.openai_embedding_model
                    self.embedding_dimensions = self.openai_embedding_dimensions
                
                logger.info(f"Successfully generated embeddings using fallback method: {fallback_name}")
                return embeddings
                
            except Exception as fallback_error:
                logger.error(f"Both primary and fallback embedding methods failed!")
                logger.error(f"Primary error ({primary_name}): {primary_error}")
                logger.error(f"Fallback error ({fallback_name}): {fallback_error}")
                raise Exception(f"All embedding methods failed. Primary: {str(primary_error)}. Fallback: {str(fallback_error)}")

    async def ingest_document_data(self, document_id: str, text_blocks: List[Dict[str, Any]], document_metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Process document data, generate embeddings with fallback strategy, and store in Qdrant."""
        if not text_blocks:
            logger.warning(f"No text blocks provided for document_id: {document_id}. Nothing to ingest.")
            return {"status": "success", "message": "No text blocks to ingest.", "points_added": 0}
        
        logger.info(f"Starting ingestion for document_id: {document_id}, number of text blocks: {len(text_blocks)}")
        
        # Check if document already exists
        try:
            existing_count = self.qdrant_client.count(
                collection_name=self.collection_name,
                count_filter=qdrant_models.Filter(
                    must=[qdrant_models.FieldCondition(
                        key="document_id",
                        match=qdrant_models.MatchValue(value=document_id)
                    )]
                )
            )
            if existing_count.count > 0:
                logger.info(f"Document {document_id} already has {existing_count.count} points in Qdrant. Skipping ingestion.")
                return {"status": "success", "message": f"Document already exists with {existing_count.count} points.", "points_added": 0}
        except Exception as e:
            logger.warning(f"Error checking for existing document: {e}. Continuing with ingestion.")
        
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
                "embedding_model": self.active_embedding_model,  # Record which model was actually used
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
                logger.info(f"Successfully upserted {len(points_to_upsert)} points for document_id: {document_id} into '{self.collection_name}' using {self.active_embedding_model}.")
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
        """Process user query using embedding model with fallback for retrieval and OpenAI for generation."""
        logger.info(f"Received query: '{user_query}', top_k: {top_k}, filters: {filters}")
        cache_key = f"rag_query:{self.active_embedding_model}:{self.openai_chat_model}:{user_query}:{top_k}:{json.dumps(filters, sort_keys=True)}"
        
        # Try cache first
        if self.cache:
            try:
                cached_result = self.cache.get(cache_key)
                if cached_result:
                    logger.info(f"Returning cached result for query: '{user_query}'")
                    return json.loads(cached_result)
            except redis.exceptions.RedisError as e:
                logger.warning(f"Redis GET command failed: {e}. Proceeding without cache.")

        try:
            # Generate query embedding using fallback mechanism
            query_embedding_list = await self._generate_embeddings_with_fallback([user_query])
            if not query_embedding_list:
                raise ValueError("Failed to generate query embedding.")
            query_embedding = query_embedding_list[0]
            logger.info(f"Query embedding generated successfully using {self.active_embedding_model}")
        except Exception as e:
            logger.error(f"Failed to generate embedding for query '{user_query}': {e}", exc_info=True)
            return {"status": "error", "error": f"Query embedding generation failed: {e}"}

        # Prepare filter for Qdrant search
        qdrant_filter = None
        if filters:
            must_conditions = []
            for key, value in filters.items():
                must_conditions.append(qdrant_models.FieldCondition(key=f"payload.{key}", match=qdrant_models.MatchValue(value=value)))
            if must_conditions:
                qdrant_filter = qdrant_models.Filter(must=must_conditions)
            logger.info(f"Constructed Qdrant filter: {qdrant_filter}")

        # Search in Qdrant
        try:
            logger.debug(f"Searching Qdrant with vector from {self.active_embedding_model}")
            search_results = self.qdrant_client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                query_filter=qdrant_filter,
                limit=top_k,
                with_payload=True
            )
        except Exception as e:
            logger.error(f"Qdrant search failed for query '{user_query}': {e}", exc_info=True)
            return {"status": "error", "error": f"Vector search failed: {e}"}
        
        # Process search results
        logger.info(f"Found {len(search_results)} relevant contexts from Qdrant for query: '{user_query}'")
        contexts = []
        retrieved_sources = []
        if search_results:
            for i, hit in enumerate(search_results):
                context_text = hit.payload.get("text_content", "")
                contexts.append(f"Context [{i+1}]: {context_text}")
                retrieved_sources.append({
                    "id": hit.id,
                    "score": hit.score,
                    "document_id": hit.payload.get("document_id"),
                    "page_number": hit.payload.get("page_number"),
                    "block_id": hit.payload.get("block_id"),
                    "embedding_model": hit.payload.get("embedding_model", "unknown")
                })
        
        if not contexts:
            logger.info(f"No relevant contexts found for query: '{user_query}'. Returning direct message.")
            final_response = {
                "answer": "I could not find any relevant information in the documents for your query.",
                "sources": [],
                "query": user_query
            }
            # Cache this no-context response
            if self.cache:
                try: self.cache.setex(cache_key, self.cache_ttl, json.dumps(final_response))
                except redis.exceptions.RedisError as e: logger.warning(f"Redis SETEX command failed: {e}.")
            return {"status": "success", "result": final_response}

        # Generate response with OpenAI
        system_prompt = "You are a helpful AI assistant. Based on the provided context from insurance documents, answer the user's question. If the context does not contain the answer, state that clearly. Be concise and stick to the information in the context."
        context_str = "\n\n".join(contexts)
        user_prompt_template = f"Contexts:\n{context_str}\n\nQuestion: {user_query}\n\nAnswer:"

        try:
            logger.debug(f"Sending prompt to OpenAI chat model ({self.openai_chat_model}) for query: '{user_query}'")
            start_time = time.time()
            chat_response = self.openai_client.chat.completions.create(
                model=self.openai_chat_model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt_template}
                ],
                temperature=0.2,
            )
            llm_answer = chat_response.choices[0].message.content.strip()
            logger.info(f"Received answer from LLM in {time.time() - start_time:.2f}s for query '{user_query}': '{llm_answer[:100]}...'")
        except Exception as e:
            logger.error(f"OpenAI chat completion failed for query '{user_query}': {e}", exc_info=True)
            return {"status": "error", "error": f"LLM response generation failed: {e}"}

        final_response = {
            "answer": llm_answer,
            "sources": retrieved_sources,
            "query": user_query,
            "embedding_model_used": self.active_embedding_model
        }

        # Cache the response
        if self.cache:
            try:
                self.cache.setex(cache_key, self.cache_ttl, json.dumps(final_response))
                logger.info(f"Result for query '{user_query}' cached.")
            except redis.exceptions.RedisError as e:
                logger.warning(f"Redis SETEX command failed for query '{user_query}': {e}. Result not cached.")

        return {"status": "success", "result": final_response}

    async def get_embedding_stats(self) -> Dict[str, Any]:
        """Return stats about embedding usage and failures."""
        return {
            "active_embedding_model": self.active_embedding_model,
            "primary_model": self.openai_embedding_model if self.use_openai_first else self.embedding_model,
            "fallback_model": self.embedding_model if self.use_openai_first else self.openai_embedding_model,
            "openai_embedding_failures": self.openai_embedding_failures,
            "hf_embedding_failures": self.hf_embedding_failures,
            "embedding_dimensions": self.embedding_dimensions,
        }

# Example usage (for testing - not part of class)
# async def main_rag_test():
#     # Ensure OPENAI_API_KEY is set in environment
#     # Qdrant and Redis should be running (e.g., via docker-compose)
#     pipeline = RAGPipeline()

#     # Test Ingestion
#     sample_doc_id = "test_doc_001"
#     sample_text_blocks = [
#         {"id": "b1", "page": 1, "text": "The quick brown fox jumps over the lazy dog.", "bbox": [0.1,0.1,0.3,0.2]},
#         {"id": "b2", "page": 1, "text": "Medical expenses are covered up to $10,000.", "bbox": [0.1,0.3,0.5,0.4]},
#         {"id": "b3", "page": 2, "text": "The policy term is 12 months from the effective date.", "bbox": [0.2,0.1,0.6,0.2]}
#     ]
#     ingest_result = await pipeline.ingest_document_data(sample_doc_id, sample_text_blocks, {"filename": "policy_A.pdf"})
#     print("Ingestion Result:", json.dumps(ingest_result, indent=2))

#     if ingest_result["status"] == "success" and ingest_result.get("points_added", 0) > 0:
#         # Test Query
#         time.sleep(1) # Give Qdrant a moment to index if needed, though wait=True used in upsert
#         query1 = "What is the coverage for medical expenses?"
#         query_result1 = await pipeline.query_rag(query1)
#         print("Query 1 Result:", json.dumps(query_result1, indent=2))

#         query2 = "What is the policy term?"
#         query_result2 = await pipeline.query_rag(query2, filters={"filename": "policy_A.pdf"})
#         print("Query 2 Result (with filter):", json.dumps(query_result2, indent=2))
    
#     else:
#         print("Ingestion did not add points, skipping query test.")

# if __name__ == "__main__":
#     import asyncio
#     # logging.basicConfig(level=logging.DEBUG) # Enable for detailed logs
#     # asyncio.run(main_rag_test())
#     pass 