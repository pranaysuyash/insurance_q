import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../services/document_service.dart';
import '../services/query_service.dart';
import '../services/auth_service.dart';

final _dioProvider = Provider<Dio>((ref) {
  AuthService.configure(AppConfig.baseUrl);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
    ),
  );
  dio.interceptors
      .add(QueuedInterceptorsWrapper(onRequest: (options, handler) async {
    final token = await AuthService.accessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }));
  return dio;
});

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService(ref.watch(_dioProvider));
});

final queryServiceProvider = Provider<QueryService>((ref) {
  return QueryService(ref.watch(_dioProvider));
});
