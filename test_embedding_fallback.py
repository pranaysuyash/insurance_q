#!/usr/bin/env python
"""
Test script to demonstrate the embedding fallback mechanism.
"""
import os
import asyncio
import json
import time
import logging
from dotenv import load_dotenv
import argparse
from src.rag.pipeline import RAGPipeline
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
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

async def test_embedding_fallback():
    """Test the embedding fallback mechanism with different configurations."""
    parser = argparse.ArgumentParser(description='Test RAG pipeline embedding fallback mechanism')
    parser.add_argument('--openai-first', action='store_true', help='Use OpenAI first (default is HF first)')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    parser.add_argument('--chat-model', default=os.getenv('OPENAI_CHAT_MODEL', 'gpt-4.1-nano'), 
                        help='OpenAI chat model to use (default: gpt-4.1-nano)')
    parser.add_argument('--embedding-model', default=os.getenv('OPENAI_EMBEDDING_MODEL', 'text-embedding-ada-002'),
                        help='OpenAI embedding model to use (default: text-embedding-ada-002)')
    parser.add_argument('--small', action='store_true', help='Use a smaller test set (3 texts instead of 5)')
    parser.add_argument('--model-sequence', action='store_true', 
                        help='Try all OpenAI embedding models in sequence (ada-002, 3-small, 3-large)')
    args = parser.parse_args()
    
    # Set log level based on verbose flag
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Load environment variables
    if not load_env_from_project_dir():
        logger.error("Failed to load .env file. Please ensure it exists.")
        return
    
    # Use OpenAI first if specified, otherwise use HF first
    use_openai_first = args.openai_first
    logger.info(f"Testing with {'OpenAI' if use_openai_first else 'Hugging Face'} as primary embedding model")
    logger.info(f"Using chat model: {args.chat_model}")
    
    # Print info about API key (masked)
    api_key = os.getenv('OPENAI_API_KEY', '')
    if api_key:
        masked_key = f"{api_key[:8]}...{api_key[-8:]}"
        logger.info(f"Using OpenAI API key: {masked_key}")
    else:
        logger.warning("No OpenAI API key found in environment variables")
    
    # Define embedding models to test in specific sequence if requested
    embedding_models = ['text-embedding-ada-002', 'text-embedding-3-small', 'text-embedding-3-large']
    if not args.model_sequence:
        embedding_models = [args.embedding_model]  # Just use the specified model
    
    logger.info(f"Will test the following embedding models: {', '.join(embedding_models)}")
    
    # Test document texts - use fewer if small flag is set
    test_texts = [
        "Health insurance covers medical expenses for illnesses, injuries, and preventive care.",
        "Medicare is a federal health insurance program for people 65 or older.",
        "Premium is the amount you pay to the insurance company for your health insurance policy."
    ]
    
    if not args.small:
        test_texts.extend([
            "HIPAA (Health Insurance Portability and Accountability Act) protects sensitive patient health information.",
            "Deductible is the amount you pay before your insurance begins to cover costs."
        ])
    
    logger.info(f"Using {len(test_texts)} test texts to minimize rate limit issues")
    
    # Test each model in sequence
    for embedding_model in embedding_models:
        logger.info(f"\n=== Testing with OpenAI embedding model: {embedding_model} ===")
        
        # Create pipeline with current model
        pipeline = RAGPipeline(
            use_openai_first=use_openai_first,
            openai_chat_model=args.chat_model,
            openai_embedding_model=embedding_model
        )
        
        # Create a test document
        test_doc_id = f"test_fallback_{embedding_model.replace('text-embedding-', '')}_{int(time.time())}"
        test_blocks = [
            {"id": f"block_{i}", "page": 1, "text": text, "bbox": [0.1, 0.1*i, 0.9, 0.1*(i+1)]}
            for i, text in enumerate(test_texts)
        ]
        
        # Try to ingest document
        logger.info(f"Attempting to ingest document {test_doc_id} with {len(test_blocks)} blocks")
        try:
            # Add a small delay before starting to ensure any previous rate limit windows have passed
            time.sleep(2)
            
            # First try a single embedding to test connection
            logger.info("Testing single embedding generation before batch processing...")
            test_result = await pipeline._generate_embeddings_with_fallback(["Test connection to embedding API"])
            logger.info(f"Single test embedding successful with model: {pipeline.active_embedding_model}")
            
            # Process document
            ingest_result = await pipeline.ingest_document_data(test_doc_id, test_blocks)
            logger.info(f"Ingestion result: {json.dumps(ingest_result, indent=2)}")
            
            # Get embedding stats
            stats = await pipeline.get_embedding_stats()
            logger.info(f"Embedding stats: {json.dumps(stats, indent=2)}")
            
            # Test search
            if ingest_result.get("status") == "success" and ingest_result.get("points_added", 0) > 0:
                logger.info("Testing search...")
                # Add a small delay before querying
                time.sleep(2)
                query_result = await pipeline.query_rag("What is a health insurance premium?")
                logger.info(f"Query result: {json.dumps(query_result, indent=2)}")
                
                # Get updated stats
                stats = await pipeline.get_embedding_stats()
                logger.info(f"Updated embedding stats: {json.dumps(stats, indent=2)}")
            
        except Exception as e:
            logger.error(f"Test failed with model {embedding_model}: {e}", exc_info=True)
            
            # If the test failed, output the failure counts to see what happened
            try:
                stats = await pipeline.get_embedding_stats()
                logger.info(f"Final embedding stats after failure: {json.dumps(stats, indent=2)}")
            except:
                pass
        
        # Always add a delay between model tests
        logger.info(f"Finished testing with model {embedding_model}")
        time.sleep(3)

if __name__ == "__main__":
    asyncio.run(test_embedding_fallback()) 