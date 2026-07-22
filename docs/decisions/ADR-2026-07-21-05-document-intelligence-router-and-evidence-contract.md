# ADR-2026-07-21-05 Implementation Addendums

## Capability-Routing Workflow
1. **Capability Classification**: Use `classify_capabilities` from `document_intelligence.py` to determine native text/OCR/layout capabilities
2. **Specialist Routing**: Map capabilities to appropriate processing modules:
   - Native PDF/ayout/text → `src/ocr/native_pdf.py`
   - Forms → `src/ocr/native_office.py`
   - Tables/formula → `src/ocr/table_extractor.py` (to be created)
3. **Evidence Annotation**: Add `source_span_id` to each CIR node processed by specialists
4. **Encrypted Storage**: Route results through principal-key service before Hive storage

## Evidence Contract Updates
- CIR `nodes.retrieval_text` should include evidence citations
- `layout_json` must carry page-artifact metadata

## Benchmarking Plan
1. Initial tier (current): Native PDF/text validation
2. Mid-tier: Local OCR profile + table extractor
3. Enterprise: VLM integration with encrypted model runs

## Migration Sync
- Update `principal_key_service.dart` to require capability routing DAL:
```dart
Future<void> migrateBoxWithCapabilities({String boxName, Map<Capability, bool> routedSkills}) async {
  // Existing migration logic + capability-based routing
}
```

## Implementation update — sidecar page-artifact continuity (2026-07-22)

On-device OCR is a text recovery input, not a replacement source artifact.
When it recovers an image or scan-only PDF, the canonical service now renders
the original source into a PNG page artifact before queuing substrate
extraction. This preserves the worker contract: raw OCR remains out of the
queue payload, while persisted page artifacts provide the text/artifact pair
needed for cited review. Page-one mapping is intentionally conservative until
the mobile sidecar contract exposes authoritative per-page segmentation.

## Implementation update — native Office format expansion (2026-07-22)

The canonical route now includes native XLSX/XLSM and PPTX adapters alongside
DOCX, HTML, and EML. `openpyxl-native` preserves worksheet/cell coordinates,
data types, formula text, and embedded-image hashes; `python-pptx-native`
preserves slide text, tables/cells, and picture hashes. Both emit the existing
CIR and retain source/artifact hashes. The ten-case local evaluator passes with
zero unrun cases, establishing Tier 2 structural evidence.

This decision does not promote formula interpretation, scanned-table parsing,
semantic forms, handwriting, multilingual extraction, or VLM chart/image
interpretation. Those remain specialist benchmark gates with provenance,
uncertainty, privacy, licensing, latency, retry, and operator-recovery
requirements.
