#!/usr/bin/env python
"""
Simple script to test OpenAI API key and embedding models.
"""
import os
import time
import logging
import argparse
from openai import OpenAI
from dotenv import load_dotenv
import sys
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Ensure we're loading from the local .env file
def load_env_from_project_dir():
    """Load environment variables from .env in current project directory."""
    # Get the project directory (where this script is located)
    project_dir = Path(__file__).parent.absolute()
    env_path = project_dir / '.env'
    
    if env_path.exists():
        logger.info(f"Loading .env file from: {env_path}")
        load_dotenv(env_path)
        return True
    else:
        logger.warning(f"No .env file found at: {env_path}")
        # Try from current working directory as fallback
        cwd_env = Path.cwd() / '.env'
        if cwd_env.exists():
            logger.info(f"Loading .env file from current directory: {cwd_env}")
            load_dotenv(cwd_env)
            return True
        else:
            logger.error(f"No .env file found in current directory: {cwd_env}")
            return False

def test_openai_connection():
    """Test basic connection to OpenAI API."""
    parser = argparse.ArgumentParser(description='Test OpenAI API connection and rate limits')
    parser.add_argument('--model', default='text-embedding-ada-002', 
                        help='Single embedding model to test (default: text-embedding-ada-002)')
    parser.add_argument('--all-models', action='store_true', 
                        help='Test with multiple embedding models in sequence')
    parser.add_argument('--batch-size', type=int, default=10,
                        help='Number of texts to use in batch test (default: 10)')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('--show-full-key', action='store_true', help='Show full API key (for debugging)')
    # This function is also exercised by pytest. Ignore pytest's own command
    # line flags while preserving strict parsing for direct script usage.
    args, _unknown_args = parser.parse_known_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Load environment variables from local .env
    if not load_env_from_project_dir():
        logger.error("Failed to load .env file. Please ensure it exists.")
        return
    
    # Display environment variables for debugging
    logger.info(f"Current working directory: {os.getcwd()}")
    logger.info(f"Python path: {sys.executable}")
    
    # Get API key from environment
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key:
        logger.error("No OPENAI_API_KEY found in environment variables")
        logger.info("Environment variables:")
        for key, value in os.environ.items():
            if 'API' in key or 'KEY' in key or 'TOKEN' in key:
                logger.info(f"  {key}: {'[REDACTED]' if 'KEY' in key or 'TOKEN' in key else value}")
        return
    
    # Display API key (masked or full)
    if args.show_full_key:
        logger.info(f"Using OpenAI API key: {api_key}")
    else:
        masked_key = f"{api_key[:8]}...{api_key[-8:]}"
        logger.info(f"Using OpenAI API key: {masked_key}")
    
    # Show other relevant environment variables
    logger.info(f"Environment: OPENAI_EMBEDDING_MODEL={os.getenv('OPENAI_EMBEDDING_MODEL', 'Not set')}")
    logger.info(f"Environment: OPENAI_CHAT_MODEL={os.getenv('OPENAI_CHAT_MODEL', 'Not set')}")
    
    # Define embedding models to test in specific sequence
    models_to_test = ['text-embedding-ada-002', 'text-embedding-3-small', 'text-embedding-3-large']
    if not args.all_models:
        models_to_test = [args.model]  # Just test one model
    
    logger.info(f"Will test the following embedding models in sequence: {', '.join(models_to_test)}")
    
    # Initialize OpenAI client
    try:
        client = OpenAI(api_key=api_key)
        logger.info("Successfully initialized OpenAI client")
    except Exception as e:
        logger.error(f"Failed to initialize OpenAI client: {e}")
        return
    
    # Test basic connection
    try:
        logger.info("Testing models endpoint...")
        start_time = time.time()
        models = client.models.list()
        logger.info(f"Connection successful - Listed {len(models.data)} models in {time.time() - start_time:.2f}s")
    except Exception as e:
        logger.error(f"Failed to connect to OpenAI API: {e}")
        return
    
    # Test each model
    for model_name in models_to_test:
        logger.info(f"\n=== Testing model: {model_name} ===")
        
        # Test embedding generation
        try:
            logger.info("Testing single embedding generation...")
            test_text = "This is a test of the OpenAI embedding API to check rate limits and API key validity."
            
            start_time = time.time()
            response = client.embeddings.create(
                input=test_text,
                model=model_name
            )
            
            # Check response
            if hasattr(response, 'data') and len(response.data) > 0:
                embedding = response.data[0].embedding
                embedding_length = len(embedding)
                logger.info(f"Successfully generated {embedding_length}-dimensional embedding in {time.time() - start_time:.2f}s")
                
                # Log usage information
                if hasattr(response, 'usage'):
                    logger.info(f"Token usage: {response.usage.total_tokens} tokens")
                
                logger.info("Embedding sample (first 5 dimensions): " + str(embedding[:5]))
            else:
                logger.error("No embedding data returned")
                continue  # Skip batch test for this model
                
            # Test batch processing to check rate limits
            batch_size = args.batch_size
            logger.info(f"Testing batch processing with {batch_size} texts...")
            test_texts = [f"This is test text {i} for batch processing with model {model_name}" for i in range(batch_size)]
            
            start_time = time.time()
            batch_response = client.embeddings.create(
                input=test_texts,
                model=model_name
            )
            
            if hasattr(batch_response, 'data') and len(batch_response.data) == batch_size:
                logger.info(f"Successfully processed batch of {batch_size} texts in {time.time() - start_time:.2f}s")
                
                # Log usage information
                if hasattr(batch_response, 'usage'):
                    logger.info(f"Batch token usage: {batch_response.usage.total_tokens} tokens")
                    tokens_per_text = batch_response.usage.total_tokens / batch_size
                    logger.info(f"Average tokens per text: {tokens_per_text:.1f}")
            else:
                logger.error(f"Expected {batch_size} embeddings, got {len(batch_response.data) if hasattr(batch_response, 'data') else 0}")
                
        except Exception as e:
            logger.error(f"Failed to test model {model_name}: {e}")
            continue
            
        logger.info(f"Tests for model {model_name} completed successfully")
        
    logger.info("\nAll requested tests completed")
    logger.info("Your OpenAI API key is working correctly for embeddings")

if __name__ == "__main__":
    test_openai_connection() 
