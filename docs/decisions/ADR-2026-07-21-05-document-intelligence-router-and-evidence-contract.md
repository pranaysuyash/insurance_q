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