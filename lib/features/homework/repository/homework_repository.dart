import '../../../core/database/database_helper.dart';
import '../models/homework_model.dart';
import '../models/homework_submission_model.dart';

/// Repository for Homework Tracking CRUD operations.
class HomeworkRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Homework CRUD ─────────────────────────────────────────────

  Future<List<HomeworkModel>> getHomework({String? studentClass, String? subject}) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>['isActive = 1'];
    final whereArgs = <dynamic>[];

    if (studentClass != null && studentClass.isNotEmpty) {
      whereClauses.add('studentClass = ?');
      whereArgs.add(studentClass);
    }
    if (subject != null && subject.isNotEmpty) {
      whereClauses.add('subject = ?');
      whereArgs.add(subject);
    }

    final maps = await db.query(
      'homework',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'dueDate DESC',
    );
    return maps.map((m) => HomeworkModel.fromMap(m)).toList();
  }

  Future<List<HomeworkModel>> getHomeworkForClass(String studentClass) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'homework',
      where: 'studentClass = ? AND isActive = 1',
      whereArgs: [studentClass],
      orderBy: 'dueDate DESC',
    );
    return maps.map((m) => HomeworkModel.fromMap(m)).toList();
  }

  Future<List<HomeworkModel>> getPendingHomeworkForStudent(int studentId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT h.* FROM homework h
      WHERE h.isActive = 1
        AND h.studentClass = (SELECT studentClass FROM students WHERE id = ?)
        AND NOT EXISTS (
          SELECT 1 FROM homework_submissions s
          WHERE s.homeworkId = h.id AND s.studentId = ? AND s.status IN ('Submitted', 'Excused')
        )
      ORDER BY h.dueDate ASC
    ''', [studentId, studentId]);
    return maps.map((m) => HomeworkModel.fromMap(m)).toList();
  }

  Future<HomeworkModel?> getHomeworkById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('homework', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return HomeworkModel.fromMap(maps.first);
  }

  Future<int> insertHomework(HomeworkModel homework) async {
    final db = await _dbHelper.database;
    return await db.insert('homework', homework.toMap());
  }

  Future<void> updateHomework(HomeworkModel homework) async {
    final db = await _dbHelper.database;
    await db.update(
      'homework',
      {...homework.toMap(), 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [homework.id],
    );
  }

  Future<void> deleteHomework(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'homework',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Submissions ───────────────────────────────────────────────

  Future<List<HomeworkSubmissionModel>> getSubmissionsForHomework(int homeworkId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'homework_submissions',
      where: 'homeworkId = ?',
      whereArgs: [homeworkId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => HomeworkSubmissionModel.fromMap(m)).toList();
  }

  Future<HomeworkSubmissionModel?> getSubmission(int homeworkId, int studentId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'homework_submissions',
      where: 'homeworkId = ? AND studentId = ?',
      whereArgs: [homeworkId, studentId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return HomeworkSubmissionModel.fromMap(maps.first);
  }

  Future<void> markSubmitted(int homeworkId, int studentId, {String? remarks}) async {
    final db = await _dbHelper.database;
    final existing = await getSubmission(homeworkId, studentId);
    final now = DateTime.now().toIso8601String();

    // Check if late
    final hw = await getHomeworkById(homeworkId);
    final isLate = hw != null && DateTime.now().isAfter(DateTime.parse(hw.dueDate));
    final status = isLate ? 'Late' : 'Submitted';

    if (existing == null) {
      await db.insert('homework_submissions', {
        'homeworkId': homeworkId,
        'studentId': studentId,
        'status': status,
        'submittedAt': now,
        'remarks': remarks,
        'createdAt': now,
      });
    } else {
      await db.update(
        'homework_submissions',
        {
          'status': status,
          'submittedAt': now,
          'remarks': remarks ?? existing.remarks,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
  }

  Future<void> markExcused(int homeworkId, int studentId, {String? remarks}) async {
    final db = await _dbHelper.database;
    final existing = await getSubmission(homeworkId, studentId);
    final now = DateTime.now().toIso8601String();

    if (existing == null) {
      await db.insert('homework_submissions', {
        'homeworkId': homeworkId,
        'studentId': studentId,
        'status': 'Excused',
        'remarks': remarks,
        'createdAt': now,
      });
    } else {
      await db.update(
        'homework_submissions',
        {'status': 'Excused', 'remarks': remarks ?? existing.remarks, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
  }

  Future<void> markPending(int homeworkId, int studentId) async {
    final db = await _dbHelper.database;
    final existing = await getSubmission(homeworkId, studentId);
    if (existing != null) {
      await db.update(
        'homework_submissions',
        {'status': 'Pending', 'submittedAt': null, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
  }

  // ── Stats ─────────────────────────────────────────────────────

  Future<Map<String, int>> getSubmissionStats(int homeworkId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT status, COUNT(*) as cnt
      FROM homework_submissions
      WHERE homeworkId = ?
      GROUP BY status
    ''', [homeworkId]);

    final stats = {'Submitted': 0, 'Pending': 0, 'Late': 0, 'Excused': 0};
    for (final row in result) {
      stats[row['status'] as String] = (row['cnt'] as int?) ?? 0;
    }
    return stats;
  }

  Future<int> getOverdueHomeworkCount() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM homework WHERE isActive = 1 AND dueDate < ?",
      [today],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
