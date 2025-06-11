#!/usr/bin/env python3
"""
Check installed package versions
"""
import subprocess
import sys

packages_to_check = [
    "openai",
    "huggingface-hub", 
    "qdrant-client",
    "redis",
    "fastapi",
    "uvicorn"
]

print("📦 Checking installed package versions...")
print("=" * 50)

for package in packages_to_check:
    try:
        result = subprocess.run([sys.executable, "-m", "pip", "show", package], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            lines = result.stdout.split('\n')
            for line in lines:
                if line.startswith('Version:'):
                    version = line.split(':', 1)[1].strip()
                    print(f"📌 {package}: {version}")
                    break
        else:
            print(f"❌ {package}: Not installed")
    except Exception as e:
        print(f"❌ {package}: Error checking - {e}")

print("\n" + "=" * 50)
print("📦 Package check complete!")
