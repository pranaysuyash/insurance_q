#!/usr/bin/env python3
"""Print the safe runtime document-capability registry."""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from src.ocr.capability_registry import capability_registry_snapshot


if __name__ == "__main__":
    print(json.dumps(capability_registry_snapshot(), indent=2, sort_keys=True))
