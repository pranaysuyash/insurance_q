import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_model.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class LocalStorageService {
  static const String _documentsKey = 'local_documents_list';
  static const Uuid _uuid = Uuid();

  // Save a document file to local storage and store metadata in SharedPreferences
  Future<InsuranceDocument> saveDocument(File file, {Map<String, dynamic>? additionalMetadata}) async {
    final prefs = await SharedPreferences.getInstance();
    
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
      filename: fileName,
      uploadedOn: DateTime.now(),
      size: fileSize,
      status: 'completed',
      processingCompletedAt: DateTime.now(),
      localFilePath: localFilePath,
      // Add additional metadata if provided
      documentType: additionalMetadata?['document_type'],
      insurer: additionalMetadata?['insurer'],
    );
    
    // Get existing documents
    final documents = await getDocuments();
    
    // Add new document to the list
    documents.add(document);
    
    // Save the updated list back to SharedPreferences
    await _saveDocumentsList(documents);
    
    return document;
  }

  // Get all documents from SharedPreferences
  Future<List<InsuranceDocument>> getDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsList = prefs.getStringList(_documentsKey) ?? [];
    
    return documentsList
        .map((jsonStr) => InsuranceDocument.fromJsonString(jsonStr))
        .toList();
  }
  
  // Update an existing document
  Future<bool> updateDocument(InsuranceDocument updatedDocument) async {
    try {
      // Get all existing documents
      final documents = await getDocuments();
      
      // Find the index of the document to update
      final index = documents.indexWhere((doc) => doc.id == updatedDocument.id);
      
      // If document not found, return false
      if (index == -1) {
        return false;
      }
      
      // Replace the document at the found index
      documents[index] = updatedDocument;
      
      // Save the updated list back to SharedPreferences
      await _saveDocumentsList(documents);
      
      return true;
    } catch (e) {
      debugPrint('Error updating document: $e');
      return false;
    }
  }
  
  // Get a specific document by ID
  Future<InsuranceDocument?> getDocumentById(String documentId) async {
    final documents = await getDocuments();
    try {
      return documents.firstWhere((doc) => doc.id == documentId);
    } catch (e) {
      debugPrint('Document not found: $documentId');
      return null;
    }
  }
  
  // Delete a document from SharedPreferences and the local file system
  Future<bool> deleteDocument(String documentId) async {
    try {
      // Get existing documents
      final documents = await getDocuments();
      
      // Find the document to delete
      final documentToDelete = documents.firstWhere(
        (doc) => doc.id == documentId,
        orElse: () => throw Exception('Document not found'),
      );
      
      // Delete the local file if it exists
      if (documentToDelete.localFilePath != null) {
        final file = File(documentToDelete.localFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Remove the document from the list
      documents.removeWhere((doc) => doc.id == documentId);
      
      // Save the updated list back to SharedPreferences
      await _saveDocumentsList(documents);
      
      return true;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      return false;
    }
  }
  
  // Helper method to save the list of documents to SharedPreferences
  Future<void> _saveDocumentsList(List<InsuranceDocument> documents) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStrings = documents.map((doc) => doc.toJsonString()).toList();
    await prefs.setStringList(_documentsKey, jsonStrings);
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
        .replaceAll(RegExp(r'\(\d{4}-\d{2}-\d{2}\)$'), '') // Remove dates like (2023-05-01)
        .trim();
    
    return baseFilename;
  }
} 