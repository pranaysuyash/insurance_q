/// Typed identity model for CoverWise.
///
/// P0.2: Replaces the conflated string-based identity system with a sealed
/// class hierarchy that distinguishes three separate identity contracts:
///
///   WorkspacePrincipal — which encrypted local workspace to open
///   AccountIdentity   — who is authenticated with Supabase
///   ApiCredential     — which token authorizes backend requests
// ignore_for_file: dangling_library_doc_comments

// ─── WorkspacePrincipal ─────────────────────────────────────────────────────
///
/// Identifies which encrypted local workspace should be opened. The
/// workspace is backed by Hive boxes encrypted with a DEK stored in
/// secure storage under the [principalId].
///
/// Two variants:
///   LocalPrincipal  — no Supabase session; workspace derived from install ID
///   AccountPrincipal — Supabase session exists; workspace derived from user UUID
sealed class WorkspacePrincipal {
  const WorkspacePrincipal();
  String get principalId;
}

/// A local-only workspace, derived from the device install ID.
/// No Supabase session exists — the user has not signed in.
class LocalPrincipal extends WorkspacePrincipal {
  const LocalPrincipal(this.installId);
  final String installId;

  @override
  String get principalId => 'local-only-$installId';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalPrincipal && installId == other.installId;

  @override
  int get hashCode => installId.hashCode;

  @override
  String toString() => 'LocalPrincipal($principalId)';
}

/// An account-backed workspace, derived from the Supabase user UUID.
/// A Supabase session exists (registered or anonymous).
class AccountPrincipal extends WorkspacePrincipal {
  const AccountPrincipal(this.userId);
  final String userId;

  @override
  String get principalId => userId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountPrincipal && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'AccountPrincipal($principalId)';
}

// ─── AccountIdentity ────────────────────────────────────────────────────────
///
/// Describes the Supabase authentication state. Independent of the workspace
/// principal (a LocalPrincipal workspace can exist alongside any session
/// state during transitions).
sealed class AccountIdentity {
  const AccountIdentity();
}

/// No Supabase session exists. The app is running in local-only mode, or
/// the session was lost (expired, signed out, or never created).
class NoAccount extends AccountIdentity {
  const NoAccount();
}

/// A Supabase anonymous session exists. The user has not yet registered
/// but has a server-side identity for anonymous API access.
class AnonymousAccount extends AccountIdentity {
  const AnonymousAccount(this.userId);
  final String userId;
}

/// A registered Supabase user session exists.
class RegisteredAccount extends AccountIdentity {
  const RegisteredAccount(this.userId);
  final String userId;
}

// ─── ApiCredential ──────────────────────────────────────────────────────────
///
/// The credential used to authorize backend API requests. Separate from
/// AccountIdentity because the backend may issue its own tokens independent
/// of the Supabase session (e.g. anonymous API tokens).
sealed class ApiCredential {
  const ApiCredential();
  String? get token;
}

/// No credential is available — the user has no backend session.
class NoCredential extends ApiCredential {
  const NoCredential();
  @override
  String? get token => null;
}

/// An anonymous API token acquired from POST /user/anonymous.
/// Stored in secure storage, independent of Supabase session.
class AnonymousCredential extends ApiCredential {
  const AnonymousCredential(this.token);
  @override
  final String token;
}

/// A Supabase session token (access_token JWT). Obtained from the
/// Supabase auth session.
class SessionCredential extends ApiCredential {
  const SessionCredential(this.token);
  @override
  final String token;
}
