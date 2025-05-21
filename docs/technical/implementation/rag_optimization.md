# RAG System Optimization

## Embedding Model Improvements (May 2025)

### Initial Problem
- Poor answer quality in RAG system responses
- Example: Policy number query returning document ID instead of actual policy number from text

### Optimization Strategy

#### 1. Simplified Embedding Pipeline
- **Before**: Using OpenAI embedding models with HuggingFace fallback
- **After**: Pure OpenAI embedding pipeline (removed fallback complexity)
- **Why**: Simplified architecture reduces potential points of failure and ensures consistent embedding space

#### 2. Embedding Model Testing
- **Phase 1**: Testing with `text-embedding-ada-002`
- **Phase 2**: Testing with `text-embedding-3-small`
- **Future**: May consider `text-embedding-3-large` for further improvements

#### 3. Implementation Changes
- Modified `_generate_embeddings_with_fallback` to only use OpenAI (no HF fallback)
- Disabled HF configuration in environment variables
- Added detailed context logging for better debugging of retrieval quality

### Configuration Updates
Apply these changes to your `.env` file:
```
# OpenAI Configuration
OPENAI_EMBEDDING_MODEL=text-embedding-ada-002 or text-embedding-3-small

# Hugging Face Configuration - DISABLED
# HF_TOKEN=your_token_here
# EMBEDDING_MODEL=sentence-transformers/all-mpnet-base-v2

# Embedding Strategy - Not needed anymore, always using OpenAI
# USE_OPENAI_FIRST=true
```

### Restart Services
After making the above changes:
```bash
# Rebuild and restart the RAG service
docker compose up --build -d rag_service
```

## Results and Analysis

| Model | Query | Top Result | Score | Notes |
|-------|-------|------------|-------|-------|
| ada-002 | "What is my policy number?" | TBD | TBD | Initial test |
| text-embedding-3-small | "What is my policy number?" | TBD | TBD | Improved model |

### Next Steps
1. Compare retrieval quality between embedding models using debug logs
2. Fine-tune context window and chunk sizes if needed
3. Consider customizing the system prompt based on query types 