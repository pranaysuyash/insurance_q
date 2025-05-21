#!/bin/bash
# Script to set OpenAI API environment variables

# Read .env file and set variables
if [ -f .env ]; then
  echo "Loading variables from .env file"
  source .env
  echo "Environment file loaded"
else
  echo "ERROR: .env file not found!"
  exit 1
fi

# Set default values if not already set
if [ -z "$OPENAI_EMBEDDING_MODEL" ]; then
  export OPENAI_EMBEDDING_MODEL="text-embedding-ada-002"
  echo "Set OPENAI_EMBEDDING_MODEL=text-embedding-ada-002"
else
  echo "Using OPENAI_EMBEDDING_MODEL=$OPENAI_EMBEDDING_MODEL"
fi

if [ -z "$OPENAI_CHAT_MODEL" ]; then
  export OPENAI_CHAT_MODEL="gpt-4.1-nano"
  echo "Set OPENAI_CHAT_MODEL=gpt-4.1-nano"
else
  echo "Using OPENAI_CHAT_MODEL=$OPENAI_CHAT_MODEL"
fi

if [ -z "$EMBEDDING_MODEL" ]; then
  export EMBEDDING_MODEL="sentence-transformers/all-mpnet-base-v2"
  echo "Set EMBEDDING_MODEL=sentence-transformers/all-mpnet-base-v2"
else
  echo "Using EMBEDDING_MODEL=$EMBEDDING_MODEL"
fi

if [ -z "$USE_OPENAI_FIRST" ]; then
  export USE_OPENAI_FIRST="true"
  echo "Set USE_OPENAI_FIRST=true"
else
  echo "Using USE_OPENAI_FIRST=$USE_OPENAI_FIRST"
fi

# Check if OpenAI API key is set
if [ -z "$OPENAI_API_KEY" ]; then
  echo "WARNING: OPENAI_API_KEY is not set in the environment!"
  echo "Please make sure it's in your .env file or set it manually."
  exit 1
else
  # Mask the key for display
  KEY_PREFIX="${OPENAI_API_KEY:0:8}"
  KEY_SUFFIX="${OPENAI_API_KEY: -8}"
  echo "Using OPENAI_API_KEY=${KEY_PREFIX}...${KEY_SUFFIX}"
fi

echo ""
echo "Environment variables have been set in your current shell session."
echo "You can now run the test scripts:"
echo "python test_openai_key.py --all-models --verbose"
echo "python test_embedding_fallback.py --openai-first --small --model-sequence --verbose" 