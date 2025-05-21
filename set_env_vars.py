#!/usr/bin/env python
"""
Script to set environment variables from .env file and explicitly set missing values.
"""
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

def set_env_vars():
    """Set environment variables from .env file and add missing values."""
    # Find and load .env file
    env_path = Path.cwd() / '.env'
    if env_path.exists():
        print(f"Loading environment variables from: {env_path}")
        load_dotenv(env_path)
    else:
        print(f"No .env file found at: {env_path}")
        return False
    
    # Define default values for required variables
    defaults = {
        'OPENAI_EMBEDDING_MODEL': 'text-embedding-ada-002',
        'OPENAI_CHAT_MODEL': 'gpt-4.1-nano',
        'EMBEDDING_MODEL': 'sentence-transformers/all-mpnet-base-v2',
        'USE_OPENAI_FIRST': 'true'
    }
    
    # Set missing environment variables
    changes_made = False
    for key, default_value in defaults.items():
        if not os.environ.get(key):
            os.environ[key] = default_value
            print(f"Set missing environment variable: {key}={default_value}")
            changes_made = True
        else:
            print(f"Using existing environment variable: {key}={os.environ[key]}")
    
    # Verify API key
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        print("WARNING: OPENAI_API_KEY is not set!")
        return False
    
    masked_key = f"{api_key[:8]}...{api_key[-8:]}"
    print(f"Using OpenAI API key: {masked_key}")
    
    return True

if __name__ == "__main__":
    success = set_env_vars()
    if success:
        print("\nEnvironment variables have been set correctly.")
        print("To use these variables in your current terminal session, run:")
        print("python -c \"import set_env_vars; set_env_vars.set_env_vars()\"")
        
        # Show how to export variables in current shell
        print("\nOr you can set them directly in your shell with:")
        print("export OPENAI_EMBEDDING_MODEL=text-embedding-ada-002")
        print("export OPENAI_CHAT_MODEL=gpt-4.1-nano")
    else:
        print("\nFailed to set environment variables. Please check your .env file.")
        sys.exit(1) 