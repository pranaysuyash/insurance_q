#!/usr/bin/env python
"""
Script to create .env file with provided OpenAI API key.
"""
import os
from pathlib import Path

# Try to read current .env file first to preserve the API key
current_key = None
env_path = Path.cwd() / '.env'
if env_path.exists():
    print(f"Reading current .env file: {env_path}")
    with open(env_path, 'r') as f:
        for line in f:
            if line.startswith('OPENAI_API_KEY='):
                current_key = line.strip().split('=', 1)[1]
                print(f"Found existing API key")
                break

# Use the existing key or the default placeholder
api_key = current_key or "your_openai_api_key_here"

env_content = f"""# OpenAI Configuration
OPENAI_API_KEY={api_key}
OPENAI_EMBEDDING_MODEL=text-embedding-ada-002
OPENAI_CHAT_MODEL=gpt-4.1-nano

# Hugging Face Configuration
HF_TOKEN=your_huggingface_token_here
EMBEDDING_MODEL=sentence-transformers/all-mpnet-base-v2

# Embedding Strategy
# Set to "true" to try OpenAI first, then fall back to Hugging Face if rate limited
# Set to "false" to try Hugging Face first, then fall back to OpenAI
USE_OPENAI_FIRST=true

# Qdrant Vector Database
QDRANT_HOST=localhost
QDRANT_PORT=6333
QDRANT_COLLECTION=insurance_documents_v2

# Redis Cache
REDIS_HOST=localhost
REDIS_PORT=6379
CACHE_TTL_SECONDS=3600

# Logging
LOG_LEVEL=INFO
"""

with open('.env', 'w') as f:
    f.write(env_content)

print("Created .env file with OpenAI API key and text-embedding-ada-002 model")
print("To test the OpenAI API connection directly, run:")
print("python test_openai_key.py --verbose")
print("\nTo test multiple embedding models in sequence, run:")
print("python test_openai_key.py --all-models --verbose")
print("\nTo test the fallback mechanism with OpenAI first, run:")
print("python test_embedding_fallback.py --openai-first --small --verbose")
print("")
print("To test with HF as primary, run:")
print("python test_embedding_fallback.py --verbose") 