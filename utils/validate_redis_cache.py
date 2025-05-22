#!/usr/bin/env python3
"""
Redis Cache Validator and Fixer

This script scans all keys in the Redis cache used by the RAG system, 
validates their format, and fixes any malformed responses to ensure 
they follow the standardized structure.

Usage:
    python validate_redis_cache.py [--dry-run] [--verbose] [--pattern=PREFIX:*]

Options:
    --dry-run   Don't modify any data, just report issues
    --verbose   Show detailed information about each key
    --pattern   Redis key pattern to scan (default: rag:query:*)
"""

import redis
import json
import argparse
import os
import sys
from dotenv import load_dotenv
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("redis-cache-validator")

# Load environment variables
load_dotenv()

# Expected response format has:
# 1. A "status" key with "success" value
# 2. A "result" key containing the answer, sources, etc.
def is_valid_format(response_data):
    """Check if the cached response has the expected format."""
    try:
        if not isinstance(response_data, dict):
            return False
        
        if "status" not in response_data:
            return False
            
        if response_data["status"] != "success":
            # Non-success responses are still valid formats
            return "error" in response_data
            
        if "result" not in response_data:
            return False
            
        result = response_data["result"]
        if not isinstance(result, dict):
            return False
            
        # Check required fields in result
        if "answer" not in result:
            return False
            
        return True
    except Exception as e:
        logger.error(f"Error validating format: {e}")
        return False

def fix_response_format(response_data, query=None):
    """Fix a malformed response to match the expected format."""
    try:
        # If it's not a dict, try to work with it if possible
        if not isinstance(response_data, dict):
            logger.warning(f"Response is not a dictionary: {type(response_data)}")
            return {"status": "error", "error": "Malformed cache entry"}
        
        # Handle direct answer/sources format
        if "answer" in response_data and "status" not in response_data:
            sources = response_data.get("sources", [])
            embedding_model = response_data.get("embedding_model_used")
            
            return {
                "status": "success",
                "result": {
                    "answer": response_data["answer"],
                    "sources": sources,
                    "query": query,
                    "embedding_model_used": embedding_model
                }
            }
        
        # Handle response with status but missing result structure
        if "status" in response_data and response_data["status"] == "success":
            if "result" not in response_data and "answer" in response_data:
                return {
                    "status": "success",
                    "result": {
                        "answer": response_data["answer"],
                        "sources": response_data.get("sources", []),
                        "query": query,
                        "embedding_model_used": response_data.get("embedding_model_used")
                    }
                }
        
        # If we can't fix it, mark as error
        if "status" not in response_data or "result" not in response_data:
            return {"status": "error", "error": "Unable to repair malformed cache entry"}
            
        return response_data
    except Exception as e:
        logger.error(f"Error fixing response format: {e}")
        return {"status": "error", "error": f"Exception during repair: {str(e)}"}

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Validate and fix Redis cache entries")
    parser.add_argument("--dry-run", action="store_true", help="Don't modify data, just report")
    parser.add_argument("--verbose", action="store_true", help="Show detailed information")
    parser.add_argument("--pattern", default="rag:query:*", help="Redis key pattern to scan")
    args = parser.parse_args()
    
    # Set up Redis connection
    redis_host = os.getenv("REDIS_HOST", "localhost")
    redis_port = int(os.getenv("REDIS_PORT", 6379))
    redis_db = int(os.getenv("REDIS_DB", 0))
    redis_password = os.getenv("REDIS_PASSWORD", None)
    
    try:
        r = redis.Redis(
            host=redis_host, 
            port=redis_port,
            db=redis_db,
            password=redis_password,
            decode_responses=False  # Keep as bytes to properly deserialize
        )
        r.ping()  # Test connection
        logger.info(f"Connected to Redis at {redis_host}:{redis_port}")
    except redis.ConnectionError as e:
        logger.error(f"Failed to connect to Redis: {e}")
        sys.exit(1)
    
    # Scan for keys matching the pattern
    cursor = 0
    key_count = 0
    invalid_count = 0
    fixed_count = 0
    
    logger.info(f"Scanning Redis keys matching pattern: {args.pattern}")
    
    while True:
        cursor, keys = r.scan(cursor=cursor, match=args.pattern, count=100)
        
        for key in keys:
            key_count += 1
            key_str = key.decode('utf-8') if isinstance(key, bytes) else key
            
            # Extract query from key if possible
            query = None
            if ":" in key_str:
                try:
                    query = key_str.split(":", 2)[2]  # rag:query:<query>
                except:
                    query = None
            
            try:
                value = r.get(key)
                if value is None:
                    logger.warning(f"Key {key_str} exists but has no value")
                    continue
                
                # Try to decode JSON
                try:
                    data = json.loads(value)
                    
                    # Validate format
                    valid = is_valid_format(data)
                    
                    if args.verbose:
                        logger.info(f"Key: {key_str}, Valid: {valid}")
                        
                    if not valid:
                        invalid_count += 1
                        logger.warning(f"Invalid format for key: {key_str}")
                        
                        # Fix the format
                        fixed_data = fix_response_format(data, query)
                        if not args.dry_run:
                            r.set(key, json.dumps(fixed_data))
                            fixed_count += 1
                            logger.info(f"Fixed format for key: {key_str}")
                        else:
                            if args.verbose:
                                logger.info(f"Would fix key {key_str} (dry run)")
                                
                except json.JSONDecodeError:
                    invalid_count += 1
                    logger.warning(f"Non-JSON value for key: {key_str}")
                    if not args.dry_run:
                        # Remove invalid entry
                        r.delete(key)
                        logger.info(f"Deleted non-JSON key: {key_str}")
                    
            except Exception as e:
                logger.error(f"Error processing key {key_str}: {e}")
        
        # If cursor is 0, we've completed the scan
        if cursor == 0:
            break
    
    # Summary
    logger.info("====== Cache Validation Summary ======")
    logger.info(f"Total keys scanned: {key_count}")
    logger.info(f"Invalid format keys: {invalid_count}")
    if args.dry_run:
        logger.info(f"Keys that would be fixed: {invalid_count}")
    else:
        logger.info(f"Keys fixed: {fixed_count}")
    
    if invalid_count > 0 and args.dry_run:
        logger.warning("Found invalid keys. Run without --dry-run to fix them.")
    elif invalid_count == 0:
        logger.info("All cache entries have valid format!")

if __name__ == "__main__":
    main() 