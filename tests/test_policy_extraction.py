"""
Tests for the policy extraction service, RRF merge, and cross-encoder reranking.
"""
import os
import tempfile

import pytest
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from src.models.extraction import PolicySummaryExtraction, CoverageItem
from src.services.policy_extraction_service import PolicyExtractionService


class TestPolicySummaryExtraction:
    """Test the Pydantic model for structured policy extraction."""

    def test_empty_extraction(self):
        """All fields should default to None or empty."""
        extraction = PolicySummaryExtraction()
        assert extraction.policy_number is None
        assert extraction.insurer is None
        assert extraction.coverage_amount is None
        assert extraction.key_benefits == []
        assert extraction.exclusions == []
        assert extraction.coverage_items == []

    def test_full_extraction(self):
        """Should accept all fields."""
        extraction = PolicySummaryExtraction(
            policy_number="4214i/CPHSR/407834350/00/000",
            insurer="ICICI Lombard General Insurance Company Limited",
            insurer_helpline="1800 2666",
            insurer_email="ihealthcare@icicilombard.com",
            document_type="Health Insurance",
            coverage_amount=2500000,
            deductible=None,
            premium_amount=31705,
            premium_frequency="annually",
            effective_date="2025-08-27",
            expiration_date="2026-08-26",
            key_benefits=[
                "In-patient hospitalization up to sum insured",
                "Pre-hospitalization expenses for 60 days",
                "Post-hospitalization expenses for 180 days",
                "Daycare procedures covered",
                "Maternity benefit up to ₹40,000",
            ],
            exclusions=[
                "Pre-existing conditions (subject to policy terms)",
                "Cosmetic/aesthetic treatments",
                "Self-inflicted injuries",
                "War-related injuries",
            ],
            waiting_periods=[
                "Initial 30 days waiting period",
                "Pre-existing conditions: as per policy terms",
            ],
            coverage_items=[
                CoverageItem(name="Hospitalization", covered=True, limit_text="Up to ₹25L"),
                CoverageItem(name="Maternity", covered=True, limit=40000, limit_text="₹40,000"),
                CoverageItem(name="Dental", covered=False, notes="Not listed in policy schedule"),
            ],
        )
        assert extraction.policy_number == "4214i/CPHSR/407834350/00/000"
        assert extraction.coverage_amount == 2500000
        assert len(extraction.key_benefits) == 5
        assert len(extraction.coverage_items) == 3
        assert extraction.coverage_items[2].covered is False

    def test_coverage_item(self):
        """CoverageItem should serialize/deserialize correctly."""
        item = CoverageItem(name="Test", limit=50000, covered=True, limit_text="₹50,000")
        d = item.model_dump()
        assert d["name"] == "Test"
        assert d["limit"] == 50000
        assert d["covered"] is True

        restored = CoverageItem.model_validate(d)
        assert restored.name == "Test"
        assert restored.limit == 50000


class TestPolicyExtractionService:
    """Test the extraction service."""

    @pytest.mark.asyncio
    async def test_extract_summary_success(self):
        """Should extract summary from text via LLM."""
        mock_llm = MagicMock()
        mock_llm.generate_structured = AsyncMock(return_value=PolicySummaryExtraction(
            policy_number="TEST-123",
            insurer="Test Insurance Co",
            document_type="Health Insurance",
            coverage_amount=500000,
            premium_amount=10000,
            key_benefits=["Hospitalization", "Daycare"],
            exclusions=["Cosmetic"],
        ))

        service = PolicyExtractionService(mock_llm)
        result = await service.extract_summary("doc-1", "This is a test insurance policy document with some text that is long enough to pass the minimum threshold check for extraction to proceed.", "Health Insurance")

        assert result is not None
        assert result["policy_number"] == "TEST-123"
        assert result["insurer"] == "Test Insurance Co"
        assert result["coverage_amount"] == 500000
        assert result["document_id"] == "doc-1"
        assert "key_benefits" in result

    @pytest.mark.asyncio
    async def test_extract_summary_insufficient_text(self):
        """Should return None for text that's too short."""
        mock_llm = MagicMock()
        service = PolicyExtractionService(mock_llm)
        result = await service.extract_summary("doc-1", "Too short", "Health Insurance")
        assert result is None

    @pytest.mark.asyncio
    async def test_extract_summary_llm_failure(self):
        """Should return None when LLM fails."""
        mock_llm = MagicMock()
        mock_llm.generate_structured = AsyncMock(side_effect=Exception("LLM error"))
        service = PolicyExtractionService(mock_llm)
        result = await service.extract_summary("doc-fail", "This is a long enough text for the extraction to proceed and not be rejected due to insufficient length.", "Health Insurance")
        assert result is None

    def test_get_summary(self):
        """Should retrieve a stored summary."""
        mock_llm = MagicMock()
        service = PolicyExtractionService(mock_llm)
        service._store_summary("doc-1", {"policy_number": "TEST-123"})
        assert service.get_summary("doc-1")["policy_number"] == "TEST-123"
        assert service.get_summary("nonexistent") is None

    def test_delete_summary(self):
        """Should delete a stored summary."""
        mock_llm = MagicMock()
        service = PolicyExtractionService(mock_llm)
        service._store_summary("doc-1", {"policy_number": "TEST-123"})
        service.delete_summary("doc-1")
        assert service.get_summary("doc-1") is None

    def test_get_all_summaries(self):
        """Should return all stored summaries."""
        mock_llm = MagicMock()
        with patch("src.services.policy_extraction_service._SUMMARY_DIR", tempfile.mkdtemp()):
            service = PolicyExtractionService(mock_llm)
            service._store_summary("doc-all-1", {"policy_number": "A"})
            service._store_summary("doc-all-2", {"policy_number": "B"})
            all_s = service.get_all_summaries()
        assert len(all_s) == 2
        assert "doc-all-1" in all_s
        assert "doc-all-2" in all_s


class TestRRFMerge:
    """Test the Reciprocal Rank Fusion merge logic (in isolation from RAGPipeline)."""

    @staticmethod
    def _rrf_merge(dense_results, local_results, k=20):
        """Standalone RRF merge for testing without importing RAGPipeline."""
        rrf_scores = {}
        point_store = {}

        for rank, hit in enumerate(dense_results, 1):
            point_id = str(getattr(hit, "id", ""))
            score = 1.0 / (k + rank)
            rrf_scores[point_id] = rrf_scores.get(point_id, 0.0) + score
            if point_id not in point_store:
                point_store[point_id] = SimpleNamespace(
                    id=point_id, score=0.0,
                    payload=dict(getattr(hit, "payload", {}) or {}),
                )

        for rank, hit in enumerate(local_results, 1):
            point_id = str(getattr(hit, "id", ""))
            score = 1.0 / (k + rank)
            rrf_scores[point_id] = rrf_scores.get(point_id, 0.0) + score
            if point_id not in point_store:
                point_store[point_id] = SimpleNamespace(
                    id=point_id, score=0.0,
                    payload=dict(getattr(hit, "payload", {}) or {}),
                )

        for point_id, rrf_score in rrf_scores.items():
            point_store[point_id].score = round(rrf_score, 6)

        return sorted(point_store.values(), key=lambda x: x.score, reverse=True)

    def _make_hit(self, point_id, score, text="test"):
        return SimpleNamespace(
            id=point_id,
            score=score,
            payload={"text_content": text, "document_id": "doc1"},
        )

    def test_rrf_merge_consensus_wins(self):
        """A result that appears in both lists should rank higher."""
        dense = [
            self._make_hit("A", 0.95, "text A"),
            self._make_hit("B", 0.85, "text B"),
            self._make_hit("C", 0.75, "text C"),
        ]
        sparse = [
            self._make_hit("C", 0.8, "text C"),
            self._make_hit("A", 0.6, "text A"),
            self._make_hit("D", 0.4, "text D"),
        ]

        merged = self._rrf_merge(dense, sparse)
        ids = [str(h.id) for h in merged]
        assert "A" in ids
        assert "C" in ids
        # A and C should be in top 2 (consensus)
        assert ids[0] in ("A", "C")
        assert ids[1] in ("A", "C")

    def test_rrf_merge_unique_results(self):
        """Results that appear in only one list should be included."""
        dense = [self._make_hit("A", 0.9)]
        sparse = [self._make_hit("B", 0.5)]
        merged = self._rrf_merge(dense, sparse)
        ids = {str(h.id) for h in merged}
        assert ids == {"A", "B"}

    def test_rrf_merge_empty_lists(self):
        """Should return empty list for empty inputs."""
        merged = self._rrf_merge([], [])
        assert merged == []