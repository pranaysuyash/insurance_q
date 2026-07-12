import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps CoverWise's anonymous identity in platform secure storage.
///
/// There is no account wall, but policy requests still carry a server-signed
/// bearer credential; a caller-controlled UUID is not an ownership boundary.
class AuthService {
  static const _tokenKey = 'anonymous_access_token';
  static const _storage = FlutterSecureStorage();
  static String? _baseUrl;
  static String? _cachedToken;

  static void configure(String baseUrl) => _baseUrl = baseUrl;

  static Future<String?> accessToken() async {
    final cached = _cachedToken;
    if (cached != null) return cached;
    final stored = await _storage.read(key: _tokenKey);
    if (stored != null && stored.isNotEmpty) {
      _cachedToken = stored;
      return stored;
    }
    final baseUrl = _baseUrl;
    if (baseUrl == null) return null;
    try {
      final response = await Dio(BaseOptions(baseUrl: baseUrl))
          .post<Map<String, dynamic>>('/user/anonymous');
      final token = response.data?['access_token']?.toString();
      if (token == null || token.isEmpty) return null;
      await _storage.write(key: _tokenKey, value: token);
      _cachedToken = token;
      return token;
    } on DioException {
      return null;
    }
  }

  static Future<void> clear() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }
}
