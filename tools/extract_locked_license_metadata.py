#!/usr/bin/env python3
"""Extract published licence metadata for a hash-locked Python dependency graph.

This is an evidence-preparation tool, not a licence-compliance decision. It
matches each pinned package in a requirements lock against the distributions
installed in the Python interpreter running the command. Missing packages,
version mismatches, blank licence fields, and non-SPDX free text remain
explicitly visible for legal/owner review.
"""

from __future__ import annotations

import argparse
import importlib.metadata
import json
import re
import sys
from collections.abc import Iterable
from pathlib import Path
from typing import Any


PIN_PATTERN = re.compile(r"^([A-Za-z0-9_.-]+)==([^\s\\]+)")


def canonical_name(name: str) -> str:
    """Return the PEP 503-compatible project-name form."""
    return re.sub(r"[-_.]+", "-", name).lower()


def locked_packages(lock_file: Path) -> list[tuple[str, str]]:
    """Read unique package/version pairs from a pip-compile hash lock."""
    packages: list[tuple[str, str]] = []
    seen: set[str] = set()
    for raw_line in lock_file.read_text(encoding="utf-8").splitlines():
        match = PIN_PATTERN.match(raw_line.strip())
        if not match:
            continue
        name, version = match.groups()
        normalized = canonical_name(name)
        if normalized not in seen:
            seen.add(normalized)
            packages.append((name, version))
    if not packages:
        raise ValueError(f"no pinned packages found in {lock_file}")
    return packages


def installed_distributions() -> dict[str, importlib.metadata.Distribution]:
    """Index installed distributions by normalised project name."""
    return {
        canonical_name(distribution.metadata["Name"]): distribution
        for distribution in importlib.metadata.distributions()
        if distribution.metadata.get("Name")
    }


def values(metadata: importlib.metadata.PackageMetadata, field: str) -> list[str]:
    """Read non-empty repeated package-metadata values."""
    return sorted({value.strip() for value in metadata.get_all(field, []) if value.strip()})


def component_record(
    name: str,
    locked_version: str,
    distributions: dict[str, importlib.metadata.Distribution],
) -> dict[str, Any]:
    """Build one review record without inferring a legal conclusion."""
    distribution = distributions.get(canonical_name(name))
    base: dict[str, Any] = {
        "name": name,
        "version": locked_version,
        "metadata_source": "installed-distribution-metadata",
        "review_status": "legal-review-required",
    }
    if distribution is None:
        return {**base, "match_status": "missing-from-interpreter", "licence_metadata": None}
    if distribution.version != locked_version:
        return {
            **base,
            "match_status": "version-mismatch",
            "installed_version": distribution.version,
            "licence_metadata": None,
        }

    metadata = distribution.metadata
    licence_expression = metadata.get("License-Expression", "").strip() or None
    licence_text = metadata.get("License", "").strip() or None
    licence_classifiers = [
        classifier
        for classifier in values(metadata, "Classifier")
        if classifier.startswith("License ::")
    ]
    populated = bool(licence_expression or licence_text or licence_classifiers)
    return {
        **base,
        "match_status": "matched",
        "licence_metadata": {
            "license_expression": licence_expression,
            "license_text": licence_text,
            "license_classifiers": licence_classifiers,
            "metadata_populated": populated,
        },
    }


def build_report(lock_file: Path) -> dict[str, Any]:
    """Create a deterministic licence-metadata review candidate."""
    distributions = installed_distributions()
    components = [
        component_record(name, version, distributions)
        for name, version in locked_packages(lock_file)
    ]
    matched = [item for item in components if item["match_status"] == "matched"]
    populated = [
        item
        for item in matched
        if item["licence_metadata"] and item["licence_metadata"]["metadata_populated"]
    ]
    return {
        "schema_version": 1,
        "purpose": "licence-metadata review candidate; not a compliance approval",
        "lock_file": str(lock_file),
        "python": sys.version.split()[0],
        "components": components,
        "summary": {
            "locked_components": len(components),
            "matched_components": len(matched),
            "missing_from_interpreter": sum(
                item["match_status"] == "missing-from-interpreter" for item in components
            ),
            "version_mismatches": sum(
                item["match_status"] == "version-mismatch" for item in components
            ),
            "components_with_declared_licence_metadata": len(populated),
            "components_without_declared_licence_metadata": len(matched) - len(populated),
            "legal_approval": "not-recorded",
        },
    }


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lock", type=Path, required=True, help="hash-locked requirements file")
    parser.add_argument("--output", type=Path, required=True, help="new JSON report path")
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    if not args.lock.is_file():
        raise SystemExit(f"lock file not found: {args.lock}")
    if args.output.exists():
        raise SystemExit(f"refusing to overwrite existing output: {args.output}")
    report = build_report(args.lock)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    summary = report["summary"]
    print(
        "wrote {output}: {matched}/{locked} matched; {populated} with declared licence metadata; "
        "{missing} missing; {mismatches} version mismatches; legal approval not recorded".format(
            output=args.output,
            matched=summary["matched_components"],
            locked=summary["locked_components"],
            populated=summary["components_with_declared_licence_metadata"],
            missing=summary["missing_from_interpreter"],
            mismatches=summary["version_mismatches"],
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
