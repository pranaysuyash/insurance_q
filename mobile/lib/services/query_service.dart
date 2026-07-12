import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'local_storage_service.dart';
import 'session_service.dart';
import 'demo_service.dart';

class QueryService {
  final Dio _dio;
  final LocalStorageService _localStorageService = LocalStorageService();
  final DemoService _demoService;

  QueryService(this._dio) : _demoService = DemoService();

  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await _dio.get(
        '/health',
        options: Options(validateStatus: (status) => true),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return {'status': 'healthy', 'backend': response.data};
      }

      return {
        'status': 'degraded',
        'error': 'Backend health check failed',
        'backend_status': response.statusCode,
      };
    } catch (e) {
      return {'status': 'unavailable', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> askQuestion(String question) async {
    try {
      return await queryDocument(question);
    } catch (e) {
      debugPrint('Error asking question: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> queryDocument(String query,
      {String? documentId}) async {
    try {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        Map<String, dynamic> data = {
          'query': query,
          '_cache_buster': timestamp.toString(),
        };

        if (documentId != null) {
          final backendDocumentId =
              await _localStorageService.getBackendDocumentId(documentId);
          if (backendDocumentId == null) {
            return _buildUnavailableAnswer(
              query,
              reason: 'document_not_synced',
              documentId: documentId,
            );
          }
          data['filters'] = {'document_id': backendDocumentId};
        }

        final sessionId = await SessionService.getSessionId();

        Response response = await _dio.post(
          '/query',
          data: data,
          options: Options(
            headers: {'X-Session-ID': sessionId},
            contentType: Headers.jsonContentType,
            validateStatus: (status) => true,
            receiveTimeout: const Duration(seconds: 60),
          ),
        );

        if (response.statusCode == 200) {
          final responseData = response.data;

          if (responseData is! Map<String, dynamic>) {
            return _buildUnavailableAnswer(
              query, reason: 'non_map_response', documentId: documentId);
          }

          if (responseData.containsKey('answer')) {
            return _processDirectAnswer(responseData, query, documentId);
          }

          if (responseData.containsKey('status') &&
              responseData['status'] == 'success') {
            return _processWrappedAnswer(responseData, query, documentId);
          }

          return _buildUnavailableAnswer(
            query, reason: 'unrecognized_response_format', documentId: documentId);
        } else if (response.statusCode == 500 &&
            response.data is Map<String, dynamic>) {
          final error = response.data as Map<String, dynamic>;
          final errorMessage = error['detail']?.toString() ?? 'Server error';

          if (errorMessage.contains('result')) {
            return _buildUnavailableAnswer(
              query, reason: 'missing_result_field', documentId: documentId);
          }

          return _buildUnavailableAnswer(
            query, reason: 'server_error', documentId: documentId);
        } else {
          throw DioException(
            requestOptions: RequestOptions(path: '/query'),
            response: response,
            type: DioExceptionType.badResponse,
          );
        }
      } catch (e) {
        debugPrint('Error with real query: $e');
        if (AppConfig.bootstrapPolicyDemo) {
          return _demoService.buildLocalPolicyAnswer(query, documentId: documentId);
        }
        return _buildUnavailableAnswer(
          query,
          reason: e is DioException ? e.type.toString() : 'query_error',
          documentId: documentId,
        );
      }
    } catch (e) {
      debugPrint('Falling back to local mock response: $e');
      if (AppConfig.bootstrapPolicyDemo) {
        return _demoService.buildLocalPolicyAnswer(query, documentId: documentId);
      }
      return _buildUnavailableAnswer(
        query, reason: 'unhandled_error', documentId: documentId);
    }
  }

  Map<String, dynamic> _processDirectAnswer(
      Map<String, dynamic> responseData, String query, String? documentId) {
    List<String> sources = _extractSources(responseData);

    final answerText = responseData['answer']?.toString() ?? 'No answer provided';
    final errorText = responseData['error']?.toString();

    if (_isErrorAnswer(errorText, answerText)) {
      if (AppConfig.bootstrapPolicyDemo) {
        return _demoService.buildLocalPolicyAnswer(query, documentId: documentId);
      }
      return _buildUnavailableAnswer(
        query, reason: 'backend_error_answer', documentId: documentId);
    }

    return {
      'answer': answerText,
      'sources': sources,
      'confidence': responseData['confidence'],
      'error': responseData['error'],
      'citations': responseData['citations'],
      'missing_information': responseData['missing_information'],
      'follow_up_questions': responseData['follow_up_questions'],
      'retrieval_confidence': responseData['retrieval_confidence'],
      'retrieval_strategy': responseData['retrieval_strategy'],
      'embedding_model_used': responseData['embedding_model_used'],
      'document_id': documentId,
    };
  }

  Map<String, dynamic> _processWrappedAnswer(
      Map<String, dynamic> responseData, String query, String? documentId) {
    if (responseData.containsKey('result') &&
        responseData['result'] is Map<String, dynamic>) {
      final result = responseData['result'] as Map<String, dynamic>;
      List<String> sources = _extractSources(result);

      final answerText = result['answer']?.toString() ?? 'No answer provided';
      final errorText = result['error']?.toString();

      if (_isErrorAnswer(errorText, answerText)) {
        if (AppConfig.bootstrapPolicyDemo) {
          return _demoService.buildLocalPolicyAnswer(query, documentId: documentId);
        }
        return _buildUnavailableAnswer(
          query, reason: 'legacy_backend_error_answer', documentId: documentId);
      }

      return {
        'answer': answerText,
        'sources': sources,
        'confidence': result['confidence'],
        'error': result['error'],
        'citations': result['citations'],
        'missing_information': result['missing_information'],
        'follow_up_questions': result['follow_up_questions'],
        'retrieval_confidence': result['retrieval_confidence'],
        'retrieval_strategy': result['retrieval_strategy'],
        'embedding_model_used': result['embedding_model_used'],
        'document_id': documentId,
      };
    }
    return _buildUnavailableAnswer(
      query, reason: 'missing_result_field', documentId: documentId);
  }

  List<String> _extractSources(Map<String, dynamic> data) {
    List<dynamic> sources = [];
    if (data.containsKey('sources') && data['sources'] is List) {
      sources = data['sources'] as List<dynamic>;
    }
    return sources.map((source) {
      if (source is String) return source;
      if (source is Map<String, dynamic>) return source['text']?.toString() ?? source.toString();
      return source.toString();
    }).toList();
  }

  bool _isErrorAnswer(String? errorText, String answerText) {
    if (errorText != null &&
        (errorText.contains('insufficient_quota') ||
            answerText.toLowerCase().contains('encountered an error') ||
            answerText.toLowerCase().contains('please try again later'))) {
      return true;
    }
    return false;
  }

  Map<String, dynamic> _buildUnavailableAnswer(
    String query, {
    required String reason,
    String? documentId,
  }) {
    return {
      'status': 'unavailable',
      'error': 'verified_answer_unavailable',
      'message':
          'I could not retrieve a verified answer for this question right now.',
      'reason': reason,
      'can_retry': true,
      'sources': const [],
      'query': query,
      if (documentId != null) 'document_id': documentId,
    };
  }

  Future<Map<String, dynamic>> getUsageStats() async {
    try {
      final sessionId = await SessionService.getSessionId();
      final response = await _dio.get(
        '/documents/usage-stats',
        options: Options(
          headers: {'X-Session-ID': sessionId},
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get usage stats: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting usage stats: $e');
      return {
        'session_uploads': 0,
        'session_limit': 5,
        'ip_uploads': 0,
        'ip_limit': 10,
      };
    }
  }
}
