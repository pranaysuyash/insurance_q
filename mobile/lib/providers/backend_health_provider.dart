import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

/// Pings the backend [GET /health] endpoint and returns true when the
/// response is a 2xx status code. A short timeout ensures the splash screen
/// does not stall for longer than necessary.
///
/// Consumers should watch this provider and degrade gracefully when it
/// resolves to false. The splash screen uses a periodic timer to invalidate
/// this provider so the banner auto-dismisses when the backend recovers.
final backendHealthProvider = FutureProvider<bool>((ref) async {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  try {
    final response = await dio.get('/health');
    return response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
  } catch (_) {
    return false;
  }
});
