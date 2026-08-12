"""Tests for the Policy Wording Specialist persona layer.

Covers (per motto_v5: tests are part of delivery, not afterthought):
- Persona prompt construction (additive over the security boundary, never weakening it).
- Multi-label granular taxonomy (_classify_section_types) + coarse parent mapping.
- Definition-privileging retrieval boost.
- WordingAssessment schema (legal-safe coverage interpretation, never a decision).
- query_rag embeds persona_version + wording_assessment in the response.

These are offline (no API) and assert on real implementation behaviour.
"""

from __future__ import annotations

import re

import pytest
from unittest.mock import AsyncMock, MagicMock
from types import SimpleNamespace

from src.rag.persona import (
    build_policy_wording_specialist_system_message,
    get_persona_version,
    build_system_message,
    is_policy_wording_persona_enabled,
    PERSONA_VERSION,
)
from src.security.prompt_injection import SYSTEM_PROMPT_PREFIX
from src.rag.pipeline import RAGPipeline
from src.models.rag import RAGAnswer, RAGCitation, WordingAssessment, CoverageLimitationRef


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def classifier():
    # Bypass __init__ (heavy); we only exercise pure methods.
    return RAGPipeline.__new__(RAGPipeline)


# ---------------------------------------------------------------------------
# Persona prompt construction
# ---------------------------------------------------------------------------

def test_persona_version_format_is_traceable():
    assert re.fullmatch(r"\d{4}-\d{2}-\d{2}\.pws-v\d+", get_persona_version())
    assert get_persona_version() == PERSONA_VERSION


def test_persona_message_is_additive_over_security_boundary():
    from src.security.prompt_injection import SYSTEM_PROMPT_PREFIX

    msg = build_policy_wording_specialist_system_message()
    # Additive: the security boundary must remain at the front, untouched.
    assert msg.startswith(SYSTEM_PROMPT_PREFIX)
    # Persona is appended, not replacing the boundary.
    assert len(msg) > len(SYSTEM_PROMPT_PREFIX)
    # The boundary's own instruction must still be present after stacking.
    assert SYSTEM_PROMPT_PREFIX in msg


def test_persona_message_carries_coverage_reasoning_scaffold():
    msg = build_policy_wording_specialist_system_message()
    for marker in (
        "Policy Wording Specialist",
        "Coverage trigger",
        "Definitions",
        "Exclusions",
        "Exceptions",
        "Conditions",
        "Limits and deductibles",
        "Adversarial interpretation test",
    ):
        assert marker in msg, f"persona missing reasoning marker: {marker}"


def test_persona_message_never_makes_a_coverage_decision():
    msg = build_policy_wording_specialist_system_message()
    # Legal-safety: must explicitly refuse to decide and defer to the insurer.
    assert "do NOT make, approve, or deny" in msg
    assert "defer to them" in msg
    # Hard rules must forbid rewriting wording in a coverage-altering way.
    assert "Preserve intended coverage" in msg
    assert "do not assert a single binding reading" in msg


# ---------------------------------------------------------------------------
# Feature flag (interim kill-switch) — ADR-2026-08-12 amendment
# ---------------------------------------------------------------------------

def test_flag_defaults_enabled(monkeypatch):
    monkeypatch.delenv("COVERWISE_POLICY_WORDING_PERSONA", raising=False)
    assert is_policy_wording_persona_enabled() is True


@pytest.mark.parametrize("value, expected", [
    ("on", True), ("true", True), ("1", True), ("yes", True), ("enabled", True),
    ("", True),  # unset-equivalent empty string still parses as enabled
    ("off", False), ("false", False), ("0", False), ("no", False),
    ("disabled", False), ("OFF", False), ("FALSE", False),
])
def test_flag_parses_env(monkeypatch, value, expected):
    monkeypatch.setenv("COVERWISE_POLICY_WORDING_PERSONA", value)
    assert is_policy_wording_persona_enabled() is expected


def test_build_system_message_uses_persona_when_enabled(monkeypatch):
    monkeypatch.setenv("COVERWISE_POLICY_WORDING_PERSONA", "on")
    msg = build_system_message()
    assert "Policy Wording Specialist" in msg
    assert "careful insurance-document assistant" not in msg


def test_build_system_message_reverts_to_generic_when_disabled(monkeypatch):
    monkeypatch.setenv("COVERWISE_POLICY_WORDING_PERSONA", "off")
    msg = build_system_message()
    # Byte-for-byte the pre-persona generic assistant (security boundary preserved).
    assert msg.startswith(SYSTEM_PROMPT_PREFIX)
    assert "careful insurance-document assistant" in msg
    assert "Policy Wording Specialist" not in msg


@pytest.mark.asyncio
async def test_query_rag_disabled_flag_omits_persona(monkeypatch):
    """When the flag is off, query_rag must not stamp a persona version and must
    not ask for a wording_assessment (the instruction is gated)."""
    import sqlite3

    monkeypatch.setenv("COVERWISE_POLICY_WORDING_PERSONA", "off")

    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(
        "CREATE TABLE rag_chunks (lex_id INTEGER PRIMARY KEY AUTOINCREMENT, point_id TEXT UNIQUE, "
        "document_id TEXT, filename TEXT, page_number INTEGER, section TEXT, text_content TEXT NOT NULL, "
        "embedding_model TEXT, updated_at TEXT)"
    )
    conn.execute("CREATE VIRTUAL TABLE rag_chunks_fts USING fts5(point_id UNINDEXED, search_text)")
    conn.commit()

    pipeline = RAGPipeline.__new__(RAGPipeline)
    pipeline.collection_name = "insurance_documents_v2"
    pipeline.active_embedding_model = "text-embedding-3-small"
    pipeline.embedding_dimensions = 1536
    pipeline.hybrid_index_enabled = True
    pipeline.hybrid_index = conn
    pipeline.vector_backend = "qdrant"
    pipeline.qdrant_client = MagicMock()
    pipeline.qdrant_client.search = MagicMock()
    pipeline.redis = MagicMock()
    pipeline.cache = False
    pipeline.openai_chat_model = "gpt-4o"
    pipeline._upsert_hybrid_index(
        "chunk-1",
        {"document_id": "doc-1", "filename": "policy.pdf", "page_number": 2,
         "section": "coverage", "text_content": "We will pay the sum insured on death.",
         "embedding_model": "text-embedding-3-small"},
    )
    captured = {}

    async def _fake_generate(messages, **kwargs):
        captured["messages"] = messages
        return RAGAnswer(
            answer="The policy pays the sum insured on death.",
            citations=[RAGCitation(source_index=1, quote="We will pay the sum insured on death.")],
            confidence=0.8,
            missing_information=[],
            follow_up_questions=[],
            wording_assessment=None,  # flag off -> caller should not request one
        )

    pipeline.llm = MagicMock()
    pipeline.llm.generate_structured = AsyncMock(side_effect=_fake_generate)
    pipeline._generate_embeddings_with_fallback = AsyncMock(return_value=[[0.1, 0.2, 0.3]])
    pipeline._build_qdrant_filter = MagicMock(return_value=None)
    pipeline.qdrant_client.query_points = MagicMock(
        return_value=SimpleNamespace(points=[_make_hit("1", 0.92, "We will pay the sum insured on death.",
                                                       document_id="doc-1", page_number=2)])
    )

    result = await RAGPipeline.query_rag(
        pipeline, "Is death covered?", top_k=2, filters={"document_id": "doc-1"}
    )

    assert result["status"] == "success"
    res = result["result"]
    assert res["persona_version"] is None
    assert res["wording_assessment"] is None
    # The wording_assessment instruction must NOT appear in the gated user message.
    user_msg = captured["messages"][1]["content"]
    assert "wording_assessment" not in user_msg
    assert "Policy Wording Specialist" not in captured["messages"][0]["content"]


# ---------------------------------------------------------------------------
# Multi-label granular taxonomy
# ---------------------------------------------------------------------------

def test_classify_section_types_is_multilabel_and_ranked(classifier):
    # insuring_agreement hits twice ('we will indemnify', 'we will pay');
    # benefit hits once ('we will pay' is shared). Coarse order: by count desc.
    text = "We will indemnify you. We will pay the sum insured on death."
    tags = classifier._classify_section_types(text)
    assert isinstance(tags, list)
    assert tags[0] == "insuring_agreement"
    assert "benefit" in tags
    assert tags.count("insuring_agreement") == 1  # multi-label, not duplicated


def test_classify_section_types_finds_endorsement(classifier):
    tags = classifier._classify_section_types(
        "Endorsement no. 2 amends the wording of this policy."
    )
    assert "endorsement" in tags


def test_classify_section_types_finds_condition(classifier):
    tags = classifier._classify_section_types(
        "Subject to the condition precedent, you must notify us of any claim."
    )
    assert "condition" in tags


def test_classify_section_types_finds_deductible(classifier):
    tags = classifier._classify_section_types(
        "There is a deductible of 5000 and an excess of 200 applies."
    )
    assert "deductible" in tags


def test_classify_section_types_finds_definition(classifier):
    tags = classifier._classify_section_types(
        "The term 'Accident' means a sudden, unforeseen event. See this definition."
    )
    assert "definition" in tags


def test_classify_section_types_empty_returns_empty(classifier):
    assert classifier._classify_section_types("") == []
    assert classifier._classify_section_types("   ") == []


# ---------------------------------------------------------------------------
# Coarse parent mapping (DB-valid section_type)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("text, expected_coarse", [
    ("We will indemnify you for the loss.", "benefit"),          # insuring_agreement -> benefit
    ("Subject to the condition precedent you must notify us.", "general"),  # condition -> general
    ("Endorsement no. 3 amends the wording.", "general"),        # endorsement -> general
    ("Exception to the exclusion, cover is restored.", "exclusion"),  # exception -> exclusion
    ("A deductible of 500 applies.", "sub_limit"),               # deductible -> sub_limit
])
def test_classify_section_type_coarse_mapping(classifier, text, expected_coarse):
    assert classifier._classify_section_type(text) == expected_coarse


def test_classify_section_type_empty_is_general(classifier):
    assert classifier._classify_section_type("") == "general"


# ---------------------------------------------------------------------------
# Definition-privileging retrieval boost
# ---------------------------------------------------------------------------

def test_definition_boost_only_applies_to_definition_chunks(classifier):
    query = "what does accident mean"
    text = "Accident means a sudden unforeseen event."
    base = {"section_tags": []}
    defn = {"section_tags": ["definition"]}
    boost_with = classifier._exact_match_boost(query, text, defn)
    boost_without = classifier._exact_match_boost(query, text, base)
    # Token-overlap contribution is identical; only the 0.15 definition boost differs.
    assert boost_with >= boost_without + 0.15


def test_definition_boost_requires_definition_intent_keyword(classifier):
    # Chunk is a definition, but the query does NOT ask about a term -> no boost.
    # NOTE: avoid def-intent keywords ("what is", "mean", "definition", ...).
    boost = classifier._exact_match_boost(
        "show the deductible amount",  # no definition-intent keyword
        "Accident means a sudden unforeseen event.",
        {"section_tags": ["definition"]},
    )
    assert boost < 0.15


# ---------------------------------------------------------------------------
# WordingAssessment schema (legal-safe interpretation, never a decision)
# ---------------------------------------------------------------------------

def test_wording_assessment_valid_readings_accept():
    for reading in ("likely_covered", "likely_not_covered", "conditional", "ambiguous"):
        wa = WordingAssessment(reading=reading, summary="x")
        assert wa.reading == reading


def test_wording_assessment_rejects_invalid_reading():
    with pytest.raises(Exception):
        WordingAssessment(reading="decided", summary="x")


def test_wording_assessment_defaults_and_disclaimer():
    wa = WordingAssessment(summary="Test reading.")
    # Default reading is the honest 'ambiguous' (never a confident decision).
    assert wa.reading == "ambiguous"
    assert "not a binding" in wa.disclaimer
    assert "insurer" in wa.disclaimer


def test_wording_assessment_limitation_ref_lists():
    wa = WordingAssessment(
        reading="conditional",
        summary="Covered if condition met.",
        applicable_exclusions=[CoverageLimitationRef(label="Exclusion 1", quote="not covered")],
        applicable_conditions=[CoverageLimitationRef(label="Condition 3", source_index=2)],
    )
    assert wa.applicable_exclusions[0].label == "Exclusion 1"
    assert wa.applicable_conditions[0].source_index == 2


# Helper for the query integration test below
def _make_hit(hit_id, score, text, **payload):
    return SimpleNamespace(id=hit_id, score=score, payload={"text_content": text, **payload})


@pytest.mark.asyncio
async def test_query_rag_embeds_persona_version_and_wording_assessment():
    """query_rag must stamp the active persona version and surface the
    WordingAssessment in the response payload (the persona is active)."""
    import sqlite3

    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(
        "CREATE TABLE rag_chunks (lex_id INTEGER PRIMARY KEY AUTOINCREMENT, point_id TEXT UNIQUE, "
        "document_id TEXT, filename TEXT, page_number INTEGER, section TEXT, text_content TEXT NOT NULL, "
        "embedding_model TEXT, updated_at TEXT)"
    )
    conn.execute("CREATE VIRTUAL TABLE rag_chunks_fts USING fts5(point_id UNINDEXED, search_text)")
    conn.commit()

    pipeline = RAGPipeline.__new__(RAGPipeline)
    pipeline.collection_name = "insurance_documents_v2"
    pipeline.active_embedding_model = "text-embedding-3-small"
    pipeline.embedding_dimensions = 1536
    pipeline.hybrid_index_enabled = True
    pipeline.hybrid_index = conn
    pipeline.vector_backend = "qdrant"
    pipeline.qdrant_client = MagicMock()
    pipeline.qdrant_client.search = MagicMock()
    pipeline.redis = MagicMock()
    pipeline.cache = False
    pipeline.openai_chat_model = "gpt-4o"
    pipeline._upsert_hybrid_index(
        "chunk-1",
        {"document_id": "doc-1", "filename": "policy.pdf", "page_number": 2,
         "section": "coverage", "text_content": "We will pay the sum insured on death.",
         "embedding_model": "text-embedding-3-small"},
    )
    pipeline.llm = MagicMock()
    pipeline.llm.generate_structured = AsyncMock(
        return_value=RAGAnswer(
            answer="The policy pays the sum insured on death.",
            citations=[RAGCitation(source_index=1, quote="We will pay the sum insured on death.")],
            confidence=0.8,
            missing_information=[],
            follow_up_questions=[],
            wording_assessment=WordingAssessment(
                reading="likely_covered",
                summary="Death benefit is granted by the insuring agreement.",
            ),
        )
    )
    pipeline._generate_embeddings_with_fallback = AsyncMock(return_value=[[0.1, 0.2, 0.3]])
    pipeline._build_qdrant_filter = MagicMock(return_value=None)

    search_hits = [_make_hit("1", 0.92, "We will pay the sum insured on death.",
                             document_id="doc-1", page_number=2)]
    pipeline.qdrant_client.query_points = MagicMock(
        return_value=SimpleNamespace(points=search_hits)
    )

    result = await RAGPipeline.query_rag(
        pipeline,
        "Is death covered?",
        top_k=2,
        filters={"document_id": "doc-1"},  # singular -> no policy-map priming path
    )

    assert result["status"] == "success"
    res = result["result"]
    # Persona traceability
    assert res["persona_version"] == get_persona_version()
    # WordingAssessment surfaced and parsed
    assert res["wording_assessment"] is not None
    assert res["wording_assessment"]["reading"] == "likely_covered"
    assert "disclaimer" in res["wording_assessment"]
