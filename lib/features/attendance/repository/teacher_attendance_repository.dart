import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/utils/attendance_date_validator.dart';
import '../models/attendance_summary_model.dart';
import '../models/teacher_attendance_model.dart';

/// Repository for Teacher Attendance database operations.
///
/// Enforces UNIQUE(teacherId, date) via upserts (INSERT OR REPLACE)
/// so editing existing hours for a date updates SQLite cleanly without duplicate records.
class TeacherAttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ──────────────────────────────────────────────────────────────────────
  // Batch Save / Update Teacher Attendance
  // Uses a single SQLite transaction with ConflictAlgorithm.replace.
  // Enforces AttendanceDateValidator: future dates are rejected.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> saveOrUpdateTeacherAttendanceBatch(
    List<TeacherAttendanceModel> records,
  ) async {
    if (records.isEmpty) return;

    // Validate all records before opening transaction
    for (final item in records) {
      AttendanceDateValidator.validateNotFuture(item.date);
    }

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final item in records) {
        final recordMap = item.toMap();
        recordMap['createdAt'] = item.createdAt ?? now;
        recordMap['updatedAt'] = now;

        await txn.insert(
          'teacher_attendance',
          recordMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    // Sync each record to cloud
    for (final item in records) {
      SyncEngine.instance.registerTeacherAttendanceChange(
        attendanceId: item.id ?? 0,
        operation: 'CREATE',
        payload: item.toMap(),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Safe Cleanup of Future Test Records
  // Removes teacher attendance records with dates later than today's local date.
  // ──────────────────────────────────────────────────────────────────────

  Future<int> cleanupFutureTestRecords() async {
    final db = await _dbHelper.database;
    final today = AttendanceDateValidator.todayIso;
    return await db.delete(
      'teacher_attendance',
      where: 'date > ?',
      whereArgs: [today],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Teacher Attendance for Date (Active Teachers Only)
  // Excludes inactive teachers from daily attendance-taking list,
  // but loads existing recorded hours for active teachers on that date.
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TeacherAttendanceModel>> getTeacherAttendanceByDate(
    String date,
  ) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT 
        t.id AS teacherId,
        t.name AS teacherName,
        t.subject AS teacherSubject,
        t.mobile AS teacherMobile,
        t.payPerHour AS teacherPayPerHour,
        ta.id AS id,
        ta.date AS date,
        COALESCE(ta.hoursWorked, 0.0) AS hoursWorked,
        ta.remarks AS remarks,
        ta.createdAt AS createdAt,
        ta.updatedAt AS updatedAt
      FROM teachers t
      LEFT JOIN teacher_attendance ta 
        ON t.id = ta.teacherId AND ta.date = ?
      WHERE t.isActive = 1
      ORDER BY t.name ASC
    ''';

    final maps = await db.rawQuery(query, [date]);

    return maps.map((map) {
      return TeacherAttendanceModel(
        id: map['id'] as int?,
        teacherId: map['teacherId'] as int,
        date: (map['date'] as String?) ?? date,
        hoursWorked: (map['hoursWorked'] as num?)?.toDouble() ?? 0.0,
        remarks: map['remarks'] as String?,
        createdAt: map['createdAt'] as String?,
        updatedAt: map['updatedAt'] as String?,
        teacherName: map['teacherName'] as String?,
        teacherSubject: map['teacherSubject'] as String?,
        teacherMobile: map['teacherMobile'] as String?,
        teacherPayPerHour: (map['teacherPayPerHour'] as num?)?.toDouble(),
      );
    }).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Attendance History for a Teacher (Works for Active & Inactive)
  // Historical attendance for inactive teachers remains accessible.
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TeacherAttendanceModel>> getTeacherAttendanceHistory(
    int teacherId,
  ) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'teacher_attendance',
      where: 'teacherId = ?',
      whereArgs: [teacherId],
      orderBy: 'date DESC',
    );
    return maps.map(TeacherAttendanceModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Compute Monthly Hours Summary for a Teacher
  // yearMonth format: 'YYYY-MM'
  // ──────────────────────────────────────────────────────────────────────

  Future<TeacherAttendanceSummary> getTeacherMonthlySummary({
    required int teacherId,
    required String yearMonth,
  }) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT 
        COUNT(*) AS totalWorkingDays,
        COALESCE(SUM(hoursWorked), 0.0) AS totalHours
      FROM teacher_attendance
      WHERE teacherId = ? AND date LIKE ? AND hoursWorked > 0
    ''';

    final results = await db.rawQuery(query, [teacherId, '$yearMonth%']);

    if (results.isEmpty || results.first['totalWorkingDays'] == 0) {
      return TeacherAttendanceSummary.empty();
    }

    final row = results.first;
    return TeacherAttendanceSummary(
      totalWorkingDays: (row['totalWorkingDays'] as num).toInt(),
      totalHoursWorked: (row['totalHours'] as num).toDouble(),
    );
  }
}
