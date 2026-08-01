import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import '../config/app_config.dart';
import '../models/document_model.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'encrypted_attachment_store.dart';

class LocalStorageService {
  static const String legacyDocumentsKey = 'local_documents_list';
  static const String documentsBoxName = 'documents_box';

  /// The only record injected by the explicit development demo mode. Remove it
  /// on a production-capable build so beta/demo upgrades cannot present sample
  /// policy data as a customer's real coverage.
  static const String bundledDemoDocumentId =
      '3022ffcb-86c5-42ae-ae9f-2d6e00025631';
  static const Uuid _uuid = Uuid();

  Box<String> get _documentsBox => Hive.box<String>(documentsBoxName);

  // Save a document file to local storage and persist metadata in Hive.
  Future<InsuranceDocument> saveDocument(File file,
      {Map<String, dynamic>? additionalMetadata,
      String? remoteId,
      String syncState = 'synced',
      String processingState = 'ready',
      String? processingConsentVersion,
      String? status}) async {
    // Create a unique ID for the document
    final docId = _uuid.v4();

    final fileName = path.basename(file.path);

    // CW-P0-002: Store in principal-scoped attachments directory with
    // opaque filename instead of global documents directory.
    final localFilePath = await EncryptedAttachmentStore.copyFrom(
      documentId: docId,
      sourceFile: file,
    );
    if (localFilePath == null) {
      throw StateError(
        'Cannot save document: no active workspace. '
        'Ensure HiveWorkspaceService.openForActivePrincipal() was called.',
      );
    }

    // Get the file size
    final fileSize = await File(localFilePath).length();

    // Create a document object
    final document = InsuranceDocument(
      id: docId,
      remoteId: remoteId,
      filename: fileName,
      uploadedOn: DateTime.now(),
      size: fileSize,
      status: status ?? (syncState == 'synced' ? 'completed' : 'pending'),
      syncState: syncState,
      processingState: processingState,
      processingConsentVersion: processingConsentVersion,
      processingCompletedAt: DateTime.now(),
      localFilePath: localFilePath,
      // Add additional metadata if provided
      documentType: additionalMetadata?['document_type'],
      insurer: additionalMetadata?['insurer'],
    );

    await _documentsBox.put(docId, document.toJsonString());

    return document;
  }

  /// Persist a web-selected document's bytes to disk and record metadata.
  ///
  /// Audit 5 P0.2: The previous implementation discarded the bytes and set
  /// [InsuranceDocument.localFilePath] to null, causing the retry queue to
  /// mark the document as failed (no file to upload). The bytes are now
  /// written to the principal-scoped attachments directory so
  /// [retryPendingUploads] can replay them.
  Future<InsuranceDocument> saveWebDocument(
    String filename,
    Uint8List bytes, {
    Map<String, dynamic>? additionalMetadata,
    String? remoteId,
    String syncState = 'synced',
    String processingState = 'ready',
    String? processingConsentVersion,
    String? status,
  }) async {
    final docId = _uuid.v4();

    // CW-P0-002: Persist bytes in principal-scoped attachments directory
    // with opaque filename.
    final localFilePath = await EncryptedAttachmentStore.write(
      documentId: docId,
      originalFilename: filename,
      bytes: bytes,
    );
    if (localFilePath == null) {
      throw StateError(
        'Cannot save web document: no active workspace. '
        'Ensure HiveWorkspaceService.openForActivePrincipal() was called.',
      );
    }

    final document = InsuranceDocument(
      id: docId,
      remoteId: remoteId,
      filename: filename,
      uploadedOn: DateTime.now(),
      size: bytes.length,
      status: status ?? (syncState == 'synced' ? 'completed' : 'pending'),
      syncState: syncState,
      processingState: processingState,
      processingConsentVersion: processingConsentVersion,
      processingCompletedAt: DateTime.now(),
      localFilePath: localFilePath,
      documentType: additionalMetadata?['document_type'],
      insurer: additionalMetadata?['insurer'],
    );

    await _documentsBox.put(docId, document.toJsonString());
    return document;
  }

  // Get all documents from local storage
  Future<List<InsuranceDocument>> getDocuments() async {
    if (!AppConfig.bootstrapPolicyDemo &&
        _documentsBox.containsKey(bundledDemoDocumentId)) {
      await _documentsBox.delete(bundledDemoDocumentId);
    }
    final entries = _documentsBox.values.toList();

    if (entries.isEmpty) {
      // Keep a one-time compatibility bridge for older SharedPreferences
      // installs until they have been migrated into Hive.
      final prefs = await SharedPreferences.getInstance();
      final legacyEntries = prefs.getStringList(legacyDocumentsKey) ?? [];
      if (legacyEntries.isNotEmpty) {
        for (final raw in legacyEntries) {
          final doc = InsuranceDocument.fromJsonString(raw);
          await _documentsBox.put(doc.id, doc.toJsonString());
        }
        await prefs.remove(legacyDocumentsKey);
        return _documentsBox.values
            .map((jsonStr) => InsuranceDocument.fromJsonString(jsonStr))
            .toList();
      }
    }

    if (entries.isEmpty && AppConfig.bootstrapPolicyDemo) {
      final demoDocument = InsuranceDocument(
        id: bundledDemoDocumentId,
        remoteId: bundledDemoDocumentId,
        filename: 'policy.pdf',
        uploadedOn: DateTime.parse('2026-07-08T13:10:22.277452'),
        documentType: 'Health Insurance',
        insurer: 'ICICI Lombard General Insurance Company Limited',
        status: 'completed',
        syncState: 'synced',
        processingState: 'ready',
        processingCompletedAt: DateTime.parse('2026-07-08T13:10:22.277452'),
        size: 550955,
        localFilePath: null,
        policyHolders: [
          PolicyHolder(
            name: 'Aarav Mehta',
            dob: '15-Mar-1985',
            relationship: 'SELF',
          ),
          PolicyHolder(
            name: 'Priya Mehta',
            dob: '22-Jul-1987',
            relationship: 'SPOUSE',
          ),
          PolicyHolder(
            name: 'Anika Mehta',
            dob: '10-Nov-2019',
            relationship: 'DAUGHTER',
          ),
        ],
      );

      await _documentsBox.put(demoDocument.id, demoDocument.toJsonString());
      return [demoDocument];
    }

    if (entries.isEmpty) {
      return [];
    }

    return entries
        .map((jsonStr) => InsuranceDocument.fromJsonString(jsonStr))
        .toList();
  }

  // Update an existing document
  Future<bool> updateDocument(InsuranceDocument updatedDocument) async {
    try {
      if (!_documentsBox.containsKey(updatedDocument.id)) {
        return false;
      }

      await _documentsBox.put(
          updatedDocument.id, updatedDocument.toJsonString());

      return true;
    } catch (e) {
      debugPrint('Error updating document: $e');
      return false;
    }
  }

  /// Reconcile a server-owned document into the active principal's local
  /// metadata cache. A remote-only document has no local source file; its
  /// server ID remains the stable identity for detail, query, and deletion.
  Future<InsuranceDocument> upsertRemoteDocument(
      InsuranceDocument remoteDocument) async {
    final remoteId = remoteDocument.remoteId ?? remoteDocument.id;
    final existing = await getDocumentById(remoteId);
    final merged = InsuranceDocument(
      id: existing?.id ?? _uuid.v4(),
      remoteId: remoteId,
      filename: remoteDocument.filename,
      uploadedOn: remoteDocument.uploadedOn,
      documentType: remoteDocument.documentType ?? existing?.documentType,
      insurer: remoteDocument.insurer ?? existing?.insurer,
      status: remoteDocument.status,
      syncState: 'synced',
      processingState: remoteDocument.processingState,
      processingConsentVersion: remoteDocument.processingConsentVersion ??
          existing?.processingConsentVersion,
      schemaVersion: remoteDocument.schemaVersion,
      processingCompletedAt: remoteDocument.processingCompletedAt ??
          existing?.processingCompletedAt,
      size: remoteDocument.size ?? existing?.size,
      localFilePath: existing?.localFilePath,
      policyHolders: existing?.policyHolders,
    );
    await _documentsBox.put(merged.id, merged.toJsonString());
    return merged;
  }

  /// Persist a server-owned source file locally without putting document
  /// bytes into Hive. The existing local identity and extracted metadata stay
  /// stable so reconciliation cannot create a duplicate document.
  Future<InsuranceDocument> cacheRemoteSource(
      InsuranceDocument document, Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw StateError('Downloaded source document was empty');
    }
    // CW-P0-002: Store in principal-scoped attachments directory.
    final localPath = await EncryptedAttachmentStore.write(
      documentId: document.id,
      originalFilename: document.filename,
      bytes: bytes,
    );
    if (localPath == null) {
      throw StateError(
        'Cannot cache remote source: no active workspace. '
        'Ensure HiveWorkspaceService.openForActivePrincipal() was called.',
      );
    }
    final cached = InsuranceDocument(
      id: document.id,
      remoteId: document.remoteId,
      filename: document.filename,
      uploadedOn: document.uploadedOn,
      documentType: document.documentType,
      insurer: document.insurer,
      status: document.status,
      syncState: document.syncState,
      processingState: document.processingState,
      processingConsentVersion: document.processingConsentVersion,
      schemaVersion: document.schemaVersion,
      processingCompletedAt: document.processingCompletedAt,
      size: bytes.length,
      localFilePath: localPath,
      policyHolders: document.policyHolders,
    );
    await _documentsBox.put(cached.id, cached.toJsonString());
    return cached;
  }

  /// Remove temporary cached source files that this service owns.
  ///
  /// P0.5: Only deletes the CoverWise subtree under the temp directory,
  /// not the entire application temp directory which may contain files
  /// owned by file pickers, downloads, image processing, or other plugins.
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cwDir = Directory('${tempDir.path}/coverwise');
      if (await cwDir.exists()) {
        await cwDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing CoverWise cache directory: $e');
    }
  }

  // Get a specific document by ID
  Future<InsuranceDocument?> getDocumentById(String documentId) async {
    try {
      final byLocalId = _documentsBox.get(documentId);
      if (byLocalId != null) {
        return InsuranceDocument.fromJsonString(byLocalId);
      }
      for (final raw in _documentsBox.values) {
        final doc = InsuranceDocument.fromJsonString(raw);
        if (doc.remoteId == documentId) {
          return doc;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Document not found: $documentId');
      return null;
    }
  }

  Future<String?> getBackendDocumentId(String documentId) async {
    final document = await getDocumentById(documentId);
    if (document == null) {
      return documentId;
    }
    return document.remoteId;
  }

  /// Archive a document: mark it as archived so it no longer appears in the
  /// active document list but can be restored later. The local file is kept.
  Future<bool> archiveDocument(String documentId) async {
    try {
      final doc = await getDocumentById(documentId);
      if (doc == null) return false;
      final archived = doc.copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
      );
      return updateDocument(archived);
    } catch (e) {
      debugPrint('Error archiving document: $e');
      return false;
    }
  }

  /// Restore an archived document back to the active list.
  Future<bool> restoreDocument(String documentId) async {
    try {
      final doc = await getDocumentById(documentId);
      if (doc == null) return false;
      final restored = doc.copyWith(
        isArchived: false,
        archivedAt: null,
      );
      return updateDocument(restored);
    } catch (e) {
      debugPrint('Error restoring document: $e');
      return false;
    }
  }

  /// Count how many documents are archived.
  Future<int> archivedDocumentCount() async {
    try {
      final docs = await getDocuments();
      return docs.where((d) => d.isArchived).length;
    } catch (e) {
      debugPrint('Error counting archived documents: $e');
      return 0;
    }
  }

  /// Count how many active (non-archived) documents exist.
  Future<int> activeDocumentCount() async {
    try {
      final docs = await getDocuments();
      return docs.where((d) => !d.isArchived).length;
    } catch (e) {
      debugPrint('Error counting active documents: $e');
      return 0;
    }
  }

  // Delete a document from local storage and the local file system
  Future<bool> deleteDocument(String documentId) async {
    try {
      final documentToDelete = await getDocumentById(documentId);
      if (documentToDelete == null) {
        return false;
      }

      // CW-P0-002: Use safeDelete with path containment validation.
      // Never delete using a raw stored path — verify it's inside the
      // principal's attachments directory first.
      if (documentToDelete.localFilePath != null) {
        final deleted = await EncryptedAttachmentStore.safeDelete(
          documentToDelete.localFilePath!,
        );
        if (!deleted) {
          debugPrint(
            'CW-P0-002: Refused to delete ${documentToDelete.localFilePath} — '
            'path outside principal attachments directory',
          );
        }
      }

      await _documentsBox.delete(documentToDelete.id);

      return true;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      return false;
    }
  }

  // Check if a document with the same filename already exists
  Future<InsuranceDocument?> findDuplicateDocument(String filename) async {
    final documents = await getDocuments();

    // First check for exact filename match
    for (final doc in documents) {
      if (doc.filename.toLowerCase() == filename.toLowerCase()) {
        return doc;
      }
    }

    // Then check for similar filenames (ignoring version numbers or timestamps)
    // This handles cases like "policy_v1.pdf" and "policy_v2.pdf"
    final baseFilename = _getBaseFilename(filename);
    if (baseFilename.isNotEmpty) {
      for (final doc in documents) {
        final docBaseFilename = _getBaseFilename(doc.filename);
        if (docBaseFilename == baseFilename) {
          return doc;
        }
      }
    }

    return null; // No duplicate found
  }

  // Helper to extract base filename by removing version numbers and common suffixes
  String _getBaseFilename(String filename) {
    // Remove file extension
    final withoutExtension = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;

    // Remove common patterns like _v1, -2, (2023-05-01), etc.
    final baseFilename = withoutExtension
        .replaceAll(RegExp(r'[-_]v\d+$'), '') // Remove _v1, -v2, etc.
        .replaceAll(RegExp(r'[-_]rev\d+$'), '') // Remove _rev1, -rev2
        .replaceAll(RegExp(r'[-_]\d+$'), '') // Remove _1, -2, etc.
        .replaceAll(RegExp(r'\(\d{4}-\d{2}-\d{2}\)$'),
            '') // Remove dates like (2023-05-01)
        .trim();

    return baseFilename;
  }

  Future<int> countDocuments() async {
    return _documentsBox.length;
  }

  Future<List<InsuranceDocument>> getPendingUploads() async {
    final documents = await getDocuments();
    return documents
        .where((document) =>
            document.remoteId == null && document.syncState == 'pending_upload')
        .toList();
  }
}
