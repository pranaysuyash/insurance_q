import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state_store.dart';
import 'analytics_service.dart';
import 'install_service.dart';
import 'principal_key_service.dart';
import 'entitlement_service.dart';
import 'billing_adapter.dart';
import '../config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authServiceProvider = NotifierProvider<AuthNotifier, AuthServiceState>(
  AuthNotifier.new,
);

/// Auth client initialization status — sealed class replacing the old bool
/// [AuthServiceState.accountClientReady] which could not distinguish
/// "not configured" from "initializing" from "ready" from "failed".
///
/// I3-P1b: The sealed class is extensible — each subtype can carry
/// additional data (e.g. [FailedAuth] carries an optional error message).
/// This enables the UI to show differentiated states rather than silently
/// appearing broken.
sealed class AccountAuthRuntime {
  const AccountAuthRuntime();

  /// Whether the auth client is in a usable state.
  bool get isReady => this is ReadyAuth;
}

/// Supabase SDK has not been configured for this build.
class UnconfiguredAuth extends AccountAuthRuntime {
  const UnconfiguredAuth();
}

/// Supabase SDK is being initialized (between config check and
/// Supabase.initialize() completion). Transient state — should resolve
/// to [ReadyAuth] or [FailedAuth] within a single bootstrap cycle.
class InitializingAuth extends AccountAuthRuntime {
  const InitializingAuth();
}

/// Supabase SDK is configured and initialized successfully.
class ReadyAuth extends AccountAuthRuntime {
  const ReadyAuth();
}

/// Supabase SDK initialization failed at bootstrap.
class FailedAuth extends AccountAuthRuntime {
  /// Optional human-readable error description.
  final String? message;
  const FailedAuth([this.message]);
}

/// Riverpod-managed state for [AuthNotifier].
class AuthServiceState {
  /// Auth client initialization status. See [AccountAuthRuntime] for states.
  /// I3-P1b: Sealed class replacing the old AuthClientStatus enum.
  final AccountAuthRuntime authRuntime;

  /// Whether the auth client is ready. Equivalent to [authRuntime.isReady].
  bool get accountClientReady => authRuntime.isReady;

  final bool preserveAnonymousWorkspaceForClaim;

  /// Set to true when a 401 response arrives and token refresh fails.
  /// The UI shows a non-blocking "Session expired — Sign in again" banner
  /// instead of a generic error. The user can continue viewing cached data
  /// while being prompted to re-auth.
  /// Cleared when a new token is successfully acquired or the user signs in.
  final bool sessionExpired;

  const AuthServiceState({
    required this.authRuntime,
    required this.preserveAnonymousWorkspaceForClaim,
    this.sessionExpired = false,
  });
}

/// I3-P1a: AuthService — final static surface.
///
/// Phase 4 (complete): All delegation statics removed. The remaining
/// statics are either canonical (clearToken, updateUserPhone, etc.)
/// or inherently pre-Riverpod (loadPersistedClaimFlag, hasAccountSession).
///
/// == Remaining static callers ==
///
/// Pre-Riverpod (before runApp):
///   bootstrap/app_bootstrap.dart:
///     loadPersistedClaimFlag, hasAccountSession (×2),
///     accessToken, acquireToken
///
/// Internal (auth_service.dart itself):
///   AuthNotifier methods call canonical statics: clearToken,
///   updateUserPhone, resendEmailVerification, resetPassword,
///   _readCachedToken
///   AuthInterceptor: accessToken (via _resolveAccessToken),
///     hasAccountSession, _instance (for acquireToken)
///
/// == Migration history ==
///
/// Phase 1 (done): Consolidated clearToken, updateUserPhone,
///                 resendEmailVerification, resetPassword as canonical
/// Phase 2 (done): Simplified isClientReady, hasAccountSession,
///                 accountUserId to direct Supabase checks
/// Phase 3 (done): All screen/widget/service callers migrated to
///                 Riverpod providers — zero AuthService.* calls
///                 remain in screens/, widgets/, services/, providers/
/// Phase 4 (done): Removed all delegation statics (signIn, signUp,
///                 signInWithPhoneOtp, verifyPhoneOtp, signOut,
///                 signInWithGoogle, deleteAccount, getDeletionStatus,
///                 exportAccount, prepareAnonymousWorkspaceClaim,
///                 consumeAnonymousWorkspaceClaim, claimAnonymousData).
class AuthService {
  static const _tokenKey = 'anonymous_auth_token';
  static const _tokenExpiryKey = 'anonymous_auth_token_expiry';
  static const _identityCreatedKey = 'analytics_identity_created';
  static const _claimFlagKey = 'anonymous_workspace_claim_pending';

  static Box get _box => Hive.box(AppStateStore.boxName);
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static AuthNotifier? _instance;
  static AuthNotifier? get _notifier => _instance;

  /// P0.4: Static cache for the persisted claim flag, set during startup
  /// bootstrap (main.dart _startup) by reading FlutterSecureStorage.
  /// This allows [consumeAnonymousWorkspaceClaim] to check the flag
  /// synchronously (required for ref.listen callback) even if the process
  /// was killed and restarted during an OAuth flow.
  static bool _persistedClaimFlag = false;

  /// Set [persistedClaimFlag] from a startup-time secure storage read.
  /// Called once during bootstrap (main.dart _startup) after Supabase init.
  /// This is the async bridge that makes the durable claim flag visible to
  /// the synchronous [consumeAnonymousWorkspaceClaim] method.
  static Future<void> loadPersistedClaimFlag() async {
    final flag = await _secureStorage.read(key: _claimFlagKey);
    if (flag == '1') {
      // Verify there's still a valid anonymous token — the flag may be
      // stale from a cancelled OAuth flow in a previous session.
      // Without this check, a cancelled Google sign-in could cause an
      // unnecessary workspace copy on the next sign-in.
      // Wrap in try-catch because _readCachedToken() may fall back to
      // Hive.box() for legacy tokens, and that box may not be open yet
      // during startup bootstrap (runs before openForActivePrincipal).
      try {
        _persistedClaimFlag = await _readCachedToken() != null;
      } catch (_) {
        // Hive fallback unavailable during startup; assume no claim.
        _persistedClaimFlag = false;
      }
    } else {
      _persistedClaimFlag = false;
    }
  }

  /// Whether the Supabase client is configured and ready.
  /// I3-P1a Phase 2: Removed notifier routing — Supabase is initialized
  /// at bootstrap before runApp(), so if it's configured, it's ready.
  /// Widgets needing reactive state should watch authServiceProvider instead.
  static bool get isClientReady => AppConfig.hasSupabaseAuthConfig;

  /// Whether a Supabase session exists (registered or anonymous).
  /// I3-P1a Phase 2: Removed notifier routing — checks Supabase directly.
  /// The notifier version provides the same check for Riverpod watchers.
  static bool get hasAccountSession =>
      AppConfig.hasSupabaseAuthConfig &&
      Supabase.instance.client.auth.currentSession != null;

  /// The current Supabase user ID, or null if no session exists.
  /// I3-P1a Phase 2: Removed notifier routing — checks Supabase directly.
  static String? get accountUserId =>
      hasAccountSession ? Supabase.instance.client.auth.currentUser?.id : null;

  /// Canonical token-resolution entry point. Routes directly through
  /// [_resolveAccessToken] — no notifier indirection needed since the
  /// Supabase-session-vs-cached-token decision is entirely static.
  static Future<String?> accessToken() => _resolveAccessToken();



  /// Update phone — pure-forward to Supabase.
  /// I3-P1a Phase 1: removed notifier routing since the notifier method
  /// just calls Supabase with the same session check.
  static Future<UserResponse> updateUserPhone(String phone) async {
    if (!hasAccountSession) {
      throw StateError('Must be signed in to link phone to account');
    }
    return Supabase.instance.client.auth.updateUser(
      UserAttributes(phone: phone.trim()),
    );
  }



  /// Resend email verification — pure-forward to Supabase.
  /// No state/analytics in the notifier; makes this a pure static.
  /// I3-P1a Phase 1: removed notifier routing since the notifier method
  /// just calls Supabase directly with no extra tracking.
  static Future<void> resendEmailVerification(String email) async {
    await Supabase.instance.client.auth.resend(
      email: email.trim(),
      type: OtpType.signup,
    );
  }

  /// Reset password — pure-forward to Supabase.
  /// No state/analytics in the notifier; makes this a pure static.
  /// I3-P1a Phase 1: removed notifier routing since the notifier method
  /// just calls Supabase directly with the same redirect URI.
  static Future<void> resetPassword(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.resetPasswordRedirectUri,
    );
  }



  /// Clear token — canonical implementation. Deletes from both secure
  /// storage and Hive legacy fallback.
  /// I3-P1a Phase 1: removed `_notifier?.clearToken()` call at the end
  /// because AuthNotifier.clearToken() now forwards here, creating
  /// infinite recursion. The static method is the canonical implementation.
  static Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    await _box.delete(_tokenKey);
    await _box.delete(_tokenExpiryKey);
  }

  static Future<String?> acquireToken(Dio dio) async {
    return _notifier?.acquireToken(dio);
  }

  /// Canonical token-resolution method — the single decision point for
  /// obtaining an access token. Used by both [AuthService.accessToken]
  /// (static routing) and [AuthNotifier.accessToken] (instance routing).
  ///
  /// Prefers the Supabase session token when an account session exists;
  /// otherwise falls back to the cached anonymous API token.
  static Future<String?> _resolveAccessToken() async {
    if (hasAccountSession) {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    }
    return _readCachedToken();
  }

  /// Read the cached anonymous API token from secure storage, with Hive
  /// legacy migration. Returns null if no valid token exists (expired,
  /// corrupted, or never acquired).
  ///
  /// This is the canonical cached-token reader used by all paths:
  /// [_resolveAccessToken], [claimAnonymousData], and
  /// [prepareAnonymousWorkspaceClaim].
  static Future<String?> _readCachedToken() async {
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
    // Supabase is initialized at bootstrap before runApp(), so the client
    // is ready by the time the notifier builds.
    return AuthServiceState(
      authRuntime: AppConfig.hasSupabaseAuthConfig
          ? const ReadyAuth()
          : const UnconfiguredAuth(),
      preserveAnonymousWorkspaceForClaim: false,
    );
  }

  bool get isClientReady => state.authRuntime.isReady;

  bool get hasAccountSession =>
      AppConfig.hasSupabaseAuthConfig &&
      isClientReady &&
      Supabase.instance.client.auth.currentSession != null;

  String? get accountUserId =>
      hasAccountSession ? Supabase.instance.client.auth.currentUser?.id : null;

  Future<String?> accessToken() async {
    // Route through the canonical static method to avoid duplicating
    // the Supabase-session-vs-cached-token decision logic.
    return AuthService._resolveAccessToken();
  }

  Future<AuthResponse> signIn(String email, String password) async {
    // P0.4: Prepare anonymous workspace claim before sign-in, so if the
    // session transition runs, the local anonymous workspace data is
    // preserved and claimed into the new account.
    await prepareAnonymousWorkspaceClaim();

    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.user != null) {
      // A successful sign-in means the session is no longer expired.
      // Clear the flag so the UI dismisses the "Session expired" banner.
      updateSessionExpired(false);
      // P1.6: signIn() is a sign-in, not a sign-up.
      // Track as signed_in — not account_created — to avoid corrupting
      // acquisition funnel metrics. signUp() separately fires account_created.
      _trackEvent('account_signed_in', {'auth_method': 'email'});
    }
    return response;
  }

  Future<AuthResponse> signUp(
      String email, String password, String displayName) async {
    // P0.4: Prepare anonymous workspace claim before sign-up. If the user
    // had anonymous local data, it will be preserved and claimed into the
    // new account. prepareAnonymousWorkspaceClaim is a no-op if no cached
    // anonymous token exists.
    await prepareAnonymousWorkspaceClaim();

    final response = await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    if (response.user != null) {
      // A successful sign-up resets the session; clear any stale
      // expired-state banner left from a prior auth failure.
      updateSessionExpired(false);
      _trackEvent('account_created', {'auth_method': 'email'});
    }
    return response;
  }

  Future<void> signInWithPhoneOtp(String phone) async {
    if (state.authRuntime is! ReadyAuth) return;
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
      // A successful phone OTP verification creates a valid session; clear
      // any stale expired-state banner from a prior auth failure.
      updateSessionExpired(false);

      // P1.6: Phone OTP is used for both sign-up and sign-in. Detect which
      // by checking whether the user record was just created.
      // Supabase's User.createdAt is a non-nullable String ISO-8601
      // timestamp in the Flutter SDK version used by this project.
      // Parse it to DateTime and check if it's within the last 5 seconds
      // (fresh registration vs. returning user sign-in).
      bool isNewUser = false;
      final createdAt = DateTime.tryParse(response.user!.createdAt);
      if (createdAt != null) {
        isNewUser = DateTime.now().difference(createdAt).inSeconds < 5;
      }
      _trackEvent(
        isNewUser ? 'account_created' : 'account_signed_in',
        {'auth_method': 'phone_otp'},
      );
    }
    return response;
  }

  /// Update phone — delegates to the canonical static method.
  /// I3-P1a Phase 1: forwards to AuthService.updateUserPhone to eliminate
  /// duplicate Supabase call + session check.
  Future<UserResponse> updateUserPhone(String phone) async {
    return AuthService.updateUserPhone(phone);
  }

  /// Track an analytics event with the install_id and auth_method.
  /// Separated from the old _trackAccountCreated (which conflated sign-in
  /// with sign-up) to support both account_signed_in and account_created
  /// independently.
  void _trackEvent(String eventName, Map<String, dynamic> extraProps) {
    try {
      AnalyticsService.track(eventName, {
        'install_id': InstallService.getInstallId(),
        ...extraProps,
      });
    } catch (e) {
      debugPrint('AuthService: failed to track $eventName: $e');
    }
  }

  Future<void> claimAnonymousData() async {
    final legacyToken = await AuthService._readCachedToken();
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

  /// Persist a durable claim flag to secure storage so it survives
  /// process death (critical for OAuth flows that kill and restart the
  /// Flutter process). The flag is cleared by [consumeAnonymousWorkspaceClaim]
  /// after the workspace transition completes.
  ///
  /// P0.4: Previously memory-only — the flag was lost if the process was
  /// killed between prepare and consume (e.g. OAuth browser redirect).
  /// Now persisted to FlutterSecureStorage.
  Future<void> prepareAnonymousWorkspaceClaim() async {
    final hasToken = await AuthService._readCachedToken() != null;
    if (hasToken) {
      await AuthService._secureStorage.write(
        key: AuthService._claimFlagKey,
        value: '1',
      );
    }
    state = state.copyWith(preserveAnonymousWorkspaceForClaim: hasToken);
  }

  /// Consume the claim flag: checks both the in-memory Riverpod state AND
  /// the static [AuthService._persistedClaimFlag] (set during startup
  /// bootstrap from secure storage). Returns true if anonymous data should
  /// be preserved and claimed into the new account.
  ///
  /// Must be synchronous — called from within a ref.listen callback in
  /// main.dart. The async storage read already happened during startup
  /// bootstrap via [AuthService.loadPersistedClaimFlag], which populates
  /// the static flag that bridges across process death.
  ///
  /// P0.4: The static flag handles the OAuth process-death case:
  ///  1. prepareAnonymousWorkspaceClaim() writes '1' to secure storage
  ///  2. OAuth kills and restarts the Flutter process
  ///  3. Startup bootstrap reads the flag into _persistedClaimFlag
  ///  4. After signedIn event, this method returns true
  bool consumeAnonymousWorkspaceClaim() {
    final preserve = state.preserveAnonymousWorkspaceForClaim ||
        AuthService._persistedClaimFlag;
    AuthService._persistedClaimFlag = false;
    state = state.copyWith(preserveAnonymousWorkspaceForClaim: false);
    // Fire-and-forget the storage delete to avoid blocking the callback.
    unawaited(_clearClaimFlag());
    return preserve;
  }

  /// Clear the persisted claim flag from secure storage.
  /// Runs asynchronously; the in-memory flag is already consumed.
  Future<void> _clearClaimFlag() async {
    try {
      await AuthService._secureStorage.delete(key: AuthService._claimFlagKey);
    } catch (_) {}
  }

  Future<void> signOut() async {
    if (state.authRuntime is ReadyAuth) {
      await Supabase.instance.client.auth.signOut();
    }

    // P0.3: Clear the anonymous auth token from secure storage and Hive.
    // This runs even when Supabase is not ready — a stale token may exist
    // from a prior session. Errors from Hive box access are non-fatal
    // (the box may not be open during workspace migration).
    try {
      await clearToken();
    } catch (_) {}

    // P0.3: Clear the in-memory DEK so encrypted Hive workspace boxes
    // become unreadable. The auth listener in main.dart also does this
    // when Supabase fires the signedOut event, but clearing it here
    // closes the gap between signOut() returning and the listener firing.
    PrincipalKeyService().clearKey();

    // P0.3: Detach the RevenueCat customer from the signed-out account.
    // RevenueCat maintains its own identity — without this, account A's
    // entitlements could bleed into a guest or account B session.
    // Use a temporary BillingAdapter; the static _initialized flag
    // ensures Purchases.logOut() only runs if RevenueCat was configured.
    try {
      final billing = BillingAdapter(EntitlementService());
      await billing.clearAccountIdentity();
    } catch (_) {
      // RevenueCat logout is best-effort; the next workspace start will
      // re-establish identity through billingInitProvider.
    }

    // P0.4: Clear the persisted claim flag so a stale flag from a previous
    // session does not cause incorrect workspace preservation on next sign-in.
    await _clearClaimFlag();

    // P0.3: Reset analytics identity synchronously in signOut() rather
    // than waiting for the Supabase signedOut auth listener to fire.
    // The listener will also call resetForWorkspace() as part of the
    // workspace transition, but calling it here closes the window where
    // a pending analytics timer could fire with a stale session ID.
    // resetForWorkspace() is idempotent — the second call is harmless.
    AnalyticsNotifier.instance?.resetForWorkspace();

    // P0.3: Clear the Sentry user identity. After sign-out, crash reports
    // must not be attributed to a stale user. This runs even if Sentry
    // wasn't initialized (SentryFlutter.init skipped) — configureScope
    // and setUser are no-ops when the SDK is disabled.
    Sentry.configureScope((scope) {
      scope.setUser(null);
    });

    // The auth listener in main.dart will fire on the Supabase signedOut
    // event and handle: workspace transition via resetForPrincipal(),
    // additional analytics reset (idempotent), sync cancellation, and
    // local-only principal setup.
  }

  Future<void> signInWithGoogle() async {
    // P0.4: Persist the anonymous workspace claim flag BEFORE the OAuth
    // flow starts. The OAuth browser redirect may kill and restart the
    // Flutter process; a memory-only flag would be lost. The secure storage
    // flag survives process death and is consumed by
    // consumeAnonymousWorkspaceClaim() when the signedIn event fires in the
    // auth listener (main.dart).
    await prepareAnonymousWorkspaceClaim();
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.loginRedirectUri,
    );
  }

  /// Resend email verification — delegates to canonical static.
  /// I3-P1a Phase 1: forwards to AuthService.resendEmailVerification
  Future<void> resendEmailVerification(String email) async {
    await AuthService.resendEmailVerification(email);
  }

  /// Reset password — delegates to canonical static.
  /// I3-P1a Phase 1: forwards to AuthService.resetPassword
  Future<void> resetPassword(String email) async {
    await AuthService.resetPassword(email);
  }

  /// Initiate account deletion on the backend, then sign out locally only
  /// if the backend confirms synchronous completion (status ==
  /// "deletion_succeeded"). If the backend returns 202 "In Progress", the
  /// user retains their session and can call [getDeletionStatus] to check
  /// progress.
  ///
  /// I3-P1e: Previously called signOut() unconditionally, which destroyed
  /// the session and made getDeletionStatus() impossible for async deletions.
  /// Also clears local data after successful deletion to prevent stale
  /// cached content from rendering after deletion completes.
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
    // I3-P1e: Only sign out if deletion completed synchronously.
    // If the backend returned 202 (async in progress), keep the session
    // so the user can call getDeletionStatus() to monitor progress.
    if (result.isComplete) {
      await signOut();
    }
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

  /// Clear token — delegates to the canonical static method.
  /// I3-P1a Phase 1: forwards to AuthService.clearToken to eliminate
  /// duplicate secure storage + Hive deletion code.
  Future<void> clearToken() async {
    await AuthService.clearToken();
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

  Future<void> _trackIdentityCreated() async {
    try {
      // Use secure storage (always available at startup) instead of Hive
      // to avoid a race with openForActivePrincipal(). The identity-created
      // flag is a one-shot telemetry guard that persists across restarts;
      // secure storage provides that guarantee without depending on Hive
      // box availability.
      final alreadyTracked =
          await AuthService._secureStorage.read(key: AuthService._identityCreatedKey);
      if (alreadyTracked != null) return;
      await AuthService._secureStorage.write(
        key: AuthService._identityCreatedKey,
        value: '1',
      );
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
    AccountAuthRuntime? authRuntime,
    bool? preserveAnonymousWorkspaceForClaim,
    bool? sessionExpired,
  }) {
    return AuthServiceState(
      authRuntime: authRuntime ?? this.authRuntime,
      preserveAnonymousWorkspaceForClaim:
          preserveAnonymousWorkspaceForClaim ?? this.preserveAnonymousWorkspaceForClaim,
      sessionExpired: sessionExpired ?? this.sessionExpired,
    );
  }

}

/// Dio interceptor: adds the auth header, auto-refreshes on 401.
///
/// P1.4: Uses single-flight refresh so 10 concurrent 401s trigger only one
/// refresh call. Clones request options before retrying to avoid mutating
/// the original (which may be needed for the original error path). Adds
/// `authRetryAttempt` metadata to prevent infinite retry loops.
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  AuthInterceptor(this._dio);

  /// Single-flight lock for token refresh.
  /// When multiple requests hit 401 simultaneously, only one refresh is
  /// triggered; all wait on the same future.
  Future<String?>? _refreshInProgress;

  /// Maximum number of retries for a single request's auth retry.
  static const int _maxRetries = 1;

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
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // P1.4: Prevent infinite retry loops — if this request was already
    // retried once, do not retry again.
    final retryCount = err.requestOptions.extra['authRetryAttempt'] as int? ?? 0;
    if (retryCount >= _maxRetries) {
      debugPrint('AuthInterceptor: max retries ($_maxRetries) reached for '
          '${err.requestOptions.path}; giving up.');
      handler.next(err);
      return;
    }

    debugPrint('Got 401 on ${err.requestOptions.path}, attempting token refresh...');

    // P1.4: Single-flight refresh — one refresh at a time.
    String? newToken;
    if (_refreshInProgress != null) {
      // Another request is already refreshing; wait for it.
      newToken = await _refreshInProgress;
    } else {
      // Start a new refresh; all concurrent 401s will share this future.
      _refreshInProgress = _performRefresh();
      try {
        newToken = await _refreshInProgress;
      } finally {
        _refreshInProgress = null;
      }
    }

    if (newToken != null) {
      // Refresh succeeded — clear the expired state if it was set.
      AuthService._notifier?.updateSessionExpired(false);

      // Clone request options explicitly to avoid mutating the original.
      // Using RequestOptions.copyWith causes mutation of the original;
      // instead create a fresh RequestOptions from the original's data.
      final retryOptions = RequestOptions(
        method: err.requestOptions.method,
        path: err.requestOptions.path,
        baseUrl: err.requestOptions.baseUrl,
        data: err.requestOptions.data,
        queryParameters: err.requestOptions.queryParameters,
        headers: Map<String, dynamic>.from(err.requestOptions.headers)
          ..['Authorization'] = 'Bearer $newToken',
        extra: Map<String, dynamic>.from(err.requestOptions.extra)
          ..['authRetryAttempt'] = retryCount + 1,
        connectTimeout: err.requestOptions.connectTimeout,
        receiveTimeout: err.requestOptions.receiveTimeout,
        responseType: err.requestOptions.responseType,
        contentType: err.requestOptions.contentType,
        followRedirects: err.requestOptions.followRedirects,
        maxRedirects: err.requestOptions.maxRedirects,
        sendTimeout: err.requestOptions.sendTimeout,
        listFormat: err.requestOptions.listFormat,
      );

      try {
        final response = await _dio.fetch(retryOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        handler.next(err);
        return;
      }
    }

    // Refresh failed — signal session expired so the UI shows a
    // non-blocking banner instead of a generic error. The user can
    // continue viewing cached data while being prompted to re-auth.
    AuthService._notifier?.updateSessionExpired(true);
    handler.next(err);
  }

  /// Perform the actual token refresh, shared by all concurrent 401 retries.
  Future<String?> _performRefresh() async {
    try {
      if (AuthService.hasAccountSession) {
        final response =
            await Supabase.instance.client.auth.refreshSession();
        return response.session?.accessToken;
      } else {
        return await AuthService._instance?.acquireToken(_dio);
      }
    } catch (_) {
      return null;
    }
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
