import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'app_state_store.dart';

/// Anonymous bearer-token authentication for the CoverWise API.
///
/// The backend requires `Authorization: Bearer <token>` on all policy-bearing
/// requests. The token is obtained from `POST /user/anonymous` and lasts 30 days.
/// Wired into the Dio interceptor so every request automatically gets the header.
class AuthService {
  static const _tokenKey = 'anonymous_auth_token';
  static const _tokenExpiryKey = 'anonymous_auth_token_expiry';

  static Box get _box => Hive.box(AppStateStore.boxName);

  static String? get cachedToken {
    final token = _box.get(_tokenKey) as String?;
    if (token == null) return null;
    final expiryStr = _box.get(_tokenExpiryKey) as String?;
    if (expiryStr != null) {
      try {
        final expiry = DateTime.parse(expiryStr);
        if (DateTime.now().isAfter(expiry)) return null;
      } catch (_) {
        return null;
      }
    }
    return token;
  }

  static Future<String?> acquireToken(Dio dio) async {
    try {
      final response = await dio.post('/user/anonymous');
      if (response.statusCode == 200 && response.data['access_token'] != null) {
        final token = response.data['access_token'] as String;
        final expiresAt = response.data['expires_at'] as String?;
        await _box.put(_tokenKey, token);
        if (expiresAt != null) {
          await _box.put(_tokenExpiryKey, expiresAt);
        }
        debugPrint('Anonymous auth token acquired, expires: $expiresAt');
        return token;
      }
    } catch (e) {
      debugPrint('Failed to acquire anonymous token: $e');
    }
    return null;
  }

  static Future<void> clearToken() async {
    await _box.delete(_tokenKey);
    await _box.delete(_tokenExpiryKey);
  }
}

/// Dio interceptor: adds the anonymous auth header, auto-refreshes on 401.
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/user/anonymous')) {
      handler.next(options);
      return;
    }
    final token = AuthService.cachedToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      debugPrint('Got 401, attempting token refresh...');
      final newToken = await AuthService.acquireToken(_dio);
      if (newToken != null) {
        final clonedRequest = err.requestOptions
          ..headers['Authorization'] = 'Bearer $newToken';
        try {
          final response = await _dio.fetch(clonedRequest);
          handler.resolve(response);
          return;
        } catch (e) {
          handler.reject(err);
          return;
        }
      }
    }
    handler.next(err);
  }
}
