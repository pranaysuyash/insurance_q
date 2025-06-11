import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import '../models/document_model.dart';
import 'local_storage_service.dart';
import 'session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Set your backend base URL here - only needed for query operations
  // static const String baseUrl = 'http://192.168.1.12:8080'; // Your laptop's IP on the WiFi network
  // static const String baseUrl = 'http://172.21.0.237:8080'; // Your laptop's IP on the WiFi network
  // static const String baseUrl = 'https://insurance-frontend-app.azurewebsites.net'; // Old Azure backend (deprecated)
  // static const String baseUrl = 'https://8ud4pyy9mc.ap-south-1.awsapprunner.com'; // Previous AWS deployment
  // static const String baseUrl = 'https://nrmmvtpyaf.ap-south-1.awsapprunner.com'; // Previous AWS App Runner backend
  static const String baseUrl = 'https://aa2485vt7t.ap-south-1.awsapprunner.com'; // Latest AWS App Runner backend with anti-abuse system

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

  Future<Map<String, dynamic>> uploadFile(File file, {String? email, String? phone}) async {
    try {
      // Get session ID for anti-abuse tracking
      final sessionId = await SessionService.getSessionId();
      
      // Try to upload to backend first for real processing
      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path),
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
        });
        
        final response = await _dio.post(
          '/documents/upload',
          data: formData,
          options: Options(
            headers: {
              'X-Session-ID': sessionId,
            },
            contentType: 'multipart/form-data',
          ),
        );
        
        if (response.statusCode == 200) {
          // Backend upload successful
          final responseData = response.data;
          
          // Also save locally for offline access
          final documentType = _inferDocumentType(file.path);
          final insurerInfo = _inferInsurerInfo(file.path);
          
          final baseDocument = {
            'document_type': documentType,
            'insurer': insurerInfo['insurer'],
          };
          
          await _localStorageService.saveDocument(file, additionalMetadata: baseDocument);
          
          return responseData;
        } else if (response.statusCode == 429) {
          // Rate limit exceeded
          final errorData = response.data;
          return {
            'error': 'rate_limit_exceeded',
            'message': errorData['detail'] ?? 'Upload limit exceeded. Please try again later.',
            'retry_after': errorData['retry_after'],
          };
        } else {
          throw DioException(
            requestOptions: RequestOptions(path: '/documents/upload'),
            response: response,
            type: DioExceptionType.badResponse,
          );
        }
      } catch (e) {
        print('Backend upload failed, falling back to local storage: $e');
        
        // Check if it's a rate limit error
        if (e is DioException && e.response?.statusCode == 429) {
          final errorData = e.response?.data;
          return {
            'error': 'rate_limit_exceeded',
            'message': errorData?['detail'] ?? 'Upload limit exceeded. Please try again later.',
            'retry_after': errorData?['retry_after'],
          };
        }
        
        // Fall back to local storage for offline functionality
        final documentType = _inferDocumentType(file.path);
        final insurerInfo = _inferInsurerInfo(file.path);
        
        final baseDocument = {
          'document_type': documentType,
          'insurer': insurerInfo['insurer'],
        };
        
        final document = await _localStorageService.saveDocument(file, additionalMetadata: baseDocument);
        
        // Try to extract policy holders
        final policyHolders = await extractPolicyHolders(document.id);
        
        return {
          'message': 'File uploaded successfully (offline mode)',
          'document_id': document.id,
          'document_type': documentType,
          'insurer': insurerInfo['insurer'],
          'policy_holders': policyHolders,
          'text': 'This is a sample text extracted from the document.',
          'offline_mode': true,
        };
      }
    } catch (e) {
      print('Error uploading file: $e');
      return {'error': e.toString()};
    }
  }

  String _inferDocumentType(String filePath) {
    final fileName = filePath.toLowerCase();
    
    // Infer document type from filename
    if (fileName.contains('health') || fileName.contains('medical')) {
      return 'Health Insurance';
    } else if (fileName.contains('auto') || fileName.contains('car') || fileName.contains('vehicle')) {
      return 'Auto Insurance';
    } else if (fileName.contains('home') || fileName.contains('property') || fileName.contains('house')) {
      return 'Home Insurance';
    } else if (fileName.contains('life')) {
      return 'Life Insurance';
    } else {
      // Default case: try to extract from file content later
      return 'Insurance Policy';
    }
  }

  Map<String, dynamic> _inferInsurerInfo(String filePath) {
    final fileName = filePath.toLowerCase();
    String insurer = 'Unknown';
    
    // List of common insurance companies
    final insurers = [
      'Aetna', 'Anthem', 'Blue Cross', 'Blue Shield', 'Cigna', 'UnitedHealth', 
      'Humana', 'Kaiser', 'MetLife', 'Prudential', 'State Farm', 'Allstate',
      'Geico', 'Progressive', 'Farmers', 'Liberty Mutual', 'Nationwide',
      'Travelers', 'USAA', 'New York Life', 'Northwestern Mutual'
    ];
    
    // Check if any insurer name is in the filename
    for (final company in insurers) {
      if (fileName.contains(company.toLowerCase())) {
        insurer = company;
        break;
      }
    }
    
    return {
      'insurer': insurer,
    };
  }

  Future<Map<String, dynamic>> uploadDocument(File file, {String? email, String? phone}) {
    return uploadFile(file, email: email, phone: phone);
  }

  Future<List<InsuranceDocument>> getDocuments() async {
    try {
      // Get documents from local storage
      final documents = await _localStorageService.getDocuments();
      
      // Update document types if they're missing
      final updatedDocuments = <InsuranceDocument>[];
      
      for (final doc in documents) {
        if (doc.documentType == null || doc.documentType == 'Unknown') {
          // Perform document type inference
          final inferredType = await inferDocumentTypeFromContent(doc.id);
          
          // Create updated document with inferred type
          final updatedDoc = InsuranceDocument(
            id: doc.id,
            filename: doc.filename,
            uploadedOn: doc.uploadedOn,
            documentType: inferredType,
            insurer: doc.insurer,
            status: doc.status,
            processingCompletedAt: doc.processingCompletedAt,
            size: doc.size,
            localFilePath: doc.localFilePath,
          );
          
          // Update the document in local storage
          await _localStorageService.updateDocument(updatedDoc);
          
          updatedDocuments.add(updatedDoc);
        } else {
          updatedDocuments.add(doc);
        }
      }
      
      return updatedDocuments;
    } catch (e) {
      print('Error getting documents: $e');
      rethrow;
    }
  }
  
  Future<String> inferDocumentTypeFromContent(String documentId) async {
    // In a real implementation, we would query the document content
    // For now, use simple inference based on document ID to simulate
    try {
      // Try to query for document type
      final result = await queryDocument(
        "What type of insurance policy is this? Please answer with just the type: Health, Auto, Home, or Life.",
        documentId: documentId,
      );
      
      if (result.containsKey('answer')) {
        final answer = result['answer'].toString().toLowerCase();
        
        if (answer.contains('health')) {
          return 'Health Insurance';
        } else if (answer.contains('auto')) {
          return 'Auto Insurance';
        } else if (answer.contains('home')) {
          return 'Home Insurance';
        } else if (answer.contains('life')) {
          return 'Life Insurance';
        }
      }
      
      // Fallback to default
      return 'Insurance Policy';
    } catch (e) {
      print('Error inferring document type: $e');
      return 'Insurance Policy';
    }
  }
  
  Future<List<PolicyHolder>> extractPolicyHolders(String documentId) async {
    try {
      // Query the document for policy holder information
      final result = await queryDocument(
        "Who are the policy holders and insured individuals in this document? Please provide their names and dates of birth in a structured format.",
        documentId: documentId,
      );
      
      if (result.containsKey('answer')) {
        final answer = result['answer'].toString();
        
        // Simple parsing of the answer to extract names and dates
        // This is a basic implementation - in real app would use more robust parsing
        final List<PolicyHolder> holders = [];
        
        // Basic name extraction using regex
        final nameRegex = RegExp(r'([A-Z][a-z]+ [A-Z][a-z]+)');
        final dobRegex = RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})');
        
        final nameMatches = nameRegex.allMatches(answer);
        final dobMatches = dobRegex.allMatches(answer);
        
        // Match names with DOBs where possible
        for (var i = 0; i < nameMatches.length; i++) {
          final name = nameMatches.elementAt(i).group(1);
          final dob = i < dobMatches.length ? dobMatches.elementAt(i).group(1) : null;
          
          if (name != null) {
            holders.add(PolicyHolder(
              name: name,
              dob: dob,
              relationship: i == 0 ? 'Primary Insured' : 'Dependent',
            ));
          }
        }
        
        // If no structured data found, create a mock holder for demo
        if (holders.isEmpty) {
          // Use document ID to generate consistent mock data
          final hash = documentId.hashCode;
          final rng = Random(hash);
          
          // Random selection of mock names
          final names = [
            'John Smith', 'Jane Doe', 'Michael Johnson', 
            'Sarah Williams', 'David Brown', 'Emily Davis'
          ];
          
          // Add a primary holder
          holders.add(PolicyHolder(
            name: names[rng.nextInt(names.length)],
            dob: '${1 + rng.nextInt(28)}/${1 + rng.nextInt(12)}/${1960 + rng.nextInt(40)}',
            relationship: 'Primary Insured',
          ));
          
          // Maybe add a dependent (50% chance)
          if (rng.nextBool()) {
            holders.add(PolicyHolder(
              name: names[rng.nextInt(names.length)],
              dob: '${1 + rng.nextInt(28)}/${1 + rng.nextInt(12)}/${1960 + rng.nextInt(40)}',
              relationship: 'Spouse',
            ));
          }
        }
        
        // Update document with these policy holders
        final document = await _localStorageService.getDocumentById(documentId);
        if (document != null) {
          final updatedDoc = InsuranceDocument(
            id: document.id,
            filename: document.filename,
            uploadedOn: document.uploadedOn,
            documentType: document.documentType,
            insurer: document.insurer,
            status: document.status,
            processingCompletedAt: document.processingCompletedAt,
            size: document.size,
            localFilePath: document.localFilePath,
            policyHolders: holders,
          );
          await _localStorageService.updateDocument(updatedDoc);
        }
        
        return holders;
      }
      
      // Default empty result
      return [];
    } catch (e) {
      print('Error extracting policy holders: $e');
      return [];
    }
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
        
        // Get session ID for tracking
        final sessionId = await SessionService.getSessionId();
        
        // Use correct content type and improved error handling
        Response response = await _dio.post(
          '/query',
          data: data,
          options: Options(
            headers: {
              'X-Session-ID': sessionId,
            },
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
      // Fallback to local mock responses if all else fails
      print('Falling back to local mock response: $e');
      
      // Mock responses for common questions for demo purposes
      if (query.contains('policy number')) {
        return {
          'answer': 'Your policy number is POL-${documentId?.substring(0, 8).toUpperCase() ?? '12345678'}.',
          'sources': [{'text': 'Policy Document', 'page_number': 1}]
        };
      } else if (query.contains('deductible')) {
        return {
          'answer': 'Your annual deductible is \$1,500 for in-network services and \$3,000 for out-of-network services.',
          'sources': [{'text': 'Benefit Summary', 'page_number': 3}]
        };
      } else if (query.contains('premium')) {
        return {
          'answer': 'Your monthly premium is \$375.42.',
          'sources': [{'text': 'Premium Statement', 'page_number': 1}]
        };
      } else if (query.contains('coverage')) {
        return {
          'answer': 'Your policy provides coverage for medical services, prescription drugs, and emergency care. Dental and vision services are not included.',
          'sources': [{'text': 'Coverage Details', 'page_number': 2}]
        };
      } else if (query.contains('type of insurance')) {
        // For document type questions, use consistent responses
        final hash = documentId?.hashCode ?? 0;
        final types = ['Health Insurance', 'Auto Insurance', 'Home Insurance', 'Life Insurance'];
        final type = types[hash % types.length];
        
        return {
          'answer': 'This is a $type policy.',
          'sources': [{'text': 'Policy Cover Page', 'page_number': 1}]
        };
      } else {
        return {
          'answer': 'I don\'t have specific information about that in your policy. Please check your full policy document or contact your insurance provider for details.',
          'sources': []
        };
      }
    }
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }

  Future<Map<String, dynamic>> getUsageStats() async {
    try {
      final sessionId = await SessionService.getSessionId();
      
      final response = await _dio.get(
        '/documents/usage-stats',
        options: Options(
          headers: {
            'X-Session-ID': sessionId,
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get usage stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting usage stats: $e');
      // Return default stats for offline mode
      return {
        'session_uploads': 0,
        'session_limit': 5,
        'ip_uploads': 0,
        'ip_limit': 10,
      };
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      // Get document first to record its filename
      final document = await _localStorageService.getDocumentById(documentId);
      if (document == null) {
        return false;
      }
      
      // Delete document from local storage
      final deleted = await _localStorageService.deleteDocument(documentId);
      
      // Record this deletion in SharedPreferences for activity tracking
      if (deleted) {
        final prefs = await SharedPreferences.getInstance();
        final recentlyDeleted = prefs.getStringList('recently_deleted_docs') ?? [];
        
        // Add this document to the recently deleted list
        if (!recentlyDeleted.contains(document.filename)) {
          recentlyDeleted.insert(0, document.filename);
          // Keep only the most recent 5 deletions
          if (recentlyDeleted.length > 5) {
            recentlyDeleted.removeLast();
          }
          await prefs.setStringList('recently_deleted_docs', recentlyDeleted);
        }
      }
      
      return deleted;
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
  Future<Map<String, dynamic>> uploadDocumentWithLimitCheck(File file, {String? email, String? phone}) async {
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
      return await uploadDocument(file, email: email, phone: phone);
    } catch (e) {
      return {'error': e.toString()};
    }
  }
} 