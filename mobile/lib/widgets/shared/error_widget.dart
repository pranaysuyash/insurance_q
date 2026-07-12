import 'package:flutter/material.dart';

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: Colors.grey[600])),
            ),
            if (onRetry != null)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: onRetry,
                tooltip: 'Retry',
              ),
          ],
        ),
      ),
    );
  }
}
