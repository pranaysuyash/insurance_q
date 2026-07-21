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
    if batch_size < 1 or batch_size > 1000:
        return {"status": "error", "error": "batch_size must be between 1 and 1000"}

    processed_count = 0
    updated_count = 0
    errors = []

    # If Supabase backend.  This is deliberately a bounded, resumable pass:
    # the embedding contract lives in columns, not only in metadata, so a
    # backfill must update the model/version/dimension identity atomically with
    # the new vector.
    if getattr(pipeline, "vector_backend", "qdrant") == "supabase" and hasattr(pipeline, "vector_store"):
        client = pipeline.vector_store._client
        expected_model = str(getattr(pipeline, "active_embedding_model", "") or "").strip()
        expected_version = str(getattr(pipeline, "embedding_version", "v1") or "v1").strip()
        expected_dimensions = int(getattr(pipeline, "embedding_dimensions", 1536))
        if not expected_model or expected_dimensions != 1536:
            return {"status": "error", "error": "Supabase backfill requires a named 1536-dimensional embedding contract"}

        offset = 0
        while True:
            query = client.table("document_chunks").select(
                "id, content, metadata, document_id, owner_id, embedding_model, embedding_version, embedding_dimensions"
            ).order("id").range(offset, offset + batch_size - 1)
            if owner_id:
                query = query.eq("owner_id", owner_id)
            response = query.execute()
            rows = response.data or []
            if not rows:
                break
            logger.info("Inspecting backfill batch offset=%d size=%d", offset, len(rows))

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

                        # Update row in database, including the canonical contract.
                        update_query = client.table("document_chunks").update({
                            "metadata": metadata,
                            "embedding": new_vector,
                            "embedding_model": expected_model,
                            "embedding_dimensions": expected_dimensions,
                            "embedding_version": expected_version,
                        }).eq("id", row["id"])
                        if owner_id:
                            update_query = update_query.eq("owner_id", owner_id)
                        update_query.execute()

                        updated_count += 1
                except Exception as e:
                    logger.error("Failed to backfill chunk %s: %s", row["id"], e)
                    errors.append({"chunk_id": row["id"], "error": str(e)})

            offset += len(rows)
            if len(rows) < batch_size:
                break

    elif getattr(pipeline, "vector_backend", "qdrant") != "supabase":
        return {"status": "error", "error": "contextual backfill is only supported for the canonical Supabase backend"}

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
