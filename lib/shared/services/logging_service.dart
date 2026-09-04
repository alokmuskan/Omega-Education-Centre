import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Centralized Logging Service
///
/// Replaces scattered print() statements with a consistent logging framework.
/// Logs are only emitted in debug mode and can be easily extended with
/// remote logging (Sentry, Firebase Crashlytics, etc.) in the future.
class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();
  LoggingService._();

  bool _initialized = false;
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  /// Initialize the logging service
  void init({LogLevel? minLevel}) {
    if (_initialized) return;
    _minLevel = minLevel ?? _minLevel;
    _initialized = true;
  }

  /// Set minimum log level
  void setMinLevel(LogLevel level) => _minLevel = level;

  // ══════════════════════════════════════════════════════════════════════
  // LOG METHODS
  // ══════════════════════════════════════════════════════════════════════

  /// Log debug message (only in debug mode)
  void d(String tag, String message) {
    if (_minLevel.index > LogLevel.debug.index) return;
    _log('DEBUG', tag, message);
  }

  /// Log info message
  void i(String tag, String message) {
    if (_minLevel.index > LogLevel.info.index) return;
    _log('INFO', tag, message);
  }

  /// Log warning message
  void w(String tag, String message) {
    if (_minLevel.index > LogLevel.warning.index) return;
    _log('WARNING', tag, message);
  }

  /// Log error message with optional stack trace
  void e(String tag, String message, [StackTrace? stackTrace]) {
    if (_minLevel.index > LogLevel.error.index) return;
    _log('ERROR', tag, message);
    if (stackTrace != null && kDebugMode) {
      developer.log('Stack trace: $stackTrace', name: tag);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // PRIVATE METHODS
  // ══════════════════════════════════════════════════════════════════════

  void _log(String level, String tag, String message) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      developer.log('[$timestamp] [$level] $message', name: tag);
    }

    // In production, you could send to remote logging service:
    // if (kReleaseMode) {
    //   Sentry.captureMessage('[$level] [$tag] $message');
    // }
  }
}

/// Log levels for filtering
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Extension on LogLevel for convenience
extension LogLevelExtension on LogLevel {
  String get name {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}
