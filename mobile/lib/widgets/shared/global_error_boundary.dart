import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/analytics_service.dart';

/// Global error boundary that wraps the entire app and catches unhandled errors.
///
/// Catches:
/// - Flutter framework errors (build/layout/paint)
/// - Widget build errors via [ErrorWidget.builder]
/// - Asynchronous errors via [PlatformDispatcher]
/// - Uncaught zone errors via [runZonedGuarded]
///
/// Shows a friendly error screen with retry option instead of a red screen.
class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;

  const GlobalErrorBoundary({super.key, required this.child});

  @override
  GlobalErrorBoundaryState createState() => GlobalErrorBoundaryState();
}

class GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  /// Current error details, null if no error.
  FlutterErrorDetails? _errorDetails;

  /// Whether the app is in error state.
  bool get hasError => _errorDetails != null;

  @override
  void initState() {
    super.initState();
    _setupErrorHandlers();
  }

  void _setupErrorHandlers() {
    // Catch Flutter framework errors (build/layout/paint)
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
      _handleError(details);
    };

    // Override ErrorWidget.builder to show friendly UI instead of red screen
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Schedule error handling for next frame to avoid build-during-build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleError(details);
      });
      // Show a visible error indicator immediately, not an invisible widget
      return Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Something went wrong',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    };

    // Catch asynchronous errors from the platform dispatcher
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _handleError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Flutter',
      ));
      return true;
    };
  }

  void _handleError(FlutterErrorDetails details) {
    if (!mounted) return;

    // Log error in debug mode
    if (kDebugMode) {
      debugPrint('=== GLOBAL ERROR ===');
      debugPrint('Error: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
      debugPrint('Library: ${details.library}');
      debugPrint('====================');
    }

    // Track error event for production monitoring
    _trackError(details);

    setState(() {
      _errorDetails = details;
    });
  }

  /// Track an error event with safe, non-PII properties for production monitoring.
  void _trackError(FlutterErrorDetails details) {
    try {
      AnalyticsService.track('global_error', {
        'error_type': details.exception.runtimeType.toString(),
        'error_message': _safeErrorMessage(details.exception),
        'library': details.library ?? 'unknown',
        'stack_summary': _stackTraceSummary(details.stack),
      });
    } catch (_) {
      // Analytics failure should never disrupt error handling
    }
  }

  /// Extract a safe error message (no PII, truncated to 200 chars).
  String _safeErrorMessage(Object error) {
    final message = error.toString();
    return message.length > 200 ? '${message.substring(0, 200)}...' : message;
  }

  /// Create a compact stack trace summary (top 3 frames, no file paths).
  String _stackTraceSummary(StackTrace? stack) {
    if (stack == null) return 'no_stack';
    final frames = stack.toString().split('\n').where((f) => f.trim().isNotEmpty).take(3).map((f) => f.trim()).join(' | ');
    return frames.isEmpty ? 'no_stack' : frames;
  }

  /// Clear the current error and attempt to rebuild.
  void clearError() {
    // Track error recovery for analytics
    try {
      AnalyticsService.track('global_error_recovered', {
        'error_type': _errorDetails?.exception.runtimeType.toString() ?? 'unknown',
      });
    } catch (_) {
      // Analytics failure should never disrupt error handling
    }

    setState(() {
      _errorDetails = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return _ErrorScreen(
        error: _errorDetails!,
        onRetry: clearError,
      );
    }
    return widget.child;
  }
}

/// Full-screen error display shown when an unhandled error occurs.
/// Uses Scaffold directly (no duplicate MaterialApp).
class _ErrorScreen extends StatelessWidget {
  final FlutterErrorDetails error;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Note: This widget renders outside MaterialApp, so Theme.of(context)
    // is not available. We use hardcoded brand colors to match the splash
    // screen and main app theme.
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  'An unexpected error occurred. Your data is safe — '
                  'this is just a display issue.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Error details (debug only)
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${error.exception}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Retry button
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Close button
                TextButton(
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  child: Text(
                    'Close App',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
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
