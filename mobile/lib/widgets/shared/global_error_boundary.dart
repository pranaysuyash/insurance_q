import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/analytics_service.dart';
import '../../theme/coverwise_theme.dart';

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

  /// Saved original handlers for restoration in dispose().
  FlutterExceptionHandler? _originalFlutterOnError;
  late Widget Function(FlutterErrorDetails) _originalErrorWidgetBuilder;
  bool Function(Object, StackTrace)? _originalPlatformDispatcherOnError;

  /// Dedup flag: prevents both FlutterError.onError and ErrorWidget.builder
  /// from scheduling duplicate _handleError calls for the same error.
  bool _errorUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _saveOriginalHandlers();
    _setupErrorHandlers();
  }

  /// Save the original error handlers so we can restore them in dispose().
  void _saveOriginalHandlers() {
    _originalFlutterOnError = FlutterError.onError;
    _originalErrorWidgetBuilder = ErrorWidget.builder;
    _originalPlatformDispatcherOnError = PlatformDispatcher.instance.onError;
  }

  /// Restore the original error handlers when this boundary is disposed.
  void _restoreOriginalHandlers() {
    FlutterError.onError = _originalFlutterOnError;
    ErrorWidget.builder = _originalErrorWidgetBuilder;
    if (_originalPlatformDispatcherOnError != null) {
      PlatformDispatcher.instance.onError = _originalPlatformDispatcherOnError!;
    }
  }

  void _setupErrorHandlers() {
    // Catch Flutter framework errors (build/layout/paint).
    // Do NOT call FlutterError.presentError() here — the ErrorWidget.builder
    // override below handles the user-facing display. Calling presentError()
    // in debug mode would interfere with the test framework's pending
    // exception tracking, causing _pendingExceptionDetails assertion failures.
    FlutterError.onError = (FlutterErrorDetails details) {
      _scheduleHandleError(details);
    };

    // Override ErrorWidget.builder to show friendly UI instead of red screen.
    // Always active — the post-frame callback pattern avoids build-during-build
    // and the PlatformDispatcher override (release-only) is what previously
    // caused infinite frame scheduling loops in tests.
    // NOTE: We use a simple static widget here (no CircularProgressIndicator)
    // to avoid infinite frame scheduling. The full _ErrorScreen replaces this
    // once _handleError runs via the post-frame callback.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Schedule error handling for next frame to avoid build-during-build
      _scheduleHandleError(details);
      // Show a minimal error indicator immediately — static, no animations
      return Semantics(
        liveRegion: true,
        label: 'Something went wrong',
        child: const Material(
          color: CoverWiseColors.ink,
          child: Center(
            child: Text(
              'Something went wrong',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    };

    // Catch asynchronous errors from the platform dispatcher.
    // Skip in debug mode — FlutterError.onError and ErrorWidget.builder
    // already handle most errors there. The PlatformDispatcher override is
    // needed only in release mode for truly uncaught async errors, but it
    // creates infinite frame scheduling loops in tests and debug builds.
    if (kReleaseMode) {
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        _scheduleHandleError(FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Flutter',
        ));
        return true;
      };
    }
  }

  void _scheduleHandleError(FlutterErrorDetails details) {
    if (_errorUpdateScheduled || !mounted) return;
    _errorUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _errorUpdateScheduled = false;
      if (mounted) _handleError(details);
    });
  }

  @override
  void dispose() {
    _errorUpdateScheduled = false;
    _restoreOriginalHandlers();
    super.dispose();
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

  /// Track an error event with allowlisted, non-PII properties only.
  ///
  /// Security audit P0-12 (2026-07-18): the previous implementation
  /// sent `_safeErrorMessage(details.exception)` which is the
  /// exception's `toString()`. The audit says exceptions can contain
  /// filenames, URLs, server responses, bearer tokens, paths, or
  /// policy IDs. Per the audit: "emit allowlisted error codes only;
  /// put detailed crash diagnostics in a separate protected,
  /// redacted system."
  ///
  /// The Phase 0 minimum: do NOT send the exception message or
  /// stack frames. Send only:
  ///   - error_type: the runtime class name of the exception
  ///   - library: the originating library
  ///   - error_code: a hash of the exception type, used for
  ///     deduplication on the operator side
  /// Detailed crash info stays in debug-only logs (already gated
  /// by kDebugMode).
  void _trackError(FlutterErrorDetails details) {
    try {
      final errorType = details.exception.runtimeType.toString();
      AnalyticsService.track('global_error', {
        'error_type': errorType,
        'error_code': _errorCode(errorType),
        'library': details.library ?? 'unknown',
        // No error_message, no stack_summary. Per the audit, those
        // leak PII. Detailed diagnostics live in debug logs only.
      });
    } catch (_) {
      // Analytics failure should never disrupt error handling
    }
  }

  /// Short allowlisted error code derived from the exception type.
  /// Used by the operator dashboard to deduplicate errors without
  /// seeing the exception message itself. Format: `err_<sha-prefix>`.
  String _errorCode(String errorType) {
    final hash = errorType.hashCode.toRadixString(16);
    return 'err_${hash.length > 8 ? hash.substring(0, 8) : hash}';
  }

  /// Clear the current error and attempt to rebuild.
  void clearError() {
    // Track error recovery for analytics. The error_type is the
    // runtime class name (allowlisted); the error message is not
    // sent (per security audit P0-12).
    try {
      final errorType =
          _errorDetails?.exception.runtimeType.toString() ?? 'unknown';
      AnalyticsService.track('global_error_recovered', {
        'error_type': errorType,
        'error_code': _errorCode(errorType),
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
/// Uses Container + SafeArea (no Scaffold — avoids internal animations that
/// interfere with test pumping).
class _ErrorScreen extends StatelessWidget {
  final FlutterErrorDetails error;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Note: This widget renders outside MaterialApp, so Theme.of(context)
    // is not available. We use hardcoded brand colors to match the splash
    // screen and main app theme.
    // NOTE: We intentionally avoid Scaffold here — Scaffold has internal
    // animations and state that interfere with test pumping (pump() hangs).
    // Instead we use a full-screen Container with SafeArea.
    return Semantics(
      container: true,
      liveRegion: true,
      label:
          'Something went wrong. An unexpected display error occurred. Retry or close the app.',
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [CoverWiseColors.inkSoft, CoverWiseColors.ink],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical -
                    48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Error icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
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
                    'An unexpected display error occurred. Try again to return to the app.',
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
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: CoverWiseColors.blueDeep,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Close button
                  TextButton.icon(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                    label: Text(
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
      ),
    );
  }
}
