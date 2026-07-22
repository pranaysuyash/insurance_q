import 'package:flutter/material.dart';

/// Standardized snackbar helper for CoverWise.
///
/// Provides consistent styling, context-specific error messages, and
/// route-aware dismissal so toasts never persist across screen changes.
///
/// P2-05 improvements:
/// - [error] accepts an [operation] parameter for context-specific messages
/// - [CoverWiseSnackBarObserver] auto-dismisses snackbars on route changes
/// - [dismissAll] provides programmatic dismissal
///
/// Usage:
/// ```dart
/// CoverWiseSnackBar.error(context, 'Upload failed', operation: 'policy upload');
/// CoverWiseSnackBar.success(context, 'Saved successfully');
/// CoverWiseSnackBar.info(context, 'Processing in background');
/// CoverWiseSnackBar.dismissAll(context);
/// ```
class CoverWiseSnackBar {
  CoverWiseSnackBar._();

  /// Canonical messenger owned by the root MaterialApp. Using the root
  /// messenger keeps route transitions and nested scaffolds on one dismissal
  /// contract.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Shows an error snackbar with red background and dismiss action.
  ///
  /// When [operation] is provided, the message is prefixed with the
  /// operation name so the user knows *what* failed, e.g.:
  ///   "Upload failed: File too large" instead of just "File too large".
  static void error(
    BuildContext context,
    String message, {
    String? operation,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final displayMessage =
        operation != null ? '$operation failed: $message' : message;
    _show(
      context,
      message: displayMessage,
      backgroundColor: Theme.of(context).colorScheme.error,
      textColor: Theme.of(context).colorScheme.onError,
      icon: Icons.error_outline_rounded,
      duration: const Duration(seconds: 5),
      actionLabel: actionLabel ?? (onAction != null ? 'Retry' : null),
      onAction: onAction,
    );
  }

  /// Shows a success snackbar with green background.
  static void success(BuildContext context, String message,
      {Duration? duration}) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFF2E7D32),
      textColor: Colors.white,
      icon: Icons.check_circle_outline_rounded,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Shows an info snackbar with theme surface color.
  static void info(BuildContext context, String message, {Duration? duration}) {
    _show(
      context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      textColor: Theme.of(context).colorScheme.onSurface,
      icon: Icons.info_outline_rounded,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Shows a warning snackbar with orange background.
  static void warning(BuildContext context, String message,
      {Duration? duration, String? actionLabel, VoidCallback? onAction}) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFF57C00),
      textColor: Colors.white,
      icon: Icons.warning_amber_rounded,
      duration: duration ?? const Duration(seconds: 4),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Programmatically dismiss any visible snackbar.
  static void dismissAll(BuildContext context) {
    (scaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context))
        .clearSnackBars();
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    // Clear any existing snackbar before showing a new one
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        dismissDirection: DismissDirection.horizontal,
        content: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: textColor,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}

/// A [NavigatorObserver] that automatically dismisses any visible snackbar
/// when the user navigates to a new route.
///
/// Register this in your [MaterialApp]'s `navigatorObservers`:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [CoverWiseSnackBarObserver()],
///   // ...
/// )
/// ```
///
/// This ensures toasts from the previous screen never persist into the next
/// screen — one of the key P2-05 requirements.
class CoverWiseSnackBarObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissIfNeeded();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _dismissIfNeeded();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissIfNeeded();
  }

  void _dismissIfNeeded() {
    CoverWiseSnackBar.scaffoldMessengerKey.currentState?.clearSnackBars();
  }

  /// Access the navigator's state to get a valid context for dismissal.
  NavigatorState? get observerState {
    // navigator is null during tests, which is fine — we skip dismissal.
    return navigator;
  }
}
