import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/coverwise_theme.dart';

/// A thin amber banner shown at the top of the app shell when the auth session
/// has expired and token refresh has failed. Unlike a blocking dialog, this
/// banner lets the user continue viewing cached documents and policy details
/// while being prompted to sign in again.
///
/// Place it as a child inside a [Column] above the screen body, below the
/// [OfflineBanner] if both are visible (offline takes priority).
class AuthExpiredBanner extends ConsumerWidget {
  const AuthExpiredBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = ref.watch(authSessionExpiredProvider);
    if (!expired) return const SizedBox.shrink();

    final theme = Theme.of(context);
    const warning = Color(0xFFD97706);

    return Semantics(
      container: true,
      liveRegion: true,
      label:
          'Your session has expired. Cached data is still available locally, but uploading and Q&A need a fresh sign-in.',
      excludeSemantics: true,
      child: Material(
        color: theme.brightness == Brightness.dark
            ? warning.withValues(alpha: 0.16)
            : const Color(0xFFFFF4DD),
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: CoverWiseColors.line,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified_user_outlined,
                      size: 20, color: warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Session expired. Sign in again to upload and ask questions.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
