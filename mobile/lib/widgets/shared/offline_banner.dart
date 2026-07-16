import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connectivity_provider.dart';
import '../../theme/coverwise_theme.dart';

/// A thin amber banner shown at the top of backend-dependent screens when the
/// device is offline. The app is offline-first, so this is informational — it
/// tells the user why Q&A answers and live uploads are unavailable, rather than
/// leaving them to infer it from repeated SnackBar errors.
///
/// Place it as the first child inside a [Column] above the screen body.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) return const SizedBox.shrink();
    final theme = Theme.of(context);
    const warning = Color(0xFFD97706);

    return Semantics(
      container: true,
      liveRegion: true,
      label:
          "You're offline. Documents are available locally, but Ask and uploads need a connection.",
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
                  child: const Icon(Icons.cloud_off_outlined,
                      size: 20, color: warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "You're offline. Documents are available locally, but Ask and uploads need a connection.",
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
