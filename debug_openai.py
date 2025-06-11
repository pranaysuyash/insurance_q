#!/usr/bin/env python3
"""
Debug OpenAI client initialization
"""
import sys
import os

# Add the project root to Python path
sys.path.insert(0, '/Users/pranay/Projects/medpiper/insurance_app')

print("🔍 Debugging OpenAI client initialization...")
print("=" * 50)

try:
    import openai
    print(f"✅ OpenAI version: {openai.__version__}")
    
    # Try initializing OpenAI client with minimal parameters
    from openai import OpenAI
    
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("❌ OPENAI_API_KEY not set")
    else:
        print("✅ OPENAI_API_KEY is set")
        
        # Try different initialization methods
        print("\n🔧 Testing OpenAI client initialization...")
        
        try:
            # Method 1: Basic initialization
            client = OpenAI(api_key=api_key)
            print("✅ Basic OpenAI client initialization: SUCCESS")
        except Exception as e:
            print(f"❌ Basic OpenAI client initialization failed: {e}")
            
            # Method 2: Try with explicit parameters
            try:
                client = OpenAI(
                    api_key=api_key,
                    timeout=30.0
                )
                print("✅ OpenAI client with timeout: SUCCESS")
            except Exception as e2:
                print(f"❌ OpenAI client with timeout failed: {e2}")
                
                # Method 3: Try legacy method
                try:
                    openai.api_key = api_key
                    print("✅ Legacy OpenAI initialization: SUCCESS")
                except Exception as e3:
                    print(f"❌ Legacy OpenAI initialization failed: {e3}")

except Exception as e:
    print(f"❌ OpenAI import failed: {e}")

print("\n" + "=" * 50)
print("🔍 OpenAI diagnosis complete!")
