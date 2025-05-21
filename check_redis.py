#!/usr/bin/env python3
import redis
import sys
import json

# Connect to Redis
r = redis.Redis(host='localhost', port=6379, decode_responses=True)

def list_all_keys():
    """List all keys in Redis"""
    keys = r.keys('*')
    
    if not keys:
        print("No keys found in Redis")
        return
    
    print(f"Found {len(keys)} keys in Redis:")
    for idx, key in enumerate(keys, 1):
        print(f"{idx}. {key}")
        
def get_key_value(key):
    """Get the value for a specific key"""
    if not r.exists(key):
        print(f"Key '{key}' not found in Redis")
        return
    
    value = r.get(key)
    try:
        # Try to parse as JSON for better display
        data = json.loads(value)
        print(f"Value for key '{key}':")
        print(json.dumps(data, indent=2))
    except json.JSONDecodeError:
        # If not JSON, print raw value
        print(f"Value for key '{key}': {value}")

def clear_cache():
    """Clear all Redis cache keys"""
    keys = r.keys('ocr_cache:*')
    if keys:
        count = r.delete(*keys)
        print(f"Cleared {count} OCR cache keys from Redis")
    else:
        print("No OCR cache keys found to clear")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python check_redis.py [list|get|clear] [key]")
        sys.exit(1)
    
    command = sys.argv[1].lower()
    
    if command == "list":
        list_all_keys()
    elif command == "get" and len(sys.argv) > 2:
        key = sys.argv[2]
        get_key_value(key)
    elif command == "clear":
        clear_cache()
    else:
        print("Invalid command. Use 'list', 'get <key>', or 'clear'") 