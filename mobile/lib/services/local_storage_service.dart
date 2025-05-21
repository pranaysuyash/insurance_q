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
  Future<InsuranceDocument> saveDocument(File file) async {
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
} 