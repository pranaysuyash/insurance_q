import 'dart:io';
import 'package:dio/dio.dart';
import '../models/document_model.dart';
import 'local_storage_service.dart';

class ApiService {
  // Set your backend base URL here - only needed for query operations
  static const String baseUrl = 'http://192.168.1.12:8080'; // Your laptop's IP on the WiFi network

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 90),
    ),
  );

  final LocalStorageService _localStorageService = LocalStorageService();

  Future<Map<String, dynamic>> getHealth() async {
    // Just return a success response for now
    return {'status': 'healthy', 'mode': 'local_storage'};
  }

  Future<Map<String, dynamic>> uploadFile(File file) async {
    try {
      // Save the document locally
      final document = await _localStorageService.saveDocument(file);
      
      // Return a success response
      return {
        'message': 'File uploaded successfully',
        'document_id': document.id,
        'text': 'This is a sample text extracted from the document.',
      };
    } catch (e) {
      print('Error uploading file: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadDocument(File file) {
    return uploadFile(file);
  }

  Future<Map<String, dynamic>> askQuestion(String question) async {
    try {
      // In local storage mode, just return a mock response
      return {
        'answer': 'This is a mock answer to your question: $question',
        'sources': [
          {'text': 'Mock source 1', 'page_number': 1},
          {'text': 'Mock source 2', 'page_number': 2}
        ]
      };
    } catch (e) {
      print('Error asking question: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> queryDocument(String query, {String? documentId}) async {
    try {
      // Try to connect to backend for real answers
      try {
        // Build the query payload according to the API's expected format
        Map<String, dynamic> data = {
          'query': query,
        };
        
        // Only add filters if a document ID is specified
        if (documentId != null) {
          data['filters'] = {
            'document_id': documentId
          };
        }
        
        print('Sending query to: ${_dio.options.baseUrl}/query');
        print('Query data: $data');
        
        // Use correct content type and improved error handling
        Response response = await _dio.post(
          '/query',
          data: data,
          options: Options(
            contentType: Headers.jsonContentType,
            validateStatus: (status) => status! < 500, // Accept all non-500 responses for debugging
            receiveTimeout: const Duration(seconds: 30), // Longer timeout for queries
          ),
        );
        
        print('Response status: ${response.statusCode}');
        print('Response data: ${response.data}');
        
        // Handle different response formats
        final responseData = response.data;
        
        // New format has 'status' and 'result' fields
        if (responseData is Map<String, dynamic> && responseData.containsKey('status')) {
          if (responseData['status'] == 'success') {
            // Extract the result from the API response
            if (responseData.containsKey('result')) {
              return responseData['result'];
            } else {
              // Missing result field, construct a simple response
              return {
                'answer': responseData['answer'] ?? 'No answer provided',
                'sources': responseData['sources'] ?? []
              };
            }
          } else {
            return {'error': responseData['detail'] ?? 'Unknown error'};
          }
        }
        
        // Old format returns the result directly
        return responseData;
      } catch (e) {
        // Log the full error for debugging
        print('Using mock response for query: $e');
        
        // Fallback to mock response
        return {
          'answer': 'This is a mock answer to your query: $query',
          'sources': [
            {'text': 'Mock source 1', 'page_number': 1},
            {'text': 'Mock source 2', 'page_number': 2}
          ]
        };
      }
    } catch (e) {
      print('Error with query: $e');
      return {'error': e.toString()};
    }
  }

  Future<List<InsuranceDocument>> getDocuments() async {
    try {
      // Get documents from local storage
      return await _localStorageService.getDocuments();
    } catch (e) {
      print('Error getting documents: $e');
      return [];
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      // Delete document from local storage
      return await _localStorageService.deleteDocument(documentId);
    } catch (e) {
      print('Error deleting document: $e');
      return false;
    }
  }

  // This function checks if we have reached the document limit and
  // deletes the oldest document if necessary before uploading
  Future<Map<String, dynamic>> uploadDocumentWithLimitCheck(File file) async {
    try {
      // Get current documents
      final documents = await getDocuments();
      
      // Check if we've reached the limit (5 documents)
      if (documents.length >= 5) {
        // Find the oldest document by upload date
        documents.sort((a, b) => a.uploadedOn.compareTo(b.uploadedOn));
        final oldestDoc = documents.first;
        
        // Delete the oldest document
        final deleted = await deleteDocument(oldestDoc.id);
        if (!deleted) {
          return {
            'error': 'Failed to delete oldest document. Cannot upload new document.'
          };
        }
      }
      
      // Upload the new document
      return await uploadDocument(file);
    } catch (e) {
      return {'error': e.toString()};
    }
  }
} 