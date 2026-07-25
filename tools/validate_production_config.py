#!/usr/bin/env python3
"""Validate the safe Cloud Run/Supabase launch configuration without printing secrets."""

from __future__ import annotations

import argparse
import importlib
import os
import sys
from pathlib import Path

from dotenv import dotenv_values
import yaml

# Make the validator runnable exactly as documented from the repository root,
# without requiring callers to set PYTHONPATH manually.
REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

production_configuration_errors = importlib.import_module(
    "src.utils.runtime_config"
).production_configuration_errors


def _load_runtime_env_file(path: Path) -> dict[str, str]:
    """Parse dotenv files and the YAML mapping accepted by gcloud."""
    if path.suffix.lower() in {".yaml", ".yml"}:
        with path.open("r", encoding="utf-8") as stream:
            values = yaml.safe_load(stream) or {}
        if not isinstance(values, dict):
            raise ValueError("runtime YAML env file must contain a mapping")
        parsed: dict[str, str] = {}
        for name, value in values.items():
            if not isinstance(name, str) or not name.strip():
                raise ValueError("runtime YAML env keys must be non-empty strings")
            if value is not None:
                parsed[name] = (
                    str(value).lower() if isinstance(value, bool) else str(value)
                )
        return parsed
    return {
        name: value for name, value in dotenv_values(path).items() if value is not None
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--env-file", type=Path, help="Optional local env file; never commit it."
    )
    parser.add_argument(
        "--secret-bound",
        action="append",
        default=[],
        metavar="NAME",
        help=(
            "Mark a supported production secret as supplied by Secret Manager "
            "rather than the non-secret env file; repeat for each bound name."
        ),
    )
    parser.add_argument(
        "--profile",
        choices=("api", "worker"),
        default="api",
        help="Production runtime profile to validate (default: api).",
    )
    args = parser.parse_args()
    file_values: dict[str, str] = {}
    if args.env_file:
        if not args.env_file.is_file():
            print(
                "configuration error: supplied env file does not exist", file=sys.stderr
            )
            return 2
        try:
            file_values = _load_runtime_env_file(args.env_file)
        except (OSError, ValueError, yaml.YAMLError) as error:
            print(
                f"configuration error: invalid runtime env file: {error}",
                file=sys.stderr,
            )
            return 2

    supported_secret_names = {
        "OPENAI_API_KEY",
        "SUPABASE_SERVICE_ROLE_KEY",
        "SUPABASE_SECRET_KEY",
        "ANONYMOUS_AUTH_SIGNING_KEY",
        "REVENUECAT_WEBHOOK_AUTHORIZATION",
        "PROCESSING_PAYLOAD_ENCRYPTION_KEY",
    }
    unknown_secret_names = sorted(set(args.secret_bound) - supported_secret_names)
    if unknown_secret_names:
        print(
            "configuration error: unsupported --secret-bound name(s): "
            + ", ".join(unknown_secret_names),
            file=sys.stderr,
        )
        return 2

    secret_names_in_file = sorted(supported_secret_names.intersection(file_values))
    if secret_names_in_file:
        print(
            "configuration error: runtime env file must not contain secret-bound "
            "name(s): " + ", ".join(secret_names_in_file),
            file=sys.stderr,
        )
        return 2

    # An explicitly supplied runtime file is the deployment contract. It must
    # override same-named shell values so preflight validates what gcloud will
    # actually receive, rather than an ambient developer environment.
    environment = {**os.environ, **file_values, "ENVIRONMENT": "production"}
    for name in args.secret_bound:
        environment[name] = "secret-manager-bound-value-with-valid-length-0123456789"
    errors = production_configuration_errors(environment, profile=args.profile)
    if errors:
        print("production configuration is not launch-ready:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("production configuration contract is valid; no secret values were printed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
