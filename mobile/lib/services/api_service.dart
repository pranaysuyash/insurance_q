import 'dart:io';
import 'package:dio/dio.dart';
import '../models/document_model.dart';

class ApiService {
  // Set your backend base URL here
  static const String baseUrl = 'http://192.168.1.12:8080'; // Change to your backend IP/port

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 90),
    ),
  );

  Future<Map<String, dynamic>> getHealth() async {
    Response response = await _dio.get('/health');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadFile(File file) async {
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      Response response = await _dio.post('/upload', data: formData);
      return response.data;
    } catch (e) {
      if (e is DioError) {
        print('DioError: ${e.message}');
        if (e.response != null) {
          print('Response data: ${e.response!.data}');
          print('Response status: ${e.response!.statusCode}');
        }
      } else {
        print('Error: $e');
      }
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadDocument(File file) {
    return uploadFile(file);
  }

  Future<Map<String, dynamic>> askQuestion(String question) async {
    final response = await _dio.post(
      '/query',
      data: {'query': question},
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> queryDocument(String query, {String? documentId}) async {
    try {
      Map<String, dynamic> data = {
        'query': query,
      };
      
      if (documentId != null) {
        data['filters'] = {
          'document_id': documentId
        };
      }
      
      Response response = await _dio.post('/query', data: data);
      return response.data;
    } catch (e) {
      if (e is DioError) {
        print('DioError: ${e.message}');
        if (e.response != null) {
          print('Response data: ${e.response!.data}');
          print('Response status: ${e.response!.statusCode}');
        }
      } else {
        print('Error: $e');
      }
      return {'error': e.toString()};
    }
  }

  Future<List<InsuranceDocument>> getDocuments() async {
    try {
      Response response = await _dio.get('/documents');
      final List<dynamic> docsData = response.data['documents'] ?? [];
      return docsData.map((doc) => InsuranceDocument.fromJson(doc)).toList();
    } catch (e) {
      print('Error getting documents: $e');
      return [];
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      Response response = await _dio.delete('/documents/$documentId');
      return response.statusCode == 200;
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