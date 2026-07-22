"""Deterministic native-PDF layout, table, and image observations.

This adapter intentionally handles only evidence available in the PDF itself.
It does not OCR scans and does not infer semantic fields. It is the low-cost
specialist profile used before optional OCR/VLM routes.
"""

from __future__ import annotations

import hashlib
from typing import Any

import fitz

from src.models.document_intelligence import CIRNode


def _bbox(rect: tuple[float, float, float, float], page: fitz.Page) -> dict[str, float]:
    x0, y0, x1, y1 = rect
    return {
        "x": float(x0),
        "y": float(y0),
        "w": float(max(0.0, x1 - x0)),
        "h": float(max(0.0, y1 - y0)),
        "page_w": float(page.rect.width),
        "page_h": float(page.rect.height),
    }


def _node(
    *,
    node_id: str,
    node_type: str,
    page_number: int,
    page: fitz.Page,
    parser_version: str,
    source_text: str | None = None,
    bbox: tuple[float, float, float, float] | None = None,
    artifact_sha256: str | None = None,
    reading_order: int | None = None,
    parent_id: str | None = None,
    attributes: dict[str, Any] | None = None,
) -> CIRNode:
    return CIRNode(
        node_id=node_id,
        node_type=node_type,
        page_number=page_number,
        source_text=source_text,
        retrieval_text=source_text,
        bbox=_bbox(bbox, page) if bbox else None,
        artifact_sha256=artifact_sha256,
        reading_order=reading_order,
        parent_id=parent_id,
        parser_name="pymupdf_native",
        parser_version=parser_version,
        attributes=attributes or {},
    )


def extract_native_pdf_nodes(
    pdf_bytes: bytes,
    *,
    parser_version: str = "pymupdf-native.v1",
) -> list[CIRNode]:
    """Extract observable layout/table/cell/figure nodes from a PDF.

    Table detection failures are recorded by omission because PyMuPDF's table
    detector is a capability probe, not a reason to fail native text
    extraction. Callers retain the parser profile and can route the document
    to a specialist profile when the benchmark requires it.
    """

    nodes: list[CIRNode] = []
    document = fitz.open(stream=pdf_bytes, filetype="pdf")
    try:
        for page_index, page in enumerate(document, start=1):
            block_order = 0
            for block in page.get_text("blocks"):
                x0, y0, x1, y1, text, *_ = block
                if not str(text).strip():
                    continue
                nodes.append(
                    _node(
                        node_id=f"page-{page_index}-layout-{block_order}",
                        node_type="layout_block",
                        page_number=page_index,
                        page=page,
                        parser_version=parser_version,
                        source_text=str(text).strip(),
                        bbox=(x0, y0, x1, y1),
                        reading_order=block_order,
                        attributes={"source": "pymupdf.get_text.blocks"},
                    )
                )
                block_order += 1

            try:
                tables = page.find_tables().tables
            except (AttributeError, RuntimeError, ValueError):
                tables = []

            for table_index, table in enumerate(tables):
                matrix = table.extract()
                table_id = f"page-{page_index}-table-{table_index}"
                column_count = max((len(row) for row in matrix), default=0)
                nodes.append(
                    _node(
                        node_id=table_id,
                        node_type="table",
                        page_number=page_index,
                        page=page,
                        parser_version=parser_version,
                        bbox=tuple(table.bbox),
                        reading_order=block_order,
                        attributes={
                            "rows": len(matrix),
                            "columns": column_count,
                            "matrix": matrix,
                            "detector": "pymupdf.find_tables",
                        },
                    )
                )
                for row_index, row in enumerate(matrix):
                    for column_index, value in enumerate(row):
                        cell_index = row_index * max(column_count, 1) + column_index
                        if cell_index >= len(table.cells):
                            continue
                        cell_bbox = table.cells[cell_index]
                        nodes.append(
                            _node(
                                node_id=f"{table_id}-cell-{row_index}-{column_index}",
                                node_type="table_cell",
                                page_number=page_index,
                                page=page,
                                parser_version=parser_version,
                                source_text=str(value).strip() if value is not None else None,
                                bbox=tuple(cell_bbox) if cell_bbox else None,
                                reading_order=block_order,
                                parent_id=table_id,
                                attributes={
                                    "table_id": table_id,
                                    "row_index": row_index,
                                    "column_index": column_index,
                                },
                            )
                        )
                        block_order += 1

            for image_index, image in enumerate(page.get_images(full=True)):
                xref = image[0]
                try:
                    extracted = document.extract_image(xref)
                    image_bytes = extracted.get("image", b"")
                    if not image_bytes:
                        continue
                    rects = page.get_image_rects(xref)
                except (KeyError, RuntimeError, ValueError):
                    continue
                for rect_index, rect in enumerate(rects):
                    nodes.append(
                        _node(
                            node_id=f"page-{page_index}-figure-{image_index}-{rect_index}",
                            node_type="figure",
                            page_number=page_index,
                            page=page,
                            parser_version=parser_version,
                            bbox=(rect.x0, rect.y0, rect.x1, rect.y1),
                            artifact_sha256=hashlib.sha256(image_bytes).hexdigest(),
                            reading_order=block_order,
                            attributes={
                                "source": "pymupdf.get_images",
                                "xref": xref,
                                "mime_type": extracted.get("ext"),
                            },
                        )
                    )
                    block_order += 1

            # AcroForm widgets are deterministic structure present in the PDF
            # itself. Preserve the field identity, value, type, flags, and
            # geometry as evidence; do not infer semantics from the label.
            try:
                widgets = list(page.widgets() or [])
            except (AttributeError, RuntimeError, ValueError):
                widgets = []
            for field_index, widget in enumerate(widgets):
                rect = widget.rect
                field_value = getattr(widget, "field_value", None)
                field_name = getattr(widget, "field_name", None)
                field_type = getattr(widget, "field_type_string", None)
                nodes.append(
                    _node(
                        node_id=f"page-{page_index}-form-field-{field_index}",
                        node_type="form_field",
                        page_number=page_index,
                        page=page,
                        parser_version=parser_version,
                        source_text=str(field_value) if field_value not in (None, "") else None,
                        bbox=(rect.x0, rect.y0, rect.x1, rect.y1),
                        reading_order=block_order,
                        attributes={
                            "field_name": field_name,
                            "field_type": field_type,
                            "field_flags": getattr(widget, "field_flags", None),
                            "field_value": field_value,
                            "source": "pymupdf.widgets",
                        },
                    )
                )
                block_order += 1
    finally:
        document.close()

    return nodes
