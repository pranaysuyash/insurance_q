"""
Backfill script for Contextual Retrieval (Commit 6, ADR-2026-07-20-26).
Populates retrieval_text for document chunks where retrieval_text == source_text.
"""
import asyncio
import logging
from typing import Dict, Any, List, Optional
from src.rag.pipeline import RAGPipeline

logger = logging.getLogger(__name__)


async def backfill_contextual_retrieval(
    pipeline: RAGPipeline,
    collection_name: Optional[str] = None,
    owner_id: Optional[str] = None,
    batch_size: int = 20,
) -> Dict[str, Any]:
    """Backfill LLM-generated contextual retrieval_text for stored document chunks.
    
    Per ADR-26 (Commit 6):
    Iterates document chunks where retrieval_text is unpopulated or equals source_text,
    generates 1-2 sentence context prepended to retrieval_text, and updates vector store.
    """
    logger.info("Starting contextual retrieval backfill...")
    if not pipeline.llm:
        return {"status": "error", "error": "LLM client not available"}

    processed_count = 0
    updated_count = 0
    errors = []

    # If Supabase backend
    if getattr(pipeline, "vector_backend", "qdrant") == "supabase" and hasattr(pipeline, "vector_store"):
        client = pipeline.vector_store._client
        query = client.table("document_chunks").select("id, content, metadata, document_id, owner_id")
        if owner_id:
            query = query.eq("owner_id", owner_id)
        
        response = query.execute()
        rows = response.data or []
        logger.info("Found %d chunks to inspect for backfill", len(rows))

        for row in rows:
            processed_count += 1
            content = row.get("content", "")
            metadata = dict(row.get("metadata") or {})
            source_text = metadata.get("source_text", content)
            retrieval_text = metadata.get("retrieval_text", content)

            # Skip if already contextualized
            if retrieval_text != source_text and len(retrieval_text) > len(source_text):
                continue

            try:
                # Contextualize single chunk
                block = {"text": content, "source_text": source_text}
                doc_meta = {"document_id": row.get("document_id")}
                contextualized_blocks = await pipeline._contextualize_chunks([block], doc_meta)
                new_retrieval_text = contextualized_blocks[0].get("retrieval_text", source_text)

                if new_retrieval_text != source_text:
                    metadata["retrieval_text"] = new_retrieval_text
                    metadata["contextualized"] = True

                    # Generate new embedding for retrieval_text
                    embeddings = await pipeline._generate_embeddings_with_fallback([new_retrieval_text])
                    new_vector = embeddings[0]

                    # Update row in database
                    client.table("document_chunks").update({
                        "metadata": metadata,
                        "embedding": new_vector
                    }).eq("id", row["id"]).execute()
                    
                    updated_count += 1
            except Exception as e:
                logger.error("Failed to backfill chunk %s: %s", row["id"], e)
                errors.append({"chunk_id": row["id"], "error": str(e)})

    return {
        "status": "success",
        "processed_count": processed_count,
        "updated_count": updated_count,
        "error_count": len(errors),
        "errors": errors[:10],
    }


if __name__ == "__main__":
    async def main():
        pipeline = RAGPipeline()
        res = await backfill_contextual_retrieval(pipeline)
        print(res)
    asyncio.run(main())
