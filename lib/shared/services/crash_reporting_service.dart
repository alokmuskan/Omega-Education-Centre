import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Crash Reporting Service
///
/// Provides crash reporting, error logging, and performance monitoring.
/// Uses local logging in debug mode; can be extended with Sentry/Crashlytics in production.
class CrashReportingService {
  static CrashReportingService? _instance;
  static CrashReportingService get instance => _instance ??= CrashReportingService._();
  CrashReportingService._();

  bool _initialized = false;
  String? _sentryDsn;
  String? _userId;
  String? _userRole;

  /// Initialize crash reporting
  ///
  /// Call this in main() before runApp().
  /// [sentryDsn] is optional — if null, falls back to local logging only.
  Future<void> init({String? sentryDsn}) async {
    if (_initialized) return;

    _sentryDsn = sentryDsn;

    // Set up Flutter error handler
    FlutterError.onError = _handleFlutterError;

    // Set up platform error handler
    PlatformDispatcher.instance.onError = _handlePlatformError;

    // Set up async error handler
    runZonedGuarded(() {}, (error, stackTrace) {
      _reportError(error, stackTrace, reason: 'Uncaught async error');
    });

    if (kDebugMode) {
      developer.log('CrashReportingService initialized (debug mode — local logging only)',
          name: 'CrashReporting');
    }

    _initialized = true;
  }

  /// Set user context for crash reports
  void setUserContext({required String userId, required String role, String? email}) {
    _userId = userId;
    _userRole = role;

    if (kDebugMode) {
      developer.log('User context set: $userId ($role)', name: 'CrashReporting');
    }
  }

  /// Clear user context (e.g., on logout)
  void clearUserContext() {
    _userId = null;
    _userRole = null;
  }

  /// Report a non-fatal error
  void reportError(Object error, StackTrace stackTrace, {String? reason, bool fatal = false}) {
    _reportError(error, stackTrace, reason: reason, fatal: fatal);
  }

  /// Report a message (breadcrumb or info)
  void reportMessage(String message, {String? level}) {
    if (kDebugMode) {
      developer.log('[${level ?? 'INFO'}] $message', name: 'CrashReporting');
    }
  }

  /// Add a breadcrumb for context
  void addBreadcrumb(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      final details = data != null ? ' | $data' : '';
      developer.log('BREADCRUMB: $message$details', name: 'CrashReporting');
    }
  }

  // --- Private Methods ---

  void _handleFlutterError(FlutterErrorDetails details) {
    _reportError(
      details.exception,
      details.stack ?? StackTrace.current,
      reason: details.context?.toString(),
      fatal: details.silent != true,
    );

    // Still print to console in debug mode
    FlutterError.presentError(details);
  }

  bool _handlePlatformError(Object error, StackTrace stackTrace) {
    _reportError(error, stackTrace, reason: 'Platform dispatcher error', fatal: true);
    return true; // Handled
  }

  void _reportError(Object error, StackTrace stackTrace, {String? reason, bool fatal = false}) {
    final errorInfo = _buildErrorReport(error, stackTrace, reason: reason, fatal: fatal);

    if (kDebugMode) {
      developer.log(
        'ERROR${fatal ? ' (FATAL)' : ''}: ${error.runtimeType}: $error\n'
        'Reason: ${reason ?? 'N/A'}\n'
        'Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}',
        name: 'CrashReporting',
      );
    }

    // In production, send to Sentry (or other service)
    if (kReleaseMode && _sentryDsn != null) {
      _sendToSentry(errorInfo);
    }
  }

  Map<String, dynamic> _buildErrorReport(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    return {
      'error': error.toString(),
      'type': error.runtimeType.toString(),
      'reason': reason,
      'fatal': fatal,
      'userId': _userId,
      'userRole': _userRole,
      'timestamp': DateTime.now().toIso8601String(),
      'stackTrace': stackTrace.toString().split('\n').take(20).join('\n'),
    };
  }

  Future<void> _sendToSentry(Map<String, dynamic> errorInfo) async {
    // Placeholder for Sentry integration
    // When ready to integrate Sentry:
    // 1. Add sentry_flutter to pubspec.yaml
    // 2. Import 'package:sentry_flutter/sentry_flutter.dart'
    // 3. Use Sentry.captureException() here
    //
    // Example:
    // await Sentry.captureException(
    //   errorInfo['error'],
    //   stackTrace: StackTrace.fromString(errorInfo['stackTrace']),
    //   hint: Hint.withMap({'reason': errorInfo['reason']}),
    // );
  }
}
