#!/usr/bin/env python3
"""Validate the safe Cloud Run/Supabase launch configuration without printing secrets."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

from src.utils.runtime_config import production_configuration_errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path, help="Optional local env file; never commit it.")
    args = parser.parse_args()
    if args.env_file:
        if not args.env_file.is_file():
            print("configuration error: supplied env file does not exist", file=sys.stderr)
            return 2
        load_dotenv(args.env_file, override=False)

    errors = production_configuration_errors({**os.environ, "ENVIRONMENT": "production"})
    if errors:
        print("production configuration is not launch-ready:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("production configuration contract is valid; no secret values were printed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
