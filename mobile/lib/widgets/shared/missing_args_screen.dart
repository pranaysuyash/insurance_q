import 'package:flutter/material.dart';

/// Fallback screen shown when a deep link arrives without required arguments,
/// or when an unknown route is navigated to.
///
/// Extracted from app.dart to be reusable across route handlers and
/// deep-link validation.
class MissingArgsScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? recoveryRoute;
  final String recoveryLabel;

  const MissingArgsScreen({
    super.key,
    required this.title,
    required this.message,
    this.recoveryRoute,
    this.recoveryLabel = 'Go back',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_off_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () {
                  if (recoveryRoute case final route?) {
                    Navigator.of(context).pushReplacementNamed(route);
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                child: Text(recoveryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
