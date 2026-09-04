import '../../../core/database/database_helper.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/utils/attendance_date_validator.dart';
import '../../teachers/models/teacher_model.dart';
import '../../teachers/repository/teacher_repository.dart';
import '../models/daily_class_record_model.dart';

/// Repository for Daily Class Record SQLite database operations.
///
/// Stores operational teaching logs of classes conducted by teachers.
/// Joins [teachers] table on [teacherId] to dynamically resolve teacher names.
/// Enforces [AttendanceDateValidator.validateNotFuture] on all write operations.
class DailyClassRecordRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TeacherRepository _teacherRepository = TeacherRepository();

  // ──────────────────────────────────────────────────────────────────────
  // Insert Class Record
  // Rejects future dates via AttendanceDateValidator.validateNotFuture
  // ──────────────────────────────────────────────────────────────────────

  Future<int> insertRecord(DailyClassRecordModel record) async {
    AttendanceDateValidator.validateNotFuture(record.date);

    if (record.topic.trim().isEmpty) {
      throw ArgumentError('Topic covered is mandatory.');
    }

    if (record.durationMinutes <= 0) {
      throw ArgumentError('Duration must be greater than 0 minutes.');
    }

    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    final recordMap = record.toMap();

    recordMap['createdAt'] = record.createdAt ?? nowIso;
    recordMap['updatedAt'] = nowIso;

    final recordId = await db.insert('daily_class_records', recordMap);

    // Sync to cloud
    SyncEngine.instance.registerDailyClassRecordChange(
      recordId: recordId,
      operation: 'CREATE',
      payload: recordMap..['id'] = recordId,
    );

    return recordId;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Update Class Record
  // Rejects future dates via AttendanceDateValidator.validateNotFuture
  // ──────────────────────────────────────────────────────────────────────

  Future<int> updateRecord(DailyClassRecordModel record) async {
    if (record.id == null) {
      throw ArgumentError('Cannot update daily class record without an ID.');
    }

    AttendanceDateValidator.validateNotFuture(record.date);

    if (record.topic.trim().isEmpty) {
      throw ArgumentError('Topic covered is mandatory.');
    }

    if (record.durationMinutes <= 0) {
      throw ArgumentError('Duration must be greater than 0 minutes.');
    }

    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    final recordMap = record.toMap();

    recordMap['updatedAt'] = nowIso;

    return await db.update(
      'daily_class_records',
      recordMap,
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Delete Class Record
  // ──────────────────────────────────────────────────────────────────────

  Future<int> deleteRecord(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'daily_class_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Class Record By ID
  // ──────────────────────────────────────────────────────────────────────

  Future<DailyClassRecordModel?> getRecordById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        dcr.*,
        t.name AS teacherName
      FROM daily_class_records dcr
      LEFT JOIN teachers t ON dcr.teacherId = t.id
      WHERE dcr.id = ?
      LIMIT 1
    ''';

    final results = await db.rawQuery(query, [id]);
    if (results.isEmpty) return null;
    return DailyClassRecordModel.fromMap(results.first);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get All Class Records (ordered newest first)
  // ──────────────────────────────────────────────────────────────────────

  Future<List<DailyClassRecordModel>> getAllRecords() async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        dcr.*,
        t.name AS teacherName
      FROM daily_class_records dcr
      LEFT JOIN teachers t ON dcr.teacherId = t.id
      ORDER BY dcr.date DESC, dcr.id DESC
    ''';

    final results = await db.rawQuery(query);
    return results.map(DailyClassRecordModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Records for a Specific Teacher (Teacher History)
  // ──────────────────────────────────────────────────────────────────────

  Future<List<DailyClassRecordModel>> getRecordsByTeacher(int teacherId) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        dcr.*,
        t.name AS teacherName
      FROM daily_class_records dcr
      LEFT JOIN teachers t ON dcr.teacherId = t.id
      WHERE dcr.teacherId = ?
      ORDER BY dcr.date DESC, dcr.id DESC
    ''';

    final results = await db.rawQuery(query, [teacherId]);
    return results.map(DailyClassRecordModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Filtered & Searched Query
  // Supports search, class, board, teacherId, subject, batch, date filters
  // ──────────────────────────────────────────────────────────────────────

  Future<List<DailyClassRecordModel>> getRecordsFiltered({
    String? searchQuery,
    String? studentClass,
    String? board,
    int? teacherId,
    String? subject,
    String? batch,
    String? dateFilter, // 'Today' | 'This Week' | 'This Month' | 'Custom'
    String? startDate,  // YYYY-MM-DD
    String? endDate,    // YYYY-MM-DD
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      whereClauses.add(
        '(t.name LIKE ? OR dcr.subject LIKE ? OR dcr.studentClass LIKE ? OR dcr.batch LIKE ? OR dcr.topic LIKE ?)',
      );
      whereArgs.addAll([q, q, q, q, q]);
    }

    if (studentClass != null && studentClass != 'All' && studentClass.isNotEmpty) {
      whereClauses.add('dcr.studentClass = ?');
      whereArgs.add(studentClass);
    }

    if (board != null && board != 'All' && board.isNotEmpty) {
      whereClauses.add('dcr.board = ?');
      whereArgs.add(board);
    }

    if (teacherId != null && teacherId > 0) {
      whereClauses.add('dcr.teacherId = ?');
      whereArgs.add(teacherId);
    }

    if (subject != null && subject != 'All' && subject.isNotEmpty) {
      whereClauses.add('dcr.subject = ?');
      whereArgs.add(subject);
    }

    if (batch != null && batch.trim().isNotEmpty) {
      whereClauses.add('dcr.batch LIKE ?');
      whereArgs.add('%${batch.trim()}%');
    }

    // Date Filtering
    final now = DateTime.now();
    final todayStr = AttendanceDateValidator.todayIso;

    if (dateFilter == 'Today') {
      whereClauses.add('dcr.date = ?');
      whereArgs.add(todayStr);
    } else if (dateFilter == 'This Week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final mondayStr = AttendanceDateValidator.formatDateIso(monday);
      whereClauses.add('dcr.date >= ? AND dcr.date <= ?');
      whereArgs.addAll([mondayStr, todayStr]);
    } else if (dateFilter == 'This Month') {
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final firstOfMonthStr = AttendanceDateValidator.formatDateIso(firstOfMonth);
      whereClauses.add('dcr.date >= ? AND dcr.date <= ?');
      whereArgs.addAll([firstOfMonthStr, todayStr]);
    } else if (startDate != null && startDate.isNotEmpty && endDate != null && endDate.isNotEmpty) {
      whereClauses.add('dcr.date >= ? AND dcr.date <= ?');
      whereArgs.addAll([startDate, endDate]);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        dcr.*,
        t.name AS teacherName
      FROM daily_class_records dcr
      LEFT JOIN teachers t ON dcr.teacherId = t.id
      $whereString
      ORDER BY dcr.date DESC, dcr.id DESC
    ''';

    final results = await db.rawQuery(query, whereArgs);
    return results.map(DailyClassRecordModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Pending Active Teachers (Active teachers with no teaching log for date)
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TeacherModel>> getPendingActiveTeachers(String dateIso) async {
    final allTeachers = await _teacherRepository.getTeachers();
    final activeTeachers = allTeachers.where((t) => t.isActive).toList();

    final db = await _dbHelper.database;
    final submittedMaps = await db.rawQuery(
      'SELECT DISTINCT teacherId FROM daily_class_records WHERE date = ?',
      [dateIso],
    );

    final submittedIds = submittedMaps.map((m) => m['teacherId'] as int).toSet();

    return activeTeachers.where((t) => !submittedIds.contains(t.id)).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Daily Admin Monitoring Summary for a specific date
  // ──────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDailyMonitoringSummary(String dateIso) async {
    final db = await _dbHelper.database;
    final recordsOnDate = await db.rawQuery(
      'SELECT teacherId, durationMinutes FROM daily_class_records WHERE date = ?',
      [dateIso],
    );

    final totalClasses = recordsOnDate.length;
    final totalMins = recordsOnDate.fold<int>(0, (sum, r) => sum + ((r['durationMinutes'] as num? ?? 60).toInt()));
    final submittedTeacherIds = recordsOnDate.map((r) => r['teacherId'] as int).toSet();

    final pendingTeachers = await getPendingActiveTeachers(dateIso);

    return {
      'date': dateIso,
      'totalClasses': totalClasses,
      'totalMins': totalMins,
      'totalHours': totalMins / 60.0,
      'submittedCount': submittedTeacherIds.length,
      'pendingCount': pendingTeachers.length,
      'pendingTeachers': pendingTeachers,
    };
  }
}
