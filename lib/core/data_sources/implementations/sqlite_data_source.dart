import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/utils/app_session.dart';
import '../interfaces/data_source.dart';

/// SQLite-backed data source for native platforms (Android, iOS, Windows, macOS, Linux).
///
/// Uses the existing [DatabaseHelper] for all local database operations.
/// This is the default data source on non-web platforms.
class SqliteDataSource extends DataSource {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  bool get isLocal => true;

  @override
  bool get isRemote => false;

  @override
  bool get supportsSync => true;

  // ══════════════════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ══════════════════════════════════════════════════════════════════════

  @override
  Future<Map<String, dynamic>> authenticate(String username, String password) async {
    final db = await _dbHelper.database;

    // Try admin login first
    final adminResult = await _authenticateAdmin(db, username, password);
    if (adminResult != null) return adminResult;

    // Try teacher login
    final teacherResult = await _authenticateTeacher(db, username, password);
    if (teacherResult != null) return teacherResult;

    // Try student login
    final studentResult = await _authenticateStudent(db, username, password);
    if (studentResult != null) return studentResult;

    throw Exception('Invalid username or password');
  }

  Future<Map<String, dynamic>?> _authenticateAdmin(Database db, String username, String password) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();

    final rows = await db.query('admin_accounts', where: 'LOWER(username) = ?', whereArgs: [cleanUser]);
    if (rows.isEmpty) return null;

    final storedHash = rows.first['passwordHash'] as String?;
    if (storedHash == null || storedHash.isEmpty) return null;

    final computedHash = _hashPassword(cleanPass);
    if (computedHash != storedHash) return null;

    return {
      'id': rows.first['id'],
      'username': rows.first['username'],
      'role': 'admin',
      'displayName': rows.first['displayName'] ?? rows.first['username'],
    };
  }

  Future<Map<String, dynamic>?> _authenticateTeacher(Database db, String username, String password) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();

    final rows = await db.query(
      'teachers',
      where: 'LOWER(username) = ? AND isActive = 1',
      whereArgs: [cleanUser],
    );
    if (rows.isEmpty) return null;

    final storedHash = rows.first['passwordHash'] as String?;
    if (storedHash == null || storedHash.isEmpty) return null;

    final computedHash = _hashPassword(cleanPass);
    if (computedHash != storedHash) return null;

    return {
      'id': rows.first['id'],
      'username': rows.first['username'],
      'role': 'teacher',
      'displayName': rows.first['name'],
    };
  }

  Future<Map<String, dynamic>?> _authenticateStudent(Database db, String username, String password) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();

    final rows = await db.query(
      'students',
      where: 'LOWER(username) = ? AND isActive = 1',
      whereArgs: [cleanUser],
    );
    if (rows.isEmpty) return null;

    final storedHash = rows.first['passwordHash'] as String?;
    if (storedHash == null || storedHash.isEmpty) return null;

    final computedHash = _hashPassword(cleanPass);
    if (computedHash != storedHash) return null;

    return {
      'id': rows.first['id'],
      'username': rows.first['username'],
      'role': 'student',
      'displayName': rows.first['name'],
      'classId': rows.first['classId'],
      'className': rows.first['className'],
    };
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  @override
  Future<Map<String, dynamic>?> restoreSession() async {
    final session = AppSession.instance;
    if (session.currentUsername.isEmpty || session.currentRole.isEmpty) return null;

    final db = await _dbHelper.database;
    final table = session.currentRole == 'admin'
        ? 'admin_accounts'
        : session.currentRole == 'teacher'
            ? 'teachers'
            : 'students';

    final rows = await db.query(
      table,
      where: 'LOWER(username) = ? AND isActive = 1',
      whereArgs: [session.currentUsername.toLowerCase()],
    );

    if (rows.isEmpty) {
      AppSession.instance.clearSession();
      return null;
    }

    final row = rows.first;
    return {
      'id': row['id'],
      'username': row['username'],
      'role': session.currentRole,
      'displayName': row['name'] ?? row['displayName'] ?? row['username'],
    };
  }

  @override
  Future<void> syncLocalAdminCredential(String password) async {
    try {
      final db = await _dbHelper.database;
      final prefs = await SharedPreferences.getInstance();
      final adminUsername = prefs.getString('admin_username') ?? 'admin';
      final newHash = _hashPassword(password);

      final rows = await db.query(
        'admin_accounts',
        where: 'LOWER(username) = ?',
        whereArgs: [adminUsername.toLowerCase()],
      );

      if (rows.isNotEmpty) {
        await db.update(
          'admin_accounts',
          {'passwordHash': newHash},
          where: 'LOWER(username) = ?',
          whereArgs: [adminUsername.toLowerCase()],
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[DATASOURCE] syncLocalAdminCredential failed: $e');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DASHBOARD DATA
  // ══════════════════════════════════════════════════════════════════════

  @override
  Future<DashboardData> loadDashboardData() async {
    final db = await _dbHelper.database;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    // 1. Active Students
    final studentRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM students WHERE isActive = 1',
    );
    final studentCount = (studentRes.first['cnt'] as int?) ?? 0;

    // 2. Active Teachers
    final teacherRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM teachers WHERE isActive = 1',
    );
    final teacherCount = (teacherRes.first['cnt'] as int?) ?? 0;

    // 3. Classes Today
    int classesToday = 0;
    try {
      final classRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM daily_class_records WHERE date = ?',
        [todayStr],
      );
      classesToday = (classRes.first['cnt'] as int?) ?? 0;
    } catch (_) {}

    // 4. Teacher Hours Today
    double teacherHours = 0.0;
    try {
      final hoursRes = await db.rawQuery(
        'SELECT COALESCE(SUM(hoursWorked), 0.0) as total FROM teacher_attendance WHERE date = ?',
        [todayStr],
      );
      teacherHours = (hoursRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // 5. Student Attendance Breakdown
    int sPresent = 0, sAbsent = 0, sLate = 0, sLeave = 0;
    try {
      final attRes = await db.rawQuery(
        "SELECT status, COUNT(*) as cnt FROM student_attendance WHERE date = '$todayStr' GROUP BY status",
      );
      for (final row in attRes) {
        final s = (row['status'] as String?) ?? '';
        final c = (row['cnt'] as int?) ?? 0;
        if (s == 'Present') {
          sPresent = c;
        } else if (s == 'Absent') {
          sAbsent = c;
        } else if (s == 'Late') {
          sLate = c;
        } else if (s == 'Leave') {
          sLeave = c;
        }
      }
    } catch (_) {}

    // 6. Teachers Recorded Today
    int teachersRecorded = 0;
    try {
      final tRecRes = await db.rawQuery(
        'SELECT COUNT(DISTINCT teacherId) as cnt FROM teacher_attendance WHERE date = ?',
        [todayStr],
      );
      teachersRecorded = (tRecRes.first['cnt'] as int?) ?? 0;
    } catch (_) {}

    // 7. Fee Due
    double feeDue = 0.0;
    try {
      final feeRes = await db.rawQuery('SELECT COALESCE(SUM(courseFee), 0) as total FROM fees');
      final totalFee = (feeRes.first['total'] as num?)?.toDouble() ?? 0.0;
      final paidRes = await db.rawQuery('SELECT COALESCE(SUM(amountPaid), 0) as total FROM fee_payments');
      final totalPaid = (paidRes.first['total'] as num?)?.toDouble() ?? 0.0;
      feeDue = (totalFee - totalPaid).clamp(0.0, double.infinity);
    } catch (_) {}

    // 8. Salary Due (current month)
    double salaryDue = 0.0;
    try {
      final teachersList = await db.query('teachers', columns: ['id', 'payPerHour'], where: 'isActive = 1');
      for (final t in teachersList) {
        final tId = t['id'];
        final payRate = (t['payPerHour'] as num?)?.toDouble() ?? 0.0;
        final hoursRes = await db.rawQuery(
          'SELECT COALESCE(SUM(hoursWorked), 0.0) as total FROM teacher_attendance WHERE teacherId = ? AND date LIKE ?',
          [tId, '$currentMonth%'],
        );
        final hours = (hoursRes.first['total'] as num?)?.toDouble() ?? 0.0;
        final paidRes = await db.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) as total FROM teacher_payments WHERE teacherId = ? AND year = ?',
          [tId, DateTime.now().year],
        );
        final paid = (paidRes.first['total'] as num?)?.toDouble() ?? 0.0;
        final due = (hours * payRate) - paid;
        if (due > 0) salaryDue += due;
      }
    } catch (_) {}

    // 9. Today's Classes
    List<Map<String, dynamic>> todayClasses = [];
    try {
      final classList = await db.rawQuery(
        '''SELECT dcr.*, t.name as teacherName
           FROM daily_class_records dcr
           LEFT JOIN teachers t ON dcr.teacherId = t.id
           WHERE dcr.date = ?
           ORDER BY dcr.startTime ASC LIMIT 3''',
        [todayStr],
      );
      todayClasses = classList.map((c) => {
        'time': c['startTime'] as String? ?? '--:--',
        'class': c['studentClass'] as String? ?? '',
        'batch': c['batch'] as String? ?? '',
        'teacher': c['teacherName'] as String? ?? 'Teacher',
        'subject': c['subject'] as String? ?? '',
        'topic': c['topic'] as String? ?? '',
        'duration': '${c['durationMinutes']} mins',
      }).toList();
    } catch (_) {}

    // 10. Recent Tests
    List<Map<String, dynamic>> recentTests = [];
    try {
      recentTests = await db.query('tests', orderBy: 'createdAt DESC', limit: 3);
    } catch (_) {}

    // 11. Recent Notices
    List<Map<String, dynamic>> notices = [];
    try {
      notices = await db.query('notices', orderBy: 'createdAt DESC', limit: 3);
    } catch (_) {}

    return DashboardData(
      activeStudentCount: studentCount,
      activeTeacherCount: teacherCount,
      classesTodayCount: classesToday,
      teacherHoursToday: teacherHours,
      studentPresentCount: sPresent,
      studentAbsentCount: sAbsent,
      studentLateCount: sLate,
      studentLeaveCount: sLeave,
      teachersRecordedCount: teachersRecorded,
      centerFeeDue: feeDue,
      centerSalaryDue: salaryDue,
      todayClasses: todayClasses,
      recentTests: recentTests,
      recentNotices: notices,
    );
  }
}
