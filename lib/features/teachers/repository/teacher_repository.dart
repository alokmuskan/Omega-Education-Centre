import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/utils/password_util.dart';
import '../models/teacher_model.dart';

/// Repository for Teacher SQLite operations.
///
/// Implements parameterized queries, soft deactivation, and safe error handling.
class TeacherRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ──────────────────────────────────────────────────────────────────────
  // Get All Teachers (ordered by name)
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TeacherModel>> getTeachers() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'teachers',
      orderBy: 'name ASC',
    );
    return maps.map(TeacherModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Teacher By ID
  // ──────────────────────────────────────────────────────────────────────

  Future<TeacherModel?> getTeacherById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'teachers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TeacherModel.fromMap(maps.first);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Insert Teacher
  // Also creates initial pay-rate history entry.
  // ──────────────────────────────────────────────────────────────────────

  Future<int> insertTeacher(TeacherModel teacher) async {
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final id = await db.transaction((txn) async {
      final map = teacher.toMap();
      final insertedId = await txn.insert('teachers', map);

      // Create initial rate record in teacher_pay_rate_history
      await txn.insert('teacher_pay_rate_history', {
        'teacherId': insertedId,
        'payPerHour': teacher.payPerHour,
        'effectiveFrom': todayIso,
        'effectiveTo': null,
        'createdAt': nowIso,
        'updatedAt': nowIso,
      });

      // Automatically seed user account for teacher with role = Teacher
      final mobileStr = teacher.mobile.trim();
      if (mobileStr.isNotEmpty) {
        final existing = await txn.query(
          'users',
          where: 'LOWER(username) = LOWER(?)',
          whereArgs: [mobileStr],
        );
        if (existing.isEmpty) {
          final salt = PasswordUtil.generateSalt();
          final hash = PasswordUtil.hashPassword(mobileStr, salt);
          await txn.insert('users', {
            'username': mobileStr,
            'passwordHash': hash,
            'salt': salt,
            'role': AppConstants.roleTeacher,
            'referenceId': insertedId,
            'isActive': 1,
            'createdAt': nowIso,
          });
        }
      }

      return insertedId;
    });

    final createdTeacher = teacher.copyWith(id: id);
    SyncEngine.instance.registerTeacherChange(
      teacherId: id,
      operation: 'CREATE',
      payload: createdTeacher.toMap(),
    );

    return id;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Update Teacher
  // If payPerHour changes: closes existing open rate period and creates a new rate period.
  // ──────────────────────────────────────────────────────────────────────

  Future<int> updateTeacher(TeacherModel teacher, {String? effectiveDateStr}) async {
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    final effectiveFrom = effectiveDateStr ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    return await db.transaction((txn) async {
      // Check existing teacher record to compare payPerHour
      final existingMaps = await txn.query(
        'teachers',
        where: 'id = ?',
        whereArgs: [teacher.id],
        limit: 1,
      );

      final oldPayPerHour = existingMaps.isNotEmpty
          ? (existingMaps.first['payPerHour'] as num).toDouble()
          : null;

      // Update teacher record
      final result = await txn.update(
        'teachers',
        teacher.toMap(),
        where: 'id = ?',
        whereArgs: [teacher.id],
      );

      // If pay rate has changed (or no previous history exists), manage rate history
      if (oldPayPerHour == null || oldPayPerHour != teacher.payPerHour) {
        // Calculate yesterday for closing effectiveTo
        final parsedFrom = DateTime.parse(effectiveFrom);
        final yesterday = parsedFrom.subtract(const Duration(days: 1));
        final yesterdayIso = DateFormat('yyyy-MM-dd').format(yesterday);

        // Close currently active rate period if any
        await txn.update(
          'teacher_pay_rate_history',
          {
            'effectiveTo': yesterdayIso,
            'updatedAt': nowIso,
          },
          where: 'teacherId = ? AND effectiveTo IS NULL',
          whereArgs: [teacher.id],
        );

        // Insert new active rate period
        await txn.insert('teacher_pay_rate_history', {
          'teacherId': teacher.id,
          'payPerHour': teacher.payPerHour,
          'effectiveFrom': effectiveFrom,
          'effectiveTo': null,
          'createdAt': nowIso,
          'updatedAt': nowIso,
        });
      }

      if (teacher.id != null) {
        SyncEngine.instance.registerTeacherChange(
          teacherId: teacher.id!,
          operation: 'UPDATE',
          payload: teacher.toMap(),
        );
      }

      return result;
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  // Toggle / Set Active Status (Soft Deactivation / Activation)
  // Preserves historical attendance & payment records linked by teacherId.
  // ──────────────────────────────────────────────────────────────────────

  Future<int> setTeacherActiveStatus(int id, bool isActive) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final result = await db.update(
      'teachers',
      {
        'isActive': isActive ? 1 : 0,
        'updatedAt': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    SyncEngine.instance.registerTeacherChange(
      teacherId: id,
      operation: isActive ? 'UPDATE' : 'DELETE',
      payload: {'id': id, 'isActive': isActive ? 1 : 0},
    );

    return result;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Search & Filter Teachers
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TeacherModel>> searchTeachers({
    String? query,
    String? subject,
    String? statusFilter, // 'All', 'Active', 'Inactive'
  }) async {
    final db = await _dbHelper.database;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      conditions.add('(name LIKE ? OR mobile LIKE ? OR subject LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    if (subject != null && subject != 'All') {
      conditions.add('subject = ?');
      args.add(subject);
    }

    if (statusFilter != null && statusFilter != 'All') {
      final isActiveVal = statusFilter == 'Active' ? 1 : 0;
      conditions.add('isActive = ?');
      args.add(isActiveVal);
    }

    final maps = await db.query(
      'teachers',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );

    return maps.map(TeacherModel.fromMap).toList();
  }
}
