import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../services/document_service.dart';
import '../services/query_service.dart';
import '../services/auth_service.dart';

final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
    ),
  );
  dio.interceptors.add(AuthInterceptor(dio));
  return dio;
});

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService(ref.watch(_dioProvider));
});

final queryServiceProvider = Provider<QueryService>((ref) {
  return QueryService(ref.watch(_dioProvider));
});
