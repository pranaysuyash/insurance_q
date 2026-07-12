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
