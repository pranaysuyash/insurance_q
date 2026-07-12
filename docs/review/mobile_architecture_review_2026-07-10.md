# Mobile Architecture Review 2026-07-10

## Scope

Mobile app only (`mobile/`). Web stack was ignored for this pass.

## Findings Addressed

- Backend failures no longer fabricate policy answers in production mode.
- Local and backend document identifiers are now tracked separately.
- The document storage limit now rejects uploads explicitly instead of deleting the oldest record.
- Document metadata persistence moved from SharedPreferences-only storage to a Hive-backed document box with legacy migration.
- Mobile operational state such as selected document, recent questions, last-uploaded document, and deletion history now lives in a Hive-backed app-state box.
- Query responses now preserve structured metadata such as citations and retrieval confidence.
- Production logging is muted by default through the app bootstrap guard.

## Implementation Notes

- `InsuranceDocument` now carries `remoteId`, `syncState`, `processingState`, and `schemaVersion`.
- `LocalStorageService` stores documents in `Hive` and migrates legacy `local_documents_list` entries on read.
- `AppStateRepository` stores selected document state, recent questions, last-uploaded document state, and deletion history in Hive.
- `ApiService.queryDocument()` resolves backend IDs before querying and returns an explicit unavailable state when a local-only document is not synced.
- `ApiService.uploadDocumentWithLimitCheck()` returns a `storage_limit_reached` error instead of silently deleting data.
- `QaAnswer` now preserves structured retrieval metadata.
- Browser-emulator validation surfaced and closed a mutability bug in the app-state list helpers, so recent questions and deletion history now persist correctly in web storage.

## Verification

- `flutter analyze`
- `flutter test -r expanded`
- Browser-emulator validation in Flutter web using a local `web-server` build and Chrome emulation.

Both passed after the storage and QA changes.

## Remaining Gaps

- The only remaining SharedPreferences path is the narrow legacy document-list migration bridge inside `LocalStorageService`.
- The app still has some presentation-layer debug logging outside the main API service.
- The demo fallback path still exists, but it is gated behind `BOOTSTRAP_POLICY_DEMO`.

## Follow-Up Path

1. Remove the legacy document-list migration bridge once old installs are no longer a concern.
2. Add redacted, role-specific logging for any remaining debug paths.
3. Replace demo fallback data with a dedicated demo flavor if product needs it long term.
