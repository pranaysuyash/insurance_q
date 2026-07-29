/// Typed arguments for the password reset navigation route.
///
/// Replaces the raw URI string that was previously passed through route
/// settings. Supabase handles the token exchange internally via the deep
/// link; ResetPasswordScreen calls auth.updateUser() directly and does
/// not need the redirect URL.
///
/// The raw URI could contain auth material (access_token, refresh_token)
/// in the fragment or query, which would leak through route settings,
/// crash breadcrumbs, and debug logs.
class ResetPasswordArgs {
  const ResetPasswordArgs();
}
