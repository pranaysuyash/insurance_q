import 'dart:io';
import 'package:dio/dio.dart';

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

  Future<Map<String, dynamic>> uploadDocument(File file) async {
    final fileName = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });
    final response = await _dio.post('/upload', data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> askQuestion(String question) async {
    final response = await _dio.post(
      '/query',
      data: {'query': question},
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data as Map<String, dynamic>;
  }
} 