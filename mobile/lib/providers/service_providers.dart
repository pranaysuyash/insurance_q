import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../services/document_service.dart';
import '../services/query_service.dart';
import '../services/auth_service.dart';
import '../services/server_consent_service.dart';
import '../services/local_storage_service.dart';
import 'capabilities_provider.dart';

final authenticatedDioProvider = Provider<Dio>((ref) {
  // A1-P1b: Prefer server-provided timeouts from capabilities, falling back
  // to AppConfig static defaults. The capabilities fetch is warm-started
  // before runApp() via unawaited(capabilitiesService.fetch()) in main.dart,
  // so by the time this provider builds, the cached value (or AppConfig
  // fallback) is already available.
  final caps = capabilitiesService.latest;
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(seconds: caps.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: caps.receiveTimeoutSeconds),
    ),
  );
  dio.interceptors.add(AuthInterceptor(dio));
  return dio;
});

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService(ref.watch(authenticatedDioProvider));
});

final queryServiceProvider = Provider<QueryService>((ref) {
  return QueryService(ref.watch(authenticatedDioProvider));
});

final serverConsentServiceProvider = Provider<ServerConsentService>((ref) {
  final dio = ref.watch(authenticatedDioProvider);
  return ServerConsentService(dio: dio);
});

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});
