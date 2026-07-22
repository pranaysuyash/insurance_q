"""Native, source-preserving adapters for lightweight document formats."""

from __future__ import annotations

import hashlib
import html
import re
from email import policy
from email.parser import BytesParser
from html.parser import HTMLParser
from typing import Any

from src.models.document_intelligence import CIRNode


def _node(
    *,
    node_id: str,
    node_type: str,
    text: str | None,
    order: int,
    parent_id: str = "page-1",
    attributes: dict[str, Any] | None = None,
    artifact_hash: str | None = None,
    parser_name: str,
) -> CIRNode:
    return CIRNode(
        node_id=node_id,
        node_type=node_type,
        page_number=1,
        source_text=text,
        retrieval_text=text,
        parent_id=parent_id,
        reading_order=order,
        artifact_sha256=artifact_hash,
        parser_name=parser_name,
        parser_version=f"{parser_name}.v1",
        attributes=attributes or {},
    )


class _HTMLStructureParser(HTMLParser):
    _TEXT_TAGS = {"h1", "h2", "h3", "h4", "h5", "h6", "p", "li", "caption"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.nodes: list[CIRNode] = []
        self.text_parts: list[str] = []
        self._stack: list[tuple[str, list[str], dict[str, Any]]] = []
        self._table_id: str | None = None
        self._row_index = -1
        self._column_index = 0
        self._order = 1

    @staticmethod
    def _clean(value: str) -> str:
        return re.sub(r"\s+", " ", html.unescape(value)).strip()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        attr_map = {key: value or "" for key, value in attrs}
        if tag == "table":
            self._table_id = f"page-1-table-{self._order}"
            self.nodes.append(
                _node(
                    node_id=self._table_id,
                    node_type="table",
                    text=None,
                    order=self._order,
                    attributes={"source": "html_table"},
                    parser_name="html-native",
                )
            )
            self._order += 1
        elif tag == "tr":
            self._row_index += 1
            self._column_index = 0
        elif tag in {"th", "td"}:
            self._stack.append((tag, [], attr_map))
        elif tag in self._TEXT_TAGS:
            self._stack.append((tag, [], attr_map))
        elif tag == "img":
            self.nodes.append(
                _node(
                    node_id=f"page-1-figure-{self._order}",
                    node_type="figure",
                    text=None,
                    order=self._order,
                    attributes={
                        "source": "html_image_reference",
                        "src": attr_map.get("src", ""),
                        "alt": attr_map.get("alt", ""),
                        "artifact_status": "reference_only",
                    },
                    parser_name="html-native",
                )
            )
            self._order += 1

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag == "table":
            self._table_id = None
            return
        if not self._stack or self._stack[-1][0] != tag:
            return
        _, parts, attrs = self._stack.pop()
        text = self._clean(" ".join(parts))
        if not text:
            return
        if tag in {"th", "td"} and self._table_id:
            self.nodes.append(
                _node(
                    node_id=f"{self._table_id}-cell-{self._row_index}-{self._column_index}",
                    node_type="table_cell",
                    text=text,
                    order=self._order,
                    parent_id=self._table_id,
                    attributes={
                        "table_id": self._table_id,
                        "row_index": self._row_index,
                        "column_index": self._column_index,
                        "header": tag == "th",
                        "source": "html_table_cell",
                    },
                    parser_name="html-native",
                )
            )
            self._column_index += 1
            self._order += 1
        else:
            node_type = "heading" if tag.startswith("h") else "list_item" if tag == "li" else "text_block"
            self.nodes.append(
                _node(
                    node_id=f"page-1-{node_type}-{self._order}",
                    node_type=node_type,
                    text=text,
                    order=self._order,
                    attributes={
                        "source": "html_element",
                        "tag": tag,
                        "heading_level": int(tag[1:]) if tag.startswith("h") else None,
                        **attrs,
                    },
                    parser_name="html-native",
                )
            )
            self._order += 1
        self.text_parts.append(text)

    def handle_data(self, data: str) -> None:
        if self._stack:
            self._stack[-1][1].append(data)


def extract_native_html_document(html_bytes: bytes) -> dict[str, Any]:
    """Extract HTML structure without fetching external resources."""

    source_hash = hashlib.sha256(html_bytes).hexdigest()
    parser = _HTMLStructureParser()
    parser.feed(html_bytes.decode("utf-8", errors="replace"))
    text = "\n\n".join(parser.text_parts)
    nodes = [
        _node(
            node_id="page-1",
            node_type="page",
            text=None,
            order=0,
            artifact_hash=source_hash,
            attributes={"source": "html_document"},
            parser_name="html-native",
        ),
        *parser.nodes,
    ]
    return {
        "full_text": text,
        "page_texts": {1: text},
        "nodes": nodes,
        "source_artifact_sha256": source_hash,
        "parser_profile": "html-native",
    }


def extract_native_eml_document(eml_bytes: bytes) -> dict[str, Any]:
    """Extract an RFC822 message body and attachment lineage."""

    source_hash = hashlib.sha256(eml_bytes).hexdigest()
    message = BytesParser(policy=policy.default).parsebytes(eml_bytes)
    body_parts: list[str] = []
    attachments: list[tuple[str, str, bytes]] = []
    for part in message.walk():
        if part.is_multipart():
            continue
        payload = part.get_payload(decode=True) or b""
        filename = part.get_filename()
        if filename or part.get_content_disposition() == "attachment":
            attachments.append((filename or "attachment", part.get_content_type(), payload))
            continue
        if part.get_content_type() == "text/plain":
            body_parts.append(part.get_content())
        elif part.get_content_type() == "text/html" and not body_parts:
            body_parts.append(extract_native_html_document(payload)["full_text"])

    body = "\n\n".join(part.strip() for part in body_parts if part.strip())
    subject = str(message.get("subject", "")).strip()
    nodes = [
        _node(
            node_id="page-1",
            node_type="page",
            text=None,
            order=0,
            artifact_hash=source_hash,
            attributes={"source": "eml_message"},
            parser_name="email-native",
        )
    ]
    order = 1
    if subject:
        nodes.append(
            _node(
                node_id="page-1-subject",
                node_type="heading",
                text=subject,
                order=order,
                attributes={"source": "email_header", "header_name": "subject"},
                parser_name="email-native",
            )
        )
        order += 1
    if body:
        nodes.append(
            _node(
                node_id="page-1-body",
                node_type="text_block",
                text=body,
                order=order,
                attributes={
                    "source": "email_body",
                    "from": str(message.get("from", "")),
                    "to": str(message.get("to", "")),
                },
                parser_name="email-native",
            )
        )
        order += 1
    for index, (filename, content_type, payload) in enumerate(attachments):
        node_type = "figure" if content_type.startswith("image/") else "attachment"
        nodes.append(
            _node(
                node_id=f"page-1-attachment-{index}",
                node_type=node_type,
                text=None,
                order=order,
                artifact_hash=hashlib.sha256(payload).hexdigest(),
                attributes={
                    "source": "email_attachment",
                    "filename": filename,
                    "mime_type": content_type,
                    "size_bytes": len(payload),
                },
                parser_name="email-native",
            )
        )
        order += 1
    return {
        "full_text": body,
        "page_texts": {1: body},
        "nodes": nodes,
        "source_artifact_sha256": source_hash,
        "parser_profile": "email-native",
    }
