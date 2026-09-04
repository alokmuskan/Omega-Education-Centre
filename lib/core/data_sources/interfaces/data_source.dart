import 'package:flutter/foundation.dart';

/// Abstract data source interface.
///
/// All feature code should depend on this interface rather than checking
/// `kIsWeb` directly. The [DataSourceFactory] selects the correct
/// implementation (SQLite for native, Supabase REST for web) at runtime.
abstract class DataSource {
  // ══════════════════════════════════════════════════════════════════════
  // PLATFORM IDENTITY
  // ══════════════════════════════════════════════════════════════════════

  /// Whether this data source operates locally (SQLite).
  bool get isLocal;

  /// Whether this data source operates remotely (Supabase).
  bool get isRemote;

  // ══════════════════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ══════════════════════════════════════════════════════════════════════

  /// Authenticate a user with the given credentials.
  /// Returns user data map on success, throws on failure.
  Future<Map<String, dynamic>> authenticate(String username, String password);

  /// Restore a previously saved session.
  /// Returns user data map if valid, null otherwise.
  Future<Map<String, dynamic>?> restoreSession();

  /// Synchronize local admin credentials after admin login (native only).
  Future<void> syncLocalAdminCredential(String password) async {}

  // ══════════════════════════════════════════════════════════════════════
  // DASHBOARD DATA
  // ══════════════════════════════════════════════════════════════════════

  /// Load dashboard statistics (student count, teacher count, etc.).
  Future<DashboardData> loadDashboardData();

  // ══════════════════════════════════════════════════════════════════════
  // SYNC
  // ══════════════════════════════════════════════════════════════════════

  /// Whether synchronization is supported on this platform.
  bool get supportsSync;

  /// Execute a full sync (only meaningful for native SQLite ↔ Supabase).
  Future<void> syncAll() async {}
}

/// Dashboard statistics model.
class DashboardData {
  final int activeStudentCount;
  final int activeTeacherCount;
  final int classesTodayCount;
  final double teacherHoursToday;
  final int studentPresentCount;
  final int studentAbsentCount;
  final int studentLateCount;
  final int studentLeaveCount;
  final int teachersRecordedCount;
  final double centerFeeDue;
  final double centerSalaryDue;
  final List<Map<String, dynamic>> todayClasses;
  final List<Map<String, dynamic>> recentTests;
  final List<Map<String, dynamic>> recentNotices;

  const DashboardData({
    this.activeStudentCount = 0,
    this.activeTeacherCount = 0,
    this.classesTodayCount = 0,
    this.teacherHoursToday = 0.0,
    this.studentPresentCount = 0,
    this.studentAbsentCount = 0,
    this.studentLateCount = 0,
    this.studentLeaveCount = 0,
    this.teachersRecordedCount = 0,
    this.centerFeeDue = 0.0,
    this.centerSalaryDue = 0.0,
    this.todayClasses = const [],
    this.recentTests = const [],
    this.recentNotices = const [],
  });
}
