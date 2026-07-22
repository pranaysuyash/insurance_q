import 'package:flutter/material.dart';
import '../../theme/coverwise_theme.dart';

/// Lightweight registry that routes errors from the global error handler
/// to the most specific active [ScreenErrorBoundary].
///
/// Boundaries register on [State.initState] and unregister on [State.dispose].
/// When [GlobalErrorBoundary] detects an error, it calls [dispatch] first.
/// If a screen-level boundary is active, the error is scoped to that screen
/// instead of taking down the entire app.
class ErrorBoundaryRegistry {
  ErrorBoundaryRegistry._();
  static final _instance = ErrorBoundaryRegistry._();
  static ErrorBoundaryRegistry get instance => _instance;

  final List<_BoundaryEntry> _boundaries = [];

  void register(String screenName, void Function(FlutterErrorDetails) onError) {
    _boundaries.add(_BoundaryEntry(name: screenName, onError: onError));
  }

  void unregister(String screenName) {
    _boundaries.removeWhere((e) => e.name == screenName);
  }

  /// Returns true if an active screen boundary handled the error.
  bool dispatch(FlutterErrorDetails details) {
    if (_boundaries.isEmpty) return false;
    _boundaries.last.onError(details);
    return true;
  }
}

class _BoundaryEntry {
  final String name;
  final void Function(FlutterErrorDetails) onError;
  _BoundaryEntry({required this.name, required this.onError});
}

/// Per-screen error boundary that isolates crashes to the current screen.
///
/// Wraps a screen's widget tree so that a build error in one screen does not
/// take down the entire app. When an error occurs, this boundary shows a
/// localized fallback UI with a retry button instead of propagating to the
/// global [GlobalErrorBoundary].
///
/// Use in [IndexedStack] children, navigation destinations, and any screen
/// that should be self-healing:
///
/// ```dart
/// ScreenErrorBoundary(
///   screenName: 'documents',
///   child: DocumentsScreen(),
/// )
/// ```
class ScreenErrorBoundary extends StatefulWidget {
  final String screenName;
  final Widget child;
  final Widget Function(FlutterErrorDetails details)? errorBuilder;

  const ScreenErrorBoundary({
    super.key,
    required this.screenName,
    required this.child,
    this.errorBuilder,
  });

  @override
  State<ScreenErrorBoundary> createState() => _ScreenErrorBoundaryState();
}

class _ScreenErrorBoundaryState extends State<ScreenErrorBoundary> {
  FlutterErrorDetails? _error;

  bool get hasError => _error != null;

  @override
  void initState() {
    super.initState();
    ErrorBoundaryRegistry.instance.register(widget.screenName, _onError);
  }

  @override
  void dispose() {
    ErrorBoundaryRegistry.instance.unregister(widget.screenName);
    super.dispose();
  }

  void _onError(FlutterErrorDetails details) {
    if (!mounted) return;
    setState(() {
      _error = details;
    });
  }

  void _clearError() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error case final error?) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(error);
      }
      return _ScreenErrorFallback(
        screenName: widget.screenName,
        onRetry: _clearError,
      );
    }
    return widget.child;
  }
}

/// Default fallback UI shown by [ScreenErrorBoundary] when no custom
/// [errorBuilder] is provided.
class _ScreenErrorFallback extends StatelessWidget {
  final String screenName;
  final VoidCallback onRetry;

  const _ScreenErrorFallback({
    required this.screenName,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Something went wrong on this screen. Retry available.',
      button: true,
      onTap: onRetry,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'An unexpected error occurred on this screen.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
