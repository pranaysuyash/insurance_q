#!/usr/bin/env python3
"""Add sign-off entries to the Update log of ADRs 17-25.

The first run updated the Status line. This run adds the
Update log entry. Idempotent: checks if the entry already exists.
"""
from pathlib import Path
import re

DECISIONS_DIR = Path("/Users/pranay/Projects/medpiper/insurance_app/docs/decisions")

ADRS = [
    "ADR-2026-07-19-17-coverage-adequacy-substrate-extension",
    "ADR-2026-07-19-18-coverage-check-in-substrate-extension",
    "ADR-2026-07-19-19-claim-document-vault-substrate-extension",
    "ADR-2026-07-19-20-family-coverage-map-privacy-policy",
    "ADR-2026-07-19-21-coverage-check-in-privacy-policy",
    "ADR-2026-07-19-22-coverage-adequacy-privacy-policy",
    "ADR-2026-07-19-23-llm-provider-data-handling-policy",
    "ADR-2026-07-19-24-qdrant-vector-database-data-handling-policy",
    "ADR-2026-07-19-25-supabase-storage-data-handling-policy",
]

# Find each ADR's first paragraph after the Status line (the long Status block)
# and append a sign-off entry to the Update log
for stem in ADRS:
    files = list(DECISIONS_DIR.glob(f"{stem}.md"))
    if not files:
        print(f"NOT FOUND: {stem}")
        continue
    f = files[0]
    text = f.read_text()
    
    if "operator sign-off, revision 1" in text and "Update log" in text.split("operator sign-off, revision 1")[1][:500]:
        print(f"ALREADY SIGNED: {f.name}")
        continue
    
    # Find the Update log section and append
    if "## Update log" not in text:
        print(f"NO UPDATE LOG: {f.name}")
        continue
    
    # Build the sign-off entry by extracting the first sentence from the Status line block
    # The Status line starts with "- **Status:** **Accepted" and ends with "See \"Update log\""
    status_start = text.find("- **Status:** **Accepted")
    if status_start < 0:
        print(f"NO ACCEPTED STATUS: {f.name}")
        continue
    status_end = text.find('See "Update log"', status_start)
    if status_end < 0:
        print(f"NO UPDATE LOG REF: {f.name}")
        continue
    status_block = text[status_start:status_end].strip()
    # Remove the prefix and "See" tail
    status_body = re.sub(r"^- \*\*Status:\*\* \*\*Accepted \(revision 1, operator sign-off 2026-07-19\)\.\*\*\s*", "", status_block)
    # Capitalize the first letter
    if status_body:
        status_body = status_body[0].upper() + status_body[1:]
    
    signoff_entry = f"\n- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. {status_body}\n"
    
    # Insert after the original line in the Update log
    # The original line ends with " Status: Proposed." and has a long summary before
    new_text = re.sub(
        r"(- \*\*2026-07-19 \(original\)\*\*: Initial proposal\.[^\n]*?Status: Proposed\.)",
        rf"\1{signoff_entry}",
        text,
        count=1
    )
    
    if new_text == text:
        print(f"NO ORIGINAL MATCH: {f.name}")
        continue
    
    f.write_text(new_text)
    print(f"OK: {f.name}")
