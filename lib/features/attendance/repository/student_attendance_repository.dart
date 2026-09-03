import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/utils/attendance_date_validator.dart';
import '../models/attendance_summary_model.dart';
import '../models/student_attendance_model.dart';

/// Repository for Student Attendance database operations.
///
/// Enforces UNIQUE(studentId, date) via upserts (INSERT OR REPLACE)
/// so editing existing date records updates SQLite cleanly without duplicates.
class StudentAttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ──────────────────────────────────────────────────────────────────────
  // Batch Save / Update Attendance
  // Uses a single SQLite transaction with ConflictAlgorithm.replace.
  // Enforces AttendanceDateValidator: future dates are rejected.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> saveOrUpdateAttendanceBatch(
    List<StudentAttendanceModel> records,
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
          'student_attendance',
          recordMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  // Safe Cleanup of Future Test Records
  // Removes student attendance records with dates later than today's local date.
  // ──────────────────────────────────────────────────────────────────────

  Future<int> cleanupFutureTestRecords() async {
    final db = await _dbHelper.database;
    final today = AttendanceDateValidator.todayIso;
    return await db.delete(
      'student_attendance',
      where: 'date > ?',
      whereArgs: [today],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Class Attendance for Date
  // Returns list of student attendance models for all active students in class.
  // If student has no attendance recorded on date, status defaults to 'Present'.
  // ──────────────────────────────────────────────────────────────────────

  Future<List<StudentAttendanceModel>> getAttendanceByClassAndDate({
    required String studentClass,
    required String date,
  }) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT 
        s.id AS studentId,
        s.name AS studentName,
        s.rollNo AS studentRollNo,
        s.studentClass AS studentClass,
        sa.id AS id,
        sa.date AS date,
        COALESCE(sa.status, 'Present') AS status,
        sa.remarks AS remarks,
        sa.createdAt AS createdAt,
        sa.updatedAt AS updatedAt
      FROM students s
      LEFT JOIN student_attendance sa 
        ON s.id = sa.studentId AND sa.date = ?
      WHERE s.studentClass = ? AND s.isActive = 1
      ORDER BY s.rollNo ASC, s.name ASC
    ''';

    final maps = await db.rawQuery(query, [date, studentClass]);

    return maps.map((map) {
      return StudentAttendanceModel(
        id: map['id'] as int?,
        studentId: map['studentId'] as int,
        date: (map['date'] as String?) ?? date,
        status: (map['status'] as String?) ?? 'Present',
        remarks: map['remarks'] as String?,
        createdAt: map['createdAt'] as String?,
        updatedAt: map['updatedAt'] as String?,
        studentName: map['studentName'] as String?,
        studentRollNo: map['studentRollNo']?.toString(),
        studentClass: map['studentClass'] as String?,
      );
    }).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Attendance History for a Student
  // ──────────────────────────────────────────────────────────────────────

  Future<List<StudentAttendanceModel>> getStudentAttendanceHistory(
    int studentId,
  ) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'student_attendance',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
    return maps.map(StudentAttendanceModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Compute Monthly Attendance Summary for a Student
  // yearMonth format: 'YYYY-MM'
  // ──────────────────────────────────────────────────────────────────────

  Future<StudentAttendanceSummary> getStudentMonthlySummary({
    required int studentId,
    required String yearMonth,
  }) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT 
        COUNT(*) AS totalDays,
        SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) AS presentCount,
        SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) AS absentCount,
        SUM(CASE WHEN status = 'Late' THEN 1 ELSE 0 END) AS lateCount,
        SUM(CASE WHEN status = 'Leave' THEN 1 ELSE 0 END) AS leaveCount
      FROM student_attendance
      WHERE studentId = ? AND date LIKE ?
    ''';

    final results = await db.rawQuery(query, [studentId, '$yearMonth%']);

    if (results.isEmpty || results.first['totalDays'] == 0) {
      return StudentAttendanceSummary.empty();
    }

    final row = results.first;
    return StudentAttendanceSummary(
      totalRecordedDays: (row['totalDays'] as num).toInt(),
      presentCount: (row['presentCount'] as num).toInt(),
      absentCount: (row['absentCount'] as num).toInt(),
      lateCount: (row['lateCount'] as num).toInt(),
      leaveCount: (row['leaveCount'] as num).toInt(),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Compute Total Overall Attendance Summary for a Student (All Time)
  // ──────────────────────────────────────────────────────────────────────

  Future<StudentAttendanceSummary> getStudentOverallSummary(
    int studentId,
  ) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT 
        COUNT(*) AS totalDays,
        SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) AS presentCount,
        SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) AS absentCount,
        SUM(CASE WHEN status = 'Late' THEN 1 ELSE 0 END) AS lateCount,
        SUM(CASE WHEN status = 'Leave' THEN 1 ELSE 0 END) AS leaveCount
      FROM student_attendance
      WHERE studentId = ?
    ''';

    final results = await db.rawQuery(query, [studentId]);

    if (results.isEmpty || results.first['totalDays'] == 0) {
      return StudentAttendanceSummary.empty();
    }

    final row = results.first;
    return StudentAttendanceSummary(
      totalRecordedDays: (row['totalDays'] as num).toInt(),
      presentCount: (row['presentCount'] as num).toInt(),
      absentCount: (row['absentCount'] as num).toInt(),
      lateCount: (row['lateCount'] as num).toInt(),
      leaveCount: (row['leaveCount'] as num).toInt(),
    );
  }
}
