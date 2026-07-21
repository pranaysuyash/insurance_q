"""Tests for deterministic native-PDF capability observations."""

from __future__ import annotations

import io

import fitz
from PIL import Image

from src.ocr.native_pdf import extract_native_pdf_nodes


def _mixed_pdf() -> bytes:
    document = fitz.open()
    page = document.new_page(width=320, height=240)
    page.insert_text((30, 30), "Health policy schedule")

    for x in (30, 150, 290):
        page.draw_line((x, 70), (x, 150))
    for y in (70, 110, 150):
        page.draw_line((30, y), (290, y))
    page.insert_text((40, 95), "Benefit")
    page.insert_text((160, 95), "Limit")
    page.insert_text((40, 135), "Health")
    page.insert_text((160, 135), "500000")

    image = Image.new("RGB", (20, 20), "#2f80ed")
    image_buffer = io.BytesIO()
    image.save(image_buffer, format="PNG")
    page.insert_image(fitz.Rect(30, 170, 90, 230), stream=image_buffer.getvalue())

    result = document.tobytes()
    document.close()
    return result


def test_native_pdf_adapter_emits_layout_table_cells_and_figures():
    nodes = extract_native_pdf_nodes(_mixed_pdf())

    node_types = {node.node_type for node in nodes}
    assert "layout_block" in node_types
    assert "table" in node_types
    assert "table_cell" in node_types
    assert "figure" in node_types

    table = next(node for node in nodes if node.node_type == "table")
    assert table.attributes["rows"] == 2
    assert table.attributes["columns"] == 2

    cell = next(node for node in nodes if node.node_type == "table_cell")
    assert cell.source_text in {"Benefit", "Limit", "Health", "500000"}
    assert cell.bbox["page_w"] == 320.0
    assert cell.bbox["page_h"] == 240.0

    figure = next(node for node in nodes if node.node_type == "figure")
    assert len(figure.artifact_sha256) == 64
