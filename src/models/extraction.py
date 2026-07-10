from pydantic import BaseModel, Field
from typing import Optional


class InsuranceDocumentExtraction(BaseModel):
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
