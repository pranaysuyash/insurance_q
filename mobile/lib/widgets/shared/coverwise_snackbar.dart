import 'package:flutter/material.dart';

/// Standardized snack bar helper for CoverWise.
///
/// Replaces raw `SnackBar(...)` usages across the app with consistent
/// styling, auto-dismissal, and manual dismiss options. Ensures snackbars
/// don't persist across screen changes by using the current context's
/// ScaffoldMessenger.
///
/// Usage:
/// ```dart
/// CoverWiseSnackBar.error(context, 'Something went wrong');
/// CoverWiseSnackBar.success(context, 'Saved successfully');
/// CoverWiseSnackBar.info(context, 'Processing in background');
/// ```
class CoverWiseSnackBar {
  CoverWiseSnackBar._();

  /// Shows an error snackbar with red background and dismiss action.
  static void error(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(
      context,
      message: message,
      backgroundColor: Theme.of(context).colorScheme.error,
      textColor: Theme.of(context).colorScheme.onError,
      icon: Icons.error_outline_rounded,
      duration: const Duration(seconds: 5),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Shows a success snackbar with green background.
  static void success(BuildContext context, String message, {Duration? duration}) {
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
  static void warning(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _show(
      context,
      message: message,
      backgroundColor: const Color(0xFFF57C00),
      textColor: Colors.white,
      icon: Icons.warning_amber_rounded,
      duration: const Duration(seconds: 4),
      actionLabel: actionLabel,
      onAction: onAction,
    );
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
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
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
