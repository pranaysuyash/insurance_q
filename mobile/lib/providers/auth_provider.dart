import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

/// Reactive auth state that rebuilds widgets when the user signs in/out.
///
/// Wraps Supabase's `onAuthStateChange` stream into a Riverpod provider.
/// Falls back to a value-based provider when Supabase is not configured.
final authStateProvider = StreamProvider<AuthState>((ref) {
  if (!AppConfig.hasSupabaseAuthConfig || !AuthService.isClientReady) {
    // No Supabase configured — emit a single "no session" state.
    return Stream.value(
      const AuthState(AuthChangeEvent.initialSession, null),
    );
  }
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Convenience provider: is the user signed in with a Supabase account?
final hasAccountProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
        data: (state) => state.session != null,
      ) ??
      false;
});

/// Convenience provider: the current Supabase user, or null.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (state) => state.session?.user,
  );
});
