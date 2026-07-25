import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state_store.dart';
import 'analytics_service.dart';
import 'install_service.dart';
import '../config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authServiceProvider = NotifierProvider<AuthNotifier, AuthServiceState>(
  AuthNotifier.new,
);

/// Riverpod-managed state for [AuthNotifier].
class AuthServiceState {
  final bool accountClientReady;
  final bool preserveAnonymousWorkspaceForClaim;

  /// Set to true when a 401 response arrives and token refresh fails.
  /// The UI shows a non-blocking "Session expired — Sign in again" banner
  /// instead of a generic error. The user can continue viewing cached data
  /// while being prompted to re-auth.
  /// Cleared when a new token is successfully acquired or the user signs in.
  final bool sessionExpired;

  const AuthServiceState({
    required this.accountClientReady,
    required this.preserveAnonymousWorkspaceForClaim,
    this.sessionExpired = false,
  });
}

class AuthService {
  static const _tokenKey = 'anonymous_auth_token';
  static const _tokenExpiryKey = 'anonymous_auth_token_expiry';
  static const _identityCreatedKey = 'analytics_identity_created';

  static Box get _box => Hive.box(AppStateStore.boxName);
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static AuthNotifier? _instance;
  static AuthNotifier? get _notifier => _instance;

  static Future<void> initializeAccountClient() async {
    if (!AppConfig.hasSupabaseAuthConfig) return;
    await _notifier?.initializeAccountClient();
  }

  static bool get isClientReady => _notifier?.isClientReady ?? false;

  static bool get hasAccountSession =>
      _notifier?.hasAccountSession ??
      (AppConfig.hasSupabaseAuthConfig &&
          _notifier?.isClientReady == true &&
          Supabase.instance.client.auth.currentSession != null);

  static String? get accountUserId =>
      _notifier?.accountUserId ??
      (hasAccountSession ? Supabase.instance.client.auth.currentUser?.id : null);

  static Future<String?> accessToken() async {
    return _notifier?.accessToken() ?? _fallbackAccessToken();
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    final notifier = _notifier;
    if (notifier != null) return notifier.signIn(email, password);
    return Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<AuthResponse> signUp(
      String email, String password, String displayName) async {
    final notifier = _notifier;
    if (notifier != null) return notifier.signUp(email, password, displayName);
    return Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
  }

  static Future<void> signInWithPhoneOtp(String phone) async {
    final notifier = _notifier;
    if (notifier != null) return notifier.signInWithPhoneOtp(phone);
    return Supabase.instance.client.auth.signInWithOtp(phone: phone.trim());
  }

  static Future<AuthResponse> verifyPhoneOtp(String phone, String token) async {
    final notifier = _notifier;
    if (notifier != null) return notifier.verifyPhoneOtp(phone, token);
    return Supabase.instance.client.auth.verifyOTP(
      phone: phone.trim(),
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  static Future<UserResponse> updateUserPhone(String phone) async {
    if (!hasAccountSession) {
      throw StateError('Must be signed in to link phone to account');
    }
    final notifier = _notifier;
    if (notifier != null) return notifier.updateUserPhone(phone);
    return Supabase.instance.client.auth.updateUser(
      UserAttributes(phone: phone.trim()),
    );
  }

  static Future<void> signOut() async {
    await _notifier?.signOut();
  }

  static Future<void> signInWithGoogle() async {
    await _notifier?.signInWithGoogle();
  }

  static Future<void> resendEmailVerification(String email) async {
    await _notifier?.resendEmailVerification(email);
  }

  static Future<void> resetPassword(String email) async {
    await _notifier?.resetPassword(email);
  }

  static Future<DeleteAccountResult> deleteAccount() async {
    return _notifier?.deleteAccount() ??
        Future.error(StateError('No AuthNotifier instance'));
  }

  static Future<DeletionStatus> getDeletionStatus() async {
    return _notifier?.getDeletionStatus() ??
        Future.error(StateError('No AuthNotifier instance'));
  }

  /// Export the signed-in account's server-held metadata and short-lived source
  /// download links. The backend, not the client, enforces account ownership.
  static Future<Map<String, dynamic>> exportAccount() {
    return _notifier?.exportAccount() ??
        Future.error(StateError('No AuthNotifier instance'));
  }

  static Future<void> prepareAnonymousWorkspaceClaim() async {
    await _notifier?.prepareAnonymousWorkspaceClaim();
  }

  static bool consumeAnonymousWorkspaceClaim() {
    return _notifier?.consumeAnonymousWorkspaceClaim() ?? false;
  }

  static Future<void> claimAnonymousData() async {
    await _notifier?.claimAnonymousData();
  }

  static Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    await _box.delete(_tokenKey);
    await _box.delete(_tokenExpiryKey);
    await _notifier?.clearToken();
  }

  static Future<String?> acquireToken(Dio dio) async {
    return _notifier?.acquireToken(dio);
  }

  // Fallback implementations for when Notifier isn't available
  static Future<String?> _fallbackAccessToken() async {
    if (hasAccountSession) {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    }
    return _fallbackCachedToken();
  }

  static Future<String?> _fallbackCachedToken() async {
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
}

class AuthNotifier extends Notifier<AuthServiceState> {
  static AuthNotifier? _instance;
  static AuthNotifier? get instance => _instance;  @override
  AuthServiceState build() {
    _instance = this;
    AuthService._instance = this;
    ref.onDispose(() {
      _instance = null;
      AuthService._instance = null;
    });
    return const AuthServiceState(
      accountClientReady: false,
      preserveAnonymousWorkspaceForClaim: false,
    );
  }

  bool get isClientReady => state.accountClientReady;

  bool get hasAccountSession =>
      AppConfig.hasSupabaseAuthConfig &&
      isClientReady &&
      Supabase.instance.client.auth.currentSession != null;

  String? get accountUserId =>
      hasAccountSession ? Supabase.instance.client.auth.currentUser?.id : null;

  Future<void> initializeAccountClient() async {
    if (!AppConfig.hasSupabaseAuthConfig || state.accountClientReady) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    state = state.copyWith(accountClientReady: true);
  }

  Future<String?> accessToken() async {
    if (hasAccountSession) {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    }
    return _cachedToken();
  }

  Future<String?> _cachedToken() async {
    var token = await AuthService._secureStorage.read(key: AuthService._tokenKey);
    var expiryStr = await AuthService._secureStorage.read(key: AuthService._tokenExpiryKey);
    if (token == null) {
      final legacyToken = AuthService._box.get(AuthService._tokenKey) as String?;
      final legacyExpiry = AuthService._box.get(AuthService._tokenExpiryKey) as String?;
      if (legacyToken != null) {
        await AuthService._secureStorage.write(key: AuthService._tokenKey, value: legacyToken);
        if (legacyExpiry != null) {
          await AuthService._secureStorage.write(key: AuthService._tokenExpiryKey, value: legacyExpiry);
        }
        await AuthService._box.delete(AuthService._tokenKey);
        await AuthService._box.delete(AuthService._tokenExpiryKey);
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

  Future<AuthResponse> signIn(String email, String password) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.user != null) {
      _trackAccountCreated(authMethod: 'email');
    }
    return response;
  }

  Future<AuthResponse> signUp(
      String email, String password, String displayName) async {
    final response = await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    if (response.user != null) {
      _trackAccountCreated(authMethod: 'email');
    }
    return response;
  }

  Future<void> signInWithPhoneOtp(String phone) async {
    if (!isClientReady) return;
    await prepareAnonymousWorkspaceClaim();
    await Supabase.instance.client.auth.signInWithOtp(
      phone: phone.trim(),
    );
  }

  Future<AuthResponse> verifyPhoneOtp(String phone, String token) async {
    final response = await Supabase.instance.client.auth.verifyOTP(
      phone: phone.trim(),
      token: token.trim(),
      type: OtpType.sms,
    );
    if (response.user != null) {
      _trackAccountCreated(authMethod: 'phone_otp');
    }
    return response;
  }

  Future<UserResponse> updateUserPhone(String phone) async {
    if (!hasAccountSession) {
      throw StateError('Must be signed in to link phone to account');
    }
    return Supabase.instance.client.auth.updateUser(
      UserAttributes(phone: phone.trim()),
    );
  }

  void _trackAccountCreated({required String authMethod}) {
    try {
      AnalyticsService.track('account_created', {
        'install_id': InstallService.getInstallId(),
        'auth_method': authMethod,
      });
    } catch (e) {
      debugPrint('AuthService: failed to track account_created: $e');
    }
  }

  Future<void> claimAnonymousData() async {
    final legacyToken = await _cachedToken();
    if (legacyToken == null || !hasAccountSession) return;
    AnalyticsService.track('claim_initiated', {
      'anonymous_token_age_hours_bucket': 'unknown',
    });
    final dio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
    dio.interceptors.add(AuthInterceptor(dio));
    try {
      final response = await dio.post('/user/claim-anonymous',
          data: {'anonymous_token': legacyToken});
      final transferred = (response.data is Map)
          ? ((response.data as Map)['transferred_documents'] as int? ?? 0)
          : 0;
      AnalyticsService.track('claim_succeeded', {
        'transferred_count': transferred,
      });
      await clearToken();
    } catch (error) {
      AnalyticsService.track('claim_failed', {
        'error_class': error.runtimeType.toString(),
        'transferred_count': 0,
      });
      rethrow;
    }
  }

  Future<void> prepareAnonymousWorkspaceClaim() async {
    final hasToken = await _cachedToken() != null;
    state = state.copyWith(preserveAnonymousWorkspaceForClaim: hasToken);
  }

  bool consumeAnonymousWorkspaceClaim() {
    final preserve = state.preserveAnonymousWorkspaceForClaim;
    state = state.copyWith(preserveAnonymousWorkspaceForClaim: false);
    return preserve;
  }

  Future<void> signOut() async {
    if (isClientReady) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  Future<void> signInWithGoogle() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.coverwise://login-callback',
    );
  }

  Future<void> resendEmailVerification(String email) async {
    await Supabase.instance.client.auth.resend(
      email: email.trim(),
      type: OtpType.signup,
    );
  }

  Future<void> resetPassword(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'io.coverwise://reset-callback',
    );
  }

  Future<DeleteAccountResult> deleteAccount() async {
    if (!hasAccountSession) {
      throw StateError('No account session to delete');
    }
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    dio.interceptors.add(AuthInterceptor(dio));
    final response = await dio.delete('/user/account');
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw Exception('Server returned ${response.statusCode}');
    }
    final data = (response.data as Map?)?.cast<String, dynamic>() ?? {};
    final failedStages =
        (data['failed_stages'] as List?)?.cast<String>() ?? const <String>[];
    final result = DeleteAccountResult(
      status: data['status'] as String? ?? 'unknown',
      deletedDocuments: (data['deleted_documents'] as int?) ?? 0,
      deletedStorageFiles: (data['deleted_storage_files'] as int?) ?? 0,
      storageErrors: (data['storage_errors'] as int?) ?? 0,
      authUserDeleted: data['auth_user_deleted'] as bool? ?? false,
      failedStages: failedStages,
      message: data['message'] as String? ?? '',
    );
    await signOut();
    return result;
  }

  Future<DeletionStatus> getDeletionStatus() async {
    if (!hasAccountSession) {
      throw StateError('No account session to read deletion status');
    }
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    dio.interceptors.add(AuthInterceptor(dio));
    final response = await dio.get('/user/account/deletion-status');
    final data = (response.data as Map?)?.cast<String, dynamic>() ?? {};
    return DeletionStatus.fromJson(data);
  }

  Future<Map<String, dynamic>> exportAccount() async {
    if (!hasAccountSession) {
      throw StateError('No account session to export');
    }
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    dio.interceptors.add(AuthInterceptor(dio));
    final response = await dio.get('/user/account/export');
    if (response.statusCode != 200 || response.data is! Map) {
      throw Exception('Account export is temporarily unavailable');
    }
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<void> clearToken() async {
    await AuthService._secureStorage.delete(key: AuthService._tokenKey);
    await AuthService._secureStorage.delete(key: AuthService._tokenExpiryKey);
    await AuthService._box.delete(AuthService._tokenKey);
    await AuthService._box.delete(AuthService._tokenExpiryKey);
  }

  /// Update the session-expired flag. Called by [AuthInterceptor] when a 401
  /// refresh fails, or cleared when a new token is successfully acquired.
  void updateSessionExpired(bool expired) {
    if (state.sessionExpired == expired) return;
    state = state.copyWith(sessionExpired: expired);
  }

  Future<String?> acquireToken(Dio dio) async {
    try {
      final response = await dio.post('/user/anonymous');
      if (response.statusCode == 200 && response.data['access_token'] != null) {
        final token = response.data['access_token'] as String;
        final expiresAt = response.data['expires_at'] as String?;
        await AuthService._secureStorage.write(key: AuthService._tokenKey, value: token);
        if (expiresAt != null) {
          await AuthService._secureStorage.write(key: AuthService._tokenExpiryKey, value: expiresAt);
        }
        debugPrint('Anonymous auth token acquired, expires: $expiresAt');
        _trackIdentityCreated();
        return token;
      }
    } catch (e) {
      debugPrint('Failed to acquire anonymous token: $e');
    }
    return null;
  }

  void _trackIdentityCreated() {
    try {
      final box = AuthService._box;
      final alreadyTracked = box.get(AuthService._identityCreatedKey) == true;
      if (alreadyTracked) return;
      box.put(AuthService._identityCreatedKey, true);
      AnalyticsService.track('identity_created', {
        'identity_type': 'anonymous',
        'install_id': InstallService.getInstallId(),
      });
    } catch (e) {
      debugPrint('AuthService: failed to track identity_created: $e');
    }
  }
}

extension AuthServiceStateCopy on AuthServiceState {
  AuthServiceState copyWith({
    bool? accountClientReady,
    bool? preserveAnonymousWorkspaceForClaim,
    bool? sessionExpired,
  }) {
    return AuthServiceState(
      accountClientReady: accountClientReady ?? this.accountClientReady,
      preserveAnonymousWorkspaceForClaim:
          preserveAnonymousWorkspaceForClaim ?? this.preserveAnonymousWorkspaceForClaim,
      sessionExpired: sessionExpired ?? this.sessionExpired,
    );
  }
}

/// Dio interceptor: adds the anonymous auth header, auto-refreshes on 401.
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.path.contains('/user/anonymous')) {
      handler.next(options);
      return;
    }
    final token = await AuthService.accessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      debugPrint('Got 401, attempting token refresh...');
      String? newToken;
      if (AuthService.hasAccountSession) {
        try {
          final response = await Supabase.instance.client.auth.refreshSession();
          newToken = response.session?.accessToken;
        } catch (_) {
          newToken = null;
        }
      } else {
        newToken = await AuthService._instance?.acquireToken(_dio);
      }
      if (newToken != null) {
        // Refresh succeeded — clear the expired state if it was set.
        AuthService._notifier?.updateSessionExpired(false);
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
      } else {
        // Refresh failed — signal session expired so the UI shows a
        // non-blocking banner instead of a generic error. The user can
        // continue viewing cached data while being prompted to re-auth.
        AuthService._notifier?.updateSessionExpired(true);
      }
    }
    handler.next(err);
  }
}

/// The per-stage result of [AuthService.deleteAccount].
class DeleteAccountResult {
  final String status;
  final int deletedDocuments;
  final int deletedStorageFiles;
  final int storageErrors;
  final bool authUserDeleted;
  final List<String> failedStages;
  final String message;

  const DeleteAccountResult({
    required this.status,
    required this.deletedDocuments,
    required this.deletedStorageFiles,
    required this.storageErrors,
    required this.authUserDeleted,
    required this.failedStages,
    required this.message,
  });

  bool get isComplete => status == 'deletion_succeeded';
  bool get isPartial => status == 'deletion_partial';
}

class DeletionStatus {
  final String status;
  final String? requestId;
  final DateTime? requestedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  const DeletionStatus({
    required this.status,
    this.requestId,
    this.requestedAt,
    this.startedAt,
    this.completedAt,
    this.updatedAt,
  });

  factory DeletionStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    return DeletionStatus(
      status: json['status'] as String? ?? 'unknown',
      requestId: json['request_id'] as String?,
      requestedAt: parse(json['requested_at']),
      startedAt: parse(json['started_at']),
      completedAt: parse(json['completed_at']),
      updatedAt: parse(json['updated_at']),
    );
  }

  bool get isActionable =>
      status == 'pending' || status == 'running' || status == 'failed';
}
