import '../../../core/database/database_helper.dart';
import '../models/timetable_entry_model.dart';

/// Repository for Timetable SQLite database operations.
class TimetableRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String get todayDayOfWeek {
    final weekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    return daysOfWeek[weekday - 1];
  }

  // ──────────────────────────────────────────────────────────────────────
  // Conflict Validation
  // ──────────────────────────────────────────────────────────────────────

  Future<void> validateConflicts(TimetableEntryModel entry) async {
    if (entry.startMinutes >= entry.endMinutes) {
      throw ArgumentError('End time must be after start time.');
    }

    final allEntries = await getAllTimetableEntries();
    final activeSameDay = allEntries.where((e) => e.isActive && e.dayOfWeek == entry.dayOfWeek && e.id != entry.id).toList();

    // 1. Teacher Conflict Check
    for (final existing in activeSameDay) {
      if (existing.teacherId == entry.teacherId) {
        final overlap = (entry.startMinutes < existing.endMinutes) && (entry.endMinutes > existing.startMinutes);
        if (overlap) {
          final tName = existing.teacherName ?? 'Teacher';
          throw ArgumentError(
            'Teacher schedule conflict: $tName is already scheduled for Class ${existing.studentClass} ${existing.subject} (${existing.timeSlot}) on ${entry.dayOfWeek}.',
          );
        }
      }
    }

    // 2. Class / Batch Conflict Check
    for (final existing in activeSameDay) {
      if (existing.studentClass == entry.studentClass && existing.board == entry.board) {
        final sameBatch = (entry.batch == null || entry.batch!.isEmpty || existing.batch == null || existing.batch!.isEmpty) ||
            (entry.batch!.trim().toLowerCase() == existing.batch!.trim().toLowerCase());

        if (sameBatch) {
          final overlap = (entry.startMinutes < existing.endMinutes) && (entry.endMinutes > existing.startMinutes);
          if (overlap) {
            final bLabel = existing.batch != null && existing.batch!.isNotEmpty ? ' (${existing.batch})' : '';
            throw ArgumentError(
              'Class schedule conflict: Class ${existing.studentClass}$bLabel is already scheduled for ${existing.subject} (${existing.timeSlot}) on ${entry.dayOfWeek}.',
            );
          }
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Repository Operations
  // ──────────────────────────────────────────────────────────────────────

  Future<int> insertTimetableEntry(TimetableEntryModel entry) async {
    await validateConflicts(entry);

    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    final map = entry.toMap();

    map['createdAt'] = entry.createdAt ?? nowIso;
    map['updatedAt'] = nowIso;

    return await db.insert('timetable_entries', map);
  }

  Future<int> updateTimetableEntry(TimetableEntryModel entry) async {
    if (entry.id == null) {
      throw ArgumentError('Cannot update timetable entry without an ID.');
    }

    await validateConflicts(entry);

    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    final map = entry.toMap();

    map['updatedAt'] = nowIso;

    return await db.update(
      'timetable_entries',
      map,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteTimetableEntry(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'timetable_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TimetableEntryModel?> getEntryById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        te.*,
        t.name AS teacherName
      FROM timetable_entries te
      LEFT JOIN teachers t ON te.teacherId = t.id
      WHERE te.id = ?
      LIMIT 1
    ''';

    final results = await db.rawQuery(query, [id]);
    if (results.isEmpty) return null;
    return TimetableEntryModel.fromMap(results.first);
  }

  Future<List<TimetableEntryModel>> getAllTimetableEntries() async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        te.*,
        t.name AS teacherName
      FROM timetable_entries te
      LEFT JOIN teachers t ON te.teacherId = t.id
      ORDER BY te.periodNumber ASC, te.id ASC
    ''';

    final results = await db.rawQuery(query);
    final list = results.map(TimetableEntryModel.fromMap).toList();
    _sortTimetableList(list);
    return list;
  }

  Future<List<TimetableEntryModel>> getTimetableByClass(
    String studentClass, {
    String? board,
    String? batch,
    String? dayOfWeek,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = ['te.studentClass = ?'];
    final whereArgs = <dynamic>[studentClass];

    if (board != null && board != 'All' && board.isNotEmpty) {
      whereClauses.add('te.board = ?');
      whereArgs.add(board);
    }

    if (batch != null && batch.trim().isNotEmpty) {
      whereClauses.add('(te.batch IS NULL OR te.batch = "" OR te.batch LIKE ?)');
      whereArgs.add('%${batch.trim()}%');
    }

    if (dayOfWeek != null && dayOfWeek != 'All') {
      whereClauses.add('te.dayOfWeek = ?');
      whereArgs.add(dayOfWeek);
    }

    final query = '''
      SELECT 
        te.*,
        t.name AS teacherName
      FROM timetable_entries te
      LEFT JOIN teachers t ON te.teacherId = t.id
      WHERE ${whereClauses.join(' AND ')}
    ''';

    final results = await db.rawQuery(query, whereArgs);
    final list = results.map(TimetableEntryModel.fromMap).toList();
    _sortTimetableList(list);
    return list;
  }

  Future<List<TimetableEntryModel>> getTimetableByTeacher(int teacherId, {String? dayOfWeek}) async {
    final db = await _dbHelper.database;
    final whereClauses = ['te.teacherId = ?'];
    final whereArgs = <dynamic>[teacherId];

    if (dayOfWeek != null && dayOfWeek != 'All') {
      whereClauses.add('te.dayOfWeek = ?');
      whereArgs.add(dayOfWeek);
    }

    final query = '''
      SELECT 
        te.*,
        t.name AS teacherName
      FROM timetable_entries te
      LEFT JOIN teachers t ON te.teacherId = t.id
      WHERE ${whereClauses.join(' AND ')}
    ''';

    final results = await db.rawQuery(query, whereArgs);
    final list = results.map(TimetableEntryModel.fromMap).toList();
    _sortTimetableList(list);
    return list;
  }

  Future<List<TimetableEntryModel>> getTimetableForStudent(
    String studentClass, {
    String? board,
    String? batch,
    String? dayOfWeek,
  }) async {
    return await getTimetableByClass(
      studentClass,
      board: board,
      batch: batch,
      dayOfWeek: dayOfWeek,
    );
  }

  Future<List<TimetableEntryModel>> getTodayTimetable({
    int? teacherId,
    String? studentClass,
    String? board,
    String? batch,
  }) async {
    return await getTimetableForDay(
      todayDayOfWeek,
      teacherId: teacherId,
      studentClass: studentClass,
      board: board,
      batch: batch,
    );
  }

  Future<List<TimetableEntryModel>> getTimetableForDay(
    String dayOfWeek, {
    int? teacherId,
    String? studentClass,
    String? board,
    String? batch,
  }) async {
    if (teacherId != null && teacherId > 0) {
      return await getTimetableByTeacher(teacherId, dayOfWeek: dayOfWeek);
    }

    if (studentClass != null && studentClass.isNotEmpty) {
      return await getTimetableByClass(
        studentClass,
        board: board,
        batch: batch,
        dayOfWeek: dayOfWeek,
      );
    }

    final all = await getAllTimetableEntries();
    final dayList = all.where((e) => e.isActive && e.dayOfWeek == dayOfWeek).toList();
    _sortTimetableList(dayList);
    return dayList;
  }

  void _sortTimetableList(List<TimetableEntryModel> list) {
    list.sort((a, b) {
      final dayOrderA = daysOfWeek.indexOf(a.dayOfWeek);
      final dayOrderB = daysOfWeek.indexOf(b.dayOfWeek);
      if (dayOrderA != dayOrderB) return dayOrderA.compareTo(dayOrderB);
      if (a.periodNumber != b.periodNumber) return a.periodNumber.compareTo(b.periodNumber);
      return a.startMinutes.compareTo(b.startMinutes);
    });
  }
}
