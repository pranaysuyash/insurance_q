"""Runtime document-intelligence capability registry.

This module reports capability truth without importing heavyweight model
packages or contacting providers. ``available`` means the current canonical
local path is usable or its required package is discoverable; it does not mean
corpus accuracy. Candidate and unavailable profiles remain visible so routing
cannot silently pretend that a specialist exists.
"""

from __future__ import annotations

import importlib.util
from typing import Any

from src.config.settings import settings


def _package_status(package: str, *, enabled: bool) -> dict[str, Any]:
    if not enabled:
        return {"status": "disabled", "package": package}
    if importlib.util.find_spec(package) is None:
        return {"status": "unavailable", "package": package}
    return {"status": "available", "package": package}


def capability_registry_snapshot() -> dict[str, Any]:
    """Return safe, non-secret capability/profile state for operators."""
    doctr = _package_status("doctr", enabled=True)
    docling = _package_status("docling", enabled=settings.docling_enabled)
    mineru = _package_status("magic_pdf", enabled=settings.mineru_enabled)
    surya = _package_status("surya", enabled=False)
    paddle = _package_status("paddleocr", enabled=False)
    openai_configured = bool(settings.openai_api_key.strip())
    ollama_configured = bool(settings.ollama_base_url and settings.ollama_chat_model)

    return {
        "registry_version": "document-capabilities.v1",
        "capabilities": {
            "native_text": {
                "status": "available",
                "profiles": ["pymupdf_native"],
                "evidence_tier": 2,
            },
            "sentence_segmentation": {
                "status": "available",
                "profiles": {
                    "conservative_source_segmenter": {
                        "status": "available",
                        "scope": "punctuation_and_exact_offsets_only",
                    }
                },
                "evidence_tier": 2,
                "quality_gate": "language_specific_boundary_benchmark_required",
            },
            "scanned_ocr": {
                "status": doctr["status"],
                "profiles": {"doctr": doctr},
                "evidence_tier": 2 if doctr["status"] == "available" else 0,
                "quality_gate": "synthetic_only_until_consented_corpus_benchmark",
            },
            "layout": {
                "status": "available",
                "profiles": {
                    "pymupdf_native": {"status": "available"},
                    "docling": docling,
                    "surya": surya,
                    "paddleocr": paddle,
                },
                "scope": "native_pdf_observation_only_by_default",
            },
            "reading_order": {
                "status": "available",
                "profiles": {
                    "pymupdf_native": {
                        "status": "available",
                        "scope": "emitted_block_order_not_quality_benchmarked",
                    },
                    "docling": docling,
                    "surya": surya,
                },
                "quality_gate": "multi_column_and_rotated_page_benchmark_required",
            },
            "headings_and_sections": {
                "status": "candidate",
                "profiles": {
                    "native_pdf_observation": {
                        "status": "not_implemented",
                        "scope": "layout_blocks_are_not_semantic_headings",
                    },
                    "docling": docling,
                    "surya": surya,
                    "paddleocr_pp_structure": paddle,
                },
                "quality_gate": "heading_boundary_and_hierarchy_benchmark_required",
            },
            "tables": {
                "status": "available",
                "profiles": {
                    "pymupdf_native": {"status": "available", "scope": "born_digital"},
                    "mineru": mineru,
                    "paddleocr_pp_structure": paddle,
                },
                "scope": "scanned_table_accuracy_requires_benchmark",
            },
            "key_value_extraction": {
                "status": "candidate",
                "profiles": {
                    "native_acroform": {
                        "status": "available",
                        "scope": "native_widgets_only",
                    },
                    "managed_form_parser": {"status": "candidate"},
                    "paddleocr_kie": paddle,
                },
                "quality_gate": "field_geometry_schema_and_owner_evidence_benchmark_required",
            },
            "selection_marks": {
                "status": "unavailable",
                "profiles": {
                    "managed_form_parser": {"status": "candidate"},
                    "paddleocr_kie": paddle,
                },
                "quality_gate": "checkbox_and_mark_detection_benchmark_required",
            },
            "forms": {
                "status": "available",
                "profiles": {"pymupdf_acroform": {"status": "available", "scope": "native_widgets"}},
                "scope": "scanned_key_value_and_selection_marks_pending",
            },
            "figures": {
                "status": "available",
                "profiles": {"page_artifact_preservation": {"status": "available"}},
                "scope": "derived_caption_or_chart_annotation_not_source_evidence",
            },
            "charts_and_diagrams": {
                "status": "candidate",
                "profiles": {
                    "page_artifact_preservation": {"status": "available"},
                    "vlm_reviewer": {"status": "candidate"},
                },
                "quality_gate": "bounded_annotation_fixture_and_human_review_required",
            },
            "image_understanding": {
                "status": "candidate",
                "profiles": {
                    "openai_vision": {
                        "status": "configured_unverified" if openai_configured else "not_configured",
                    },
                    "local_ollama": {
                        "status": "configured_unverified" if ollama_configured else "not_configured",
                    },
                    "document_vlm": {"status": "candidate"},
                },
                "quality_gate": "image_fixture_benchmark_privacy_review_and_derived_label_required",
            },
            "office_and_email_structure": {
                "status": "available",
                "profiles": {
                    "native_docx": {
                        "status": "available",
                        "scope": "paragraph_heading_table_cell_and_embedded_image_structure",
                    },
                    "native_html": {
                        "status": "available",
                        "scope": "headings_paragraphs_tables_cells_and_image_references",
                    },
                    "native_eml": {
                        "status": "available",
                        "scope": "headers_body_and_attachment_hashes",
                    },
                    "native_xlsx": {
                        "status": "available",
                        "scope": "worksheets_cells_formulas_and_embedded_image_hashes",
                    },
                    "native_pptx": {
                        "status": "available",
                        "scope": "slides_text_tables_and_embedded_image_hashes",
                    },
                    "docling": docling,
                    "unstructured": {"status": "candidate"},
                },
                "scope": "docx_html_eml_xlsx_pptx",
                "quality_gate": "additional_format_and_relationship_preservation_benchmark_required",
            },
            "vlm_annotation": {
                "status": "candidate",
                "profiles": {
                    "openai_vision": {
                        "status": "configured_unverified" if openai_configured else "not_configured",
                        "scope": "provider_and_image_contract_unverified",
                    },
                    "local_ollama": {
                        "status": "configured_unverified" if ollama_configured else "not_configured",
                        "scope": "current_chat_route_is_not_proof_of_image_support",
                    },
                    "mistral_ocr_annotations": {"status": "candidate"},
                    "gemini_document_understanding": {"status": "candidate"},
                },
                "quality_gate": "image_fixture_benchmark_and_provider_privacy_review_required",
            },
            "formulas": {
                "status": "candidate",
                "profiles": {"mineru": mineru, "specialist_vlm": {"status": "candidate"}},
                "quality_gate": "benchmark_and_license_review_required",
            },
            "handwriting": {
                "status": "unavailable",
                "profiles": {"managed_specialist": {"status": "candidate"}},
                "quality_gate": "manual_review_and_corpus_benchmark_required",
            },
            "multilingual": {
                "status": "routing_only",
                "profiles": {"unicode_script_observation": {"status": "available"}},
                "quality_gate": "script_level_ocr_accuracy_pending",
            },
        },
    }
