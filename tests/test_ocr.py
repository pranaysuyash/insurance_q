"""
Tests for the OCR pipeline.
"""
import pytest
import asyncio
from PIL import Image
import numpy as np
from src.ocr.pipeline import OCRPipeline
import io

@pytest.fixture
def ocr_pipeline():
    """Create OCR pipeline instance for testing."""
    return OCRPipeline(use_gpu=False)

@pytest.fixture
def sample_image():
    """Create a sample image with text for testing."""
    img = Image.new('RGB', (300, 100), color='white')
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='PNG')
    return img_bytes.getvalue()

@pytest.mark.asyncio
async def test_process_document_image(ocr_pipeline, sample_image):
    """Test processing an image document."""
    result = await ocr_pipeline.process_document(
        file_content=sample_image,
        file_type="png"
    )
    
    assert result["status"] == "success"
    assert "result" in result
    assert "metadata" in result
    assert result["metadata"]["page_count"] == 1

@pytest.mark.asyncio
async def test_process_document_invalid_type(ocr_pipeline, sample_image):
    """Test processing with invalid file type."""
    result = await ocr_pipeline.process_document(
        file_content=sample_image,
        file_type="invalid"
    )
    
    assert result["status"] == "error"
    assert "error" in result

@pytest.mark.asyncio
async def test_process_document_empty(ocr_pipeline):
    """Test processing empty content."""
    result = await ocr_pipeline.process_document(
        file_content=b"",
        file_type="png"
    )
    
    assert result["status"] == "error"
    assert "error" in result

@pytest.mark.asyncio
async def test_layout_analysis(ocr_pipeline, sample_image):
    """Test layout analysis functionality."""
    # Convert bytes to image
    image = Image.open(io.BytesIO(sample_image))
    
    # Mock OCR result
    mock_ocr_result = [[
        ([[0, 0, 100, 20]], ("Sample Title", 0.95)),
        ([[0, 30, 100, 50]], ("Sample Text", 0.90))
    ]]
    
    layout_result = await ocr_pipeline._analyze_layout(image, mock_ocr_result)
    
    assert "regions" in layout_result
    assert "structure" in layout_result
    assert len(layout_result["regions"]) == 2

@pytest.mark.asyncio
async def test_table_extraction(ocr_pipeline, sample_image):
    """Test table extraction functionality."""
    # Convert bytes to image
    image = Image.open(io.BytesIO(sample_image))
    
    # Mock layout result with table region
    mock_layout = {
        "regions": [{
            "type": "table",
            "bbox": [0, 0, 100, 50]
        }]
    }
    
    tables = await ocr_pipeline._extract_tables(image, mock_layout)
    
    assert isinstance(tables, list)
    assert len(tables) == 1
    assert "cells" in tables[0]
    assert "bbox" in tables[0]
    assert "confidence" in tables[0]

def test_structure_table_data(ocr_pipeline):
    """Test table structure extraction."""
    # Mock OCR result for a simple 2x2 table
    mock_table_ocr = [
        ([[0, 0, 50, 20]], ("Header 1", 0.95)),
        ([[60, 0, 110, 20]], ("Header 2", 0.95)),
        ([[0, 30, 50, 50]], ("Data 1", 0.90)),
        ([[60, 30, 110, 50]], ("Data 2", 0.90))
    ]
    
    table_data = ocr_pipeline._structure_table_data(mock_table_ocr)
    
    assert len(table_data) == 2  # Two rows
    assert len(table_data[0]) == 2  # Two columns
    assert table_data[0][0]["text"] == "Header 1"
    assert table_data[1][1]["text"] == "Data 2"

def test_convert_predictions_to_layout(ocr_pipeline):
    """Test layout prediction conversion."""
    mock_predictions = [0, 1, 2, 3]  # text, title, list, table
    mock_ocr_result = [[
        ([[0, 0, 100, 20]], ("Text Block", 0.95)),
        ([[0, 30, 100, 50]], ("Title Block", 0.90)),
        ([[0, 60, 100, 80]], ("List Item", 0.85)),
        ([[0, 90, 100, 110]], ("Table Cell", 0.80))
    ]]
    
    layout_info = ocr_pipeline._convert_predictions_to_layout(
        mock_predictions,
        mock_ocr_result
    )
    
    assert "regions" in layout_info
    assert "structure" in layout_info
    assert len(layout_info["regions"]) == 4
    assert layout_info["regions"][0]["type"] == "text"
    assert layout_info["regions"][1]["type"] == "title" 