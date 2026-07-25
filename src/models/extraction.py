from pydantic import BaseModel, Field
from typing import Optional, List


class CoverageItem(BaseModel):
    name: str = Field(..., description="Name of the coverage item or benefit")
    limit: Optional[float] = Field(None, description="Numeric limit amount, if applicable")
    limit_text: Optional[str] = Field(None, description="Human-readable limit description (e.g., 'Up to sum insured')")
    covered: bool = Field(True, description="Whether this item is covered")
    notes: Optional[str] = Field(None, description="Additional notes or conditions")


class PolicySummaryExtraction(BaseModel):
    """Structured extraction of key policy fields from an insurance document.
    
    Extracted via a single LLM call at ingestion time. Stored alongside the document
    and returned via the /documents/{id}/summary API endpoint.
    """
    policy_number: Optional[str] = Field(None, description="Insurance policy number or ID")
    insurer: Optional[str] = Field(None, description="Insurance company/provider name")
    insurer_helpline: Optional[str] = Field(None, description="Claims helpline or customer care phone number")
    insurer_email: Optional[str] = Field(None, description="Customer care email address")
    document_type: Optional[str] = Field(None, description="Type of insurance (health, auto, life, home, travel, other)")
    coverage_amount: Optional[float] = Field(None, description="Total coverage amount or sum insured (numeric)")
    deductible: Optional[float] = Field(None, description="Deductible amount (numeric), if applicable")
    premium_amount: Optional[float] = Field(None, description="Premium amount (numeric)")
    premium_frequency: Optional[str] = Field(None, description="Premium payment frequency (monthly, quarterly, half-yearly, annually)")
    effective_date: Optional[str] = Field(None, description="Policy effective start date (ISO format preferred)")
    expiration_date: Optional[str] = Field(None, description="Policy expiration or renewal date (ISO format preferred)")
    key_benefits: List[str] = Field(default_factory=list, description="Top 5 key benefits covered by this policy")
    exclusions: List[str] = Field(default_factory=list, description="Top 5 exclusions or things not covered")
    waiting_periods: List[str] = Field(default_factory=list, description="Any waiting periods mentioned")
    coverage_items: List[CoverageItem] = Field(default_factory=list, description="Individual coverage line items with limits")
    executive_summary: List[str] = Field(default_factory=list, description="3-bullet plain-language summary: what's covered, key limits, what to watch")


class LifePolicyDetails(BaseModel):
    """Type-specific fields for life insurance policies.

    These are extracted alongside the generic PolicySummaryExtraction fields
    when the document type is identified as life.
    """
    life_assured_name: Optional[str] = Field(None, description="Name of the life assured (primary insured person)")
    sum_assured: Optional[float] = Field(None, description="Sum assured / death benefit amount (numeric, in rupees)")
    policy_term_years: Optional[int] = Field(None, description="Policy term in years (e.g., 20)")
    premium_paying_term_years: Optional[int] = Field(None, description="Premium payment term in years (e.g., 10)")
    nominee_name: Optional[str] = Field(None, description="Nominee name")
    nominee_share: Optional[str] = Field(None, description="Nominee share percentage (e.g., '100%')")
    maturity_date: Optional[str] = Field(None, description="Policy maturity date (ISO format preferred)")
    maturity_amount: Optional[float] = Field(None, description="Maturity benefit amount (numeric, in rupees)")
    accidental_death_benefit: Optional[float] = Field(None, description="Accidental death benefit amount (numeric, in rupees)")
    terminal_illness_benefit: Optional[str] = Field(None, description="Terminal illness benefit description (e.g., 'Advance payout of 50%')")
    rider_details: List[str] = Field(default_factory=list, description="List of riders attached (e.g., Critical Illness Rider, Waiver of Premium)")
    suicide_exclusion: Optional[str] = Field(None, description="Suicide exclusion period (e.g., 'First 12 months')")
    free_look_period: Optional[str] = Field(None, description="Free look period (e.g., '30 days')")
    grace_period: Optional[str] = Field(None, description="Grace period for premium payment")
    surrender_value: Optional[str] = Field(None, description="Surrender value information")
    death_benefit_type: Optional[str] = Field(None, description="Death benefit type (Level, Increasing, Decreasing)")
    policy_type_detail: Optional[str] = Field(None, description="Life policy sub-type (e.g., Term Life, ULIP, Endowment, Money Back, Whole Life, Pension/Annuity)")


class TravelPolicyDetails(BaseModel):
    """Type-specific fields for travel insurance policies.

    These are extracted alongside the generic PolicySummaryExtraction fields
    when the document type is identified as travel.
    """
    traveller_name: Optional[str] = Field(None, description="Name of the primary traveller/policy holder")
    destination: Optional[str] = Field(None, description="Trip destination country/city (e.g., Thailand, Bangkok)")
    trip_duration_days: Optional[int] = Field(None, description="Trip duration in days (e.g., 15)")
    trip_start_date: Optional[str] = Field(None, description="Trip start date (ISO format preferred)")
    trip_end_date: Optional[str] = Field(None, description="Trip end date (ISO format preferred)")
    trip_type: Optional[str] = Field(None, description="Single trip, Annual multi-trip, or Student travel")
    trip_cost_covered: Optional[float] = Field(None, description="Trip cancellation/interruption cover amount (numeric, in rupees)")
    medical_expenses_cover: Optional[float] = Field(None, description="Medical expenses cover amount (numeric, in USD or rupees)")
    medical_evacuation_cover: Optional[float] = Field(None, description="Medical evacuation/repatriation cover amount")
    personal_accident_cover: Optional[float] = Field(None, description="Personal accident cover amount")
    baggage_loss_cover: Optional[float] = Field(None, description="Baggage loss cover amount")
    baggage_delay_cover: Optional[float] = Field(None, description="Baggage delay cover amount")
    trip_cancellation_cover: Optional[float] = Field(None, description="Trip cancellation cover amount")
    flight_delay_cover: Optional[float] = Field(None, description="Flight delay cover amount")
    add_on_covers: List[str] = Field(default_factory=list, description="Additional add-on covers (e.g., Passport Loss, Adventure Sports)")
    emergency_assistance_phone: Optional[str] = Field(None, description="24x7 emergency assistance phone number")
    geographical_zone: Optional[str] = Field(None, description="Geographical coverage zone (e.g., Schengen, Worldwide excluding USA/Canada, Asia, India)")
    preexisting_condition_waiver: Optional[str] = Field(None, description="Pre-existing condition waiver for medical expenses abroad (e.g., 'Not covered', 'Covered with 30-day stable period')")
    adventure_sports_cover: Optional[str] = Field(None, description="Adventure sports coverage (e.g., 'Not covered', 'Covered up to ₹50,000', 'Covered for bungee, scuba, trekking')")
    hijack_cover: Optional[str] = Field(None, description="Hijack cover details (e.g., '₹15,000 per 24 hours, max 7 days')")
    passport_loss_cover: Optional[str] = Field(None, description="Passport loss cover details (e.g., 'USD 200 for emergency passport expenses')")
    deductible_per_claim_travel: Optional[float] = Field(None, description="Deductible per claim for travel insurance (numeric, in USD or INR)")


class MotorPolicyDetails(BaseModel):
    """Type-specific fields for motor/auto insurance policies.

    These are extracted alongside the generic PolicySummaryExtraction fields
    when the document type is identified as auto/motor.
    """
    vehicle_registration_number: Optional[str] = Field(None, description="Vehicle registration number (e.g., MH-01-AB-1234)")
    VIN: Optional[str] = Field(None, description="Vehicle Identification Number / Chassis number")
    engine_number: Optional[str] = Field(None, description="Engine number")
    NCB_percent: Optional[float] = Field(None, description="No Claim Bonus percentage (e.g., 50.0 for 50%)")
    IDV: Optional[float] = Field(None, description="Insured Declared Value (numeric, in rupees)")
    vehicle_make_model: Optional[str] = Field(None, description="Vehicle make and model (e.g., Maruti Suzuki Swift VXI)")
    vehicle_year: Optional[int] = Field(None, description="Vehicle manufacturing year")
    add_on_covers: List[str] = Field(default_factory=list, description="Additional add-on covers selected (e.g., Zero Dep, Engine Protect)")
    own_damage_premium: Optional[float] = Field(None, description="Own damage premium amount")
    third_party_premium: Optional[float] = Field(None, description="Third-party premium amount")
    policy_type_detail: Optional[str] = Field(None, description="Policy sub-type (e.g., Comprehensive, Third Party Only, Third Party Fire & Theft)")
    geographical_limit: Optional[str] = Field(None, description="Geographical coverage area (e.g., All India, Zone A, Within city)")
    personal_accident_cover_owner: Optional[float] = Field(None, description="Personal accident cover amount for owner-driver (numeric, in rupees)")
    cubic_capacity: Optional[str] = Field(None, description="Engine cubic capacity (e.g., 1197 cc, 998 cc)")
    seating_capacity: Optional[int] = Field(None, description="Vehicle seating capacity (e.g., 5, 7)")
    garaging_pincode: Optional[str] = Field(None, description="Vehicle garaging pincode / area where vehicle is kept (e.g., '400001')")
    fuel_type: Optional[str] = Field(None, description="Vehicle fuel type (e.g., 'Petrol', 'Diesel', 'CNG', 'Electric', 'Hybrid')")
    voluntary_deductible: Optional[str] = Field(None, description="Voluntary deductible / excess chosen by policyholder (e.g., 'Nil', '₹1,000', '₹2,500')")
    hypothecation: Optional[str] = Field(None, description="Hypothecation / lien holder bank or financier name (e.g., 'HDFC Bank', 'SBI')")


class HomePolicyDetails(BaseModel):
    """Type-specific fields for home / property insurance policies.

    These are extracted alongside the generic PolicySummaryExtraction fields
    when the document type is identified as home.
    """
    property_address: Optional[str] = Field(None, description="Property address / insured premises location")
    building_sum_insured: Optional[float] = Field(None, description="Building / structure sum insured amount (numeric, in rupees)")
    contents_sum_insured: Optional[float] = Field(None, description="Contents / belongings sum insured amount (numeric, in rupees)")
    rebuild_cost: Optional[float] = Field(None, description="Rebuild cost / reinstatement value (numeric, in rupees)")
    perils_covered: List[str] = Field(default_factory=list, description="Perils covered (e.g., Fire, Flood, Earthquake, Burglary, Storm, Landslide)")
    perils_excluded: List[str] = Field(default_factory=list, description="Perils explicitly excluded (e.g., War, Nuclear risk, Terror)")
    add_on_covers: List[str] = Field(default_factory=list, description="Additional add-on covers (e.g., Jewellery Cover, Domestic Help Cover, Pedal Cycle Cover)")
    deductible: Optional[float] = Field(None, description="Deductible / excess amount specific to this policy (numeric, in rupees)")
    structure_type: Optional[str] = Field(None, description="Structure type (e.g., Apartment, Independent House, Duplex, Villa)")
    policy_type: Optional[str] = Field(None, description="Policy type (e.g., Standard Fire, Home Comprehensive, Tenant Insurance, Landlord Insurance)")
    occupancy_type: Optional[str] = Field(None, description="Occupancy type (e.g., Owner occupied, Rented out, Tenanted, Vacant)")
    construction_type: Optional[str] = Field(None, description="Building construction type (e.g., RCC framed, Load bearing, Kutcha, Mixed)")
    underinsurance_clause: Optional[str] = Field(None, description="Underinsurance / average clause (e.g., 'Average clause — if underinsured, claim reduced proportionately')")
    year_built: Optional[int] = Field(None, description="Year the building was constructed (e.g., 2018)")
    escalation_clause: Optional[str] = Field(None, description="Escalation clause for automatic sum insured increase (e.g., '10% annual automatic increase in SI')")


class HealthPolicyDetails(BaseModel):
    """Type-specific fields for health insurance policies.

    These are extracted alongside the generic PolicySummaryExtraction fields
    when the document type is identified as health.
    """
    room_rent_cap: Optional[str] = Field(None, description="Room rent cap details (e.g., '2% of sum insured, max ₹5,000/day')")
    pre_existing_diseases: List[str] = Field(default_factory=list, description="List of pre-existing disease exclusions and their waiting periods")
    co_pay_percent: Optional[float] = Field(None, description="Co-payment percentage (e.g., 10.0 for 10% co-pay)")
    network_hospitals: Optional[str] = Field(None, description="Network hospital count or list (e.g., '12,000+ hospitals nationwide')")
    maternity_cover: Optional[str] = Field(None, description="Maternity cover details including waiting period (e.g., '₹50,000 after 9-month waiting period')")
    deductible_per_claim: Optional[float] = Field(None, description="Deductible per claim amount (numeric, in rupees)")
    cumulative_bonus: Optional[str] = Field(None, description="Cumulative / No Claim Bonus details (e.g., '50% increase, max 100%')")
    day_care_procedures: Optional[str] = Field(None, description="Day care procedure coverage (e.g., '160+ day care procedures covered')")
    consumables_cover: Optional[str] = Field(None, description="Consumables / medical consumables cover (e.g., 'Up to ₹5,000 per claim')")
    ambulance_cover: Optional[float] = Field(None, description="Ambulance cover amount (numeric, in rupees)")
    health_checkup_cover: Optional[str] = Field(None, description="Health checkup cover details (e.g., 'Once every 3 years, up to ₹5,000')")
    pre_post_hospitalization_days: Optional[str] = Field(None, description="Pre and post hospitalization coverage days (e.g., '30 days pre, 60 days post')")
    restoration_benefit: Optional[str] = Field(None, description="Restoration / recharge of sum insured after exhaustion (e.g., 'Full SI restored once per year')")
    critical_illness_list: List[str] = Field(default_factory=list, description="List of covered critical illnesses (e.g., Cancer, Heart attack, Kidney failure)")
    modern_treatment_cover: Optional[str] = Field(None, description="Modern treatment coverage (e.g., 'Robotic surgery, Uterine artery embolization covered')")
    moratorium_period: Optional[str] = Field(None, description="Moratorium / no-contest period (e.g., '5 years per IRDAI 2026 guidelines')")
    pre_auth_time_limit: Optional[str] = Field(None, description="Pre-authorization/cashless approval time limit (e.g., '3 hours per IRDAI mandate')")
    domiciliary_hospitalization: Optional[str] = Field(None, description="Domiciliary / home hospitalization coverage (e.g., 'Covered, max 7 days, subject to policy limits')")
    sub_limits: List[str] = Field(default_factory=list, description="List of sub-limits within the coverage (e.g., 'Room rent: 2% of SI', 'ICU: 4x room rent', 'Dental: ₹5,000')")
    no_claim_bonus_percent: Optional[float] = Field(None, description="No Claim Bonus / Cumulative Bonus percentage increase (e.g., 50.0 for 50% increase per claim-free year)")


class MarinePolicyDetails(BaseModel):
    """Type-specific fields for marine / cargo insurance policies.

    These are extracted alongside the generic PolicySummaryExtraction fields
    when the document type is identified as marine.
    """
    policy_type_marine: Optional[str] = Field(None, description="Marine policy sub-type (e.g., 'Marine Cargo', 'Hull', 'Freight', 'Marine Liability')")
    vessel_name: Optional[str] = Field(None, description="Name of the vessel carrying the cargo (e.g., 'MV Ocean Queen')")
    voyage_details: Optional[str] = Field(None, description="Full voyage / transit route description (e.g., 'Mumbai to Singapore via Colombo')")
    cargo_description: Optional[str] = Field(None, description="Description of the insured cargo (e.g., 'Electronic components, 50 cartons')")
    cargo_value: Optional[str] = Field(None, description="Value of the insured cargo including currency (e.g., 'USD 250,000 FOB')")
    incoterms: Optional[str] = Field(None, description="International commercial terms / INCO terms (e.g., CIF, FOB, CFR, EXW)")
    institute_clauses: Optional[str] = Field(None, description="Institute Cargo Clauses version (e.g., 'Institute Cargo Clauses (A)', 'ICC (B)', 'ICC (C)')")
    voyage_from: Optional[str] = Field(None, description="Port or location where the voyage/transit starts (e.g., 'Mumbai Port, India')")
    voyage_to: Optional[str] = Field(None, description="Destination port or location (e.g., 'Singapore Port')")
    transit_start_date: Optional[str] = Field(None, description="Voyage / transit start date (ISO format preferred)")
    transit_end_date: Optional[str] = Field(None, description="Voyage / transit end date (ISO format preferred)")
    conveyance: Optional[str] = Field(None, description="Mode of transport / conveyance (e.g., 'MV Ocean Queen', 'Air India AI-101', 'truck')")
    general_average_clause: Optional[str] = Field(None, description="General average clause reference (e.g., 'York Antwerp Rules 2016', 'Not mentioned')")
    war_risk_clause: Optional[str] = Field(None, description="War risk coverage or exclusion (e.g., 'Excluded per standard ICC clauses', 'Covered by Institute War Clauses')")
    strikes_riots_clause: Optional[str] = Field(None, description="Strikes/riots/civil commotion coverage (e.g., 'Excluded per standard ICC clauses', 'Covered by Institute Strikes Clauses')")
    warehouse_to_warehouse: Optional[str] = Field(None, description="Warehouse-to-warehouse coverage clause (e.g., 'Covered, max 60 days at destination', 'Not mentioned')")
    marine_insurance_certificate_no: Optional[str] = Field(None, description="Marine insurance certificate number (e.g., 'MIC-2024-001234')")


class InsuranceDocumentExtraction(BaseModel):
    """Legacy extraction model used by the OCR pipeline for page-level field extraction."""
    policy_number: Optional[str] = Field(None, description="Insurance policy number")
    insurer: Optional[str] = Field(None, description="Insurance company/provider name")
    document_type: Optional[str] = Field(None, description="Type of insurance document (e.g. health, auto, life)")
    effective_date: Optional[str] = Field(None, description="Policy effective start date")
    expiration_date: Optional[str] = Field(None, description="Policy expiration or renewal date")
    insured_name: Optional[str] = Field(None, description="Name of the primary insured person")
    coverage_amount: Optional[str] = Field(None, description="Maximum coverage amount or sum insured")
    premium_amount: Optional[str] = Field(None, description="Premium amount")
    deductible: Optional[str] = Field(None, description="Deductible amount")
    copay: Optional[str] = Field(None, description="Co-payment or co-insurance percentage/amount")
    additional_fields: Optional[dict] = Field(None, description="Any other notable fields found in the document")


class RoomRentCapExtraction(BaseModel):
    """Typed LLM contract for room-rent-cap extraction.

    ``clause`` and ``display`` remain empty when ``present`` is false.  A
    present result is still subject to the evidence pipeline's exact-text
    check before it can become a user-visible citation.
    """

    present: bool = Field(False, description="Whether a room-rent cap is explicitly present")
    clause: str = Field("", max_length=2_000, description="Exact clause text from the source document")
    display: str = Field("", max_length=500, description="Short human-readable summary of the cap")
