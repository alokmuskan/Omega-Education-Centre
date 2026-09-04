import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../features/authentication/repository/auth_repository.dart';
import '../../../shared/services/app_session.dart';
import '../../../shared/services/supabase_auth_service.dart';
import '../../../shared/utils/encryption_key_manager.dart';
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
    if (session.username == null || session.userRole == null) return null;

    final db = await _dbHelper.database;
    final table = session.userRole == 'admin'
        ? 'admin_accounts'
        : session.userRole == 'teacher'
            ? 'teachers'
            : 'students';

    final rows = await db.query(
      table,
      where: 'LOWER(username) = ? AND isActive = 1',
      whereArgs: [session.username!.toLowerCase()],
    );

    if (rows.isEmpty) {
      AppSession.instance.clearSession();
      return null;
    }

    final row = rows.first;
    return {
      'id': row['id'],
      'username': row['username'],
      'role': session.userRole,
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

    // Active Students
    final studentRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM students WHERE isActive = 1',
    );
    final studentCount = (studentRes.first['cnt'] as int?) ?? 0;

    // Active Teachers
    final teacherRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM teachers WHERE isActive = 1',
    );
    final teacherCount = (teacherRes.first['cnt'] as int?) ?? 0;

    // Fees
    double totalCollected = 0.0;
    double totalPending = 0.0;
    try {
      final feesRes = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM fee_payments',
      );
      totalCollected = (feesRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // Today's attendance
    int todayAttendance = 0;
    try {
      final attRes = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM attendance WHERE date = '$todayStr' AND status = 'present'",
      );
      todayAttendance = (attRes.first['cnt'] as int?) ?? 0;
    } catch (_) {}

    // Recent notices
    List<Map<String, dynamic>> notices = [];
    try {
      notices = await db.query('notices', orderBy: 'createdAt DESC', limit: 5);
    } catch (_) {}

    return DashboardData(
      activeStudentCount: studentCount,
      activeTeacherCount: teacherCount,
      totalFeesCollected: totalCollected,
      pendingFees: totalPending,
      todayAttendance: todayAttendance,
      recentNotices: notices,
    );
  }
}
