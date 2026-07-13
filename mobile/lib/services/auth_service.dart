import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Reads only from platform secure storage. A one-time Hive migration avoids
  /// stranding existing anonymous owners while removing bearer tokens from the
  /// general application-state database.
  static Future<String?> cachedToken() async {
    var token = await _secureStorage.read(key: _tokenKey);
    var expiryStr = await _secureStorage.read(key: _tokenExpiryKey);
    if (token == null) {
      final legacyToken = _box.get(_tokenKey) as String?;
      final legacyExpiry = _box.get(_tokenExpiryKey) as String?;
      if (legacyToken != null) {
        await _secureStorage.write(key: _tokenKey, value: legacyToken);
        if (legacyExpiry != null) {
          await _secureStorage.write(key: _tokenExpiryKey, value: legacyExpiry);
        }
        await _box.delete(_tokenKey);
        await _box.delete(_tokenExpiryKey);
        token = legacyToken;
        expiryStr = legacyExpiry;
      }
    }
    if (token == null) return null;
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
        await _secureStorage.write(key: _tokenKey, value: token);
        if (expiresAt != null) {
          await _secureStorage.write(key: _tokenExpiryKey, value: expiresAt);
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
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    // Also clear a pre-migration token if a reset happens before first read.
    await _box.delete(_tokenKey);
    await _box.delete(_tokenExpiryKey);
  }
}

/// Dio interceptor: adds the anonymous auth header, auto-refreshes on 401.
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.path.contains('/user/anonymous')) {
      handler.next(options);
      return;
    }
    final token = await AuthService.cachedToken();
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
