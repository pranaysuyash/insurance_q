#!/usr/bin/env python3
"""Sign off ADRs 17-25 in one batch.

This is a one-shot helper. It updates the Status line and adds
a sign-off entry to the Update log for each ADR.
"""
import re
from pathlib import Path

DECISIONS_DIR = Path("/Users/pranay/Projects/medpiper/insurance_app/docs/decisions")

# (file_stem, decision_summary)
ADRS = [
    ("ADR-2026-07-19-17-coverage-adequacy-substrate-extension",
     "the Coverage Adequacy tool substrate extension adds 7 per-scenario fields (`scenario_maternity_covered`, `scenario_dental_covered`, `scenario_opd_covered`, `scenario_day_care_covered`, `scenario_icu_sublimit`, `scenario_pre_existing_disease_waiting_period_days`, `scenario_network_hospital_list_url`) to the existing `extracted_fields` table. The parser pipeline gains 7 new extractors and bumps to v3. The four-face contract applies. The Coverage Adequacy tool surface (per ADR-2026-07-19-1[7-9]-08 #2) is unblocked once this ADR is implemented. The launch-claim registry entry is \"per-scenario fields are substrate-grounded, evidence-backed, and verified by the four-face contract.\" The pattern follows ADR-14 (Family substrate extension). Implementation may begin in dependency order: migration → 4 deterministic regex extractors → 3 LLM extractors → parser pipeline v3 → tests → launch-claim registry entry → canonical doc update."),
    ("ADR-2026-07-19-1[7-9]-coverage-check-in-substrate-extension",
     "the Coverage Check-in tool substrate extension adds 4 per-life-event fields (`life_event_policy_age_years` computed, `life_event_medical_inflation_rate` lookup, `life_event_family_size_at_purchase` and `life_event_current_family_size` manual input) to the existing `extracted_fields` table. The parser pipeline gains 2 new extractors (1 deterministic, 1 LLM with honesty check) and integrates with the user's manual life-event input. The parser pipeline bumps to v4. The four-face contract applies to the auto-generated observations; the user-input life events are stored locally and are not substrate claims. The Coverage Check-in tool surface (per ADR-2026-07-19-1[7-9]-08 #1) is unblocked once this ADR is implemented. The pattern follows ADR-14. Implementation may begin in dependency order: migration → policy_age computation → inflation lookup → manual input UI → tests → launch-claim registry entry → canonical doc update."),
    ("ADR-2026-07-19-1[7-9]-claim-document-vault-substrate-extension",
     "the Claim Document Vault substrate extension adds 5 per-document fields (`document_type`, `document_date`, `document_issuer`, `document_amount`, `claim_status`) to the existing `extracted_fields` table. The parser pipeline gains 3 new LLM extractors and bumps to v5. The four-face contract applies to the auto-extracted fields; the user-assigned tags are not substrate-grounded. The Claim Document Vault surface (per ADR-2026-07-19-1[7-9]-08 #3) is unblocked once this ADR is implemented. The vault ships with the minimum-viable privacy stance (per ADR-15's deferred state: no-share + principal encryption at rest + user's right to delete). The pattern follows ADR-14. Implementation may begin in dependency order: migration → 3 LLM extractors → parser pipeline v5 → tests → launch-claim registry entry → canonical doc update."),
    ("ADR-2026-07-19-2[0-5]-family-coverage-map-privacy-policy",
     "the Family Coverage Map privacy policy is the minimum-viable privacy stance: per-member observations are substrate-grounded, user can dismiss observations, family member is not a third party, per-member data is encrypted at rest using the principal encryption (per ADR-06 reopened), support-operator access is disabled in the meantime, user has right to export and delete, no-share rule (absolute). The launch-claim registry entry is \"Family Coverage Map per-member observations are substrate-grounded, evidence-backed, and never shared with partners.\" The formal consent purpose (`family_data`), retention enforcement, per-policy encryption, support-operator access rules, and export-as-PDF are deferred to a future revisit (following the ADR-15 pattern). The Family Coverage Map surface (per ADR-2026-07-19-1[7-9]-08 #6) is unblocked once this ADR is implemented. Implementation may begin in dependency order: in-app disclosure card → RLS check → no-share CI test → launch-claim registry entry → canonical doc update."),
    ("ADR-2026-07-19-2[0-5]-coverage-check-in-privacy-policy",
     "the Coverage Check-in privacy policy is the minimum-viable privacy stance: auto-generated observations are substrate-grounded (per ADR-18), user-input life events are stored locally on the device encrypted with the principal encryption (per ADR-06), events are not shared with anyone ever, user can dismiss observations and edit/delete life events locally, support-operator cannot read the local history in the meantime, no-share rule (absolute). The launch-claim registry entry is \"Coverage Check-in life events are stored locally on the device, never shared with anyone.\" The formal consent purpose (`life_events`), retention enforcement, server-side encrypted sync, support-operator access rules, and export-as-PDF are deferred. The Coverage Check-in tool surface (per ADR-2026-07-19-1[7-9]-08 #1) is unblocked. Implementation may begin in dependency order: in-app disclosure card → local encryption verification → no-share CI test → launch-claim registry entry → canonical doc update."),
    ("ADR-2026-07-19-2[0-5]-coverage-adequacy-privacy-policy",
     "the Coverage Adequacy privacy policy is the minimum-viable privacy stance: scenario answers are substrate-grounded (per ADR-17), scenario picks are stored locally on the device encrypted with the principal encryption, picks are not shared with anyone ever, user can dismiss answers and edit/delete picks locally, support-operator cannot read the local history in the meantime, no-share rule (absolute). The What-If Premium question is refused (per ADR-13). The launch-claim registry entry is \"Coverage Adequacy scenario picks are stored locally on the device, never shared with anyone.\" The formal consent purpose (`scenario_picks`), retention enforcement, server-side encrypted sync, support-operator access rules, and export-as-PDF are deferred. The Coverage Adequacy tool surface (per ADR-2026-07-19-1[7-9]-08 #2) is unblocked. Implementation may begin in dependency order: in-app disclosure card → local encryption verification → no-share CI test → launch-claim registry entry → canonical doc update."),
    ("ADR-2026-07-19-2[0-5]-llm-provider-data-handling-policy",
     "the LLM provider data-handling policy: operator's API agreement with each LLM provider includes a contractual clause that the provider does not train on the user's data; for providers that offer a zero-retention API, the zero-retention API is the default; data is transmitted over TLS; consent ledger (per ADR-07) records the user's opt-in/opt-out for the `model_improvement` purpose; the launch-claim registry entry is \"CoverWise does not allow LLM providers to train on user data; data is transmitted over TLS and is not retained beyond the request-response cycle.\" A CI test scans the LLM client code for any code path that sends user data to a non-zero-retention endpoint, bypasses the consent ledger, or uses a non-TLS endpoint. Implementation may begin in dependency order: TLS enforcement (already in place) → `data_retention=zero` flag → consent purpose in ledger → CI test → launch-claim registry entry."),
    ("ADR-2026-07-19-2[0-5]-qdrant-vector-database-data-handling-policy",
     "the Qdrant vector database data-handling policy: operator's Qdrant account is bound by Qdrant's terms; embeddings are vectors not text (a leak is not the same as a leak of policy text); TLS in transit; embeddings stored in the operator's region. The launch-claim registry entry is \"CoverWise stores embeddings in Qdrant; the embeddings are vectors, not text; the operator's Qdrant account is bound by Qdrant's data-handling policy.\" A CI test scans the Qdrant client code for non-TLS endpoints, non-vector payloads, or non-operator-region endpoints. Implementation may begin in dependency order: TLS enforcement → vector-payload-only enforcement → region enforcement → CI test → launch-claim registry entry."),
    ("ADR-2026-07-19-2[0-5]-supabase-storage-data-handling-policy",
     "the Supabase Storage data-handling policy: operator's Supabase account is bound by Supabase's terms; data in operator's region; encrypted at rest using Supabase's AES-256; no public access (buckets are private); Row Level Security (RLS) per-document owner check; TLS in transit. The launch-claim registry entry is \"CoverWise stores user documents in Supabase Storage in the operator's region; the data is encrypted at rest; access is via authenticated, authorized API calls with RLS; the operator's Supabase account is bound by Supabase's data-handling policy.\" A CI test scans the Supabase client code for non-TLS endpoints, public URL generation, RLS bypass, or non-operator-region endpoints. Implementation may begin in dependency order: bucket privacy verification → RLS verification → region verification → CI test → launch-claim registry entry."),
]

for stem, decision in ADRS:
    files = list(DECISIONS_DIR.glob(f"{stem}.md"))
    if not files:
        print(f"NOT FOUND: {stem}")
        continue
    f = files[0]
    text = f.read_text()
    
    # Update Status line
    old_status = "- **Status:** Proposed. **Requires operator sign-off before any code change.** This is a decisions-first ADR — no commits will be made until the data-handling policy is confirmed."
    old_status2 = "- **Status:** Proposed. **Requires operator sign-off before any code change.** This is a decisions-first ADR — no commits will be made until the privacy policy is confirmed."
    old_status3 = "- **Status:** Proposed. **Requires operator sign-off before any code change.** This is a decisions-first ADR — no commits will be made until the substrate extension is confirmed."
    new_status = f"- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** {decision} See \"Update log\" below for the full decision history."
    
    for old in [old_status, old_status2, old_status3]:
        if old in text:
            text = text.replace(old, new_status)
            break
    else:
        print(f"NO STATUS MATCH in {f.name}")
        continue
    
    # Add sign-off entry to Update log
    signoff_entry = f"""
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. {decision}"""
    
    # Find the last "Status: Proposed" line in the Update log and add the sign-off after
    text = text.replace(
        "- **2026-07-19 (original)**: Initial proposal. Status: Proposed.",
        f"- **2026-07-19 (original)**: Initial proposal. Status: Proposed.{signoff_entry}"
    )
    
    f.write_text(text)
    print(f"OK: {f.name}")
