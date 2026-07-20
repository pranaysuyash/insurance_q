#!/usr/bin/env python
import asyncio
import json
from src.rag.pipeline import RAGPipeline

async def test():
    p = RAGPipeline()
    print("Testing query_rag function...")
    result = await p.query_rag('What is my policy number?')
    print("RAG Result:")
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    asyncio.run(test()) 