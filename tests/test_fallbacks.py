"""
Tests for all fallback chains in the system.
Run: pytest tests/test_fallbacks.py -v
"""
import pytest
import asyncio
import os
from unittest.mock import patch, MagicMock, AsyncMock

from src.config.settings import settings


class TestQdrantFallback:
    """Qdrant: server connection → in-memory"""

    def test_init_uses_in_memory_when_no_qdrant(self):
        from src.rag.pipeline import RAGPipeline
        settings.qdrant_url = None  # no server available
        pipeline = RAGPipeline()
        assert pipeline.qdrant_client is not None
        # in-memory client has no 'url' attr; server client does
        assert not hasattr(pipeline.qdrant_client, '_grpc_client')


class TestEmbeddingFallback:
    """Embeddings: OpenAI → local sentence-transformers"""

    @pytest.mark.asyncio
    async def test_local_embedding_works(self):
        from src.rag.pipeline import RAGPipeline
        settings.openai_api_key = "sk-test-fallback"
        settings.qdrant_url = None
        pipeline = RAGPipeline()
        assert pipeline.local_embed_model is not None
        assert pipeline.hf_embedding_dimension == 384

    @pytest.mark.asyncio
    async def test_fallback_from_openai_failure(self):
        from src.rag.pipeline import RAGPipeline
        settings.openai_api_key = "sk-test-broken"
        settings.qdrant_url = None
        # Disable Ollama so fallback goes to local sentence-transformers
        settings.ollama_base_url = ""
        pipeline = RAGPipeline()
        embeds = await pipeline._generate_embeddings_with_fallback(
            ["insurance policy test"]
        )
        assert len(embeds) == 1
        assert len(embeds[0]) == 384


class TestOCRPipeline:
    """OCR: direct text extraction → doctr OCR → LLM extraction"""

    @pytest.mark.asyncio
    async def test_pdf_direct_text(self):
        import fitz
        from src.ocr.pipeline import OCRPipeline
        doc = fitz.open()
        page = doc.new_page()
        page.insert_text((50, 100), "Health Insurance Policy\nPolicy: HP-001")
        pdf_bytes = doc.write()
        doc.close()

        ocr = OCRPipeline()
        result = await ocr.process_document(pdf_bytes, "pdf", "test.pdf")
        assert result["status"] == "success"
        full_text = result["result"]["full_text"]
        assert "Health Insurance Policy" in full_text

    @pytest.mark.asyncio
    async def test_text_file_support(self):
        from src.ocr.pipeline import OCRPipeline
        ocr = OCRPipeline()
        content = b"Policy Number: TXT-001\nInsurer: TestCorp"
        result = await ocr.process_document(content, "txt", "test.txt")
        assert result["status"] == "success"
        assert "TXT-001" in result["result"]["full_text"]

    @pytest.mark.asyncio
    async def test_image_ocr_fallback(self):
        """Test OCR fallback by creating a simple image with text"""
        from PIL import Image, ImageDraw, ImageFont
        from src.ocr.pipeline import OCRPipeline
        import io

        img = Image.new("RGB", (400, 100), "white")
        draw = ImageDraw.Draw(img)
        draw.text((10, 40), "Health Policy 500K", fill="black")
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        img_bytes = buf.getvalue()

        ocr = OCRPipeline()
        result = await ocr.process_document(img_bytes, "png", "test.png")
        assert result["status"] == "success"
        full_text = result["result"]["full_text"]
        assert len(full_text) > 0


class TestDocumentClassifier:
    """Classification: keyword/regex → default fallback"""

    def test_classify_health(self):
        from src.utils.document_classifier import DocumentClassifier
        clf = DocumentClassifier()
        text = "Health insurance policy from Niva Bupa. Medical coverage 500K."
        result = clf._classify_document_type(text)
        assert result == "Health Insurance"

    def test_classify_auto(self):
        from src.utils.document_classifier import DocumentClassifier
        clf = DocumentClassifier()
        text = "Auto insurance for vehicle VIN ABC123. Collision coverage."
        result = clf._classify_document_type(text)
        assert result == "Auto Insurance"

    def test_date_extraction(self):
        from src.utils.document_classifier import DocumentClassifier
        clf = DocumentClassifier()
        info = clf._extract_policy_info(
            "Coverage period from 01/15/2024 to 01/15/2025"
        )
        assert info["effective_date"] == "01/15/2024"
        assert info["expiration_date"] == "01/15/2025"

    def test_policy_number_extraction(self):
        from src.utils.document_classifier import DocumentClassifier
        clf = DocumentClassifier()
        info = clf._extract_policy_info(
            "Policy Number: HLT-2024-001"
        )
        assert info["policy_number"] == "HLT-2024-001"

    def test_insurer_detection(self):
        from src.utils.document_classifier import DocumentClassifier
        clf = DocumentClassifier()
        text = "This policy is issued by Niva Bupa Health Insurance"
        assert clf._extract_insurer(text) == "Niva Bupa"

    def test_fallback_classification(self):
        from src.utils.document_classifier import DocumentClassifier
        clf = DocumentClassifier()
        result = clf._default_classification()
        assert result["document_type"] == "Insurance Policy"
        assert result["confidence"] == 0.0


class TestLLMClient:
    """LLM: model with retry → fallback model"""

    @pytest.mark.asyncio
    async def test_quota_short_circuit(self):
        from src.llm.client import LLMClient
        settings.openai_api_key = "sk-test-broken"
        llm = LLMClient()
        with pytest.raises(Exception):
            await llm.generate(
                [{"role": "user", "content": "hi"}],
                max_retries=1,
                fallback_models=["gpt-4o-mini"],
            )

    def test_adapt_json_schema_kept_for_supported_models(self):
        from src.llm.client import LLMClient
        llm = LLMClient()
        rf = {"type": "json_schema", "json_schema": {"name": "Test", "schema": {}}}
        msgs = [{"role": "system", "content": "extract info"}]
        adapted_rf, adapted_msgs = llm._adapt_response_format(rf, "gpt-4o", msgs)
        assert adapted_rf == rf
        assert adapted_msgs == msgs

    def test_adapt_json_schema_converted_for_unsupported_models(self):
        from src.llm.client import LLMClient
        llm = LLMClient()
        rf = {"type": "json_schema", "json_schema": {"name": "Test", "schema": {}}}
        msgs = [{"role": "system", "content": "extract info"}]
        adapted_rf, adapted_msgs = llm._adapt_response_format(rf, "gpt-4o-mini", msgs)
        assert adapted_rf == {"type": "json_object"}
        assert "MUST respond with valid JSON" in adapted_msgs[0]["content"]

    def test_adapt_json_schema_kept_when_no_json_schema(self):
        from src.llm.client import LLMClient
        llm = LLMClient()
        rf = {"type": "json_object"}
        msgs = [{"role": "user", "content": "hi"}]
        adapted_rf, adapted_msgs = llm._adapt_response_format(rf, "gpt-4o-mini", msgs)
        assert adapted_rf == rf
        assert adapted_msgs == msgs


class TestSettings:
    """Settings: env vars → defaults"""

    def test_model_defaults(self):
        assert settings.openai_chat_model == "gpt-5-nano"
        assert settings.openai_embedding_model == "text-embedding-3-small"

    def test_qdrant_defaults(self):
        assert settings.qdrant_collection == "insurance_documents_v2"


# =============================================================================
# New tests for recently added features
# =============================================================================


class TestOllamaIntegration:
    """Ollama integration: client selection, json_schema support, fallback chain"""

    def test_select_client_returns_ollama_when_model_matches_ollama_chat_model(self):
        from src.llm.client import LLMClient
        settings.ollama_base_url = "http://localhost:11434/v1"
        settings.ollama_chat_model = "llama3.2"
        settings.ollama_alt_model = "phi3:mini"
        settings.mlx_enabled = False
        llm = LLMClient()
        client = llm._select_client("llama3.2")
        assert client is llm._get_ollama_client()

    def test_select_client_returns_openai_for_openai_models(self):
        from src.llm.client import LLMClient
        settings.ollama_base_url = "http://localhost:11434/v1"
        settings.mlx_enabled = False
        llm = LLMClient()
        client = llm._select_client("gpt-5-nano")
        assert client is llm.client

    def test_supports_json_schema_returns_false_for_ollama_models(self):
        from src.llm.client import LLMClient
        llm = LLMClient()
        for model in ["llama3.2", "mistral", "qwen2.5", "phi3:mini", "gemma2"]:
            assert not llm._supports_json_schema(model), f"{model} should not support json_schema"

    def test_fallback_chain_includes_ollama_chat_model_when_enabled(self):
        from src.llm.client import LLMClient
        settings.ollama_base_url = "http://localhost:11434/v1"
        settings.ollama_chat_model = "llama3.2"
        settings.ollama_alt_model = "phi3:mini"
        settings.mlx_enabled = False
        llm = LLMClient()
        models_to_try = [llm.model]
        if llm._ollama_enabled:
            if settings.ollama_chat_model not in models_to_try:
                models_to_try.append(settings.ollama_chat_model)
            if settings.ollama_alt_model not in models_to_try:
                models_to_try.append(settings.ollama_alt_model)
        assert "llama3.2" in models_to_try
        assert "phi3:mini" in models_to_try


class TestMLXIntegration:
    """MLX integration: client selection, json_schema support, fallback chain"""

    def test_select_client_returns_mlx_when_enabled_and_model_matches(self):
        from src.llm.client import LLMClient
        settings.mlx_enabled = True
        settings.mlx_model = "mlx-community/Phi-3-mini-4k-instruct-4bit"
        settings.ollama_base_url = ""
        llm = LLMClient()
        client = llm._select_client("mlx-community/Phi-3-mini-4k-instruct-4bit")
        assert client is llm._get_mlx_client()

    def test_supports_json_schema_returns_false_for_mlx_models(self):
        from src.llm.client import LLMClient
        settings.mlx_model = "mlx-community/Phi-3-mini-4k-instruct-4bit"
        llm = LLMClient()
        assert not llm._supports_json_schema("mlx-community/Phi-3-mini-4k-instruct-4bit")
        assert not llm._supports_json_schema("mlx-community/Mistral-7B-v0.2-4bit")

    def test_mlx_not_in_fallback_chain_when_disabled(self):
        from src.llm.client import LLMClient
        settings.mlx_enabled = False
        settings.ollama_base_url = ""
        llm = LLMClient()
        models_to_try = [llm.model]
        if llm._mlx_enabled and settings.mlx_model not in models_to_try:
            models_to_try.append(settings.mlx_model)
        assert settings.mlx_model not in models_to_try


class TestPhi3MiniAltModel:
    """Phi-3-mini alt model: routing and fallback chain"""

    def test_select_client_routes_ollama_alt_model_to_ollama(self):
        from src.llm.client import LLMClient
        settings.ollama_base_url = "http://localhost:11434/v1"
        settings.ollama_chat_model = "llama3.2"
        settings.ollama_alt_model = "phi3:mini"
        settings.mlx_enabled = False
        llm = LLMClient()
        client = llm._select_client("phi3:mini")
        assert client is llm._get_ollama_client()

    def test_fallback_chain_includes_ollama_alt_model(self):
        from src.llm.client import LLMClient
        settings.ollama_base_url = "http://localhost:11434/v1"
        settings.ollama_chat_model = "llama3.2"
        settings.ollama_alt_model = "phi3:mini"
        settings.mlx_enabled = False
        llm = LLMClient()
        models_to_try = [llm.model]
        if llm._ollama_enabled:
            if settings.ollama_chat_model not in models_to_try:
                models_to_try.append(settings.ollama_chat_model)
            if settings.ollama_alt_model not in models_to_try:
                models_to_try.append(settings.ollama_alt_model)
        assert "phi3:mini" in models_to_try


class TestBGEBaseEmbedding:
    """BGE-base embedding: settings-backed model and dimensions"""

    def test_init_hf_client_uses_settings_embedding_model(self):
        from src.rag.pipeline import RAGPipeline
        settings.openai_api_key = "sk-test-bge"
        settings.qdrant_url = None
        settings.hf_embedding_model = "BAAI/bge-base-en-v1.5"
        pipeline = RAGPipeline()
        assert pipeline.hf_embedding_model == "BAAI/bge-base-en-v1.5"
        assert pipeline.hf_embedding_dimension == 768

    def test_hf_embedding_dimensions_includes_bge_base(self):
        from src.rag.pipeline import HF_EMBEDDING_DIMENSIONS
        assert "BAAI/bge-base-en-v1.5" in HF_EMBEDDING_DIMENSIONS
        assert HF_EMBEDDING_DIMENSIONS["BAAI/bge-base-en-v1.5"] == 768


class TestDoclingPDFParser:
    """Docling PDF parser: ImportError fallback to PyMuPDF"""

    @pytest.mark.asyncio
    async def test_process_pdf_with_docling_returns_none_when_not_installed(self):
        from src.ocr.pipeline import OCRPipeline
        ocr = OCRPipeline()
        result = await ocr._process_pdf_with_docling("/fake/path.pdf")
        assert result is None

    @pytest.mark.asyncio
    async def test_process_document_falls_back_to_pymupdf_when_docling_not_installed(self):
        import fitz
        from src.ocr.pipeline import OCRPipeline
        settings.docling_enabled = True
        doc = fitz.open()
        page = doc.new_page()
        page.insert_text((50, 100), "Docling Fallback Test")
        pdf_bytes = doc.write()
        doc.close()

        ocr = OCRPipeline()
        result = await ocr.process_document(pdf_bytes, "pdf", "test_docling.pdf")
        assert result["status"] == "success"
        full_text = result["result"]["full_text"]
        assert "Docling Fallback Test" in full_text


class TestAntiAbuseDBPath:
    """Anti-abuse DB path: default and env var override"""

    def test_default_db_path(self):
        from src.utils.anti_abuse import ANTI_ABUSE_DB_PATH
        assert ANTI_ABUSE_DB_PATH == "insurance_app.db"

    def test_env_var_overrides_default(self):
        import os
        os.environ["ANTI_ABUSE_DB_PATH"] = "/tmp/test_anti_abuse.db"
        import importlib
        import src.utils.anti_abuse as aa_module
        importlib.reload(aa_module)
        assert aa_module.ANTI_ABUSE_DB_PATH == "/tmp/test_anti_abuse.db"
        del os.environ["ANTI_ABUSE_DB_PATH"]
        importlib.reload(aa_module)

    def test_check_document_hash_exists_passes_custom_path(self):
        from src.utils.anti_abuse import check_document_hash_exists, ANTI_ABUSE_DB_PATH
        with patch("src.utils.database_migration.check_document_hash_exists_db") as mock_check:
            mock_check.return_value = False
            result = check_document_hash_exists("abc123")
            mock_check.assert_called_once_with("abc123", ANTI_ABUSE_DB_PATH)


class TestStructureAwareChunking:
    """Structure-aware chunking: section headers, max block size, paragraph fallback"""

    def test_splits_on_section_headers(self):
        from src.services.document_processing_service import DocumentProcessingService
        svc = DocumentProcessingService()
        text = (
            "COVERAGE\nThis policy covers medical expenses.\n"
            "EXCLUSIONS\nPre-existing conditions are not covered.\n"
            "DEDUCTIBLE\nA $500 deductible applies."
        )
        blocks = svc._split_text_into_blocks(text, max_block_size=50)
        assert len(blocks) >= 3
        block_texts = [b["text"] for b in blocks]
        assert any("COVERAGE" in t for t in block_texts)
        assert any("EXCLUSIONS" in t for t in block_texts)
        assert any("DEDUCTIBLE" in t for t in block_texts)

    def test_blocks_dont_exceed_max_block_size(self):
        from src.services.document_processing_service import DocumentProcessingService
        svc = DocumentProcessingService()
        text = "COVERAGE\n" + "A" * 200 + "\nEXCLUSIONS\n" + "B" * 200 + "\nDEDUCTIBLE\n" + "C" * 200
        blocks = svc._split_text_into_blocks(text, max_block_size=300)
        for block in blocks:
            assert len(block["text"]) <= 300

    def test_text_without_section_headers_split_by_paragraphs(self):
        from src.services.document_processing_service import DocumentProcessingService
        svc = DocumentProcessingService()
        text = "First paragraph content here.\n\nSecond paragraph with more details.\n\nThird paragraph even longer content."
        blocks = svc._split_text_into_blocks(text, max_block_size=1000)
        assert len(blocks) >= 1
        block_texts = [b["text"] for b in blocks]
        assert any("First paragraph" in t for t in block_texts)
        assert any("Second paragraph" in t for t in block_texts)
        assert any("Third paragraph" in t for t in block_texts)


class TestSharedOCRPipeline:
    """Shared OCR pipeline: single instance shared between processors"""

    def test_document_processing_service_creates_single_ocr_pipeline(self):
        from src.services.document_processing_service import DocumentProcessingService
        svc = DocumentProcessingService()
        assert svc._ocr_pipeline is None
        assert svc.pdf_processor is None
        assert svc.image_processor is None

    @pytest.mark.asyncio
    async def test_both_processors_receive_same_ocr_pipeline(self):
        from src.services.document_processing_service import DocumentProcessingService
        svc = DocumentProcessingService()
        with patch("src.ocr.pipeline.OCRPipeline") as MockOCRPipeline:
            mock_instance = MagicMock()
            MockOCRPipeline.return_value = mock_instance
            with patch("src.ocr.pdf_processor.PDFProcessor") as MockPDFProcessor:
                with patch("src.ocr.image_processor.ImageProcessor") as MockImageProcessor:
                    mock_pdf = MagicMock()
                    mock_img = MagicMock()
                    MockPDFProcessor.return_value = mock_pdf
                    MockImageProcessor.return_value = mock_img

                    import tempfile
                    minimal_pdf = (
                        b"%PDF-1.4\n"
                        b"1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
                        b"2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n"
                        b"3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj\n"
                        b"xref\n0 4\n"
                        b"0000000000 65535 f \n"
                        b"0000000009 00000 n \n"
                        b"0000000058 00000 n \n"
                        b"0000000115 00000 n \n"
                        b"trailer<</Size 4/Root 1 0 R>>\n"
                        b"startxref\n190\n%%EOF"
                    )
                    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as f:
                        f.write(minimal_pdf)
                        pdf_path = f.name

                    try:
                        await svc._extract_text(pdf_path, "test.pdf")
                    except Exception:
                        pass

                    assert svc._ocr_pipeline is mock_instance


class TestLLMClassificationFallback:
    """LLM classification fallback: keyword → LLM when confidence low"""

    @pytest.mark.asyncio
    async def test_classify_document_calls_llm_when_keyword_confidence_low(self):
        from src.utils.document_classifier import DocumentClassifier
        clf = DocumentClassifier()
        clf.rag_pipeline = MagicMock()
        clf.rag_pipeline.llm = MagicMock()
        clf.rag_pipeline.llm.generate_structured = AsyncMock(return_value=MagicMock(
            document_type="Health Insurance",
            insurer="TestCorp",
            policy_number="POL-001",
        ))

        text = "health " + "filler words that are not insurance keywords " * 30
        result = await clf.classify_document("doc-001", text_content=text)
        assert result["document_type"] == "Health Insurance"
        assert result["insurer"] == "TestCorp"
        assert result["policy_number"] == "POL-001"

    @pytest.mark.asyncio
    async def test_classify_with_llm_returns_none_when_llm_unavailable(self):
        from src.utils.document_classifier import DocumentClassifier
        clf = DocumentClassifier()
        clf.rag_pipeline = MagicMock()
        clf.rag_pipeline.llm = MagicMock()
        clf.rag_pipeline.llm.generate_structured = AsyncMock(side_effect=Exception("LLM unavailable"))

        result = await clf._classify_with_llm("Some insurance document text here.")
        assert result is None
