#!/usr/bin/env python3
"""Enrich a CycloneDX SBOM with authoritative license metadata.

Reads the raw pip-audit CycloneDX output and the extracted license-metadata
review candidate, then merges the license data into the SBOM components.

Output is a CycloneDX-format SBOM with populated license fields, suitable
for founder review and eventual publication.

Usage:
  python tools/enrich_sbom_license_metadata.py \\
      --sbom docs/review/sboms/coverwise-production-ocr-sbom-2026-07-25.json \\
      --metadata docs/review/sboms/license-metadata-2026-07-25.json \\
      --output docs/review/sboms/coverwise-production-ocr-sbom-enriched.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections.abc import Iterable
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def canonical_name(name: str) -> str:
    """Return PEP 503-compatible project-name form (same as extractor)."""
    return re.sub(r"[-_.]+", "-", name).lower()


def load_json(path: Path) -> dict[str, Any]:
    """Load and validate a JSON file."""
    if not path.is_file():
        raise SystemExit(f"file not found: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"{path} is not a JSON object")
    return data


def build_license_index(
    metadata: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    """Build a name-indexed lookup of license metadata components.

    Keys are canonical package names. Version-mismatched and missing
    components are included but marked for review.
    """
    index: dict[str, dict[str, Any]] = {}
    for component in metadata.get("components", []):
        name = component.get("name", "")
        if not name:
            continue
        index[canonical_name(name)] = component
    return index


def pick_license_expression(
    meta: dict[str, Any] | None,
) -> list[dict[str, Any]]:
    """Extract the best SPDX license identifier from metadata.

    Returns a CycloneDX ``licenses`` array (possibly empty).
    Priority: license_expression > classifier > license_text.
    """
    if meta is None:
        return []

    lic = meta.get("licence_metadata") or {}
    expression = lic.get("license_expression") or None
    classifiers = lic.get("license_classifiers") or []
    text = lic.get("license_text") or None

    seen: set[str] = set()
    result: list[dict[str, Any]] = []

    if expression:
        expression = expression.strip()
        if expression and expression not in seen:
            seen.add(expression)
            result.append({"license": {"id": expression}})

    for classifier in classifiers:
        # "License :: OSI Approved :: MIT License" -> "MIT"
        match = re.search(r"::\s*(.+?)\s*$", classifier)
        if match:
            spdx = match.group(1).strip()
            # Map common non-SPDX classifier tails
            spdx_map = {
                "Apache Software License": "Apache-2.0",
                "MIT License": "MIT",
                "BSD License": "BSD-3-Clause",
                "ISC License (ISCL)": "ISC",
                "Mozilla Public License 2.0 (MPL 2.0)": "MPL-2.0",
                "Python Software Foundation License": "PSF",
                "The Unlicense (Unlicense)": "Unlicense",
                "BSD": "BSD-3-Clause",
            }
            spdx = spdx_map.get(spdx, spdx)
            if spdx and spdx not in seen:
                seen.add(spdx)
                result.append({"license": {"id": spdx}})

    if not result and text:
        text = text.strip()
        # Try to extract SPDX from free text
        text_spdx = {
            "Apache-2.0": "Apache-2.0",
            "Apache 2.0": "Apache-2.0",
            "Apache 2": "Apache-2.0",
            "Apache License 2.0": "Apache-2.0",
            "Apache License, Version 2.0": "Apache-2.0",
            "Apache Software License 2.0": "Apache-2.0",
            "MIT": "MIT",
            "BSD": "BSD-3-Clause",
            "BSD-3-Clause": "BSD-3-Clause",
            "3-Clause BSD License": "BSD-3-Clause",
            "ISC": "ISC",
            "MPL-2.0": "MPL-2.0",
            "Unlicense": "Unlicense",
            "GNU AFFERO GPL 3.0": "AGPL-3.0-only",
            "Dual License": "LicenseRef-dual",
            "PSFL": "PSF",
            "MIT-0": "MIT-0",
            "Apache": "Apache-2.0",
            "MIT-CMU": "MIT-CMU",
            "GPL-3.0-with-GCC-exception": "GPL-3.0-with-GCC-exception",
        }
        matched_spdx = text_spdx.get(text)
        if matched_spdx and matched_spdx not in seen:
            seen.add(matched_spdx)
            result.append({"license": {"id": matched_spdx}})

    return result


def enrich_component(
    sbom_component: dict[str, Any],
    license_meta: dict[str, Any] | None,
) -> dict[str, Any]:
    """Add license data and review properties to one SBOM component."""
    enriched = dict(sbom_component)

    # Enrich with license metadata
    if license_meta:
        meta_data = license_meta.get("licence_metadata") or {}
        licenses = pick_license_expression(license_meta)
        if licenses:
            enriched["licenses"] = licenses

        # Add review-status properties
        review_status = license_meta.get("review_status", "legal-review-required")
        match_status = license_meta.get("match_status", "unknown")
        metadata_source = license_meta.get("metadata_source", "")

        properties = enriched.get("properties", [])
        if review_status:
            properties.append({
                "name": "coverwise:license_review_status",
                "value": review_status,
            })
        if match_status:
            properties.append({
                "name": "coverwise:license_match_status",
                "value": match_status,
            })
        if metadata_source:
            properties.append({
                "name": "coverwise:license_metadata_source",
                "value": metadata_source,
            })

        # Add evidence of the declared license
        if meta_data:
            if meta_data.get("license_expression"):
                properties.append({
                    "name": "coverwise:declared_license_expression",
                    "value": meta_data["license_expression"],
                })
            if meta_data.get("license_text"):
                properties.append({
                    "name": "coverwise:declared_license_text",
                    "value": meta_data["license_text"][:200],
                })
            if meta_data.get("license_classifiers"):
                properties.append({
                    "name": "coverwise:declared_license_classifiers",
                    "value": "; ".join(meta_data["license_classifiers"]),
                })

        if properties:
            enriched["properties"] = properties
    else:
        # No license metadata available
        enriched["properties"] = enriched.get("properties", []) + [
            {"name": "coverwise:license_review_status", "value": "legal-review-required"},
            {"name": "coverwise:license_match_status", "value": "no-metadata-available"},
        ]

    return enriched


def build_report(
    sbom: dict[str, Any],
    metadata_index: dict[str, dict[str, Any]],
    metadata_purpose: str = "",
) -> dict[str, Any]:
    """Enrich all SBOM components with license metadata and produce a report."""
    enriched_components: list[dict[str, Any]] = []
    stats = {
        "total_sbom_components": 0,
        "enriched_with_license": 0,
        "enriched_no_license_available": 0,
        "not_in_metadata": 0,
        "version_mismatch": 0,
        "missing_from_interpreter": 0,
    }

    for component in sbom.get("components", []):
        stats["total_sbom_components"] += 1
        name = component.get("name", "")
        cname = canonical_name(name)
        meta = metadata_index.get(cname)

        if meta is None:
            stats["not_in_metadata"] += 1
        elif meta.get("match_status") == "version-mismatch":
            stats["version_mismatch"] += 1
        elif meta.get("match_status") == "missing-from-interpreter":
            stats["missing_from_interpreter"] += 1

        enriched = enrich_component(component, meta)
        lic_meta = meta.get("licence_metadata") if meta else None
        if lic_meta and lic_meta.get("metadata_populated"):
            stats["enriched_with_license"] += 1
        else:
            stats["enriched_no_license_available"] += 1

        enriched_components.append(enriched)

    enriched_sbom = dict(sbom)
    enriched_sbom["components"] = enriched_components

    # Add enrichment metadata
    enriched_sbom["coverwise:enrichment"] = {
        "tool": "tools/enrich_sbom_license_metadata.py",
        "metadata_source": metadata_purpose,
        "enriched_at": datetime.now(timezone.utc).isoformat(),
    }

    return enriched_sbom, stats


def print_summary(stats: dict[str, int], output_path: str) -> None:
    """Print a human-readable summary of the enrichment results."""
    total = stats["total_sbom_components"]
    enriched = stats["enriched_with_license"]
    no_license = stats["enriched_no_license_available"]
    not_found = stats["not_in_metadata"]
    mismatches = stats["version_mismatch"]
    missing = stats["missing_from_interpreter"]

    print(f"Wrote enriched SBOM: {output_path}")
    print(f"  Total components:          {total}")
    print(f"  Enriched with license:     {enriched} ({enriched/total*100:.0f}%)")
    print(f"  No license available:      {no_license} ({no_license/total*100:.0f}%)")
    print(f"  Not in metadata index:     {not_found}")
    print(f"  Version mismatches:        {mismatches}")
    print(f"  Missing from interpreter:  {missing}")
    print()
    if enriched < total:
        print("REVIEW REQUIRED: Not all components have populated license metadata.")
        print("Founder approval is needed before publishing the enriched SBOM.")


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sbom", type=Path, required=True, help="CycloneDX SBOM JSON")
    parser.add_argument("--metadata", type=Path, required=True, help="license-metadata review JSON")
    parser.add_argument("--output", type=Path, required=True, help="enriched SBOM output path")
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)

    sbom = load_json(args.sbom)
    metadata = load_json(args.metadata)

    if sbom.get("bomFormat") != "CycloneDX":
        raise SystemExit(f"{args.sbom} is not a CycloneDX document")

    metadata_index = build_license_index(metadata)
    metadata_purpose = metadata.get("purpose", "")
    enriched_sbom, stats = build_report(sbom, metadata_index, metadata_purpose)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(enriched_sbom, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print_summary(stats, str(args.output))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
