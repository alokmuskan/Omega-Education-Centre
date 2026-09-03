import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/services/sync_engine.dart';
import '../models/student_test_summary_model.dart';
import '../models/test_result_model.dart';

import '../services/result_calculation_service.dart';
import 'test_repository.dart';

/// Repository for Test Results SQLite operations.
///
/// Enforces UNIQUE(testId, studentId, testSubjectId) via upsert replace.
class TestResultRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TestRepository _testRepo = TestRepository();

  // ──────────────────────────────────────────────────────────────────────
  // Batch Save / Update Test Results
  // ──────────────────────────────────────────────────────────────────────

  Future<void> saveOrUpdateResultsBatch(List<TestResultModel> results) async {
    if (results.isEmpty) return;
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final item in results) {
        // Validate non-negative marks
        if (item.marksObtained < 0) {
          throw ArgumentError('Marks obtained cannot be negative (${item.marksObtained}).');
        }

        final map = item.toMap();
        map['createdAt'] = item.createdAt ?? nowIso;
        map['updatedAt'] = nowIso;

        // Query by unique composite key (testId, studentId, testSubjectId)
        final existing = await txn.query(
          'test_results',
          columns: ['id'],
          where: 'testId = ? AND studentId = ? AND testSubjectId = ?',
          whereArgs: [item.testId, item.studentId, item.testSubjectId],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final existingId = existing.first['id'] as int;
          map['id'] = existingId;
          await txn.update(
            'test_results',
            map,
            where: 'id = ?',
            whereArgs: [existingId],
          );
        } else {
          map.remove('id');
          await txn.insert(
            'test_results',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    // Sync each result to cloud
    for (final item in results) {
      SyncEngine.instance.registerTestResultChange(
        resultId: item.id ?? 0,
        operation: 'CREATE',
        payload: item.toMap(),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Results Recorded for a Test
  // Joined with students and test_subjects
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TestResultModel>> getResultsByTest(int testId) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT 
        tr.id AS id,
        tr.testId AS testId,
        tr.studentId AS studentId,
        tr.testSubjectId AS testSubjectId,
        tr.marksObtained AS marksObtained,
        tr.remarks AS remarks,
        tr.createdAt AS createdAt,
        tr.updatedAt AS updatedAt,
        s.name AS studentName,
        s.rollNo AS studentRollNo,
        ts.subjectName AS subjectName,
        ts.maxMarks AS maxMarks,
        ts.passMarks AS passMarks
      FROM test_results tr
      JOIN students s ON tr.studentId = s.id
      JOIN test_subjects ts ON tr.testSubjectId = ts.id
      WHERE tr.testId = ?
      ORDER BY s.rollNo ASC, s.name ASC, ts.id ASC
    ''';

    final maps = await db.rawQuery(query, [testId]);
    return maps.map(TestResultModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Results Recorded for a Student
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TestResultModel>> getResultsByStudent(int studentId) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT 
        tr.id AS id,
        tr.testId AS testId,
        tr.studentId AS studentId,
        tr.testSubjectId AS testSubjectId,
        tr.marksObtained AS marksObtained,
        tr.remarks AS remarks,
        tr.createdAt AS createdAt,
        tr.updatedAt AS updatedAt,
        s.name AS studentName,
        s.rollNo AS studentRollNo,
        ts.subjectName AS subjectName,
        ts.maxMarks AS maxMarks,
        ts.passMarks AS passMarks
      FROM test_results tr
      JOIN students s ON tr.studentId = s.id
      JOIN test_subjects ts ON tr.testSubjectId = ts.id
      WHERE tr.studentId = ?
      ORDER BY tr.testId DESC, ts.id ASC
    ''';

    final maps = await db.rawQuery(query, [studentId]);
    return maps.map(TestResultModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Class Test Summaries (With Competition Ranking)
  // Computes StudentTestSummaryModel for all active students in the test's class.
  // ──────────────────────────────────────────────────────────────────────

  Future<List<StudentTestSummaryModel>> getClassTestSummaries(int testId) async {
    final test = await _testRepo.getTestById(testId);
    if (test == null) return [];

    final db = await _dbHelper.database;

    // Fetch active students in class (and board if filtered)
    final studentQuery = '''
      SELECT id, name, rollNo, studentClass, board, profilePhotoPath
      FROM students
      WHERE studentClass = ? AND isActive = 1
      ORDER BY rollNo ASC, name ASC
    ''';
    final studentMaps = await db.rawQuery(studentQuery, [test.studentClass]);

    // Fetch all recorded results for test
    final recordedResults = await getResultsByTest(testId);

    // Build unranked summaries map
    final summaryMap = <int, StudentTestSummaryModel>{};
    final percentageMap = <int, double>{};
    final completeMap = <int, bool>{};

    for (final sMap in studentMaps) {
      final sId = sMap['id'] as int;
      final sName = sMap['name'] as String;
      final sRoll = sMap['rollNo']?.toString() ?? '';

      final sResults = recordedResults.where((r) => r.studentId == sId).toList();

      final summary = StudentTestSummaryModel.compute(
        studentId: sId,
        studentName: sName,
        studentRollNo: sRoll,
        testId: test.id!,
        testTitle: test.title,
        testType: test.testType,
        board: (sMap['board'] as String?) ?? test.board,
        studentClass: test.studentClass,
        testDate: test.testDate,
        academicYear: test.academicYear,
        profilePhotoPath: sMap['profilePhotoPath'] as String?,
        configuredSubjects: test.subjects,
        recordedResults: sResults,
      );

      summaryMap[sId] = summary;
      percentageMap[sId] = summary.percentage;
      completeMap[sId] = summary.isComplete;
    }

    // Compute standard competition ranks
    final rankMap = ResultCalculationService.computeCompetitionRanks(
      studentIdToPercentage: percentageMap,
      studentIdToIsComplete: completeMap,
    );

    // Re-construct summaries with ranks
    final rankedSummaries = <StudentTestSummaryModel>[];
    for (final sId in summaryMap.keys) {
      final s = summaryMap[sId]!;
      final r = rankMap[sId] ?? 0;
      rankedSummaries.add(
        StudentTestSummaryModel.compute(
          studentId: s.studentId,
          studentName: s.studentName,
          studentRollNo: s.studentRollNo,
          testId: s.testId,
          testTitle: s.testTitle,
          testType: s.testType,
          board: s.board,
          studentClass: s.studentClass,
          testDate: s.testDate,
          academicYear: s.academicYear,
          profilePhotoPath: s.profilePhotoPath,
          configuredSubjects: s.configuredSubjects,
          recordedResults: s.subjectResults,
          rank: r,
        ),
      );
    }

    return rankedSummaries;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get All Student Test Summaries (For Student Result History Screen)
  // ──────────────────────────────────────────────────────────────────────

  Future<List<StudentTestSummaryModel>> getStudentResultHistory(int studentId) async {
    final db = await _dbHelper.database;

    // Find tests where student has results or tests for student's class
    final studentMaps = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (studentMaps.isEmpty) return [];
    final student = studentMaps.first;
    final sClass = student['studentClass'] as String;

    final tests = await _testRepo.getTests(studentClass: sClass);

    final historyList = <StudentTestSummaryModel>[];

    for (final t in tests) {
      if (t.id == null) continue;
      final classSummaries = await getClassTestSummaries(t.id!);
      try {
        final sSummary = classSummaries.firstWhere((s) => s.studentId == studentId);
        // Only include if at least 1 subject result is recorded
        if (sSummary.subjectResults.isNotEmpty) {
          historyList.add(sSummary);
        }
      } catch (_) {}
    }

    return historyList;
  }
}
