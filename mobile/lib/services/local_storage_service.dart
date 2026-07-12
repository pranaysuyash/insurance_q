import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/document_model.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String legacyDocumentsKey = 'local_documents_list';
  static const String documentsBoxName = 'documents_box';
  static const Uuid _uuid = Uuid();

  Box<String> get _documentsBox => Hive.box<String>(documentsBoxName);

  // Save a document file to local storage and persist metadata in Hive.
  Future<InsuranceDocument> saveDocument(File file,
      {Map<String, dynamic>? additionalMetadata,
      String? remoteId,
      String syncState = 'synced',
      String processingState = 'ready',
      String? status}) async {
    // Create a unique ID for the document
    final docId = _uuid.v4();

    // Get the app's documents directory
    final directory = await getApplicationDocumentsDirectory();
    final fileName = path.basename(file.path);

    // Copy the file to our app's documents directory with a unique name
    final localFilePath = path.join(directory.path, '${docId}_$fileName');
    await file.copy(localFilePath);

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
      processingCompletedAt: DateTime.now(),
      localFilePath: localFilePath,
      // Add additional metadata if provided
      documentType: additionalMetadata?['document_type'],
      insurer: additionalMetadata?['insurer'],
    );

    await _documentsBox.put(docId, document.toJsonString());

    return document;
  }

  // Get all documents from local storage
  Future<List<InsuranceDocument>> getDocuments() async {
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
        id: '3022ffcb-86c5-42ae-ae9f-2d6e00025631',
        remoteId: '3022ffcb-86c5-42ae-ae9f-2d6e00025631',
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
            name: 'Pranay Suyash',
            dob: '10-May-1988',
            relationship: 'SELF',
          ),
          PolicyHolder(
            name: 'Diksha Sinha',
            dob: '02-Aug-1992',
            relationship: 'SPOUSE',
          ),
          PolicyHolder(
            name: 'Advay Sinha',
            dob: '28-May-2023',
            relationship: 'SON',
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

  // Delete a document from local storage and the local file system
  Future<bool> deleteDocument(String documentId) async {
    try {
      final documentToDelete = await getDocumentById(documentId);
      if (documentToDelete == null) {
        return false;
      }

      // Delete the local file if it exists
      if (documentToDelete.localFilePath != null) {
        final file = File(documentToDelete.localFilePath!);
        if (await file.exists()) {
          await file.delete();
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
}
