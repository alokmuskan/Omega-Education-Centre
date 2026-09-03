import 'package:intl/intl.dart';

/// Reusable validation helper for Attendance dates across Student and Teacher modules.
///
/// Business Rule: Attendance dates in the FUTURE (later than today's local date)
/// must be strictly rejected by Date Pickers, Screen logic, and Repositories.
/// Past dates and Today are fully allowed.
class AttendanceDateValidator {
  AttendanceDateValidator._();

  /// Formats a DateTime to normalized 'YYYY-MM-DD' calendar string.
  static String formatDateIso(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  /// Today's normalized local calendar date in 'YYYY-MM-DD' format.
  static String get todayIso => formatDateIso(DateTime.now());

  /// Today's normalized DateTime at 00:00:00.
  static DateTime get todayNormalized {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Checks if a date string ('YYYY-MM-DD') is strictly in the future compared to local Today.
  static bool isFutureDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      final normalizedParsed = DateTime(parsed.year, parsed.month, parsed.day);
      return normalizedParsed.isAfter(todayNormalized);
    } catch (_) {
      return false;
    }
  }

  /// Checks if a DateTime is strictly in the future compared to local Today.
  static bool isFutureDateTime(DateTime dt) {
    final normalized = DateTime(dt.year, dt.month, dt.day);
    return normalized.isAfter(todayNormalized);
  }

  /// Validates that an attendance date is not in the future.
  /// Throws an [ArgumentError] if the date is in the future.
  static void validateNotFuture(String dateStr) {
    if (isFutureDate(dateStr)) {
      throw ArgumentError('Future attendance cannot be recorded ($dateStr).');
    }
  }
}
