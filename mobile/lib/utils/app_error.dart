import 'dart:io';
import '../config/app_config.dart';

/// Centralized mapping from exceptions to user-friendly, actionable messages.
///
/// motto_v3 §0.11 (Customer-Facing Claims): users must never see raw
/// exception strings. Every error path must show a message that
/// explains what happened and what the user can do next.
///
/// Usage:
/// ```dart
/// } catch (e) {
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text(AppError.userMessage(e))),
///   );
/// }
/// ```
class AppError {
  AppError._();

  /// Returns a user-friendly message for the given exception.
  ///
  /// The mapping is ordered from most specific to most generic.
  /// Unrecognized exceptions get a safe fallback that doesn't
  /// leak technical details.
  static String userMessage(Object error) {
    // ── Network / connectivity ──
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (error is HttpException) {
      return 'Could not reach the server. Please try again in a moment.';
    }

    final message = error.toString().toLowerCase();

    // ── Dio / HTTP errors ──
    if (message.contains('dioexception')) {
      if (message.contains('connectionrefused') ||
          message.contains('connection refused')) {
        return 'Could not reach the server. Please try again in a moment.';
      }
      if (message.contains('connectiontimedout') ||
          message.contains('sendtimedout') ||
          message.contains('receivetimedout') ||
          message.contains('timed out')) {
        return 'The request took too long. Please check your connection and try again.';
      }
      if (message.contains('401') || message.contains('unauthorized')) {
        return 'Your session has expired. Please sign in again.';
      }
      if (message.contains('403') || message.contains('forbidden')) {
        return 'You don\'t have permission for this action.';
      }
      if (message.contains('404') || message.contains('not found')) {
        return 'The requested resource was not found.';
      }
      if (message.contains('429') || message.contains('too many')) {
        return 'Too many requests. Please wait a moment and try again.';
      }
      if (message.contains('500') ||
          message.contains('502') ||
          message.contains('503')) {
        return 'The server encountered an error. Please try again later.';
      }
      if (message.contains('canceled')) {
        return 'The request was cancelled. Please try again.';
      }
      return 'Could not connect to the server. Please try again.';
    }

    // ── File / I/O errors ──
    if (error is FileSystemException) {
      if (message.contains('not found') || message.contains('no such file')) {
        return 'The file could not be found. It may have been moved or deleted.';
      }
      if (message.contains('permission denied')) {
        return 'Permission denied. Please check your device settings.';
      }
      return 'Could not access the file. Please try again.';
    }
    if (message.contains('filenotfoundexception') ||
        message.contains('file not found')) {
      return 'The file could not be found. It may have been moved or deleted.';
    }

    // ── Platform / permission errors ──
    if (message.contains('permissiondenied')) {
      return 'Permission denied. Please check your device settings.';
    }
    if (message.contains('platformexception')) {
      if (message.contains('channelerror') || message.contains('missing plugin')) {
        return 'This feature is not available on your device.';
      }
    }

    // ── Hive / storage errors ──
    if (message.contains('hive')) {
      if (message.contains('boxnotopenerror') ||
          message.contains('box not open')) {
        return 'Local data store is not ready. Please restart the app.';
      }
      if (message.contains('criticalerror') || message.contains('corrupted')) {
        return 'Local data appears corrupted. Clearing local data may fix this (Settings → Clear local data).';
      }
      return 'There was a problem accessing local data. Please try again.';
    }

    // ── Auth errors ──
    if (message.contains('authentication') || message.contains('authexception') || message.contains('login') || message.contains('sign in') || message.contains('sign_up')) {
      if (message.contains('invalid') || message.contains('wrong password')) {
        return 'Incorrect email or password. Please try again.';
      }
      if (message.contains('user not found') || message.contains('no user')) {
        return 'No account found with this email.';
      }
      if (message.contains('email not confirmed') || message.contains('not verified')) {
        return 'Please verify your email first. Check your inbox for a verification link.';
      }
      if (message.contains('already registered') || message.contains('already exists')) {
        return 'An account with this email already exists. Try signing in instead.';
      }
      if (message.contains('expired') || message.contains('invalid token')) {
        return 'Your session has expired. Please sign in again.';
      }
      if (message.contains('rate limit') || message.contains('too many requests')) {
        return 'Too many attempts. Please wait a few minutes and try again.';
      }
    }

    // ── Billing / purchase errors ──
    if (message.contains('billing') || message.contains('purchase') || message.contains('revenuecat')) {
      if (message.contains('user cancelled') || message.contains('user_canceled') || message.contains('user_cancelled')) {
        return ''; // Silent — user deliberately cancelled. Callers should check for empty.
      }
      if (message.contains('not available') || message.contains('store not available')) {
        return 'The app store is not available on this device. Please try on a device with Google Play or the App Store.';
      }
      if (message.contains('network') || message.contains('connection')) {
        return 'Could not connect to the app store. Please check your internet connection.';
      }
      return 'Purchase could not be completed. Please try again.';
    }

    // ── Upload / document errors ──
    if (message.contains('upload') || message.contains('document')) {
      if (message.contains('too large') || message.contains('size limit')) {
        return 'The file is too large. Please upload a smaller document (max ${AppConfig.maxUploadFileSizeMB} MB).';
      }
      if (message.contains('unsupported') || message.contains('invalid format')) {
        return 'This file type is not supported. Please upload a PDF, JPEG, or PNG.';
      }
      if (message.contains('duplicate') || message.contains('already exists')) {
        return 'This policy is already saved. You can use the existing copy or replace it.';
      }
      if (message.contains('rate limit')) {
        return 'Upload limit reached. Please wait a moment and try again.';
      }
      if (message.contains('pdf') && message.contains('password')) {
        return 'This PDF is password-protected. Please unlock it first and try again.';
      }
    }

    // ── Query / RAG errors ──
    if (message.contains('query') || message.contains('rag') || message.contains('embedding')) {
      return 'Could not process your question. Please try rephrasing or ask again later.';
    }

    // ── Generic fallback ──
    // Never show raw $e to the user. Use a safe, generic message
    // that doesn't leak technical details but still acknowledges
    // the error happened.
    return 'Something went wrong. Please try again. If the problem persists, contact support.';
  }

  /// Returns true when the error is a user-initiated cancellation
  /// (e.g. closing a purchase dialog). Callers should silently
  /// ignore these rather than showing an error message.
  static bool isCancelled(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('user cancelled') ||
        message.contains('user_canceled') ||
        message.contains('user_cancelled') ||
        message.contains('canceled') ||
        message.contains('cancelled');
  }

  /// Returns a user-friendly message for a specific error context.
  ///
  /// Use this when the catch block is context-specific and a more
  /// targeted message is appropriate than the generic [userMessage].
  static String contextual({
    required Object error,
    required String operation,
  }) {
    final generic = userMessage(error);

    // For operations where the generic message is already good enough,
    // return it directly. For operations where we can be more specific:
    if (operation == 'delete_document') {
      return 'Could not remove this document from your device. Please try again.';
    }
    if (operation == 'clear_data') {
      return 'Could not clear all local data. Please try again or restart the app.';
    }
    if (operation == 'upload') {
      return 'Upload failed. Please check your internet connection and try again.';
    }
    if (operation == 'account_deletion') {
      return 'Could not delete your account. Please try again or contact support.';
    }
    if (operation == 'purchase') {
      if (generic.isEmpty) return ''; // user cancelled
      return 'Purchase could not be completed. Please try again.';
    }

    return generic;
  }
}


