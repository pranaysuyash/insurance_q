import 'package:flutter/material.dart';
import '../../theme/coverwise_theme.dart';
import 'coverwise_components.dart';

/// Centered, retryable error view for screens that failed to load content.
///
/// Named [AppErrorView] rather than `ErrorWidget` to avoid shadowing Flutter's
/// built-in [material.ErrorWidget], which renders red error screens for
/// unhandled framework exceptions. Shadowing that symbol silently replaces the
/// framework error renderer and is a latent footgun.
class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: onRetry == null ? message : '$message. Retry available.',
      button: onRetry != null,
      onTap: onRetry,
      excludeSemantics: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoverWiseIconBadge(
                icon: icon,
                color: const Color(0xFFD64C4C),
                size: 64,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: onRetry,
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline banner with an icon, message, and optional retry.
class AppErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: onRetry == null ? message : '$message. Retry available.',
      button: onRetry != null,
      onTap: onRetry,
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CoverWiseIconBadge(
                icon: Icons.info_outline_rounded,
                color: CoverWiseColors.blue,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              if (onRetry != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: onRetry,
                  tooltip: 'Retry',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
