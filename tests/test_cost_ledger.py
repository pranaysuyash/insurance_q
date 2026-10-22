import pytest
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from src.services.evidence_pipeline import (
    RoomRentCapExtractor,
    RoomRentCapExtraction,
    EvidencePipeline,
)
from src.models.evidence import PageArtifact
from src.llm.client import CostTracker

@pytest.mark.asyncio
async def test_room_rent_cap_extractor_tracks_cost():
    mock_llm = MagicMock()
    mock_llm.cost_tracker = CostTracker()
    
    async def fake_generate_structured(**kwargs):
        mock_llm.cost_tracker.record(
            model="gpt-4o-mini",
            input_tokens=1000,
            output_tokens=200,
        )
        return RoomRentCapExtraction(
            present=True,
            clause="Room rent is capped at 1% of sum insured per day.",
            display="1% of Sum Insured",
        )
        
    mock_llm.generate_structured = AsyncMock(side_effect=fake_generate_structured)
    
    extractor = RoomRentCapExtractor(mock_llm)
    doc_id = uuid4()
    page_texts = {1: "Policy terms: Room rent is capped at 1% of sum insured per day."}
    
    result = await extractor.extract(doc_id, page_texts)
    assert result is not None
    assert result.cost_usd > 0.0
    assert result.cost_usd == mock_llm.cost_tracker._total_cost

@pytest.mark.asyncio
async def test_evidence_pipeline_records_llm_cost():
    mock_substrate = MagicMock()
    mock_substrate.get_page_artifacts_for_document = AsyncMock(return_value=[
        PageArtifact(
            id=str(uuid4()),
            document_id=str(uuid4()),
            page_number=1,
            image_uri="uri",
            image_width=100,
            image_height=100,
            image_bytes=100,
            sha256="abc",
            created_at="2026-09-07T00:00:00Z",
        )
    ])
    mock_substrate.append_extracted_field = AsyncMock(return_value=uuid4())
    mock_substrate.link_field_evidence = AsyncMock()
    mock_substrate.record_extraction_cost = AsyncMock()
    
    mock_llm = MagicMock()
    mock_llm.cost_tracker = CostTracker()
    async def fake_generate_structured(**kwargs):
        mock_llm.cost_tracker.record(model="gpt-4o-mini", input_tokens=500, output_tokens=100)
        return RoomRentCapExtraction(
            present=True,
            clause="Room rent is capped at 1% of sum insured per day.",
            display="1% of SI",
        )
    mock_llm.generate_structured = AsyncMock(side_effect=fake_generate_structured)
    
    pipeline = EvidencePipeline(substrate=mock_substrate, llm_client=mock_llm)
    doc_id = uuid4()
    page_texts = {1: "Policy terms: Room rent is capped at 1% of sum insured per day."}
    
    res = await pipeline.run_for_document(doc_id, page_texts)
    assert res.total_cost_usd > 0.0
    # Verify recorded cost
    cost_calls = mock_substrate.record_extraction_cost.call_args_list
    assert len(cost_calls) > 0
    llm_cost_records = [c[0][0] for c in cost_calls if c[0][0].cost_usd > 0.0]
    assert len(llm_cost_records) == 1
    assert llm_cost_records[0].cost_usd == res.total_cost_usd
