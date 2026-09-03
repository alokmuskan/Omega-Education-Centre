import '../../../core/database/database_helper.dart';
import '../models/test_model.dart';
import '../models/test_subject_model.dart';

/// Repository for Test and TestSubject SQLite operations.
class TestRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ──────────────────────────────────────────────────────────────────────
  // Insert Test with Subjects (Transaction)
  // ──────────────────────────────────────────────────────────────────────

  Future<int> insertTestWithSubjects(
    TestModel test,
    List<TestSubjectModel> subjects,
  ) async {
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      final testMap = test.toMap();
      testMap['createdAt'] = test.createdAt ?? nowIso;
      testMap['updatedAt'] = nowIso;

      final testId = await txn.insert('tests', testMap);

      for (final subj in subjects) {
        final subjMap = subj.toMap();
        subjMap['testId'] = testId;
        subjMap['createdAt'] = nowIso;
        subjMap['updatedAt'] = nowIso;
        await txn.insert('test_subjects', subjMap);
      }

      return testId;
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Tests (With Filters)
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TestModel>> getTests({
    String? query,
    String? testType,
    String? studentClass,
    String? board,
    bool includeArchived = false,
  }) async {
    final db = await _dbHelper.database;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (!includeArchived) {
      conditions.add('isArchived = 0');
    }

    if (query != null && query.trim().isNotEmpty) {
      conditions.add('(title LIKE ? OR testName LIKE ? OR remarks LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }

    if (testType != null && testType != 'All') {
      conditions.add('testType = ?');
      args.add(testType);
    }

    if (studentClass != null && studentClass != 'All') {
      conditions.add('studentClass = ?');
      args.add(studentClass);
    }

    if (board != null && board != 'All') {
      conditions.add('board = ?');
      args.add(board);
    }

    final testMaps = await db.query(
      'tests',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'testDate DESC, id DESC',
    );

    final testsList = <TestModel>[];

    for (final tMap in testMaps) {
      final testId = tMap['id'] as int;
      final subjMaps = await db.query(
        'test_subjects',
        where: 'testId = ?',
        whereArgs: [testId],
        orderBy: 'id ASC',
      );
      final subjects = subjMaps.map(TestSubjectModel.fromMap).toList();
      testsList.add(TestModel.fromMap(tMap, subjects: subjects));
    }

    return testsList;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Test by ID
  // ──────────────────────────────────────────────────────────────────────

  Future<TestModel?> getTestById(int id) async {
    final db = await _dbHelper.database;
    final testMaps = await db.query(
      'tests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (testMaps.isEmpty) return null;

    final subjMaps = await db.query(
      'test_subjects',
      where: 'testId = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    final subjects = subjMaps.map(TestSubjectModel.fromMap).toList();

    return TestModel.fromMap(testMaps.first, subjects: subjects);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Update Test with Subjects (Transaction)
  // ──────────────────────────────────────────────────────────────────────

  Future<void> updateTestWithSubjects(
    TestModel test,
    List<TestSubjectModel> subjects,
  ) async {
    if (test.id == null) return;
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final testMap = test.toMap();
      testMap['updatedAt'] = nowIso;

      await txn.update(
        'tests',
        testMap,
        where: 'id = ?',
        whereArgs: [test.id],
      );

      // Delete subjects removed by user
      await txn.delete(
        'test_subjects',
        where: 'testId = ?',
        whereArgs: [test.id],
      );

      // Re-insert subjects
      for (final subj in subjects) {
        final subjMap = subj.toMap();
        subjMap['testId'] = test.id;
        subjMap['createdAt'] = subj.createdAt ?? nowIso;
        subjMap['updatedAt'] = nowIso;
        await txn.insert('test_subjects', subjMap);
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────
  // Soft Archive Test (Preserves Historical Results)
  // ──────────────────────────────────────────────────────────────────────

  Future<int> archiveTest(int testId) async {
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    return await db.update(
      'tests',
      {'isArchived': 1, 'updatedAt': nowIso},
      where: 'id = ?',
      whereArgs: [testId],
    );
  }
}
