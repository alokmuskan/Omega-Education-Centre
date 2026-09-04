import 'package:flutter/material.dart';

import '../services/logging_service.dart';

/// Centralized Error Handler
///
/// Provides consistent error handling patterns across the app.
/// Use this instead of scattered catch blocks with inconsistent behavior.
class ErrorHandler {
  ErrorHandler._();

  static const String _tag = 'ErrorHandler';

  /// Handle an error with user feedback.
  ///
  /// Shows a SnackBar with the error message and logs the error.
  static void handleError(
    BuildContext context,
    Object error, {
    String? customMessage,
    bool showSnackBar = true,
    bool logError = true,
  }) {
    final message = customMessage ?? _getUserFriendlyMessage(error);

    if (logError) {
      LoggingService.instance.e(_tag, 'Error: $error', StackTrace.current);
    }

    if (showSnackBar && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// Handle an error with a dialog.
  ///
  /// Shows an AlertDialog with the error message.
  static void handleErrorDialog(
    BuildContext context,
    Object error, {
    String? title,
    String? customMessage,
  }) {
    final message = customMessage ?? _getUserFriendlyMessage(error);
    LoggingService.instance.e(_tag, 'Error: $error', StackTrace.current);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
          title: Text(title ?? 'Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Handle an error with a loading state callback.
  ///
  /// Returns an AsyncValue.error for use with Riverpod providers.
  static String getErrorMessage(Object error) {
    return _getUserFriendlyMessage(error);
  }

  /// Show a success message.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: duration,
        ),
      );
    }
  }

  /// Show a warning message.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          duration: duration,
        ),
      );
    }
  }

  /// Show an info message.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.blue.shade700,
          duration: duration,
        ),
      );
    }
  }

  /// Confirm a destructive action.
  ///
  /// Returns true if confirmed, false if cancelled.
  static Future<bool> confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ══════════════════════════════════════════════════════════════════════
  // PRIVATE METHODS
  // ══════════════════════════════════════════════════════════════════════

  /// Convert technical errors to user-friendly messages.
  static String _getUserFriendlyMessage(Object error) {
    final errorString = error.toString().toLowerCase();

    // Database errors
    if (errorString.contains('database') || errorString.contains('sqlite')) {
      return 'Database error. Please try again or contact support.';
    }

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Network error. Please check your internet connection.';
    }

    // Authentication errors
    if (errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('token')) {
      return 'Authentication error. Please log in again.';
    }

    // Permission errors
    if (errorString.contains('permission') || errorString.contains('access')) {
      return 'Permission denied. Please check your access rights.';
    }

    // File errors
    if (errorString.contains('file') || errorString.contains('directory')) {
      return 'File error. Please check storage permissions.';
    }

    // Generic fallback
    return 'An unexpected error occurred. Please try again.';
  }
}
