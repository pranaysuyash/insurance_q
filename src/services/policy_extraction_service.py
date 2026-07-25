"""
Policy Extraction Service — single LLM call to extract structured policy data at ingestion time.

This replaces the mobile app's approach of sending 13 sequential questions to the backend.
Instead, the backend extracts all fields in one structured LLM call and stores the result.
The mobile app fetches the summary via a single API call.

Persistence: production summaries are stored in the canonical Supabase
`document_policy_summaries` table. Development may use Redis or a local file
compatibility adapter.
"""
import json
import logging
import os
from datetime import datetime, timezone
from typing import Optional, Dict, Any

from src.llm.client import LLMClient
from src.models.extraction import PolicySummaryExtraction
from src.security.prompt_injection import fence_untrusted_content
from src.utils.runtime_config import supabase_server_key

logger = logging.getLogger(__name__)

_SUMMARY_DIR = os.path.join("storage", "summaries")


class PolicyExtractionService:
    """Extract structured policy data from OCR text in a single LLM call."""

    def __init__(self, llm_client: LLMClient, redis_client=None):
        self.llm = llm_client
        self._redis = redis_client
        self._supabase = None
        if os.getenv("ENVIRONMENT", "development").lower() == "production":
            url = os.getenv("SUPABASE_URL", "").strip()
            key = supabase_server_key()
            if not url or not key:
                raise RuntimeError("Supabase policy-summary storage is required in production")
                from src.utils.supabase_client import create_client
            self._supabase = create_client(url, key)
        else:
            os.makedirs(_SUMMARY_DIR, exist_ok=True)

    def _redis_key(self, document_id: str) -> str:
        return f"policy_summary:{document_id}"

    def _store_summary(self, document_id: str, summary: Dict[str, Any]) -> None:
        """Persist summary to the canonical production or local adapter."""
        serialized = json.dumps(summary, default=str)
        if self._supabase is not None:
            response = self._supabase.table("document_policy_summaries").upsert({
                "document_id": document_id,
                "summary": summary,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            }, on_conflict="document_id").execute()
            if not response.data:
                raise RuntimeError("policy summary was not persisted")
            return
        if self._redis:
            try:
                self._redis.set(self._redis_key(document_id), serialized)
                return
            except Exception as e:
                logger.warning("Redis write failed for summary %s: %s", document_id, e)
        # Disk fallback
        try:
            path = os.path.join(_SUMMARY_DIR, f"{document_id}.json")
            with open(path, "w") as f:
                f.write(serialized)
        except Exception as e:
            logger.warning("Disk write failed for summary %s: %s", document_id, e)

    def _load_summary(self, document_id: str) -> Optional[Dict[str, Any]]:
        """Load summary from the canonical production or local adapter."""
        if self._supabase is not None:
            response = (self._supabase.table("document_policy_summaries")
                        .select("summary").eq("document_id", document_id)
                        .limit(1).execute())
            return response.data[0]["summary"] if response.data else None
        if self._redis:
            try:
                raw = self._redis.get(self._redis_key(document_id))
                if raw:
                    return json.loads(raw)
            except Exception as e:
                logger.warning("Redis read failed for summary %s: %s", document_id, e)
        # Disk fallback
        try:
            path = os.path.join(_SUMMARY_DIR, f"{document_id}.json")
            if os.path.exists(path):
                with open(path, "r") as f:
                    return json.loads(f.read())
        except Exception as e:
            logger.warning("Disk read failed for summary %s: %s", document_id, e)
        return None

    def _delete_summary(self, document_id: str) -> None:
        """Delete summary from both stores."""
        if self._supabase is not None:
            self._supabase.table("document_policy_summaries").delete().eq(
                "document_id", document_id
            ).execute()
            return
        if self._redis:
            try:
                self._redis.delete(self._redis_key(document_id))
            except Exception:
                pass
        try:
            path = os.path.join(_SUMMARY_DIR, f"{document_id}.json")
            if os.path.exists(path):
                os.remove(path)
        except Exception:
            pass

    async def extract_summary(
        self,
        document_id: str,
        document_text: str,
        document_type: str = "Unknown",
    ) -> Optional[Dict[str, Any]]:
        """Extract structured policy summary from document text.

        Args:
            document_id: Unique document identifier
            document_text: Full text extracted from the document (OCR output)
            document_type: Inferred document type (health, auto, life, etc.)

        Returns:
            Dict matching PolicySummaryExtraction schema, or None on failure.
        """
        if not document_text or len(document_text.strip()) < 50:
            logger.warning("Insufficient text for extraction: %s", document_id)
            return None

        # Return cached result if already extracted
        cached = self._load_summary(document_id)
        if cached:
            logger.info("Returning cached summary for %s", document_id)
            return cached

        # Truncate to avoid excessive token usage — 8000 chars is ~2000 tokens
        truncated_text = document_text[:8000]

        system_prompt = (
            "You are an expert insurance document analyst. Extract all key policy "
            "information from the provided document text. Be precise and only include "
            "information that is explicitly stated in the text. If a field is not found, "
            "use null. For amounts, provide numeric values (e.g., 2500000 for ₹25 lakhs). "
            "For dates, use ISO format (YYYY-MM-DD) if possible. For lists, provide up to "
            "5 items as brief one-line descriptions."
        )

        base_fields = (
            "- policy_number: The policy number or ID\n"
            "- insurer: Insurance company name\n"
            "- insurer_helpline: Claims/customer care phone number\n"
            "- insurer_email: Customer care email\n"
            "- document_type: Type of insurance (health, auto, life, home, travel, other)\n"
            "- coverage_amount: Total sum insured (numeric, in rupees)\n"
            "- deductible: Deductible amount (numeric, or null if not applicable)\n"
            "- premium_amount: Premium amount (numeric, in rupees)\n"
            "- premium_frequency: How often premium is paid (monthly, quarterly, half-yearly, annually)\n"
            "- effective_date: Policy start date\n"
            "- expiration_date: Policy end/expiry date\n"
            "- key_benefits: List of top 5 covered benefits (brief, one per line)\n"
            "- exclusions: List of top 5 exclusions/things not covered (brief)\n"
            "- waiting_periods: List of any waiting periods mentioned\n"
            "- coverage_items: Individual coverage line items with name, limit, covered status\n"
            "- executive_summary: 3 bullets in plain language — (1) what this policy covers, (2) the key limit or restriction, (3) what to watch for (renewal, waiting period, gap). Use simple words, no jargon."
        )

        # Type-specific fields — added to the prompt based on document type
        type_specific_fields = ""
        doc_type_lower = (document_type or "").lower()
        if any(kw in doc_type_lower for kw in ("auto", "motor", "car", "vehicle", "two wheeler", "bike")):
            type_specific_fields = (
                "\nFor this MOTOR/AUTO insurance policy, also extract these vehicle-specific fields:\n"
                "- vehicle_registration_number: Vehicle registration number (e.g., MH-01-AB-1234)\n"
                "- VIN: Vehicle Identification Number / Chassis number\n"
                "- engine_number: Engine number\n"
                "- NCB_percent: No Claim Bonus percentage as a number (e.g., 50.0 for 50%). null if not mentioned.\n"
                "- IDV: Insured Declared Value as a numeric amount in rupees\n"
                "- vehicle_make_model: Vehicle make and model (e.g., Maruti Suzuki Swift VXI)\n"
                "- vehicle_year: Vehicle manufacturing year (numeric, e.g., 2023)\n"
                "- add_on_covers: List of add-on covers selected (e.g., Zero Depreciation Cover, Engine Protector)\n"
                "- own_damage_premium: Own damage premium amount (numeric)\n"
                "- third_party_premium: Third-party premium amount (numeric)\n"
                "- policy_type_detail: Policy sub-type (e.g., 'Comprehensive', 'Third Party Only', 'Third Party Fire & Theft')\n"
                "- geographical_limit: Geographical coverage area (e.g., 'All India', 'Zone A', 'Within city')\n"
                "- personal_accident_cover_owner: Personal accident cover for owner-driver as a numeric amount in rupees. null if not mentioned.\n"
                "- cubic_capacity: Engine cubic capacity (e.g., '1197 cc', '998 cc')\n"
                "- seating_capacity: Vehicle seating capacity as a number (e.g., 5, 7). null if not mentioned.\n"
                "- garaging_pincode: Vehicle garaging pincode / area where vehicle is kept (e.g., '400001')\n"
                "- fuel_type: Vehicle fuel type (e.g., 'Petrol', 'Diesel', 'CNG', 'Electric', 'Hybrid')\n"
                "- voluntary_deductible: Voluntary deductible / excess chosen by the policyholder for lower premium (e.g., 'Nil', '₹1,000', '₹2,500'). null if not mentioned.\n"
                "- hypothecation: Hypothecation / lien holder bank or financier name (e.g., 'HDFC Bank', 'SBI Finance'). null if not mentioned or vehicle is not financed.\n"
            )
        elif any(kw in doc_type_lower for kw in ("life", "term", "ulip", "endowment", "pension", "annuity", "whole life")):
            type_specific_fields = (
                "\nFor this LIFE insurance policy, also extract these life-specific fields:\n"
                "- life_assured_name: Name of the life assured (primary person insured)\n"
                "- sum_assured: Sum assured / death benefit amount (numeric, in rupees)\n"
                "- policy_term_years: Policy term in years (numeric, e.g., 20)\n"
                "- premium_paying_term_years: Premium payment term in years (numeric, e.g., 10)\n"
                "- nominee_name: Name of the nominee / beneficiary\n"
                "- nominee_share: Nominee share percentage (e.g., '100%')\n"
                "- maturity_date: Policy maturity date\n"
                "- maturity_amount: Maturity benefit amount (numeric, in rupees)\n"
                "- accidental_death_benefit: Accidental death benefit amount (numeric, in rupees)\n"
                "- terminal_illness_benefit: Terminal illness benefit description\n"
                "- rider_details: List of riders attached (e.g., Critical Illness Rider, Waiver of Premium)\n"
                "- suicide_exclusion: Suicide exclusion period (e.g., 'First 12 months')\n"
                "- free_look_period: Free look period (e.g., '30 days')\n"
                "- grace_period: Grace period for premium payment (e.g., '30 days')\n"
                "- surrender_value: Surrender value information\n"
                "- death_benefit_type: Death benefit type (Level, Increasing, Decreasing)\n"
                "- policy_type_detail: Life policy sub-type (e.g., 'Term Life', 'ULIP', 'Endowment', 'Money Back', 'Whole Life', 'Pension/Annuity')\n"
            )
        elif any(kw in doc_type_lower for kw in ("home", "house", "property", "fire", "burglary", "tenant", "landlord", "building")):
            type_specific_fields = (
                "\nFor this HOME/PROPERTY insurance policy, also extract these property-specific fields:\n"
                "- property_address: Property address / insured premises location\n"
                "- building_sum_insured: Building / structure sum insured amount (numeric, in rupees)\n"
                "- contents_sum_insured: Contents / belongings sum insured amount (numeric, in rupees)\n"
                "- rebuild_cost: Rebuild cost / reinstatement value (numeric, in rupees)\n"
                "- perils_covered: List of perils covered (e.g., Fire, Flood, Earthquake, Burglary, Storm)\n"
                "- perils_excluded: List of perils explicitly excluded (e.g., War, Nuclear, Terror)\n"
                "- add_on_covers: List of additional add-on covers (e.g., Jewellery Cover, Domestic Help Cover)\n"
                "- deductible: Deductible / excess specific to this policy (numeric, in rupees)\n"
                "- structure_type: Structure type (e.g., Apartment, Independent House, Villa)\n"
                "- policy_type: Policy type (e.g., Standard Fire, Home Comprehensive, Tenant Insurance)\n"
                "- occupancy_type: Occupancy type (e.g., 'Owner occupied', 'Rented out', 'Tenanted', 'Vacant')\n"
                "- construction_type: Building construction type (e.g., 'RCC framed', 'Load bearing', 'Kutcha', 'Mixed')\n"
                "- underinsurance_clause: Underinsurance / average clause (e.g., 'Average clause applies — if sum insured < 85% of value, claim reduced proportionately')\n"
                "- year_built: Year the building was constructed (e.g., 2018). numeric. null if not mentioned.\n"
                "- escalation_clause: Escalation clause for automatic sum insured increase (e.g., '10% annual automatic increase in SI')\n"
            )

        elif any(kw in doc_type_lower for kw in ("health", "mediclaim", "medical", "hospital", "critical illness", "family floater", "wellness", "healthguard")):
            type_specific_fields = (
                "\nFor this HEALTH insurance policy, also extract these health-specific fields:\n"
                "- room_rent_cap: Room rent cap details (e.g., '2% of sum insured, max ₹5,000/day')\n"
                "- pre_existing_diseases: List of pre-existing disease exclusions and their waiting periods\n"
                "- co_pay_percent: Co-payment percentage as a number (e.g., 10.0 for 10% co-pay). null if not mentioned.\n"
                "- network_hospitals: Network hospital count or list (e.g., '12,000+ hospitals nationwide')\n"
                "- maternity_cover: Maternity cover details including waiting period (e.g., '₹50,000 after 9-month waiting')\n"
                "- deductible_per_claim: Deductible per claim amount (numeric, in rupees)\n"
                "- cumulative_bonus: Cumulative / No Claim Bonus details (e.g., '50% increase, max 100%')\n"
                "- day_care_procedures: Day care procedure coverage (e.g., '160+ day care procedures covered')\n"
                "- consumables_cover: Consumables / medical consumables cover (e.g., 'Up to ₹5,000 per claim')\n"
                "- ambulance_cover: Ambulance cover amount (numeric, in rupees)\n"
                "- health_checkup_cover: Health checkup cover details (e.g., 'Once every 3 years, up to ₹5,000')\n"
                "- pre_post_hospitalization_days: Pre and post hospitalization coverage (e.g., '30 days pre, 60 days post')\n"
                "- restoration_benefit: Restoration / recharge of sum insured (e.g., 'Full SI restored once per policy year after exhaustion')\n"
                "- critical_illness_list: List of covered critical illnesses (e.g., Cancer, Heart attack, Kidney failure, Stroke, Organ transplant)\n"
                "- modern_treatment_cover: Modern treatment coverage details (e.g., 'Robotic surgery, Uterine artery embolization, Balloon sinuplasty covered')\n"
                "- moratorium_period: Moratorium / no-contest period after which conditions cannot be contested (e.g., '5 years as per IRDAI 2026')\n"
                "- pre_auth_time_limit: Cashless pre-authorization approval time limit (e.g., '3 hours per IRDAI mandate')\n"
                "- domiciliary_hospitalization: Domiciliary / home hospitalization coverage (e.g., 'Covered, max 7 days at home, subject to policy limits')\n"
                "- sub_limits: List of sub-limits within the coverage (e.g., 'Room rent: 2% of SI', 'ICU: 4x room rent', 'Dental: ₹5,000')\n"
                "- no_claim_bonus_percent: NCB/Cumulative Bonus percentage increase as a number (e.g., 50.0 for 50% increase per claim-free year). null if not mentioned.\n"
            )
        elif any(kw in doc_type_lower for kw in ("travel", "overseas", "trip", "holiday", "tour")):
            type_specific_fields = (
                "\nFor this TRAVEL insurance policy, also extract these trip-specific fields:\n"
                "- traveller_name: Name of the primary traveller / policy holder\n"
                "- destination: Trip destination (country, city, or region)\n"
                "- trip_duration_days: Trip duration in days (numeric, e.g., 15)\n"
                "- trip_start_date: Trip start date\n"
                "- trip_end_date: Trip end date\n"
                "- trip_type: Single trip, Annual multi-trip, or Student travel\n"
                "- trip_cost_covered: Trip cancellation / interruption cover amount (numeric, in rupees)\n"
                "- medical_expenses_cover: Medical expenses cover amount (numeric)\n"
                "- medical_evacuation_cover: Medical evacuation / repatriation cover amount (numeric)\n"
                "- personal_accident_cover: Personal accident cover amount (numeric)\n"
                "- baggage_loss_cover: Baggage loss cover amount (numeric)\n"
                "- baggage_delay_cover: Baggage delay cover amount (numeric)\n"
                "- trip_cancellation_cover: Trip cancellation cover amount (numeric)\n"
                "- flight_delay_cover: Flight delay cover amount (numeric)\n"
                "- add_on_covers: List of add-on covers included (e.g., Passport Loss Assistance, Adventure Sports)\n"
                "- emergency_assistance_phone: 24x7 emergency assistance phone number\n"
                "- geographical_zone: Geographical coverage zone (e.g., 'Schengen', 'Worldwide excluding USA/Canada', 'Asia', 'India')\n"
                "- preexisting_condition_waiver: Pre-existing condition waiver for medical expenses abroad (e.g., 'Not covered', 'Covered with 30-day stable period')\n"
                "- adventure_sports_cover: Adventure sports coverage (e.g., 'Not covered', 'Covered up to ₹50,000', 'Covered for bungee, scuba, trekking')\n"
                "- hijack_cover: Hijack cover details (e.g., '₹15,000 per 24 hours, max 7 days')\n"
                "- passport_loss_cover: Passport loss cover details (e.g., 'USD 200 for emergency passport expenses')\n"
                "- deductible_per_claim_travel: Deductible per claim specific to this travel policy (numeric, in USD or INR). null if not mentioned.\n"
            )
        elif any(kw in doc_type_lower for kw in ("marine", "cargo", "hull", "freight", "maritime", "ship", "vessel", "ocean", "shipping")):
            type_specific_fields = (
                "\nFor this MARINE/CARGO insurance policy, also extract these marine-specific fields:\n"
                "- policy_type_marine: Marine policy sub-type (e.g., 'Marine Cargo', 'Hull', 'Freight', 'Marine Liability')\n"
                "- vessel_name: Name of the vessel (e.g., 'MV Ocean Queen'). null if by air or land.\n"
                "- voyage_details: Full voyage / transit route description (e.g., 'Mumbai to Singapore via Colombo')\n"
                "- cargo_description: Description of the insured cargo (e.g., 'Electronic components, 50 cartons')\n"
                "- cargo_value: Value of the insured cargo (e.g., 'USD 250,000 FOB'). include currency.\n"
                "- incoterms: International commercial terms (e.g., CIF, FOB, CFR, EXW). null if not mentioned.\n"
                "- institute_clauses: Institute Cargo Clauses version applied (e.g., 'Institute Cargo Clauses (A)', 'ICC (B)', 'ICC (C)'). null if not mentioned.\n"
                "- voyage_from: Port or location where transit starts (e.g., 'Mumbai Port, India')\n"
                "- voyage_to: Destination port or location (e.g., 'Singapore Port')\n"
                "- transit_start_date: Transit start date (ISO format preferred)\n"
                "- transit_end_date: Transit end date (ISO format preferred)\n"
                "- conveyance: Mode of transport (e.g., 'MV Ocean Queen', 'Air India AI-101', 'truck')\n"
                "- general_average_clause: General average clause reference (e.g., 'York Antwerp Rules 2016', 'Not mentioned'). null if not mentioned.\n"
                "- war_risk_clause: War risk coverage (e.g., 'Excluded per standard ICC clauses', 'Covered by Institute War Clauses'). null if not mentioned.\n"
                "- strikes_riots_clause: Strikes / riots / civil commotion coverage (e.g., 'Excluded per standard ICC clauses'). null if not mentioned.\n"
                "- warehouse_to_warehouse: Warehouse-to-warehouse clause (e.g., 'Covered, max 60 days at destination'). null if not mentioned.\n"
                "- marine_insurance_certificate_no: Marine insurance certificate number (e.g., 'MIC-2024-001234'). null if not mentioned.\n"
            )

        user_prompt = (
            f"Document type (inferred): {document_type}\n\n"
            f"Document text:\n{fence_untrusted_content('policy_document', truncated_text, max_chars=8000)}\n\n"
            f"Extract the following fields from this insurance document:\n"
            f"{base_fields}"
            f"{type_specific_fields}"
        )

        try:
            summary = await self.llm.generate_structured(
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                response_model=PolicySummaryExtraction,
                temperature=0.1,
                fallback_models=["gpt-4o-mini"],
            )

            if summary is None:
                logger.warning("LLM returned None for extraction: %s", document_id)
                return None

            # Convert to dict and add metadata
            result = summary.model_dump()
            result["document_id"] = document_id
            result["extracted_at"] = datetime.now(timezone.utc).isoformat()

            # Post-processing validation: validate and normalize extracted fields
            result = self._validate_summary(result)

            # Persist
            self._store_summary(document_id, result)

            logger.info("Policy summary extracted for %s: policy=%s, insurer=%s, coverage=%s",
                        document_id,
                        result.get("policy_number"),
                        result.get("insurer"),
                        result.get("coverage_amount"))
            return result

        except Exception as e:
            logger.error("Policy extraction failed for %s: %s", document_id, e)
            return None

    def get_summary(self, document_id: str) -> Optional[Dict[str, Any]]:
        """Get a previously extracted summary."""
        return self._load_summary(document_id)

    def delete_summary(self, document_id: str) -> None:
        """Delete a stored summary."""
        self._delete_summary(document_id)

    def get_all_summaries(self) -> Dict[str, Dict[str, Any]]:
        """Get all stored summaries."""
        summaries: Dict[str, Dict[str, Any]] = {}
        if self._supabase is not None:
            response = self._supabase.table("document_policy_summaries").select(
                "document_id,summary"
            ).execute()
            return {
                row["document_id"]: row["summary"]
                for row in (response.data or [])
            }
        # Load from disk
        try:
            for filename in os.listdir(_SUMMARY_DIR):
                if filename.endswith(".json"):
                    doc_id = filename[:-5]
                    summary = self._load_summary(doc_id)
                    if summary:
                        summaries[doc_id] = summary
        except Exception as e:
            logger.warning("Failed to list summaries from disk: %s", e)
        # Overlay Redis keys (if available, Redis may have newer data)
        if self._redis:
            try:
                for key in self._redis.scan_iter("policy_summary:*"):
                    doc_id = key.split(":", 1)[1]
                    if doc_id not in summaries:
                        summary = self._load_summary(doc_id)
                        if summary:
                            summaries[doc_id] = summary
            except Exception as e:
                logger.warning("Failed to scan summaries from Redis: %s", e)
        return summaries

    def _validate_summary(self, summary: Dict[str, Any]) -> Dict[str, Any]:
        """Post-processing validation: validate and normalize extracted fields.

        Catches common LLM extraction errors before storing:
        - Invalid policy numbers (too short, special chars)
        - Non-ISO dates (parse with dateutil if available)
        - Negative or non-numeric amounts
        - Empty lists that should be defaults
        """
        import re as regex

        # Validate policy number — alphanumeric with slashes/dashes, 5-25 chars
        pn = summary.get("policy_number")
        if pn:
            pn = str(pn).strip()
            if not regex.match(r'^[A-Za-z0-9/\-]{5,25}$', pn):
                logger.warning("Invalid policy number rejected: %s", pn[:20])
                summary["policy_number"] = None
            else:
                summary["policy_number"] = pn

        # Validate dates — try to parse to ISO format
        for date_field in ["effective_date", "expiration_date"]:
            val = summary.get(date_field)
            if val:
                val = str(val).strip()
                # Check if already ISO
                if regex.match(r'^\d{4}-\d{2}-\d{2}', val):
                    continue
                # Try parsing with dateutil
                try:
                    from dateutil import parser as date_parser
                    parsed = date_parser.parse(val)
                    summary[date_field] = parsed.strftime("%Y-%m-%d")
                except Exception:
                    logger.warning("Invalid %s rejected: %s", date_field, val[:30])
                    summary[date_field] = None

        # Validate amounts — must be positive numeric
        for amt_field in ["coverage_amount", "premium_amount", "deductible"]:
            val = summary.get(amt_field)
            if val is not None:
                try:
                    num_val = float(val)
                    if num_val < 0 or num_val > 100000000:  # Sanity check: max 100 Cr
                        logger.warning("Invalid %s rejected: %s", amt_field, val)
                        summary[amt_field] = None
                    else:
                        summary[amt_field] = num_val
                except (ValueError, TypeError):
                    logger.warning("Non-numeric %s rejected: %s", amt_field, val)
                    summary[amt_field] = None

        # Ensure lists are lists
        for list_field in ["key_benefits", "exclusions", "waiting_periods", "coverage_items"]:
            val = summary.get(list_field)
            if val is None:
                summary[list_field] = []
            elif not isinstance(val, list):
                summary[list_field] = [str(val)]

        return summary
