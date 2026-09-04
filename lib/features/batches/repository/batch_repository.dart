import '../../../core/database/database_helper.dart';
import '../models/batch_model.dart';
import '../models/batch_student_model.dart';

/// Repository for Batch Management CRUD operations.
class BatchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Batch CRUD ────────────────────────────────────────────────

  Future<List<BatchModel>> getBatches({String? studentClass}) async {
    final db = await _dbHelper.database;
    final where = studentClass != null ? 'studentClass = ?' : null;
    final whereArgs = studentClass != null ? [studentClass] : null;
    final maps = await db.query('batches', where: where, whereArgs: whereArgs, orderBy: 'name ASC');
    return maps.map((m) => BatchModel.fromMap(m)).toList();
  }

  Future<List<BatchModel>> getActiveBatches({String? studentClass}) async {
    final db = await _dbHelper.database;
    final whereClauses = ['isActive = 1'];
    final whereArgs = <dynamic>[];
    if (studentClass != null) {
      whereClauses.add('studentClass = ?');
      whereArgs.add(studentClass);
    }
    final maps = await db.query(
      'batches',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return maps.map((m) => BatchModel.fromMap(m)).toList();
  }

  Future<BatchModel?> getBatchById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('batches', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return BatchModel.fromMap(maps.first);
  }

  Future<int> insertBatch(BatchModel batch) async {
    final db = await _dbHelper.database;
    return await db.insert('batches', batch.toMap());
  }

  Future<void> updateBatch(BatchModel batch) async {
    final db = await _dbHelper.database;
    await db.update(
      'batches',
      {...batch.toMap(), 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  Future<void> deleteBatch(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'batches',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Student Assignment ────────────────────────────────────────

  Future<List<BatchStudentModel>> getStudentsInBatch(int batchId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'batch_students',
      where: 'batchId = ? AND isActive = 1',
      whereArgs: [batchId],
      orderBy: 'enrolledAt ASC',
    );
    return maps.map((m) => BatchStudentModel.fromMap(m)).toList();
  }

  Future<List<int>> getStudentIdsInBatch(int batchId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'batch_students',
      columns: ['studentId'],
      where: 'batchId = ? AND isActive = 1',
      whereArgs: [batchId],
    );
    return maps.map((m) => m['studentId'] as int).toList();
  }

  Future<List<int>> getBatchIdsForStudent(int studentId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'batch_students',
      columns: ['batchId'],
      where: 'studentId = ? AND isActive = 1',
      whereArgs: [studentId],
    );
    return maps.map((m) => m['batchId'] as int).toList();
  }

  Future<void> addStudentToBatch(int batchId, int studentId) async {
    final db = await _dbHelper.database;
    // Check if already enrolled
    final existing = await db.query(
      'batch_students',
      where: 'batchId = ? AND studentId = ?',
      whereArgs: [batchId, studentId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      // Reactivate if previously removed
      await db.update(
        'batch_students',
        {'isActive': 1, 'enrolledAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('batch_students', {
        'batchId': batchId,
        'studentId': studentId,
        'enrolledAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> removeStudentFromBatch(int batchId, int studentId) async {
    final db = await _dbHelper.database;
    await db.update(
      'batch_students',
      {'isActive': 0},
      where: 'batchId = ? AND studentId = ?',
      whereArgs: [batchId, studentId],
    );
  }

  Future<void> addMultipleStudentsToBatch(int batchId, List<int> studentIds) async {
    for (final studentId in studentIds) {
      await addStudentToBatch(batchId, studentId);
    }
  }

  // ── Stats ─────────────────────────────────────────────────────

  Future<int> getStudentCount(int batchId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM batch_students WHERE batchId = ? AND isActive = 1',
      [batchId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> getBatchCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM batches WHERE isActive = 1',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
