/// CW-P0-004: Deterministic principal state machine.
///
/// Replaces the scattered nondeterministic identity transitions with a single
/// sealed class that models the three authoritative identity states:
///
///   1. [InstallGuest]       — no Supabase session; workspace = LocalPrincipal
///   2. [BackendAnonymous]   — Supabase anonymous session; workspace = AccountPrincipal
///   3. [RegisteredPrincipal] — Supabase registered session; workspace = AccountPrincipal
///
/// ## Why this exists
///
/// The previous code had three separate identity concerns:
///   - `WorkspacePrincipal` (which encrypted Hive workspace to open)
///   - `AccountIdentity` (Supabase auth state)
///   - Auth listener in `app.dart` (transition logic)
///
/// These were scattered across `app.dart`, `app_bootstrap.dart`,
/// `auth_service.dart`, and `reconciliation_coordinator.dart`. The
/// deferred anonymous sign-in created a race condition where the workspace
/// opened as `LocalPrincipal` at startup, then the auth listener tried
/// to switch to `AccountPrincipal` after anonymous sign-in completed.
///
/// ## Guarantees
///
///   - **Deterministic**: Given the same Supabase session state, the same
///     [PrincipalState] is always produced.
///   - **Atomic**: Each state bundles the workspace principal and account
///     identity into a single immutable value.
///   - **Durable**: The state can be reconstructed from persisted values
///     (Supabase session + install ID) at any point.
///   - **Observable**: The sealed class hierarchy enables exhaustive
///     pattern matching — callers must handle all three states.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'identity.dart';

/// The three authoritative identity states for CoverWise.
///
/// Exhaustive matching ensures callers handle every case:
/// ```dart
/// switch (principalState) {
///   InstallGuest():          // handle guest
///   BackendAnonymous():      // handle anonymous
///   RegisteredPrincipal():   // handle registered
/// }
/// ```
sealed class PrincipalState {
  const PrincipalState();

  /// The encrypted local workspace to open.
  WorkspacePrincipal get principal;

  /// The Supabase account identity (or [NoAccount] for guests).
  AccountIdentity get identity;

  /// Whether this state represents a registered (non-anonymous) account.
  bool get isRegistered => this is RegisteredPrincipal;

  /// Whether this state represents any Supabase session (anonymous or
  /// registered). A backend-anonymous session has a server-side identity
  /// but is not a registered account.
  bool get hasSupabaseSession =>
      this is BackendAnonymous || this is RegisteredPrincipal;

  /// A stable string for logging and analytics. Never null.
  String get label => switch (this) {
        InstallGuest()        => 'install_guest',
        BackendAnonymous()    => 'backend_anonymous',
        RegisteredPrincipal() => 'registered_account',
      };
}

/// No Supabase session exists. The app is running in local-only mode.
///
/// The workspace is derived from the device install ID and encrypted
/// with a principal-scoped DEK. This is the initial state on first launch
/// and the terminal state after sign-out.
class InstallGuest extends PrincipalState {
  const InstallGuest(this.installId);

  /// The stable device install identifier.
  final String installId;

  @override
  WorkspacePrincipal get principal => LocalPrincipal(installId);

  @override
  AccountIdentity get identity => const NoAccount();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallGuest && installId == other.installId;

  @override
  int get hashCode => installId.hashCode;

  @override
  String toString() => 'InstallGuest($installId)';
}

/// A Supabase anonymous session exists. The user has not registered but
/// has a server-side identity for anonymous API access.
///
/// The workspace is derived from the anonymous Supabase user UUID.
/// Anonymous data can be claimed into a registered account via the
/// claim flag protocol.
class BackendAnonymous extends PrincipalState {
  const BackendAnonymous(this.userId);

  /// The Supabase anonymous user UUID.
  final String userId;

  @override
  WorkspacePrincipal get principal => AccountPrincipal(userId);

  @override
  AccountIdentity get identity => AnonymousAccount(userId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackendAnonymous && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'BackendAnonymous($userId)';
}

/// A registered Supabase user session exists (email, phone, or OAuth).
///
/// The workspace is derived from the registered Supabase user UUID.
/// This is the fully authenticated state with access to all account
/// features including account deletion, data export, and phone linking.
///
/// Named `RegisteredPrincipal` (not `RegisteredAccount`) to avoid a
/// naming collision with [RegisteredAccount] in [identity.dart].
class RegisteredPrincipal extends PrincipalState {
  const RegisteredPrincipal(this.userId);

  /// The Supabase registered user UUID.
  final String userId;

  @override
  WorkspacePrincipal get principal => AccountPrincipal(userId);

  @override
  AccountIdentity get identity => RegisteredAccount(userId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisteredPrincipal && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'RegisteredPrincipal($userId)';
}

/// ─── Resolution ──────────────────────────────────────────────────────────
///
/// Deterministic factory methods that map Supabase session state to the
/// correct [PrincipalState]. The single decision point for identity.

extension Resolve on PrincipalState {
  /// Resolve the principal state from a Supabase [Session] and the device
  /// install ID. This is the canonical resolution used at bootstrap and
  /// during auth transitions.
  ///
  /// Rules:
  ///   - No session → [InstallGuest]
  ///   - Session with email or phone → [RegisteredPrincipal]
  ///   - Session without email and phone → [BackendAnonymous]
  ///
  /// The install ID is used as a fallback for the guest case. It is
  /// always provided even when a session exists, so the caller can
  /// construct the correct [InstallGuest] if the session is lost.
  static PrincipalState resolve({
    required Session? session,
    required String installId,
  }) {
    if (session == null) {
      return InstallGuest(installId);
    }
    final user = session.user;
    final hasEmail = user.email != null && user.email!.isNotEmpty;
    final hasPhone = user.phone != null && user.phone!.isNotEmpty;
    if (hasEmail || hasPhone) {
      return RegisteredPrincipal(user.id);
    }
    return BackendAnonymous(user.id);
  }

  /// Resolve from current Supabase client state. Convenience wrapper
  /// for use in the auth listener where Supabase is already initialized.
  static PrincipalState resolveCurrent({required String installId}) {
    final session = Supabase.instance.client.auth.currentSession;
    return resolve(session: session, installId: installId);
  }
}
