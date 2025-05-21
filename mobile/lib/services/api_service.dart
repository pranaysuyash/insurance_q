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
        // Force cache invalidation using timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        
        // Build the query payload according to the API's expected format
        Map<String, dynamic> data = {
          'query': query,
          '_cache_buster': timestamp.toString(), // Force cache invalidation
        };
        
        // Only add filters if a document ID is specified
        if (documentId != null) {
          print('Using document filter: $documentId');
          data['filters'] = {
            'document_id': documentId
          };
        } else {
          print('No document filter specified');
        }
        
        print('Sending query to: ${_dio.options.baseUrl}/query');
        print('Full query data: $data');
        
        // Use correct content type and improved error handling
        Response response = await _dio.post(
          '/query',
          data: data,
          options: Options(
            contentType: Headers.jsonContentType,
            // Accept any response status to debug
            validateStatus: (status) => true,
            receiveTimeout: const Duration(seconds: 60), // Longer timeout for queries
          ),
        );
        
        print('Response status: ${response.statusCode}');
        print('Response data type: ${response.data.runtimeType}');
        print('Response data: ${response.data}');
        
        // Log detailed response for debugging
        if (response.statusCode != 200) {
          print('ERROR RESPONSE: ${response.data}');
        }
        
        // Handle different response formats based on status code
        if (response.statusCode == 200) {
          final responseData = response.data;
          
          // Handle three potential response formats:
          
          // Format 1: Direct answer object
          if (responseData is Map<String, dynamic> && 
              responseData.containsKey('answer') && 
              !responseData.containsKey('status')) {
            print('Processing direct answer format');
            return responseData;
          }
          
          // Format 2: Status+result wrapper (most common and expected format)
          if (responseData is Map<String, dynamic> && 
              responseData.containsKey('status') && 
              responseData['status'] == 'success') {
            print('Processing status+result format');
            if (responseData.containsKey('result')) {
              final result = responseData['result'];
              if (result is Map<String, dynamic>) {
                return result;
              } else {
                print('WARNING: result is not a Map: ${result.runtimeType}');
                // Handle case where result is not a map but has valid content
                return {
                  'answer': 'The response format from the server was unexpected. Raw result: $result',
                  'sources': []
                };
              }
            } else {
              print('WARNING: success response missing result field');
              // Improved fallback for missing result field
              return {
                'answer': 'The server response was incomplete. Please try again.',
                'sources': []
              };
            }
          }
          
          // Format 3: Unknown but valid response - try to extract answer
          print('Processing unknown format, attempting extraction');
          if (responseData is Map<String, dynamic>) {
            // Try to extract answer and sources
            final Map<String, dynamic> result = {};
            if (responseData.containsKey('answer')) {
              result['answer'] = responseData['answer'];
            }
            if (responseData.containsKey('sources')) {
              result['sources'] = responseData['sources'];
            }
            if (result.isNotEmpty) {
              return result;
            }
          }
          
          // If all structured attempts fail, just return the raw response with error indication
          return {
            'answer': 'The system returned an unexpected response format. Please try again later.',
            'error': 'Unexpected response format',
            'debug_response': responseData.toString().substring(0, min(500, responseData.toString().length)),
          };
        } else if (response.statusCode == 500 && response.data is Map<String, dynamic>) {
          // Handle 500 errors, which may contain useful error information
          final error = response.data;
          String errorMessage = 'Server error';
          
          // Try to extract error details
          if (error.containsKey('detail')) {
            errorMessage = error['detail'];
            print('Server returned error: $errorMessage');
          }
          
          // Special case for RAG service 'result' missing error
          if (errorMessage.contains('result')) {
            print('RAG service missing result field error detected');
            return {
              'answer': 'I apologize, but there was a problem retrieving your policy information. This might be due to a temporary issue with the document processing system. Please try again in a few minutes.',
              'sources': [],
              'error': errorMessage,
            };
          }
          
          // Special case for RAG service errors
          if (errorMessage.contains('Error communicating with RAG service')) {
            print('RAG service communication error detected');
            
            // Try to extract nested JSON error if present
            if (errorMessage.contains('{') && errorMessage.contains('}')) {
              try {
                // Attempt to extract JSON from string
                final startIndex = errorMessage.indexOf('{');
                final endIndex = errorMessage.lastIndexOf('}') + 1;
                if (startIndex >= 0 && endIndex > startIndex) {
                  final jsonStr = errorMessage.substring(startIndex, endIndex);
                  
                  print('Trying to parse nested JSON error: $jsonStr');
                }
              } catch (e) {
                print('Failed to parse nested JSON error: $e');
              }
            }
          }
          
          // Return a friendlier error message to user
          return {
            'answer': 'I\'m sorry, but I couldn\'t process your question at this time. There seems to be a temporary issue with the AI service. Please try again later.',
            'sources': [],
            'error': errorMessage,
          };
        } else {
          throw DioException(
            requestOptions: RequestOptions(path: '/query'),
            response: response,
            type: DioExceptionType.badResponse,
            message: 'Server returned status code ${response.statusCode}',
          );
        }
      } catch (e) {
        // Log the full error for debugging
        print('Error with real query: $e');
        
        // For network errors (like connection refused), return a different error message
        if (e is DioException && 
            (e.type == DioExceptionType.connectionTimeout || 
             e.type == DioExceptionType.connectionError ||
             e.type == DioExceptionType.unknown)) {
          return {
            'answer': 'I\'m having trouble connecting to the AI service. Please check your network connection and try again.',
            'sources': [],
            'error': 'Connection error: ${e.message}',
          };
        }
        
        // For other errors, provide a meaningful message
        return {
          'answer': 'There was a problem processing your question. Please try again later.',
          'sources': [],
          'error': e.toString(),
        };
      }
    } catch (e) {
      print('Error with query: $e');
      return {'error': e.toString()};
    }
  }

  int min(int a, int b) {
    return a < b ? a : b;
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

  // This function checks if a document already exists with the same name
  Future<InsuranceDocument?> checkForDuplicateDocument(File file) async {
    final filename = file.path.split('/').last;
    return await _localStorageService.findDuplicateDocument(filename);
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