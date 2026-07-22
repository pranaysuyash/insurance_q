"""Source-preserving native Office observations.

This adapter deliberately starts with DOCX because it is a common policy and
support-document input and has a stable local parser. It emits structural
observations into the existing CIR; it does not OCR images or infer semantic
insurance fields from labels.
"""

from __future__ import annotations

import hashlib
import io
from typing import Any

from docx import Document

from src.models.document_intelligence import CIRNode


def _node(
    *,
    node_id: str,
    node_type: str,
    source_text: str | None = None,
    parent_id: str | None = None,
    reading_order: int,
    attributes: dict[str, Any] | None = None,
    artifact_sha256: str | None = None,
) -> CIRNode:
    return CIRNode(
        node_id=node_id,
        node_type=node_type,
        page_number=1,
        source_text=source_text,
        retrieval_text=source_text,
        parent_id=parent_id,
        reading_order=reading_order,
        artifact_sha256=artifact_sha256,
        parser_name="python-docx-native",
        parser_version="python-docx-native.v1",
        attributes=attributes or {},
    )


def extract_native_docx_document(docx_bytes: bytes) -> dict[str, Any]:
    """Extract DOCX structure without flattening it into binary text."""

    source_hash = hashlib.sha256(docx_bytes).hexdigest()
    document = Document(io.BytesIO(docx_bytes))
    nodes: list[CIRNode] = [
        _node(
            node_id="page-1",
            node_type="page",
            reading_order=0,
            artifact_sha256=source_hash,
            attributes={"source": "docx_document", "page_model": "logical_document"},
        )
    ]
    text_parts: list[str] = []
    order = 1

    for paragraph_index, paragraph in enumerate(document.paragraphs):
        text = paragraph.text.strip()
        if not text:
            continue
        style_name = getattr(paragraph.style, "name", "") or ""
        is_heading = style_name.lower().startswith("heading")
        node_type = "heading" if is_heading else "text_block"
        node_id = f"page-1-{node_type}-{paragraph_index}"
        nodes.append(
            _node(
                node_id=node_id,
                node_type=node_type,
                source_text=text,
                parent_id="page-1",
                reading_order=order,
                artifact_sha256=source_hash,
                attributes={
                    "style_name": style_name,
                    "source": "docx_paragraph",
                    "heading_level": (
                        int(style_name.split()[-1])
                        if is_heading and style_name.split()[-1].isdigit()
                        else None
                    ),
                },
            )
        )
        text_parts.append(text)
        order += 1

    for table_index, table in enumerate(document.tables):
        table_id = f"page-1-table-{table_index}"
        rows = len(table.rows)
        columns = max((len(row.cells) for row in table.rows), default=0)
        nodes.append(
            _node(
                node_id=table_id,
                node_type="table",
                parent_id="page-1",
                reading_order=order,
                artifact_sha256=source_hash,
                attributes={
                    "rows": rows,
                    "columns": columns,
                    "source": "docx_table",
                },
            )
        )
        order += 1
        for row_index, row in enumerate(table.rows):
            for column_index, cell in enumerate(row.cells):
                text = cell.text.strip()
                if text:
                    text_parts.append(text)
                nodes.append(
                    _node(
                        node_id=f"{table_id}-cell-{row_index}-{column_index}",
                        node_type="table_cell",
                        source_text=text or None,
                        parent_id=table_id,
                        reading_order=order,
                        artifact_sha256=source_hash,
                        attributes={
                            "table_id": table_id,
                            "row_index": row_index,
                            "column_index": column_index,
                            "source": "docx_table_cell",
                        },
                    )
                )
                order += 1

    image_index = 0
    for relationship in document.part.rels.values():
        if "image" not in relationship.reltype:
            continue
        image_bytes = relationship.target_part.blob
        if not image_bytes:
            continue
        nodes.append(
            _node(
                node_id=f"page-1-figure-{image_index}",
                node_type="figure",
                parent_id="page-1",
                reading_order=order,
                artifact_sha256=hashlib.sha256(image_bytes).hexdigest(),
                attributes={
                    "source": "docx_relationship",
                    "relationship_id": relationship.rId,
                    "mime_type": relationship.target_part.content_type,
                },
            )
        )
        image_index += 1
        order += 1

    return {
        "full_text": "\n\n".join(text_parts),
        "page_texts": {1: "\n\n".join(text_parts)},
        "nodes": nodes,
        "source_artifact_sha256": source_hash,
        "parser_profile": "python-docx-native",
    }
