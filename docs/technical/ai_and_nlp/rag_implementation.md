# RAG Implementation: Technical Details

This document provides a detailed technical overview of the Retrieval Augmented Generation (RAG) implementation used in the Insurance Policy Parser & QA App. It covers the architecture, components, implementation details, and optimization strategies for the RAG system.

## Overview

Retrieval Augmented Generation (RAG) combines information retrieval with text generation to produce accurate, contextual answers based on specific documents. In our application, RAG enables users to ask natural language questions about their insurance policies and receive precise answers grounded in their policy documents.

The RAG system consists of three main components:
1. **Document Processing & Indexing**: Converts insurance documents into searchable chunks with vector embeddings
2. **Retrieval System**: Finds relevant document sections based on user queries
3. **Answer Generation**: Creates accurate, contextual answers using retrieved information

## Architecture

### High-Level RAG Flow

```
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ User          │    │ Query         │    │ Document      │    │ Answer        │
│ Question      │───>│ Processing    │───>│ Retrieval     │───>│ Generation    │
│               │    │               │    │               │    │               │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
                                                                        │
                                                                        ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Response      │    │ Answer        │    │ Source        │    │ Answer        │
│ Delivery      │<───│ Enhancement   │<───│ Citation      │<───│ Verification  │
│               │    │               │    │               │    │               │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
```

### Components in Detail

#### 1. Document Processing & Indexing

Before RAG can operate, documents must be processed and indexed:

```
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Document      │    │ Text          │    │ Document      │    │ Text          │
│ Upload        │───>│ Extraction    │───>│ Structure     │───>│ Chunking      │
│               │    │               │    │ Analysis      │    │               │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
                                                                        │
                                                                        ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Vector DB     │    │ Embedding     │    │ Metadata      │    │ Chunk         │
│ Storage       │<───│ Generation    │<───│ Attachment    │<───│ Enhancement   │
│               │    │               │    │               │    │               │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
```

#### 2. Retrieval System

When a user asks a question, the retrieval system finds relevant document sections:

```
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Query         │    │ Query         │    │ Embedding     │    │ Vector        │
│ Input         │───>│ Processing    │───>│ Generation    │───>│ Search        │
│               │    │               │    │               │    │               │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
                                                                        │
                                                                        ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Context       │    │ Result        │    │ Reranking     │    │ Filter &      │
│ Assembly      │<───│ Processing    │<───│               │<───│ Metadata      │
│               │    │               │    │               │    │               │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
```

#### 3. Answer Generation

The retrieved context is used to generate an accurate answer:

```
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Context &     │    │ Prompt        │    │ LLM           │    │ Response      │
│ Question      │───>│ Engineering   │───>│ Generation    │───>│ Parsing       │
│               │    │               │    │               │    │               │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
                                                                        │
                                                                        ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Response      │    │ Citation      │    │ Answer        │    │ Confidence    │
│ Formatting    │<───│ Generation    │<───│ Verification  │<───│ Scoring       │
│               │    │               │    │               │    │               │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
```

## Implementation Details

### Document Processing and Embedding

#### Text Chunking Strategies

Effective chunking is critical for retrieval quality. We implement multiple chunking strategies:

1. **Section-Based Chunking**: Respects document structure
```python
def create_section_based_chunks(document, structure):
    """Create chunks based on document sections."""
    chunks = []
    for section in structure["sections"]:
        section_text = extract_section_text(document, section)
        # Create chunk for section
        chunks.append({
            "text": section_text,
            "metadata": {
                "section": section["title"],
                "page_range": (section["start_page"], section["end_page"]),
                "level": section["level"]
            }
        })
        
        # Create sub-chunks if section is large
        if len(section_text) > MAX_CHUNK_SIZE:
            sub_chunks = split_into_chunks(section_text, MAX_CHUNK_SIZE, CHUNK_OVERLAP)
            for i, sub_chunk in enumerate(sub_chunks):
                chunks.append({
                    "text": sub_chunk,
                    "metadata": {
                        "section": section["title"],
                        "page_range": (section["start_page"], section["end_page"]),
                        "level": section["level"],
                        "sub_chunk": i
                    }
                })
    
    return chunks
```

2. **Semantic Chunking**: Maintains semantic coherence
```python
def create_semantic_chunks(document):
    """Create chunks based on semantic boundaries."""
    # Use NLP to identify sentence and paragraph boundaries
    nlp = spacy.load("en_core_web_sm")
    doc = nlp(document)
    
    # Group sentences into chunks based on semantic similarity
    chunks = []
    current_chunk = []
    current_length = 0
    
    for sent in doc.sents:
        if current_length + len(sent) > MAX_CHUNK_SIZE and current_chunk:
            # Create a new chunk
            chunks.append({"text": " ".join(current_chunk)})
            current_chunk = [sent.text]
            current_length = len(sent)
        else:
            current_chunk.append(sent.text)
            current_length += len(sent)
    
    # Add the last chunk if it exists
    if current_chunk:
        chunks.append({"text": " ".join(current_chunk)})
    
    return chunks
```

3. **Sliding Window Chunking**: Optimizes for retrieval recall
```python
def create_sliding_window_chunks(document, chunk_size=1000, chunk_overlap=200):
    """Create overlapping chunks using sliding window."""
    text = document.strip()
    chunks = []
    
    # Use token-based chunking for more accurate sizing
    tokenizer = tiktoken.get_encoding("cl100k_base")  # OpenAI tokenizer
    tokens = tokenizer.encode(text)
    
    i = 0
    while i < len(tokens):
        # Get chunk_size tokens or remaining tokens if less
        chunk_end = min(i + chunk_size, len(tokens))
        chunk_tokens = tokens[i:chunk_end]
        chunk_text = tokenizer.decode(chunk_tokens)
        
        chunks.append({
            "text": chunk_text,
            "token_count": len(chunk_tokens)
        })
        
        # Slide by (chunk_size - chunk_overlap)
        i += (chunk_size - chunk_overlap)
    
    return chunks
```

#### Embedding Generation

We use state-of-the-art embedding models to convert text chunks into vector representations:

```python
class EmbeddingService:
    """Service for generating and managing embeddings."""
    
    def __init__(self, embedding_model="text-embedding-ada-002"):
        """Initialize the embedding service."""
        self.embedding_model = embedding_model
        self.openai_client = OpenAI()
        # Fallback embeddings for offline or error cases
        self.sentence_transformer = SentenceTransformer('all-MiniLM-L6-v2')
    
    async def generate_embeddings(self, texts):
        """Generate embeddings for a list of texts."""
        try:
            # Use OpenAI embeddings for production quality
            response = await self.openai_client.embeddings.create(
                model=self.embedding_model,
                input=texts
            )
            return [item.embedding for item in response.data]
        except Exception as e:
            # Fall back to local embedding model
            logger.warning(f"OpenAI embedding failed, using fallback: {e}")
            return self.generate_fallback_embeddings(texts)
    
    def generate_fallback_embeddings(self, texts):
        """Generate embeddings using local model as fallback."""
        return self.sentence_transformer.encode(texts).tolist()
    
    async def embed_chunks(self, chunks):
        """Embed a list of text chunks."""
        texts = [chunk["text"] for chunk in chunks]
        
        # Process in batches to avoid rate limits
        batch_size = 100
        all_embeddings = []
        
        for i in range(0, len(texts), batch_size):
            batch_texts = texts[i:i+batch_size]
            batch_embeddings = await self.generate_embeddings(batch_texts)
            all_embeddings.extend(batch_embeddings)
        
        # Add embeddings to chunks
        for i, embedding in enumerate(all_embeddings):
            chunks[i]["embedding"] = embedding
        
        return chunks
```

#### Vector Storage

We use vector databases to efficiently store and query embeddings:

```python
class VectorStore:
    """Manages storage and retrieval of vector embeddings."""
    
    def __init__(self, vector_db_type="pinecone"):
        """Initialize the vector store."""
        self.vector_db_type = vector_db_type
        self.db_client = self._initialize_db_client()
    
    def _initialize_db_client(self):
        """Initialize the appropriate vector DB client."""
        if self.vector_db_type == "pinecone":
            return self._init_pinecone()
        elif self.vector_db_type == "faiss":
            return self._init_faiss()
        else:
            raise ValueError(f"Unsupported vector DB type: {self.vector_db_type}")
    
    def _init_pinecone(self):
        """Initialize Pinecone client."""
        api_key = os.environ.get("PINECONE_API_KEY")
        environment = os.environ.get("PINECONE_ENVIRONMENT")
        index_name = os.environ.get("PINECONE_INDEX_NAME")
        
        pinecone.init(api_key=api_key, environment=environment)
        return pinecone.Index(index_name)
    
    def _init_faiss(self):
        """Initialize FAISS index."""
        # For local FAISS usage
        return {"index": faiss.IndexFlatL2(1536), "id_map": {}, "count": 0}
    
    async def store_vectors(self, chunks, namespace):
        """Store vectors in the database."""
        if self.vector_db_type == "pinecone":
            vectors = []
            for i, chunk in enumerate(chunks):
                vector_id = f"{namespace}_{i}_{uuid.uuid4()}"
                vectors.append({
                    "id": vector_id,
                    "values": chunk["embedding"],
                    "metadata": {
                        "text": chunk["text"],
                        "document_id": chunk.get("document_id"),
                        "section": chunk.get("metadata", {}).get("section"),
                        "page_range": chunk.get("metadata", {}).get("page_range"),
                        # Other metadata
                    }
                })
            
            # Store in batches
            batch_size = 100
            for i in range(0, len(vectors), batch_size):
                batch = vectors[i:i+batch_size]
                self.db_client.upsert(vectors=batch, namespace=namespace)
        
        elif self.vector_db_type == "faiss":
            # For local FAISS implementation
            vectors = np.array([chunk["embedding"] for chunk in chunks]).astype('float32')
            
            # Add vectors to the index
            start_idx = self.db_client["count"]
            self.db_client["index"].add(vectors)
            
            # Update id mapping
            for i, chunk in enumerate(chunks):
                idx = start_idx + i
                vector_id = f"{namespace}_{i}_{uuid.uuid4()}"
                self.db_client["id_map"][idx] = {
                    "id": vector_id,
                    "text": chunk["text"],
                    "metadata": chunk.get("metadata", {})
                }
            
            self.db_client["count"] += len(chunks)
    
    async def search_vectors(self, query_embedding, namespace, top_k=5, filters=None):
        """Search for similar vectors."""
        if self.vector_db_type == "pinecone":
            response = self.db_client.query(
                vector=query_embedding,
                top_k=top_k,
                namespace=namespace,
                filter=filters
            )
            
            return [{
                "id": match["id"],
                "score": match["score"],
                "text": match["metadata"]["text"],
                "metadata": {k: v for k, v in match["metadata"].items() if k != "text"}
            } for match in response["matches"]]
        
        elif self.vector_db_type == "faiss":
            # Convert query to numpy array
            query_vector = np.array([query_embedding]).astype('float32')
            
            # Search the index
            D, I = self.db_client["index"].search(query_vector, top_k)
            
            # Process results
            results = []
            for i, (distance, idx) in enumerate(zip(D[0], I[0])):
                if idx < 0 or idx >= self.db_client["count"]:
                    continue
                
                item = self.db_client["id_map"][idx]
                
                # Apply filters if provided
                if filters and not self._apply_filters(item["metadata"], filters):
                    continue
                
                results.append({
                    "id": item["id"],
                    "score": 1.0 - (distance / 2.0),  # Convert distance to similarity score
                    "text": item["text"],
                    "metadata": item["metadata"]
                })
            
            return results
    
    def _apply_filters(self, metadata, filters):
        """Apply metadata filters (simplified version)."""
        for key, value in filters.items():
            if key not in metadata or metadata[key] != value:
                return False
        return True
```

### Query Processing and Retrieval

#### Query Understanding

To improve retrieval accuracy, we analyze and expand user queries:

```python
class QueryProcessor:
    """Process and enhance user queries for better retrieval."""
    
    def __init__(self, nlp_model="en_core_web_sm"):
        """Initialize the query processor."""
        self.nlp = spacy.load(nlp_model)
        
    def process_query(self, query_text, conversation_history=None):
        """Process and enhance the query."""
        # Basic processing
        query = query_text.strip()
        
        # Handle follow-up questions
        if conversation_history and self._is_followup_question(query):
            query = self._resolve_references(query, conversation_history)
        
        # Extract key entities
        entities = self._extract_entities(query)
        
        # Expand the query with related terms
        expanded_query = self._expand_query(query, entities)
        
        return {
            "original_query": query_text,
            "processed_query": query,
            "expanded_query": expanded_query,
            "entities": entities,
            "is_followup": conversation_history and self._is_followup_question(query_text)
        }
    
    def _is_followup_question(self, query):
        """Determine if a query is a follow-up question."""
        # Check for pronouns and other reference indicators
        doc = self.nlp(query)
        pronouns = {"it", "this", "that", "these", "those", "they", "them"}
        
        # Check first few tokens for pronouns or if query starts with a verb
        first_tokens = {token.text.lower() for token in list(doc)[:3]}
        starts_with_verb = len(doc) > 0 and doc[0].pos_ == "VERB"
        
        return bool(first_tokens.intersection(pronouns)) or starts_with_verb or len(query) < 20
    
    def _resolve_references(self, query, conversation_history):
        """Resolve references in follow-up questions."""
        # Get the last few exchanges
        recent_history = conversation_history[-4:] if len(conversation_history) >= 4 else conversation_history
        
        # Extract context from previous exchanges
        context = " ".join([msg["content"] for msg in recent_history if msg["role"] == "assistant"])
        
        # Simple reference resolution (could be enhanced with LLM)
        doc = self.nlp(query)
        has_pronouns = any(token.text.lower() in {"it", "this", "that", "these", "those", "they", "them"} 
                         for token in doc)
        
        if has_pronouns:
            # Extract key terms from last assistant response
            last_response = next((msg["content"] for msg in reversed(recent_history) 
                              if msg["role"] == "assistant"), "")
            key_terms = self._extract_key_terms(last_response)
            
            # Create a more explicit query
            if key_terms:
                return f"{query} about {', '.join(key_terms[:3])}"
        
        return query
    
    def _extract_entities(self, text):
        """Extract key entities from the query."""
        doc = self.nlp(text)
        entities = {}
        
        # Extract named entities
        for ent in doc.ents:
            if ent.label_ not in entities:
                entities[ent.label_] = []
            entities[ent.label_].append(ent.text)
        
        # Extract noun phrases
        noun_phrases = [chunk.text for chunk in doc.noun_chunks]
        entities["NOUN_PHRASE"] = noun_phrases
        
        # Extract key terms (nouns, verbs, adjectives)
        key_terms = [token.text for token in doc if token.pos_ in {"NOUN", "VERB", "ADJ"} 
                   and not token.is_stop]
        entities["KEY_TERM"] = key_terms
        
        return entities
    
    def _extract_key_terms(self, text):
        """Extract key terms from text."""
        doc = self.nlp(text)
        return [token.text for token in doc if token.pos_ in {"NOUN", "PROPN"} 
              and not token.is_stop and len(token.text) > 3]
    
    def _expand_query(self, query, entities):
        """Expand the query with related terms for better retrieval."""
        # Simple expansion using key terms
        key_terms = entities.get("KEY_TERM", [])
        noun_phrases = entities.get("NOUN_PHRASE", [])
        
        # For insurance domain, we could add common synonyms
        insurance_synonyms = {
            "deductible": ["deductible", "out of pocket", "initial payment"],
            "premium": ["premium", "payment", "cost", "fee"],
            "coverage": ["coverage", "protection", "covered", "benefits"],
            "claim": ["claim", "filing", "reimbursement"],
            "policy": ["policy", "plan", "insurance", "contract"]
        }
        
        expanded_terms = set()
        for term in key_terms:
            term_lower = term.lower()
            for key, synonyms in insurance_synonyms.items():
                if term_lower == key or term_lower in synonyms:
                    expanded_terms.update(synonyms)
        
        # Create expanded query
        expansion = " ".join(list(expanded_terms)[:5])
        if expansion:
            return f"{query} {expansion}"
        return query
```

#### Multi-Stage Retrieval

For accurate context retrieval, we implement a multi-stage retrieval process:

```python
class RetrievalPipeline:
    """Multi-stage retrieval pipeline for finding relevant context."""
    
    def __init__(self, embedding_service, vector_store):
        """Initialize the retrieval pipeline."""
        self.embedding_service = embedding_service
        self.vector_store = vector_store
        self.reranker = CrossEncoderReranker("cross-encoder/ms-marco-MiniLM-L-6-v2")
    
    async def retrieve(self, processed_query, user_id, policy_ids=None, top_k=10):
        """Execute the multi-stage retrieval process."""
        # Stage 1: Generate query embedding
        query_embedding = await self.embedding_service.generate_embeddings(
            [processed_query["processed_query"]]
        )
        query_embedding = query_embedding[0]
        
        # Prepare filters
        filters = {"user_id": user_id}
        if policy_ids:
            filters["policy_id"] = {"$in": policy_ids}
        
        # Stage 2: Initial broad retrieval
        initial_results = await self.vector_store.search_vectors(
            query_embedding=query_embedding,
            namespace=f"user_{user_id}",
            top_k=top_k * 3,  # Retrieve more candidates for reranking
            filters=filters
        )
        
        if not initial_results:
            return []
        
        # Stage 3: Reranking for precision
        reranked_results = await self._rerank_results(
            processed_query["processed_query"],
            initial_results
        )
        
        # Stage 4: Diversification and result selection
        final_results = self._diversify_results(reranked_results, top_k)
        
        return final_results
    
    async def _rerank_results(self, query, initial_results):
        """Rerank initial results for better precision."""
        # Prepare passages for reranking
        passages = [result["text"] for result in initial_results]
        
        # Rerank using cross-encoder
        scores = self.reranker.rerank(query, passages)
        
        # Combine with original results and sort by new scores
        reranked = []
        for i, (score, result) in enumerate(zip(scores, initial_results)):
            result_copy = result.copy()
            result_copy["rerank_score"] = float(score)
            reranked.append(result_copy)
        
        # Sort by reranking score (descending)
        reranked.sort(key=lambda x: x["rerank_score"], reverse=True)
        
        return reranked
    
    def _diversify_results(self, reranked_results, top_k):
        """Select diverse results to ensure coverage."""
        if len(reranked_results) <= top_k:
            return reranked_results
        
        # Initialize with the highest-scored result
        selected = [reranked_results[0]]
        candidates = reranked_results[1:]
        
        # Select remaining results balancing score and diversity
        while len(selected) < top_k and candidates:
            # Calculate diversity scores (simple text overlap for illustration)
            diversity_scores = []
            for candidate in candidates:
                # Calculate average text overlap with selected results
                overlaps = []
                for sel in selected:
                    overlap = self._calculate_text_overlap(candidate["text"], sel["text"])
                    overlaps.append(overlap)
                
                avg_overlap = sum(overlaps) / len(overlaps) if overlaps else 0
                diversity_score = 1.0 - avg_overlap  # Higher is more diverse
                
                # Combined score (balance of ranking and diversity)
                combined_score = (candidate["rerank_score"] * 0.7) + (diversity_score * 0.3)
                diversity_scores.append((candidate, combined_score))
            
            # Select candidate with highest combined score
            diversity_scores.sort(key=lambda x: x[1], reverse=True)
            best_candidate, _ = diversity_scores[0]
            
            # Add to selected and remove from candidates
            selected.append(best_candidate)
            candidates.remove(best_candidate)
        
        return selected
    
    def _calculate_text_overlap(self, text1, text2):
        """Calculate text overlap ratio between two texts."""
        # Simple implementation using set overlap of words
        words1 = set(text1.lower().split())
        words2 = set(text2.lower().split())
        
        if not words1 or not words2:
            return 0
        
        intersection = words1.intersection(words2)
        union = words1.union(words2)
        
        return len(intersection) / len(union)
```

#### Context Assembly

To prepare retrieved chunks for the LLM:

```python
class ContextAssembler:
    """Assemble retrieved chunks into a coherent context for the LLM."""
    
    def __init__(self, max_tokens=6000):
        """Initialize the context assembler."""
        self.max_tokens = max_tokens
        self.tokenizer = tiktoken.get_encoding("cl100k_base")  # OpenAI tokenizer
    
    def assemble_context(self, query, retrieval_results):
        """Assemble a context from retrieval results."""
        # First, prioritize chunks based on score and relevance
        prioritized_chunks = self._prioritize_chunks(retrieval_results)
        
        # Then, assemble context while respecting token limits
        context, used_chunks = self._build_context(prioritized_chunks)
        
        # Format context for the LLM
        formatted_context = self._format_context(context, query)
        
        return {
            "formatted_context": formatted_context,
            "raw_context": context,
            "used_chunks": used_chunks,
            "token_count": len(self.tokenizer.encode(formatted_context))
        }
    
    def _prioritize_chunks(self, retrieval_results):
        """Prioritize chunks based on multiple factors."""
        # For now, just use rerank score
        return sorted(retrieval_results, key=lambda x: x.get("rerank_score", x["score"]), reverse=True)
    
    def _build_context(self, prioritized_chunks):
        """Build context while respecting token limits."""
        context = []
        used_chunks = []
        total_tokens = 0
        
        # Reserve tokens for prompt template and query (approximate)
        reserved_tokens = 500
        available_tokens = self.max_tokens - reserved_tokens
        
        for chunk in prioritized_chunks:
            # Tokenize the text
            chunk_tokens = self.tokenizer.encode(chunk["text"])
            chunk_token_count = len(chunk_tokens)
            
            # Check if adding this chunk would exceed the limit
            if total_tokens + chunk_token_count > available_tokens:
                # If we have at least some context, break
                if context:
                    break
                
                # If this is the first chunk and it's too large, truncate it
                trunc_text = self.tokenizer.decode(chunk_tokens[:available_tokens])
                context.append({
                    "text": trunc_text,
                    "metadata": chunk["metadata"],
                    "score": chunk.get("rerank_score", chunk["score"]),
                    "truncated": True
                })
                used_chunks.append(chunk["id"])
                break
            
            # Add chunk to context
            context.append({
                "text": chunk["text"],
                "metadata": chunk["metadata"],
                "score": chunk.get("rerank_score", chunk["score"]),
                "truncated": False
            })
            used_chunks.append(chunk["id"])
            total_tokens += chunk_token_count
        
        return context, used_chunks
    
    def _format_context(self, context, query):
        """Format context for the LLM."""
        formatted_parts = []
        
        for i, chunk in enumerate(context, 1):
            # Format metadata for reference
            metadata = chunk["metadata"]
            meta_str = ""
            
            if "section" in metadata:
                meta_str += f"Section: {metadata['section']}"
            
            if "page_range" in metadata:
                pages = metadata["page_range"]
                if isinstance(pages, tuple) and len(pages) == 2:
                    page_str = f"Page {pages[0]}" if pages[0] == pages[1] else f"Pages {pages[0]}-{pages[1]}"
                    meta_str += f", {page_str}"
            
            # Format the context entry
            formatted_parts.append(f"[{i}] {meta_str}\n{chunk['text']}")
        
        # Join all parts
        return "\n\n".join(formatted_parts)
```

### Answer Generation

#### Prompt Engineering

Carefully crafted prompts are essential for accurate answers:

```python
class PromptManager:
    """Manage prompts for the QA system."""
    
    def __init__(self):
        """Initialize the prompt manager."""
        # Base templates that will be customized
        self.qa_templates = {
            "standard": self._standard_qa_template(),
            "verification": self._verification_template(),
            "citation": self._citation_template(),
            "followup": self._followup_template()
        }
    
    def get_qa_prompt(self, query, context, conversation_history=None, is_followup=False):
        """Get the appropriate QA prompt."""
        template_key = "followup" if is_followup else "standard"
        template = self.qa_templates[template_key]
        
        # Format the conversation history if present
        history_text = ""
        if conversation_history and len(conversation_history) > 0:
            history_text = self._format_conversation_history(conversation_history)
        
        # Return the formatted prompt
        return template.format(
            question=query,
            context=context,
            conversation_history=history_text
        )
    
    def get_verification_prompt(self, question, answer, context):
        """Get the verification prompt."""
        template = self.qa_templates["verification"]
        return template.format(
            question=question,
            answer=answer,
            context=context
        )
    
    def get_citation_prompt(self, question, answer, context):
        """Get the citation prompt."""
        template = self.qa_templates["citation"]
        return template.format(
            question=question,
            answer=answer,
            context=context
        )
    
    def _standard_qa_template(self):
        """Standard QA template."""
        return """You are an expert insurance advisor providing accurate information based solely on the policy documents.

User Question: {question}

Below are relevant excerpts from the user's insurance policy:
---
{context}
---

{conversation_history}

Provide a clear, direct answer based only on the information in these policy excerpts. If the information needed isn't present in the excerpts, state "I don't have enough information from your policy to answer this question completely."

For numerical values, quote the exact figures from the policy. Include specific section references when possible.

If explaining insurance terms, be concise but thorough."""
    
    def _verification_template(self):
        """Verification template."""
        return """You are a critical fact-checker verifying an answer about insurance policies.

Original Question: {question}
Generated Answer: {answer}

Policy Context:
---
{context}
---

Your task:
1. Verify each factual claim in the answer against the policy context
2. Identify any statements not directly supported by the context
3. Check for numerical accuracy in all figures, dates, and amounts
4. Assess if the answer is complete or missing important context
5. Identify any potential misinterpretations or oversimplifications

Provide a verification report highlighting any issues found. If the answer is fully accurate and complete, state so."""
    
    def _citation_template(self):
        """Citation template."""
        return """You are an expert at providing citations for insurance policy information.

Original Question: {question}
Generated Answer: {answer}

Policy Context:
---
{context}
---

Your task is to identify which specific parts of the context support each statement in the answer. For each statement, provide:
1. The statement from the answer
2. The exact text from the context that supports it (as a direct quote)
3. The reference number [X] from the context

Format your response as a JSON array of citation objects with the following structure:
{{
  "statement": "The statement from the answer",
  "support": "The direct quote from the context",
  "reference": "The reference number",
  "confidence": 0.95  // How confident you are in this citation (0-1)
}}

Only include statements that make factual claims needing citation."""
    
    def _followup_template(self):
        """Follow-up question template."""
        return """You are an expert insurance advisor providing accurate information based solely on the policy documents.

User's Conversation History:
{conversation_history}

User's Follow-up Question: {question}

Below are relevant excerpts from the user's insurance policy:
---
{context}
---

Provide a clear, direct answer to the follow-up question based only on the information in these policy excerpts and the conversation history. If the information needed isn't present in the excerpts, state "I don't have enough information from your policy to answer this question completely."

For numerical values, quote the exact figures from the policy. Include specific section references when possible.

If explaining insurance terms, be concise but thorough."""
    
    def _format_conversation_history(self, conversation_history):
        """Format conversation history for inclusion in prompts."""
        if not conversation_history:
            return ""
        
        # Format the history (limited to last few turns)
        recent_history = conversation_history[-6:] if len(conversation_history) > 6 else conversation_history
        
        formatted_history = "Previous conversation:\n"
        for msg in recent_history:
            role = "User" if msg["role"] == "user" else "Assistant"
            formatted_history += f"{role}: {msg['content']}\n\n"
        
        return formatted_history
```

#### LLM Interaction

Handling LLM requests with error handling and fallbacks:

```python
class LLMService:
    """Service for interacting with LLM providers."""
    
    def __init__(self):
        """Initialize the LLM service."""
        self.openai_client = OpenAI()
        self.anthropic_client = Anthropic()
        
        # Default configuration
        self.default_config = {
            "temperature": 0.1,
            "max_tokens": 1500,
            "top_p": 0.9
        }
    
    async def generate_answer(self, prompt, model="gpt-4o", config=None):
        """Generate an answer using the specified LLM."""
        model_provider = self._get_provider(model)
        
        # Merge with default config
        config = {**self.default_config, **(config or {})}
        
        try:
            if model_provider == "openai":
                return await self._generate_openai(prompt, model, config)
            elif model_provider == "anthropic":
                return await self._generate_anthropic(prompt, model, config)
            else:
                raise ValueError(f"Unsupported model provider: {model_provider}")
        except Exception as e:
            logger.error(f"Error generating answer with {model}: {e}")
            
            # Try fallback model if primary fails
            if model == "gpt-4o":
                logger.info("Using fallback model gpt-3.5-turbo")
                return await self._generate_openai(prompt, "gpt-3.5-turbo", config)
            elif model.startswith("claude"):
                logger.info("Using fallback model gpt-3.5-turbo")
                return await self._generate_openai(prompt, "gpt-3.5-turbo", config)
            
            # Re-raise if no fallback available
            raise
    
    def _get_provider(self, model):
        """Determine the provider for a given model."""
        if model.startswith("gpt-") or model.endswith("-turbo"):
            return "openai"
        elif model.startswith("claude"):
            return "anthropic"
        else:
            # Default to OpenAI
            return "openai"
    
    async def _generate_openai(self, prompt, model, config):
        """Generate an answer using OpenAI."""
        response = await self.openai_client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "You are an expert insurance advisor."},
                {"role": "user", "content": prompt}
            ],
            temperature=config["temperature"],
            max_tokens=config["max_tokens"],
            top_p=config["top_p"],
            presence_penalty=0.0,
            frequency_penalty=0.0
        )
        
        return {
            "text": response.choices[0].message.content,
            "model": model,
            "tokens": {
                "prompt": response.usage.prompt_tokens,
                "completion": response.usage.completion_tokens,
                "total": response.usage.total_tokens
            }
        }
    
    async def _generate_anthropic(self, prompt, model, config):
        """Generate an answer using Anthropic."""
        response = await self.anthropic_client.messages.create(
            model=model,
            max_tokens=config["max_tokens"],
            temperature=config["temperature"],
            system="You are an expert insurance advisor.",
            messages=[
                {"role": "user", "content": prompt}
            ]
        )
        
        return {
            "text": response.content[0].text,
            "model": model,
            "tokens": {
                "prompt": response.usage.input_tokens,
                "completion": response.usage.output_tokens,
                "total": response.usage.input_tokens + response.usage.output_tokens
            }
        }
```

#### Answer Verification

Verify answer accuracy and add citations:

```python
class AnswerProcessor:
    """Process, verify, and enhance LLM-generated answers."""
    
    def __init__(self, prompt_manager, llm_service):
        """Initialize the answer processor."""
        self.prompt_manager = prompt_manager
        self.llm_service = llm_service
    
    async def process_answer(self, query, context, llm_response):
        """Process and enhance the generated answer."""
        answer = llm_response["text"]
        
        # Verify the answer against the context
        verification = await self._verify_answer(query, answer, context["formatted_context"])
        
        # Generate citations for the answer
        citations = await self._generate_citations(query, answer, context["formatted_context"])
        
        # Calculate confidence score
        confidence_score = self._calculate_confidence(
            verification, 
            citations,
            llm_response,
            context["used_chunks"]
        )
        
        # Format the answer with citations
        formatted_answer = self._format_answer_with_citations(answer, citations)
        
        return {
            "original_answer": answer,
            "formatted_answer": formatted_answer,
            "verification": verification,
            "citations": citations,
            "confidence_score": confidence_score,
            "llm_metadata": {
                "model": llm_response["model"],
                "tokens": llm_response["tokens"]
            }
        }
    
    async def _verify_answer(self, query, answer, context):
        """Verify the answer against the context."""
        # Generate verification prompt
        verification_prompt = self.prompt_manager.get_verification_prompt(query, answer, context)
        
        # Get verification from LLM
        verification_response = await self.llm_service.generate_answer(
            verification_prompt,
            model="gpt-3.5-turbo",  # Use faster model for verification
            config={"temperature": 0.0}  # Deterministic response
        )
        
        # Parse verification results
        verification_text = verification_response["text"]
        
        # Simple classification of verification result
        verification_result = {
            "text": verification_text,
            "has_issues": "issue" in verification_text.lower() or "incorrect" in verification_text.lower(),
            "issues": self._extract_verification_issues(verification_text),
            "model": verification_response["model"]
        }
        
        return verification_result
    
    def _extract_verification_issues(self, verification_text):
        """Extract structured issues from verification text."""
        # Simple approach - scan for common issue indicators
        issues = []
        
        # Check for unsupported statements
        if "not supported" in verification_text.lower() or "no support" in verification_text.lower():
            issues.append({"type": "unsupported_statement", "severity": "high"})
        
        # Check for numerical inaccuracies
        if "incorrect" in verification_text.lower() and any(term in verification_text.lower() 
                                                         for term in ["number", "amount", "figure", "date"]):
            issues.append({"type": "numerical_inaccuracy", "severity": "high"})
        
        # Check for incompleteness
        if "incomplete" in verification_text.lower() or "missing" in verification_text.lower():
            issues.append({"type": "incomplete_answer", "severity": "medium"})
        
        # Check for misinterpretation
        if "misinterpret" in verification_text.lower() or "misunderstand" in verification_text.lower():
            issues.append({"type": "misinterpretation", "severity": "medium"})
        
        return issues
    
    async def _generate_citations(self, query, answer, context):
        """Generate citations for statements in the answer."""
        # Generate citation prompt
        citation_prompt = self.prompt_manager.get_citation_prompt(query, answer, context)
        
        # Get citations from LLM
        citation_response = await self.llm_service.generate_answer(
            citation_prompt,
            model="gpt-4o",  # Use more capable model for accurate citations
            config={"temperature": 0.0}  # Deterministic response
        )
        
        # Parse citation results (assuming JSON format)
        citation_text = citation_response["text"]
        
        # Extract JSON from the response
        try:
            # Find JSON array in the response
            json_match = re.search(r'\[\s*{.+}\s*\]', citation_text, re.DOTALL)
            if json_match:
                citations_json = json.loads(json_match.group(0))
                return citations_json
            
            # Fallback - try to parse the entire response as JSON
            return json.loads(citation_text)
        except (json.JSONDecodeError, AttributeError):
            # If parsing fails, return simplified citations
            logger.warning("Failed to parse citation JSON, using fallback")
            return self._generate_fallback_citations(answer, context)
    
    def _generate_fallback_citations(self, answer, context):
        """Generate fallback citations when JSON parsing fails."""
        # Very simple citation generation
        sentences = re.split(r'(?<=[.!?])\s+', answer)
        context_chunks = context.split('\n\n')
        
        citations = []
        for i, sentence in enumerate(sentences):
            if len(sentence) < 10:  # Skip very short sentences
                continue
            
            # Find most similar context chunk
            best_match = None
            best_score = -1
            best_ref = ""
            
            for chunk in context_chunks:
                ref_match = re.match(r'\[(\d+)\]', chunk)
                ref = ref_match.group(1) if ref_match else ""
                
                # Simple word overlap score
                sentence_words = set(sentence.lower().split())
                chunk_words = set(chunk.lower().split())
                overlap = len(sentence_words.intersection(chunk_words))
                
                if overlap > best_score:
                    best_score = overlap
                    best_match = chunk
                    best_ref = ref
            
            # Only add citations with sufficient similarity
            if best_score > 3:
                citations.append({
                    "statement": sentence,
                    "support": best_match[:100] + "..." if len(best_match) > 100 else best_match,
                    "reference": best_ref,
                    "confidence": min(best_score / len(sentence.split()), 0.95)
                })
        
        return citations
    
    def _calculate_confidence(self, verification, citations, llm_response, used_chunks):
        """Calculate confidence score for the answer."""
        # Base confidence score
        base_confidence = 0.7
        
        # Adjust for verification issues
        verification_factor = 1.0
        if verification["has_issues"]:
            # Reduce confidence based on issue severity
            issue_severities = {"high": 0.5, "medium": 0.8, "low": 0.9}
            for issue in verification["issues"]:
                severity = issue.get("severity", "medium")
                verification_factor *= issue_severities.get(severity, 0.8)
        
        # Adjust for citation coverage
        citation_confidence = 0.0
        if citations:
            citation_confidences = [c.get("confidence", 0.5) for c in citations]
            citation_confidence = sum(citation_confidences) / len(citation_confidences)
        
        # Adjust for context relevance
        context_confidence = 0.8  # Default assumption
        if used_chunks:
            # If we have relevant chunks, assume they're reasonably good
            context_confidence = 0.9
        
        # Calculate final confidence score
        confidence = base_confidence * verification_factor * (0.7 + 0.3 * citation_confidence) * context_confidence
        
        # Ensure score is within 0-1 range
        return max(0.0, min(1.0, confidence))
    
    def _format_answer_with_citations(self, answer, citations):
        """Format the answer with inline citations."""
        if not citations:
            return answer
        
        # Sort citations by statement length (longest first to avoid substring issues)
        sorted_citations = sorted(citations, key=lambda c: len(c.get("statement", "")), reverse=True)
        
        # Replace statements with cited versions
        cited_answer = answer
        for citation in sorted_citations:
            statement = citation.get("statement", "")
            reference = citation.get("reference", "")
            
            if statement and reference and statement in cited_answer:
                cited_statement = f"{statement} [{reference}]"
                cited_answer = cited_answer.replace(statement, cited_statement)
        
        return cited_answer
```

## RAG Optimization Strategies

### Chunking Optimization

Effective chunking significantly impacts retrieval quality:

1. **Adaptive Chunk Sizing**
```python
def adaptive_chunking(document, structure):
    """Adapt chunk size based on document structure."""
    chunks = []
    
    for section in structure["sections"]:
        section_text = extract_section_text(document, section)
        section_length = len(section_text)
        
        # Adjust chunk size based on section length
        if section_length < 1000:
            # Short sections - keep intact
            chunks.append({
                "text": section_text,
                "metadata": {"section": section["title"], "page_range": section["page_range"]}
            })
        elif section_length < 3000:
            # Medium sections - split into 2 chunks with overlap
            chunk_size = section_length // 2
            overlap = min(300, chunk_size // 3)
            
            chunks.append({
                "text": section_text[:chunk_size + overlap],
                "metadata": {"section": section["title"], "page_range": section["page_range"], "part": "first half"}
            })
            
            chunks.append({
                "text": section_text[chunk_size - overlap:],
                "metadata": {"section": section["title"], "page_range": section["page_range"], "part": "second half"}
            })
        else:
            # Long sections - use regular chunking with semantic boundaries
            semantic_chunks = create_semantic_chunks(section_text, max_size=1500, overlap=200)
            for i, chunk in enumerate(semantic_chunks):
                chunks.append({
                    "text": chunk,
                    "metadata": {
                        "section": section["title"], 
                        "page_range": section["page_range"],
                        "part": f"part {i+1}/{len(semantic_chunks)}"
                    }
                })
    
    return chunks
```

2. **Semantic Boundary Respecting**
```python
def semantic_boundary_chunking(text, max_size=1500, overlap=200):
    """Create chunks that respect semantic boundaries."""
    nlp = spacy.load("en_core_web_sm")
    doc = nlp(text)
    
    chunks = []
    current_chunk = []
    current_length = 0
    
    for para in doc.sents:
        para_text = para.text.strip()
        para_length = len(para_text)
        
        # If adding this paragraph would exceed the limit
        if current_length + para_length > max_size and current_chunk:
            # Complete the current chunk
            chunk_text = " ".join(current_chunk)
            chunks.append(chunk_text)
            
            # Start a new chunk with overlap
            overlap_text = current_chunk[-2:] if len(current_chunk) >= 2 else current_chunk[-1:] if current_chunk else []
            current_chunk = overlap_text + [para_text]
            current_length = sum(len(t) for t in current_chunk)
        else:
            # Add paragraph to current chunk
            current_chunk.append(para_text)
            current_length += para_length
    
    # Add the last chunk if it exists
    if current_chunk:
        chunk_text = " ".join(current_chunk)
        chunks.append(chunk_text)
    
    return chunks
```

### Embedding Optimization

Strategies to improve embedding quality:

1. **Hybrid Embedding Strategy**
```python
class HybridEmbeddingService:
    """Hybrid embedding service using multiple models."""
    
    def __init__(self):
        """Initialize the hybrid embedding service."""
        # Primary embeddings (external API)
        self.primary_embedder = OpenAIEmbeddings(model="text-embedding-ada-002")
        
        # Local embeddings (fallback and enhancement)
        self.local_embedder = SentenceTransformer('all-MiniLM-L6-v2')
        
        # Specialized embeddings for insurance domain
        self.domain_embedder = self._create_domain_embedder()
    
    async def generate_embeddings(self, texts):
        """Generate hybrid embeddings for texts."""
        try:
            # Get primary embeddings
            primary_embeddings = await self.primary_embedder.embed_documents(texts)
            
            # Get local embeddings
            local_embeddings = self.local_embedder.encode(texts)
            
            # Generate domain-specific embeddings
            domain_embeddings = self._generate_domain_embeddings(texts)
            
            # Combine embeddings (simple concatenation with normalization)
            hybrid_embeddings = []
            for p_emb, l_emb, d_emb in zip(primary_embeddings, local_embeddings, domain_embeddings):
                # Normalize each embedding
                p_norm = self._normalize_vector(p_emb)
                l_norm = self._normalize_vector(l_emb)
                d_norm = self._normalize_vector(d_emb)
                
                # Combine (weighted average)
                combined = [
                    0.6 * p + 0.2 * l + 0.2 * d 
                    for p, l, d in zip(p_norm, l_norm, d_norm)
                ]
                
                hybrid_embeddings.append(combined)
            
            return hybrid_embeddings
        
        except Exception as e:
            logger.warning(f"Primary embedding failed: {e}, using fallback")
            return self._generate_fallback_embeddings(texts)
    
    def _generate_fallback_embeddings(self, texts):
        """Generate fallback embeddings using local model."""
        return self.local_embedder.encode(texts).tolist()
    
    def _create_domain_embedder(self):
        """Create domain-specific embedder for insurance documents."""
        # In production, this would be a fine-tuned model for insurance domain
        # For now, use the same base model but with a domain-specific prompt
        return self.local_embedder
    
    def _generate_domain_embeddings(self, texts):
        """Generate domain-enhanced embeddings."""
        # Add insurance domain context to texts
        enhanced_texts = [
            f"Insurance policy document: {text}" for text in texts
        ]
        
        # Generate embeddings
        return self.domain_embedder.encode(enhanced_texts).tolist()
    
    def _normalize_vector(self, vector):
        """Normalize a vector to unit length."""
        norm = np.linalg.norm(vector)
        if norm == 0:
            return vector
        return vector / norm
```

2. **Batch Processing with Caching**
```python
class EmbeddingManager:
    """Manage embedding generation with batching and caching."""
    
    def __init__(self, embedding_service, cache_client):
        """Initialize the embedding manager."""
        self.embedding_service = embedding_service
        self.cache_client = cache_client
        
        # Defaults
        self.batch_size = 50
        self.cache_ttl = 60 * 60 * 24 * 30  # 30 days in seconds
    
    async def get_embeddings(self, texts):
        """Get embeddings for texts with caching and batching."""
        # Check cache first
        cached_embeddings = await self._get_cached_embeddings(texts)
        
        # Identify texts that need embedding
        missing_indices = [i for i, emb in enumerate(cached_embeddings) if emb is None]
        
        if not missing_indices:
            # All embeddings were cached
            return cached_embeddings
        
        # Prepare texts that need embedding
        texts_to_embed = [texts[i] for i in missing_indices]
        
        # Generate embeddings in batches
        new_embeddings = await self._batch_generate_embeddings(texts_to_embed)
        
        # Update cache with new embeddings
        await self._update_cache(texts_to_embed, new_embeddings)
        
        # Merge cached and new embeddings
        result = list(cached_embeddings)
        for idx, embedding_idx in enumerate(missing_indices):
            result[embedding_idx] = new_embeddings[idx]
        
        return result
    
    async def _get_cached_embeddings(self, texts):
        """Get cached embeddings for texts."""
        # Generate cache keys
        cache_keys = [f"emb:{hashlib.md5(text.encode()).hexdigest()}" for text in texts]
        
        # Get embeddings from cache
        cached_results = []
        for key in cache_keys:
            try:
                cached = await self.cache_client.get(key)
                if cached:
                    cached_results.append(json.loads(cached))
                else:
                    cached_results.append(None)
            except Exception as e:
                logger.warning(f"Cache retrieval error: {e}")
                cached_results.append(None)
        
        return cached_results
    
    async def _batch_generate_embeddings(self, texts):
        """Generate embeddings in batches."""
        all_embeddings = []
        
        # Process in batches
        for i in range(0, len(texts), self.batch_size):
            batch = texts[i:i + self.batch_size]
            try:
                batch_embeddings = await self.embedding_service.generate_embeddings(batch)
                all_embeddings.extend(batch_embeddings)
            except Exception as e:
                logger.error(f"Error generating embeddings for batch: {e}")
                # Use fallback for errors
                fallback_embeddings = [None] * len(batch)
                all_embeddings.extend(fallback_embeddings)
        
        return all_embeddings
    
    async def _update_cache(self, texts, embeddings):
        """Update cache with new embeddings."""
        for text, embedding in zip(texts, embeddings):
            if embedding is None:
                continue
                
            key = f"emb:{hashlib.md5(text.encode()).hexdigest()}"
            try:
                await self.cache_client.set(
                    key, 
                    json.dumps(embedding),
                    expire=self.cache_ttl
                )
            except Exception as e:
                logger.warning(f"Cache update error: {e}")
```

### Retrieval Optimization

Strategies to improve retrieval accuracy:

1. **Hybrid Search Strategy**
```python
class HybridSearchEngine:
    """Hybrid search combining vector and keyword search."""
    
    def __init__(self, vector_store, text_search_engine):
        """Initialize the hybrid search engine."""
        self.vector_store = vector_store
        self.text_search_engine = text_search_engine
    
    async def search(self, query, user_id, policy_ids=None, top_k=10):
        """Execute hybrid search combining vector and keyword approaches."""
        # Generate query embedding
        query_embedding = await self.embedding_service.generate_embeddings([query])
        query_embedding = query_embedding[0]
        
        # Extract key terms for filtering
        key_terms = self._extract_key_terms(query)
        
        # Prepare filters
        filters = {"user_id": user_id}
        if policy_ids:
            filters["policy_id"] = {"$in": policy_ids}
        
        # Execute vector search
        vector_results = await self.vector_store.search_vectors(
            query_embedding=query_embedding,
            namespace=f"user_{user_id}",
            top_k=top_k,
            filters=filters
        )
        
        # Execute keyword search
        keyword_results = await self.text_search_engine.search(
            query=query,
            key_terms=key_terms,
            user_id=user_id,
            policy_ids=policy_ids,
            top_k=top_k
        )
        
        # Merge results with reciprocal rank fusion
        merged_results = self._reciprocal_rank_fusion(
            vector_results, 
            keyword_results,
            k=60  # RRF constant
        )
        
        return merged_results[:top_k]
    
    def _extract_key_terms(self, query):
        """Extract key terms from the query for keyword search."""
        # Simple term extraction (could be more sophisticated)
        stop_words = {"the", "a", "an", "in", "of", "for", "on", "with", "by", "at", "to", "and", "or", "is", "are"}
        terms = [term.lower() for term in query.split() if term.lower() not in stop_words]
        return terms
    
    def _reciprocal_rank_fusion(self, vector_results, keyword_results, k=60):
        """Combine results using reciprocal rank fusion."""
        # Create a dictionary of all results with their scores
        all_results = {}
        
        # Process vector results
        for rank, result in enumerate(vector_results):
            result_id = result["id"]
            if result_id not in all_results:
                all_results[result_id] = {"item": result, "rrf_score": 0.0}
            
            # Add reciprocal rank score
            all_results[result_id]["rrf_score"] += 1.0 / (rank + k)
        
        # Process keyword results
        for rank, result in enumerate(keyword_results):
            result_id = result["id"]
            if result_id not in all_results:
                all_results[result_id] = {"item": result, "rrf_score": 0.0}
            
            # Add reciprocal rank score
            all_results[result_id]["rrf_score"] += 1.0 / (rank + k)
        
        # Sort by RRF score and return
        sorted_results = sorted(
            all_results.values(),
            key=lambda x: x["rrf_score"],
            reverse=True
        )
        
        return [item["item"] for item in sorted_results]
```

2. **Advanced Reranking**
```python
class AdvancedReranker:
    """Advanced reranking for retrieval results."""
    
    def __init__(self):
        """Initialize the advanced reranker."""
        # Cross-encoder reranker for semantic relevance
        self.cross_encoder = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')
        
        # Weights for different signals
        self.weights = {
            "semantic": 0.6,
            "vector": 0.2,
            "recency": 0.1,
            "specificity": 0.1
        }
    
    async def rerank(self, query, initial_results):
        """Rerank results using multiple signals."""
        if not initial_results:
            return []
        
        # Calculate semantic relevance scores
        passages = [result["text"] for result in initial_results]
        semantic_scores = self.cross_encoder.predict([(query, p) for p in passages])
        
        # Normalize all scores
        vector_scores = self._normalize_scores([r["score"] for r in initial_results])
        semantic_scores = self._normalize_scores(semantic_scores)
        
        # Calculate recency scores (if timestamp available)
        recency_scores = self._calculate_recency_scores(initial_results)
        
        # Calculate specificity scores
        specificity_scores = self._calculate_specificity_scores(initial_results)
        
        # Combine scores
        reranked = []
        for i, result in enumerate(initial_results):
            combined_score = (
                self.weights["semantic"] * semantic_scores[i] +
                self.weights["vector"] * vector_scores[i] +
                self.weights["recency"] * recency_scores[i] +
                self.weights["specificity"] * specificity_scores[i]
            )
            
            result_copy = result.copy()
            result_copy["rerank_score"] = combined_score
            result_copy["semantic_score"] = semantic_scores[i]
            reranked.append(result_copy)
        
        # Sort by combined score
        reranked.sort(key=lambda x: x["rerank_score"], reverse=True)
        
        return reranked
    
    def _normalize_scores(self, scores):
        """Min-max normalize a list of scores."""
        if not scores:
            return []
            
        min_score = min(scores)
        max_score = max(scores)
        
        if max_score == min_score:
            return [1.0] * len(scores)
            
        return [(s - min_score) / (max_score - min_score) for s in scores]
    
    def _calculate_recency_scores(self, results):
        """Calculate recency scores based on timestamp if available."""
        # Default to neutral score if timestamp not available
        recency_scores = [0.5] * len(results)
        
        # Check if timestamp is available
        timestamps = []
        for result in results:
            timestamp = result.get("metadata", {}).get("timestamp")
            if timestamp:
                try:
                    ts = datetime.fromisoformat(timestamp)
                    timestamps.append(ts)
                except (ValueError, TypeError):
                    timestamps.append(None)
            else:
                timestamps.append(None)
        
        # If we have valid timestamps, calculate recency scores
        valid_timestamps = [ts for ts in timestamps if ts is not None]
        if valid_timestamps:
            min_ts = min(valid_timestamps)
            max_ts = max(valid_timestamps)
            
            # If all timestamps are the same, return neutral scores
            if min_ts == max_ts:
                return recency_scores
                
            # Calculate timespan
            timespan = (max_ts - min_ts).total_seconds()
            
            # Calculate normalized recency scores
            for i, ts in enumerate(timestamps):
                if ts is not None:
                    elapsed = (ts - min_ts).total_seconds()
                    recency_scores[i] = elapsed / timespan
        
        return recency_scores
    
    def _calculate_specificity_scores(self, results):
        """Calculate specificity scores based on text characteristics."""
        specificity_scores = []
        
        for result in results:
            text = result["text"]
            
            # Simple heuristics for specificity
            # 1. Length (longer is often more specific)
            length_score = min(len(text) / 1000, 1.0)
            
            # 2. Number presence (texts with numbers often more specific)
            num_count = len(re.findall(r'\d+', text))
            number_score = min(num_count / 10, 1.0)
            
            # 3. Specificity terms
            specificity_terms = ["specifically", "exactly", "precisely", "in particular", 
                               "notably", "especially", "explicitly"]
            term_count = sum(1 for term in specificity_terms if term in text.lower())
            term_score = min(term_count / len(specificity_terms), 1.0)
            
            # Combined specificity score
            specificity = (0.4 * length_score) + (0.4 * number_score) + (0.2 * term_score)
            specificity_scores.append(specificity)
        
        return specificity_scores
```

### Context Assembly Optimization

Optimizing the context for the LLM:

1. **Information Density Ranking**
```python
def optimize_context_assembly(retrieved_chunks, max_tokens=6000):
    """Optimize context assembly based on information density."""
    # Calculate information density for each chunk
    for chunk in retrieved_chunks:
        # 1. Calculate numeric density (numbers often indicate specific info)
        num_count = len(re.findall(r'\d+', chunk["text"]))
        num_density = num_count / (len(chunk["text"]) + 1)
        
        # 2. Calculate named entity density
        doc = nlp(chunk["text"])
        entity_count = len(doc.ents)
        entity_density = entity_count / (len(chunk["text"]) + 1)
        
        # 3. Calculate insurance term density
        insurance_terms = ["policy", "coverage", "premium", "deductible", "claim", 
                         "benefit", "exclusion", "limit", "copay", "coinsurance"]
        term_count = sum(1 for term in insurance_terms if term in chunk["text"].lower())
        term_density = term_count / len(insurance_terms)
        
        # 4. Calculate keyword density
        keywords = ["cover", "pay", "reimburse", "exclude", "include", "limit", 
                  "provide", "offer", "restrict", "require"]
        keyword_count = sum(1 for kw in keywords if kw in chunk["text"].lower())
        keyword_density = keyword_count / len(keywords)
        
        # Combined information density score
        info_density = (0.3 * num_density) + (0.3 * entity_density) + 
                       (0.2 * term_density) + (0.2 * keyword_density)
        
        # Normalize with chunk relevance score
        combined_score = (0.7 * chunk["score"]) + (0.3 * info_density)
        chunk["density_score"] = info_density
        chunk["combined_score"] = combined_score
    
    # Sort chunks by combined score
    sorted_chunks = sorted(retrieved_chunks, key=lambda x: x["combined_score"], reverse=True)
    
    # Allocate tokens based on importance
    tokenizer = tiktoken.get_encoding("cl100k_base")
    selected_chunks = []
    total_tokens = 0
    
    for chunk in sorted_chunks:
        chunk_tokens = len(tokenizer.encode(chunk["text"]))
        
        if total_tokens + chunk_tokens <= max_tokens:
            selected_chunks.append(chunk)
            total_tokens += chunk_tokens
        else:
            # If we can't fit the whole chunk, see if we can fit a portion
            if total_tokens < max_tokens * 0.9:  # Only if we have substantial space left
                # Try to fit a portion of the chunk
                available_tokens = max_tokens - total_tokens
                partial_text = tokenizer.decode(tokenizer.encode(chunk["text"])[:available_tokens])
                
                # Find a good breakpoint (end of sentence)
                last_period = partial_text.rfind('.')
                if last_period > len(partial_text) * 0.7:  # If period is reasonably far along
                    partial_text = partial_text[:last_period+1]
                
                partial_chunk = chunk.copy()
                partial_chunk["text"] = partial_text
                partial_chunk["is_partial"] = True
                
                selected_chunks.append(partial_chunk)
            break
    
    # Reorder chunks to ensure diversity and coverage
    return optimize_chunk_order(selected_chunks)
```

2. **Context Organization**
```python
def optimize_chunk_order(chunks):
    """Organize chunks for optimal context understanding by the LLM."""
    # First, group chunks by section (if available)
    section_groups = {}
    for chunk in chunks:
        section = chunk.get("metadata", {}).get("section", "unknown")
        if section not in section_groups:
            section_groups[section] = []
        section_groups[section].append(chunk)
    
    # Sort sections by relevance (using max chunk score in section)
    section_scores = {}
    for section, section_chunks in section_groups.items():
        section_scores[section] = max(c["combined_score"] for c in section_chunks)
    
    sorted_sections = sorted(section_groups.keys(), 
                           key=lambda s: section_scores[s], reverse=True)
    
    # Organize chunks by section, maintaining order within sections
    organized_chunks = []
    for section in sorted_sections:
        # Sort chunks within section by position if available
        section_chunks = section_groups[section]
        if all("page_range" in c.get("metadata", {}) for c in section_chunks):
            section_chunks.sort(key=lambda c: c["metadata"]["page_range"][0])
        
        # Add section header for clarity
        if section != "unknown":
            organized_chunks.append({
                "text": f"=== SECTION: {section} ===",
                "is_header": True
            })
        
        # Add chunks
        organized_chunks.extend(section_chunks)
    
    return organized_chunks
```

### LLM Response Optimization

Strategies to improve answer quality:

1. **Prompt Optimization**
```python
def generate_optimized_prompt(query, context, conversation_history=None):
    """Generate optimized prompt based on query characteristics."""
    # Analyze query to determine prompt strategy
    query_characteristics = analyze_query(query)
    
    # Select base prompt template based on query type
    if query_characteristics["is_factual"]:
        base_template = FACTUAL_TEMPLATE
    elif query_characteristics["is_comparative"]:
        base_template = COMPARATIVE_TEMPLATE
    elif query_characteristics["is_explanatory"]:
        base_template = EXPLANATORY_TEMPLATE
    elif query_characteristics["is_procedural"]:
        base_template = PROCEDURAL_TEMPLATE
    else:
        base_template = STANDARD_TEMPLATE
    
    # Add domain-specific instructions
    domain_instructions = get_domain_instructions(query_characteristics["domain_hints"])
    
    # Format context with appropriate structure
    formatted_context = format_context_for_prompt(context, query_characteristics)
    
    # Add conversation history if provided
    history_text = ""
    if conversation_history:
        history_text = format_conversation_history(conversation_history)
    
    # Generate the final prompt
    prompt = base_template.format(
        question=query,
        context=formatted_context,
        conversation_history=history_text,
        domain_instructions=domain_instructions
    )
    
    return prompt

def analyze_query(query):
    """Analyze the query to determine its characteristics."""
    # Simplified implementation
    characteristics = {
        "is_factual": any(w in query.lower() for w in ["what", "when", "where", "who", "how much", "how many"]),
        "is_comparative": any(w in query.lower() for w in ["compare", "difference", "versus", "vs", "better"]),
        "is_explanatory": any(w in query.lower() for w in ["why", "how does", "explain", "understand"]),
        "is_procedural": any(w in query.lower() for w in ["how to", "steps", "process", "procedure"]),
        "domain_hints": []
    }
    
    # Extract domain hints
    insurance_domains = {
        "health": ["health", "medical", "doctor", "hospital", "prescription"],
        "auto": ["car", "auto", "vehicle", "accident", "collision"],
        "home": ["home", "house", "property", "dwelling", "damage"],
        "life": ["life", "death", "beneficiary", "term", "permanent"]
    }
    
    for domain, keywords in insurance_domains.items():
        if any(kw in query.lower() for kw in keywords):
            characteristics["domain_hints"].append(domain)
    
    return characteristics
```

2. **Answer Post-Processing**
```python
def post_process_answer(answer, query_characteristics):
    """Post-process LLM answer for clarity and usefulness."""
    processed_answer = answer
    
    # Add structured formatting for specific query types
    if query_characteristics["is_comparative"]:
        processed_answer = format_comparative_answer(answer)
    elif query_characteristics["is_procedural"]:
        processed_answer = format_procedural_answer(answer)
    
    # Enhance with key highlights
    processed_answer = highlight_key_information(processed_answer)
    
    # Add confidence indicators where appropriate
    processed_answer = add_confidence_indicators(processed_answer)
    
    # Format monetary values consistently
    processed_answer = format_monetary_values(processed_answer)
    
    # Ensure proper formatting of insurance terms
    processed_answer = format_insurance_terms(processed_answer)
    
    return processed_answer

def format_comparative_answer(answer):
    """Format comparative answers with clear structure."""
    # Use regex to detect comparison points
    comparison_points = re.findall(r'([^.!?]+(?:differ|compar|contrast|vs\.)[^.!?]+[.!?])', answer)
    
    if comparison_points:
        # Build a structured comparison
        formatted = answer.split('\n\n')[0] + "\n\n"  # Keep the introduction
        formatted += "## Comparison Points\n\n"
        
        for i, point in enumerate(comparison_points, 1):
            formatted += f"{i}. {point.strip()}\n"
        
        # Add the rest of the content
        remaining = answer[len(answer.split('\n\n')[0]):]
        remaining_without_points = re.sub(r'([^.!?]+(?:differ|compar|contrast|vs\.)[^.!?]+[.!?])', '', remaining)
        if remaining_without_points.strip():
            formatted += "\n" + remaining_without_points
        
        return formatted
    
    return answer

def highlight_key_information(answer):
    """Highlight key information in the answer."""
    # Highlight monetary values
    answer = re.sub(r'(\$\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', r'**\1**', answer)
    
    # Highlight dates
    answer = re.sub(r'(\d{1,2}\/\d{1,2}\/\d{2,4}|\d{1,2}-\d{1,2}-\d{2,4})', r'**\1**', answer)
    
    # Highlight key terms
    insurance_terms = ["deductible", "premium", "coverage", "copay", "coinsurance", 
                     "out-of-pocket", "exclusion", "limitation"]
    
    for term in insurance_terms:
        answer = re.sub(r'\b(' + term + r')\b', r'**\1**', answer, flags=re.IGNORECASE)
    
    return answer
```

## Performance and Scaling

### Query Performance

Typical performance metrics for the RAG system:

| Stage | Avg. Time (ms) | 95th Percentile (ms) | Key Optimizations |
|-------|----------------|----------------------|-------------------|
| Query Processing | 50-100 | 150 | Caching, parallel processing |
| Embedding Generation | 200-400 | 800 | Caching, batching |
| Retrieval | 300-500 | 800 | Index optimization, filtering |
| Reranking | 200-400 | 600 | Model quantization, batching |
| Context Assembly | 50-100 | 200 | Efficient text processing |
| LLM Generation | 1000-3000 | 5000 | Prompt optimization, caching |
| Post-processing | 50-150 | 300 | Efficient algorithms |
| **Total** | **1850-4650** | **7850** | **End-to-end optimization** |

### Scaling Strategy

To handle increased load, the system implements:

1. **Horizontal Scaling**
   - Stateless services for easy replication
   - Load balancing across service instances
   - Distributed vector storage

2. **Resource Optimization**
   - Tiered storage for embeddings
   - Caching at multiple levels
   - Background processing for non-critical tasks

3. **Cost Management**
   - LLM provider optimization
   - Batch processing where possible
   - Token usage monitoring and optimization

## Future Enhancements

Planned improvements to the RAG implementation:

1. **Multi-Modal RAG**
   - Support for images in insurance documents
   - Table extraction and reasoning
   - Form field recognition and extraction

2. **Adaptive Retrieval**
   - Learning from user feedback
   - Personalized retrieval strategies
   - Dynamic context window sizing

3. **Enhanced Reasoning**
   - Multi-hop question answering
   - Complex numerical reasoning
   - Temporal reasoning across policy versions

4. **Performance Enhancements**
   - Streaming responses for faster UX
   - Predictive prefetching of related information
   - On-device embedding for privacy and speed

# Modern Python & AI Stack Recommendations (2024)

This section summarizes the latest recommended Python libraries, Hugging Face models, and open-source LLMs for each major feature in the Insurance Policy Parser & QA App. It is designed to help developers avoid outdated dependencies and leverage the best open-source and cloud tools available as of 2024.

## 1. Document Upload & Management
- **PDF Parsing:** [`pdfplumber`](https://github.com/jsvine/pdfplumber), [`PyPDF2`](https://github.com/py-pdf/PyPDF2), [`pypdf`](https://github.com/py-pdf/pypdf)
- **PDF to Image:** [`pdf2image`](https://github.com/Belval/pdf2image)
- **Cloud Storage:** [`boto3`] (AWS S3), [`google-cloud-storage`], [`minio`] (S3-compatible local)

## 2. Intelligent Policy Parsing
- **OCR:**
  - [`pytesseract`](https://github.com/madmaze/pytesseract) (Tesseract OCR, open-source)
  - [`easyocr`](https://github.com/JaidedAI/EasyOCR) (deep learning-based, multi-language)
  - Cloud: [`google-cloud-vision`], [`boto3`] (Textract)
- **Table Extraction:**
  - [`camelot-py`](https://github.com/camelot-dev/camelot) (digital PDFs)
  - [`tabula-py`](https://github.com/chezou/tabula-py) (Java dependency)
  - For scanned tables: [`layoutparser`](https://github.com/Layout-Parser/layout-parser) + OCR
- **NER & Structure:**
  - [`spaCy`](https://spacy.io/) (custom NER)
  - [`transformers`](https://huggingface.co/transformers/) (Hugging Face models, e.g., `bert-base-cased`)

## 3. Policy Information Dashboard
- **Backend:** FastAPI endpoints
- **Frontend:** React (Material-UI, Ant Design, or Tailwind CSS)
- **Visualization:** `plotly`, `chart.js`, or `echarts`

## 4. Natural Language QA System (RAG)
- **RAG Pipeline:**
  - [`langchain`](https://github.com/langchain-ai/langchain)
  - [`llama-index`](https://github.com/jerryjliu/llama_index)
- **LLMs:**
  - **OpenAI:** GPT-4o, GPT-3.5-turbo (API)
  - **Anthropic:** Claude 3 (API)
  - **Hugging Face:**
    - [`mistralai/Mistral-7B-Instruct-v0.2`](https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.2)
    - [`meta-llama/Llama-3-8B-Instruct`](https://huggingface.co/meta-llama/Llama-3-8b-instruct)
    - [`google/gemma-7b-it`](https://huggingface.co/google/gemma-7b-it)
  - Use `transformers` and `vllm` or `text-generation-inference` for local serving
- **Embeddings:**
  - [`sentence-transformers`](https://www.sbert.net/) (e.g., `all-MiniLM-L6-v2`, `bge-base-en-v1.5`)
  - [`Instructor-XL`](https://huggingface.co/hkunlp/instructor-xl) (domain-specific)
  - OpenAI embeddings (`text-embedding-3-large`), fallback to local
- **Vector DB:**
  - [`faiss`](https://github.com/facebookresearch/faiss) (local)
  - [`qdrant`](https://github.com/qdrant/qdrant), [`weaviate`](https://github.com/weaviate/weaviate), [`pinecone`](https://www.pinecone.io/) (cloud)
- **Reranking:** [`cross-encoder/ms-marco-MiniLM-L-6-v2`](https://huggingface.co/cross-encoder/ms-marco-MiniLM-L-6-v2)
- **Prompt Management:** Use `langchain` prompt templates

## 5. Comparison Tools
- **Backend:** Use structured extraction to normalize policy data
- **Frontend:** React tables, diff viewers
- **NLP:** Use NER and rule-based extraction to align comparable fields

## 6. Alerts & Notifications
- **Backend:** [`celery`](https://docs.celeryq.dev/en/stable/) + `redis`
- **Email/SMS:** `sendgrid`, `twilio`, or `smtplib`

## General Guidelines
- **No Flutter dependencies**: Use React (web) and Streamlit (for MVP/prototyping)
- **Python 3.10+**: Use latest stable Python
- **Hugging Face Transformers**: Use latest `transformers` and `sentence-transformers`
- **Vector DB**: Prefer `faiss` or `qdrant`
- **OCR**: Use `pytesseract` and `easyocr` for open-source, with cloud fallback
- **Table Extraction**: `camelot-py` for digital, `layoutparser` + OCR for scanned
- **RAG**: Use `langchain` or `llama-index`

---

(Original RAG implementation documentation continues below)

# Upgrades & Future-Proofing (2024)

To keep the Insurance Policy Parser & QA App at the cutting edge, the following upgrades are recommended:

- **Embeddings:**
  - Add support for [`bge-base-en-v1.5`](https://huggingface.co/BAAI/bge-base-en-v1.5) and [`Instructor-XL`](https://huggingface.co/hkunlp/instructor-xl) for improved open-source performance.
  - Document how to switch between OpenAI and local models via config.
- **RAG Orchestration:**
  - Standardize on [`langchain`](https://github.com/langchain-ai/langchain) or [`llama-index`](https://github.com/jerryjliu/llama_index) for modular, maintainable pipelines.
  - Add a section on using advanced retrievers and custom rerankers (see RAG section).
- **LLM Serving:**
  - Add documentation for running Llama-3, Mistral, or Gemma locally using [`vllm`](https://github.com/vllm-project/vllm) or [`text-generation-inference`](https://github.com/huggingface/text-generation-inference).
  - Add a section on quantized models (GGUF) and using [`llama.cpp`](https://github.com/ggerganov/llama.cpp) or [`llama-cpp-python`](https://github.com/abetlen/llama-cpp-python).
- **Table Extraction:**
  - Add support for deep learning table extraction with [`donut`](https://huggingface.co/naver-clova-ix/donut-base) or [`table-transformer`](https://huggingface.co/microsoft/table-transformer).
- **Vector Database:**
  - Add a section on running [`qdrant`](https://github.com/qdrant/qdrant) or [`weaviate`](https://github.com/weaviate/weaviate) locally with Docker.
  - Document hybrid search (vector + keyword) using Qdrant's features.
  - Add schema versioning/migration documentation.
- **OCR:**
  - Add support for [`TrOCR`](https://huggingface.co/microsoft/trocr-base-handwritten) and [`doctr`](https://github.com/mindee/doctr) for high-accuracy OCR.
- **Batch Processing:**
  - Add a section on batch OCR and RAG processing using [`ray`](https://github.com/ray-project/ray) or `joblib`.
- **Model Monitoring:**
  - Add a section on monitoring LLM/embedding latency, throughput, and error rates (see DevOps doc).
- **Centralized Modern Stack Doc:**
  - Create `docs/technical/modern_stack_overview.md` as a single source of truth for stack and upgrade status.
- **How-to Guides:**
  - Add step-by-step guides for switching between cloud/local models, upgrading vector DBs, and adding new LLMs.
- **Changelog:**
  - Add a changelog section to each doc to track upgrades and library/model changes.

See other technical docs for details on each upgrade area.

# Appendix: MVP Streamlit + FAISS Hybrid RAG Demo

## Overview
A minimal working prototype (`policy_rag_hybrid.py`) was built using Streamlit, FAISS, and LangChain to test health insurance policy QA with GPT-4-class models. This MVP demonstrates the core RAG workflow and rapid prototyping for insurance document QA.

**How to run:**
```
streamlit run policy_rag_hybrid.py
```

## Flow
- Upload one or more policy PDFs (scanned or digital).
- The app extracts text (OCR for scanned, direct for digital) and parses tables.
- User asks a free-form question (e.g., "since when am I with Niva Bupa").
- The system:
  1. Answers instantly from extracted metadata if possible (e.g., dates).
  2. Otherwise, runs a vector RAG search using FAISS and OpenAI embeddings.
  3. If RAG fails, does a full reread with the LLM as a last resort.
- Shows the answer and the source context chunks.

## Key Features
- **PDF Parsing:** Handles both scanned (OCR via pytesseract) and digital PDFs.
- **Table Extraction:** Uses pdfplumber and pandas to flatten tables into JSON rows for retrieval.
- **Metadata Extraction:** Fast-path answers for common queries (dates, insured since, etc.).
- **Vector Search:** Uses FAISS for local vector DB, OpenAI embeddings, and LangChain retrievers.
- **LLM QA:** Uses OpenAI GPT-4o (or similar) for answer generation and fallback rescue.
- **Streamlit UI:** Simple, interactive, and easy to extend.

## Architecture Summary
- **Frontend:** Streamlit (file upload, question input, answer display)
- **Backend:**
  - PDF parsing (pdfplumber, PyPDFLoader, pytesseract, pdf2image)
  - Table extraction (pandas)
  - Embeddings (OpenAI, LangChain)
  - Vector DB (FAISS)
  - RAG pipeline (LangChain ConversationalRetrievalChain)
  - LLM (OpenAI GPT-4o via LangChain)
- **Rescue Mode:** If RAG fails, reread the full text with the LLM.

## Lessons & Next Steps
- **Rapid Prototyping:** Streamlit + LangChain enables fast iteration and user feedback.
- **Hybrid Retrieval:** Combining metadata, table rows, and full text improves answer accuracy.
- **Fallbacks:** Multi-stage answering (metadata → RAG → full reread) increases robustness.
- **Extensibility:** The MVP can be extended with local LLMs, better embeddings, and more advanced table/NER extraction as described in the main docs.

## Code Location
- See `policy_rag_hybrid.py` in the repo root for the full MVP code.

This MVP served as a practical testbed for the architecture and informed the design of the production RAG pipeline described above.