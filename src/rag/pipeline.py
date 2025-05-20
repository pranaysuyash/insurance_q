"""
Core RAG pipeline implementation using OpenAI for embeddings and generation, 
and Qdrant for vector storage.
"""
import os
import json
from typing import List, Dict, Optional, Any
from openai import OpenAI # Changed
from qdrant_client import QdrantClient, models as qdrant_models # aliased models
import redis
from datetime import datetime
import uuid # For generating IDs for Qdrant points if needed

# Configure logging
import logging
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
        openai_embedding_model: str = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-ada-002"),
        openai_chat_model: str = os.getenv("OPENAI_CHAT_MODEL", "gpt-3.5-turbo") # Consider gpt-4o-mini for balance
    ):
        """Initialize the RAG pipeline with OpenAI and Qdrant."""
        # Initialize OpenAI client
        self.openai_api_key = os.getenv("OPENAI_API_KEY")
        if not self.openai_api_key:
            logger.error("OPENAI_API_KEY environment variable not set.")
            raise ValueError("OPENAI_API_KEY environment variable not set.")
        self.openai_client = OpenAI(api_key=self.openai_api_key)
        self.openai_embedding_model = openai_embedding_model
        self.openai_chat_model = openai_chat_model
        logger.info(f"OpenAI client initialized. Embedding model: {self.openai_embedding_model}, Chat model: {self.openai_chat_model}")

        # Initialize Qdrant vector store client
        self.qdrant_client = QdrantClient(host=qdrant_host, port=qdrant_port)
        self.collection_name = collection_name
        self._ensure_collection_exists() # Ensure collection is created with correct config
        logger.info(f"Qdrant client initialized. Host: {qdrant_host}, Port: {qdrant_port}, Collection: {self.collection_name}")

        # Initialize Redis cache
        try:
            self.cache = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)
            self.cache.ping() # Verify connection
            logger.info(f"Redis cache initialized. Host: {redis_host}, Port: {redis_port}")
        except redis.exceptions.ConnectionError as e:
            logger.error(f"Redis connection failed: {e}. Cache will be unavailable.", exc_info=True)
            self.cache = None # Allow pipeline to run without cache if Redis is down
        self.cache_ttl = cache_ttl

    def _ensure_collection_exists(self):
        """Ensure the Qdrant collection exists with the correct configuration."""
        try:
            self.qdrant_client.get_collection(collection_name=self.collection_name)
            logger.info(f"Qdrant collection '{self.collection_name}' already exists.")
        except Exception as e: # More specific exception handling for Qdrant is better
            logger.info(f"Qdrant collection '{self.collection_name}' not found or error accessing: {e}. Attempting to create it.")
            # Determine vector size for the chosen OpenAI embedding model
            # text-embedding-ada-002 is 1536. For others, this might need to be dynamic.
            vector_size = 1536 # Default for text-embedding-ada-002
            if self.openai_embedding_model == "text-embedding-3-small":
                vector_size = 1536 # Also 1536, but can be 512 or 1536 based on 'dimensions' param
            elif self.openai_embedding_model == "text-embedding-3-large":
                vector_size = 3072 # Can be 256, 1024, 3072
            
            self.qdrant_client.recreate_collection(
                collection_name=self.collection_name,
                vectors_config=qdrant_models.VectorParams(
                    size=vector_size, 
                    distance=qdrant_models.Distance.COSINE
                )
            )
            logger.info(f"Qdrant collection '{self.collection_name}' created with vector size {vector_size}.")

    async def _generate_embeddings(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings for a list of texts using OpenAI."""
        if not texts:
            return []
        try:
            # Replace newlines, as recommended by OpenAI for their embedding models
            texts_to_embed = [text.replace("\n", " ") for text in texts]
            response = self.openai_client.embeddings.create(
                input=texts_to_embed,
                model=self.openai_embedding_model
            )
            return [item.embedding for item in response.data]
        except Exception as e:
            logger.error(f"Error generating OpenAI embeddings: {e}", exc_info=True)
            # Depending on policy, re-raise or return empty / handle gracefully
            raise

    async def ingest_document_data(self, document_id: str, text_blocks: List[Dict[str, Any]], document_metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Process structured document data (text_blocks from OCRPipeline), 
        generate embeddings, and store them in Qdrant.
        `document_id`: A unique identifier for the source document (e.g., filename or DB ID).
        `text_blocks`: List of dicts, each like {"id": str, "page": int, "text": str, "bbox": list}.
        `document_metadata`: Optional metadata about the entire document.
        """
        if not text_blocks:
            logger.warning(f"No text blocks provided for document_id: {document_id}. Nothing to ingest.")
            return {"status": "success", "message": "No text blocks to ingest.", "points_added": 0}
        
        logger.info(f"Starting ingestion for document_id: {document_id}, number of text blocks: {len(text_blocks)}")
        points_to_upsert = []
        texts_for_embedding = [block["text"] for block in text_blocks if block.get("text")]

        if not texts_for_embedding:
            logger.warning(f"All text blocks for document_id: {document_id} are empty. Nothing to embed.")
            return {"status": "success", "message": "No text content in blocks to ingest.", "points_added": 0}

        try:
            embeddings = await self._generate_embeddings(texts_for_embedding)
        except Exception as e:
            logger.error(f"Failed to generate embeddings for document_id: {document_id}. Error: {e}")
            return {"status": "error", "error": f"Embedding generation failed: {e}"}

        embedding_idx = 0
        for block in text_blocks:
            if not block.get("text"): # Skip empty blocks if any slipped through
                continue
            
            payload = {
                "document_id": document_id,
                "text_content": block["text"],
                "page_number": block.get("page"),
                "block_id": block.get("id", str(uuid.uuid4())), # Use provided ID or generate one
                "bbox": block.get("bbox")
            }
            if document_metadata: # Add document-level metadata to each chunk
                payload.update(document_metadata)
            
            points_to_upsert.append(qdrant_models.PointStruct(
                # id=str(uuid.uuid4()), # Or use block["id"] if globally unique and stable
                id=block.get("id", str(uuid.uuid4())), # Prefer OCR-generated block ID if available
                vector=embeddings[embedding_idx],
                payload=payload
            ))
            embedding_idx += 1

        if points_to_upsert:
            try:
                self.qdrant_client.upsert(
                    collection_name=self.collection_name,
                    points=points_to_upsert,
                    wait=True # Wait for operation to complete for robustness
                )
                logger.info(f"Successfully upserted {len(points_to_upsert)} points for document_id: {document_id} into '{self.collection_name}'.")
                return {"status": "success", "document_id": document_id, "points_added": len(points_to_upsert)}
            except Exception as e:
                logger.error(f"Qdrant upsert failed for document_id: {document_id}. Error: {e}", exc_info=True)
                return {"status": "error", "error": f"Qdrant upsert failed: {e}"}
        else:
            logger.info(f"No points were prepared for upsert for document_id: {document_id}.")
            return {"status": "success", "message": "No valid points to upsert.", "points_added": 0}

    async def query_rag(self, user_query: str, top_k: int = 5, filters: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Process a user query: embed, search Qdrant, and generate response with OpenAI LLM."""
        logger.info(f"Received query: '{user_query}', top_k: {top_k}, filters: {filters}")
        cache_key = f"rag_query:{self.openai_embedding_model}:{self.openai_chat_model}:{user_query}:{top_k}:{json.dumps(filters, sort_keys=True)}"
        
        if self.cache:
            try:
                cached_result = self.cache.get(cache_key)
                if cached_result:
                    logger.info(f"Returning cached result for query: '{user_query}'")
                    return json.loads(cached_result)
            except redis.exceptions.RedisError as e:
                logger.warning(f"Redis GET command failed: {e}. Proceeding without cache.")

        try:
            query_embedding_list = await self._generate_embeddings([user_query])
            if not query_embedding_list:
                raise ValueError("Failed to generate query embedding.")
            query_embedding = query_embedding_list[0]
        except Exception as e:
            logger.error(f"Failed to generate embedding for query '{user_query}': {e}", exc_info=True)
            return {"status": "error", "error": f"Query embedding generation failed: {e}"}

        qdrant_filter = None
        if filters:
            # Example: filters = {"document_id": "doc123", "page_number": 2}
            # Creates a list of FieldCondition
            must_conditions = []
            for key, value in filters.items():
                # Qdrant needs specific model types for values, e.g. MatchValue, MatchText etc.
                # For exact matches on keywords or numbers, MatchValue is typical.
                must_conditions.append(qdrant_models.FieldCondition(key=f"payload.{key}", match=qdrant_models.MatchValue(value=value)))
            if must_conditions:
                qdrant_filter = qdrant_models.Filter(must=must_conditions)
            logger.info(f"Constructed Qdrant filter: {qdrant_filter}")

        try:
            search_results = self.qdrant_client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                query_filter=qdrant_filter,
                limit=top_k,
                with_payload=True # Ensure payload is returned
            )
        except Exception as e:
            logger.error(f"Qdrant search failed for query '{user_query}': {e}", exc_info=True)
            return {"status": "error", "error": f"Vector search failed: {e}"}
        
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
                    # "text": context_text # Optionally include text in source for debugging
                })
        
        if not contexts:
            logger.info(f"No relevant contexts found for query: '{user_query}'. Returning direct message.")
            final_response = {
                "answer": "I could not find any relevant information in the documents for your query.",
                "sources": [],
                "query": user_query
            }
            # Cache this no-context response as well
            if self.cache:
                try: self.cache.setex(cache_key, self.cache_ttl, json.dumps(final_response))
                except redis.exceptions.RedisError as e: logger.warning(f"Redis SETEX command failed: {e}.")
            return {"status": "success", "result": final_response}

        # Prepare prompt for OpenAI Chat Completion
        system_prompt = "You are a helpful AI assistant. Based on the provided context from insurance documents, answer the user's question. If the context does not contain the answer, state that clearly. Be concise and stick to the information in the context."
        context_str = "\n\n".join(contexts)
        user_prompt_template = f"Contexts:\n{context_str}\n\nQuestion: {user_query}\n\nAnswer:"

        try:
            logger.debug(f"Sending prompt to OpenAI chat model ({self.openai_chat_model}) for query: '{user_query}'")
            chat_response = self.openai_client.chat.completions.create(
                model=self.openai_chat_model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt_template}
                ],
                temperature=0.2, # Lower temperature for more factual answers
            )
            llm_answer = chat_response.choices[0].message.content.strip()
            logger.info(f"Received answer from LLM for query '{user_query}': '{llm_answer[:100]}...'")
        except Exception as e:
            logger.error(f"OpenAI chat completion failed for query '{user_query}': {e}", exc_info=True)
            return {"status": "error", "error": f"LLM response generation failed: {e}"}

        final_response = {
            "answer": llm_answer,
            "sources": retrieved_sources, # Information about where the context came from
            "query": user_query
        }

        if self.cache:
            try:
                self.cache.setex(cache_key, self.cache_ttl, json.dumps(final_response))
                logger.info(f"Result for query '{user_query}' cached.")
            except redis.exceptions.RedisError as e:
                logger.warning(f"Redis SETEX command failed for query '{user_query}': {e}. Result not cached.")

        return {"status": "success", "result": final_response}

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