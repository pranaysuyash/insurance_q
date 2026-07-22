import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'app_state_store.dart';
import 'analytics_service.dart';
import 'install_service.dart';
import '../config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Anonymous bearer-token authentication for the CoverWise API.
///
/// The backend requires `Authorization: Bearer <token>` on all policy-bearing
/// requests. The token is obtained from `POST /user/anonymous` and lasts 30 days.
/// Wired into the Dio interceptor so every request automatically gets the header.
class AuthService {
  static const _tokenKey = 'anonymous_auth_token';
  static const _tokenExpiryKey = 'anonymous_auth_token_expiry';

  /// Hive key for the "first identity ever created on this install" flag.
  /// R1.7 (2026-07-18): used to emit the identity_created analytics event
  /// exactly once per install. Stays true even after the anonymous token
  /// rotates, so re-issuance does not double-count.
  static const _identityCreatedKey = 'analytics_identity_created';

  static Box get _box => Hive.box(AppStateStore.boxName);
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static bool _accountClientReady = false;
  static bool _preserveAnonymousWorkspaceForClaim = false;

  static Future<void> initializeAccountClient() async {
    if (!AppConfig.hasSupabaseAuthConfig || _accountClientReady) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    _accountClientReady = true;
  }

  static bool get isClientReady => _accountClientReady;

  static bool get hasAccountSession =>
      AppConfig.hasSupabaseAuthConfig &&
      _accountClientReady &&
      Supabase.instance.client.auth.currentSession != null;

  /// The canonical account owner used by the backend and RevenueCat when an
  /// account session exists. Guest ownership remains the server-issued
  /// anonymous subject until this account is explicitly claimed.
  static String? get accountUserId =>
      hasAccountSession ? Supabase.instance.client.auth.currentUser?.id : null;

  static Future<String?> accessToken() async {
    if (hasAccountSession) {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    }
    return cachedToken();
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return response;
  }

  static Future<AuthResponse> signUp(
      String email, String password, String displayName) async {
    final response = await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );

    // R1.7 (2026-07-18): emit account_created on successful sign-up.
    // Distinct from identity_created (anonymous). A user can have both events
    // if they used the app anonymously before signing up.
    if (response.user != null) {
      _trackAccountCreated(authMethod: 'email');
    }
    return response;
  }

  /// Request an SMS OTP for phone sign-in or account registration.
  static Future<void> signInWithPhoneOtp(String phone) async {
    if (!_accountClientReady) return;
    await prepareAnonymousWorkspaceClaim();
    await Supabase.instance.client.auth.signInWithOtp(
      phone: phone.trim(),
    );
  }

  /// Verify 6-digit SMS OTP code for phone sign-in.
  static Future<AuthResponse> verifyPhoneOtp(String phone, String token) async {
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

  /// Update / link phone number to existing authenticated Supabase account.
  static Future<UserResponse> updateUserPhone(String phone) async {
    if (!hasAccountSession) {
      throw StateError('Must be signed in to link phone to account');
    }
    final response = await Supabase.instance.client.auth.updateUser(
      UserAttributes(phone: phone.trim()),
    );
    return response;
  }

  /// Emit account_created once per successful Supabase Auth sign-up.
  /// Best-effort, never throws.
  static void _trackAccountCreated({required String authMethod}) {
    try {
      AnalyticsService.track('account_created', {
        'install_id': InstallService.getInstallId(),
        'auth_method': authMethod,
      });
    } catch (e) {
      debugPrint('AuthService: failed to track account_created: $e');
    }
  }

  static Future<String?> anonymousToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  static Future<void> claimAnonymousData() async {
    final legacyToken = await anonymousToken();
    if (legacyToken == null || !hasAccountSession) return;
    AnalyticsService.track('claim_initiated', {
      // The token age is intentionally not decoded on-device. The backend
      // remains the authority for token validity and ownership.
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

  /// Capture the anonymous-to-account intent before Supabase emits its auth
  /// state event. The workspace listener uses this synchronous flag to avoid
  /// racing token cleanup after a successful claim.
  static Future<void> prepareAnonymousWorkspaceClaim() async {
    _preserveAnonymousWorkspaceForClaim = await anonymousToken() != null;
  }

  static bool consumeAnonymousWorkspaceClaim() {
    final preserve = _preserveAnonymousWorkspaceForClaim;
    _preserveAnonymousWorkspaceForClaim = false;
    return preserve;
  }

  static Future<void> signOut() async {
    if (_accountClientReady) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  /// Sign in with Google via Supabase OAuth.
  /// Opens browser for Google consent. Session is established automatically
  /// when the deep link callback fires — authStateProvider picks up the change.
  static Future<void> signInWithGoogle() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.coverwise://login-callback',
    );
  }

  /// Send a phone OTP for verification.
  /// Uses Supabase's built-in phone auth.
  static Future<void> signInWithPhoneOtp(String phone) async {
    if (!_accountClientReady) return;
    await Supabase.instance.client.auth.signInWithOtp(
      phone: phone,
    );
  }

  /// Verify a phone OTP code.
  static Future<AuthResponse> verifyPhoneOtp(
      String phone, String token) async {
    final response = await Supabase.instance.client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
    return response;
  }

  /// Update the phone number on the current Supabase user.
  static Future<void> updateUserPhone(String phone) async {
    if (!_accountClientReady || !hasAccountSession) return;
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(phone: phone),
    );
  }

  /// Resend email verification for the given email.
  static Future<void> resendEmailVerification(String email) async {
    await Supabase.instance.client.auth.resend(
      email: email.trim(),
      type: OtpType.signup,
    );
  }

  /// Send a password-reset email via Supabase.
  static Future<void> resetPassword(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'io.coverwise://reset-callback',
    );
  }

  /// Permanently delete the Supabase account and all server-side data.
  /// Local data is NOT cleared here — the caller should handle that.
  ///
  /// Returns a [DeleteAccountResult] describing the per-stage
  /// outcome. The backend returns HTTP 202 (deletion_requested) with
  /// a per-stage status. The previous version only accepted HTTP 200
  /// and threw on 202, which left the client in an inconsistent
  /// state (the server had begun or completed deletion; the client
  /// threw). Per the 2026-07-19 review, the client must accept 202
  /// and surface the per-stage status to the UI.
  static Future<DeleteAccountResult> deleteAccount() async {
    if (!hasAccountSession) {
      throw StateError('No account session to delete');
    }
    // Call our backend which deletes documents/chunks + Supabase auth user.
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    dio.interceptors.add(AuthInterceptor(dio));
    final response = await dio.delete('/user/account');
    // Per ADR-2026-07-19-05 + audit Phase 0 P0-04: accept both
    // 200 and 202. The backend returns 202 with a per-stage status.
    // Throwing on 202 caused the client to leave the user in an
    // inconsistent state where the server had begun or completed
    // deletion but the client still believed the account existed.
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
    // Sign out after a server-confirmed deletion (succeeded or
    // partial). Even on partial deletion, the local session
    // is no longer valid because the auth user may be gone or
    // the durable job is in flight; the user should be signed
    // out so they don't try to use the account.
    await signOut();
    return result;
  }

  /// Read the latest server-side deletion state after a user signs back in.
  /// The backend scopes this query to the authenticated account and does not
  /// expose stage checkpoints or internal error details.
  static Future<DeletionStatus> getDeletionStatus() async {
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

        // R1.7 (2026-07-18): emit identity_created exactly once per install.
        // _trackIdentityCreated is best-effort and never throws; it sets the
        // flag before emitting so a re-acquire (e.g. after token expiry)
        // does not double-count.
        _trackIdentityCreated();

        return token;
      }
    } catch (e) {
      debugPrint('Failed to acquire anonymous token: $e');
    }
    return null;
  }

  /// Emit identity_created once per install. Idempotent: a second call is a no-op.
  /// Called from acquireToken after the first successful anonymous token issue.
  /// Per-account creation (Supabase Auth sign-up) emits a separate
  /// account_created event from the auth flow handler.
  static void _trackIdentityCreated() {
    try {
      final box = _box;
      final alreadyTracked = box.get(_identityCreatedKey) == true;
      if (alreadyTracked) return;
      // Set the flag BEFORE emitting so even a synchronous crash during track
      // does not result in a duplicate event on the next acquireToken call.
      box.put(_identityCreatedKey, true);
      AnalyticsService.track('identity_created', {
        'identity_type': 'anonymous',
        'install_id': InstallService.getInstallId(),
      });
    } catch (e) {
      // Tracking is best-effort; never propagate.
      debugPrint('AuthService: failed to track identity_created: $e');
    }
  }

  static Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    // Also clear a pre-migration token if a reset happens before first read.
    await _box.delete(_tokenKey);
    await _box.delete(_tokenExpiryKey);
  }
}

/// The per-stage result of [AuthService.deleteAccount]. The
/// server returns HTTP 202 with a per-stage status; the
/// client surfaces this to the UI so the user knows what
/// was deleted, what failed, and what will be retried.
class DeleteAccountResult {
  /// 'deletion_succeeded' or 'deletion_partial' (per the
  /// backend's audit P0-04 contract).
  final String status;

  /// The number of document metadata rows deleted.
  final int deletedDocuments;

  /// The number of Supabase Storage files deleted.
  final int deletedStorageFiles;

  /// The number of storage files that failed to delete.
  final int storageErrors;

  /// True iff the Supabase auth user was deleted.
  final bool authUserDeleted;

  /// The list of stages that failed (empty for full success).
  final List<String> failedStages;

  /// The human-readable message from the backend.
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

  /// True iff the server reported all stages clean.
  bool get isComplete => status == 'deletion_succeeded';

  /// True iff the user should be told that some stages will
  /// remain visible to the user when the request is only partially complete.
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
        newToken = await AuthService.acquireToken(_dio);
      }
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
