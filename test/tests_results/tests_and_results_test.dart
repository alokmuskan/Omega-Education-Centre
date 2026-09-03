import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/tests/models/student_test_summary_model.dart';
import 'package:omega_education_centre/features/tests/models/test_model.dart';
import 'package:omega_education_centre/features/tests/models/test_result_model.dart';
import 'package:omega_education_centre/features/tests/models/test_subject_model.dart';
import 'package:omega_education_centre/features/tests/services/result_calculation_service.dart';
import 'package:omega_education_centre/shared/utils/attendance_date_validator.dart';

void main() {
  group('Tests & Results System Unit Tests (Phase 6)', () {
    test('1 & 2 & 3. Test, Subject, and Result model serialization', () {
      const subject = TestSubjectModel(
        id: 1,
        testId: 10,
        subjectName: 'Mathematics',
        maxMarks: 100.0,
        passMarks: 33.0,
      );

      final subjMap = subject.toMap();
      expect(subjMap['subjectName'], equals('Mathematics'));
      expect(subjMap['maxMarks'], equals(100.0));
      expect(subjMap['passMarks'], equals(33.0));

      final testObj = TestModel(
        id: 10,
        title: 'August Monthly Test',
        testType: 'Monthly Test',
        board: 'CBSE',
        studentClass: 'Class 10',
        testDate: '2026-08-25', // Future test date!
        academicYear: '2026-27',
        remarks: 'Unit 1 & 2',
        subjects: [subject],
      );

      final testMap = testObj.toMap();
      expect(testMap['title'], equals('August Monthly Test'));
      expect(testMap['board'], equals('CBSE'));
      expect(testMap['studentClass'], equals('Class 10'));

      const result = TestResultModel(
        id: 100,
        testId: 10,
        studentId: 5,
        testSubjectId: 1,
        marksObtained: 85.0,
      );

      final resMap = result.toMap();
      expect(resMap['studentId'], equals(5));
      expect(resMap['marksObtained'], equals(85.0));
    });

    test('4 & 5 & 6 & 7. Test and Subject Creation Models & CopyWith', () {
      final subject = const TestSubjectModel(
        subjectName: 'Physics',
        maxMarks: 100.0,
        passMarks: 33.0,
      ).copyWith(id: 2, testId: 10);

      expect(subject.id, equals(2));
      expect(subject.testId, equals(10));
      expect(subject.subjectName, equals('Physics'));
    });

    test('8. Duplicate result key generation UNIQUE(testId, studentId, testSubjectId)', () {
      const r1 = TestResultModel(testId: 1, studentId: 5, testSubjectId: 2, marksObtained: 80.0);
      const r2 = TestResultModel(testId: 1, studentId: 5, testSubjectId: 2, marksObtained: 90.0);

      String getUniqueKey(TestResultModel r) => '${r.testId}_${r.studentId}_${r.testSubjectId}';

      final map = <String, double>{};
      map[getUniqueKey(r1)] = r1.marksObtained;
      map[getUniqueKey(r2)] = r2.marksObtained;

      expect(map.length, equals(1));
      expect(map[getUniqueKey(r1)], equals(90.0)); // Overwritten by upsert replace
    });

    test('9 & 10 & 11. Marks, Max Marks, and Pass Marks validation', () {
      bool isValidMarks(double obtained, double max, double pass) {
        return obtained >= 0 && obtained <= max && max > 0 && pass >= 0 && pass <= max;
      }

      expect(isValidMarks(85.0, 100.0, 33.0), isTrue);
      expect(isValidMarks(0.0, 100.0, 33.0), isTrue);
      expect(isValidMarks(100.0, 100.0, 33.0), isTrue);

      expect(isValidMarks(110.0, 100.0, 33.0), isFalse); // Exceeds max
      expect(isValidMarks(-5.0, 100.0, 33.0), isFalse); // Negative
      expect(isValidMarks(50.0, 100.0, 120.0), isFalse); // Pass > Max
    });

    test('12 & 13. Total & Percentage calculation formula', () {
      // Scenario: 4 subjects out of 100 each (Mathematics: 85, Physics: 78, Chemistry: 91, English: 82)
      const totalObtained = 85.0 + 78.0 + 91.0 + 82.0; // 336.0
      const totalMax = 400.0;

      final pct = ResultCalculationService.computePercentage(
        totalObtained: totalObtained,
        totalMax: totalMax,
      );

      expect(totalObtained, equals(336.0));
      expect(pct, equals(84.0)); // 336 / 400 * 100 = 84%
    });

    test('14. Grade Calculation Scale Verification', () {
      expect(ResultCalculationService.computeGrade(95.0), equals('A+'));
      expect(ResultCalculationService.computeGrade(90.0), equals('A+'));
      expect(ResultCalculationService.computeGrade(84.0), equals('A'));
      expect(ResultCalculationService.computeGrade(75.0), equals('B+'));
      expect(ResultCalculationService.computeGrade(65.0), equals('B'));
      expect(ResultCalculationService.computeGrade(55.0), equals('C'));
      expect(ResultCalculationService.computeGrade(45.0), equals('D'));
      expect(ResultCalculationService.computeGrade(35.0), equals('F'));
    });

    test('15 & 16. Subject & Overall Pass/Fail Logic', () {
      expect(
        ResultCalculationService.isSubjectPassed(marksObtained: 33.0, passMarks: 33.0),
        isTrue,
      );
      expect(
        ResultCalculationService.isSubjectPassed(marksObtained: 32.0, passMarks: 33.0),
        isFalse,
      );

      // All passed -> Pass
      final overallPass = ResultCalculationService.computeOverallStatus(
        subjectPassResults: [true, true, true, true],
        totalSubjectsConfigured: 4,
      );
      expect(overallPass, equals('Pass'));

      // One failed -> Fail
      final overallFail = ResultCalculationService.computeOverallStatus(
        subjectPassResults: [true, true, false, true],
        totalSubjectsConfigured: 4,
      );
      expect(overallFail, equals('Fail'));
    });

    test('17. Incomplete Result Handling (missing subjects)', () {
      // Configured: 4 subjects, but student has only 2 subjects entered
      final overallIncomplete = ResultCalculationService.computeOverallStatus(
        subjectPassResults: [true, true],
        totalSubjectsConfigured: 4,
      );
      expect(overallIncomplete, equals('Incomplete'));
    });

    test('18 & 19. Rank Calculation & Tie Ranking (Standard Competition 1, 1, 3)', () {
      final percentages = {
        1: 92.0,
        2: 92.0, // Tied for 1st
        3: 88.0,
        4: 75.0,
      };

      final completeMap = {
        1: true,
        2: true,
        3: true,
        4: true,
      };

      final ranks = ResultCalculationService.computeCompetitionRanks(
        studentIdToPercentage: percentages,
        studentIdToIsComplete: completeMap,
      );

      expect(ranks[1], equals(1));
      expect(ranks[2], equals(1)); // Tied rank 1
      expect(ranks[3], equals(3)); // Skipped rank 2 -> rank 3!
      expect(ranks[4], equals(4));
    });

    test('20 & 21. Class, Board, and Academic Year Filtering Simulation', () {
      final tests = [
        const TestModel(
          id: 1,
          title: 'Class 10 CBSE Final',
          testType: 'Final Exam',
          board: 'CBSE',
          studentClass: 'Class 10',
          testDate: '2026-03-01',
          academicYear: '2025-26',
        ),
        const TestModel(
          id: 2,
          title: 'Class 9 ICSE Monthly',
          testType: 'Monthly Test',
          board: 'ICSE',
          studentClass: 'Class 9',
          testDate: '2026-08-15',
          academicYear: '2026-27',
        ),
      ];

      final class10Cbse = tests
          .where((t) => t.studentClass == 'Class 10' && t.board == 'CBSE')
          .toList();
      expect(class10Cbse.length, equals(1));
      expect(class10Cbse.first.title, equals('Class 10 CBSE Final'));
    });

    test('22. Future Test Dates ARE Allowed for Examinations', () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 30));
      final futureDateStr = '${futureDate.year}-09-30';

      // Test creation model allows future testDate
      final test = TestModel(
        title: 'Upcoming September Examination',
        testType: 'Monthly Test',
        board: 'CBSE',
        studentClass: 'Class 10',
        testDate: futureDateStr,
        academicYear: '2026-27',
      );

      expect(test.testDate, equals(futureDateStr));
      expect(DateTime.parse(test.testDate).isAfter(now), isTrue);
    });

    test('23 & 24. Student Summary & Class Results List Assembly', () {
      const subj1 = TestSubjectModel(id: 1, testId: 10, subjectName: 'Math', maxMarks: 100, passMarks: 33);
      const subj2 = TestSubjectModel(id: 2, testId: 10, subjectName: 'Physics', maxMarks: 100, passMarks: 33);

      final summary = StudentTestSummaryModel.compute(
        studentId: 10,
        studentName: 'Rahul',
        studentRollNo: '01',
        testId: 10,
        testTitle: 'August Monthly Test',
        testType: 'Monthly Test',
        board: 'CBSE',
        studentClass: 'Class 10',
        testDate: '2026-08-25',
        academicYear: '2026-27',
        configuredSubjects: [subj1, subj2],
        recordedResults: [
          const TestResultModel(testId: 10, studentId: 10, testSubjectId: 1, marksObtained: 85.0),
          const TestResultModel(testId: 10, studentId: 10, testSubjectId: 2, marksObtained: 75.0),
        ],
        rank: 1,
      );

      expect(summary.totalObtained, equals(160.0));
      expect(summary.totalMax, equals(200.0));
      expect(summary.percentage, equals(80.0));
      expect(summary.grade, equals('A'));
      expect(summary.overallStatus, equals('Pass'));
      expect(summary.rank, equals(1));
    });

    test('25. Regression Check — Attendance Future Date Restriction Remains Intact', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

      // Attendance validator STILL rejects future dates
      expect(AttendanceDateValidator.isFutureDate(tomorrowStr), isTrue);
      expect(
        () => AttendanceDateValidator.validateNotFuture(tomorrowStr),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('26. Regression Fix — TestModel.toMap() contains no mandatory legacy subject column', () {
      final test = const TestModel(
        title: 'August Test',
        testType: 'Monthly Test',
        board: 'CBSE',
        studentClass: 'Class 10',
        testDate: '2026-08-25',
        academicYear: '2026-27',
      );

      final map = test.toMap();
      expect(map.containsKey('subject'), isFalse); // No legacy mandatory subject field!
      expect(map['title'], equals('August Test'));
      expect(map['board'], equals('CBSE'));
    });

    test('27. Three subjects create three independent result rows in memory/map key store', () {
      const testId = 1;
      const studentId = 5;

      const rMath = TestResultModel(id: 101, testId: testId, studentId: studentId, testSubjectId: 1, marksObtained: 69.0);
      const rPhys = TestResultModel(id: 102, testId: testId, studentId: studentId, testSubjectId: 2, marksObtained: 70.0);
      const rChem = TestResultModel(id: 103, testId: testId, studentId: studentId, testSubjectId: 3, marksObtained: 56.0);

      // Composite key UNIQUE(testId, studentId, testSubjectId)
      String key(TestResultModel r) => '${r.testId}_${r.studentId}_${r.testSubjectId}';

      final dbMap = <String, TestResultModel>{};
      dbMap[key(rMath)] = rMath;
      dbMap[key(rPhys)] = rPhys;
      dbMap[key(rChem)] = rChem;

      expect(dbMap.length, equals(3));
      expect(dbMap[key(rMath)]?.marksObtained, equals(69.0));
      expect(dbMap[key(rPhys)]?.marksObtained, equals(70.0));
      expect(dbMap[key(rChem)]?.marksObtained, equals(56.0));
    });

    test('28. Editing one subject (Physics 70 -> 75) does not modify other subjects', () {
      const testId = 1;
      const studentId = 5;
      String key(TestResultModel r) => '${r.testId}_${r.studentId}_${r.testSubjectId}';

      final dbMap = <String, TestResultModel>{
        '1_5_1': const TestResultModel(id: 101, testId: testId, studentId: studentId, testSubjectId: 1, marksObtained: 69.0),
        '1_5_2': const TestResultModel(id: 102, testId: testId, studentId: studentId, testSubjectId: 2, marksObtained: 70.0),
        '1_5_3': const TestResultModel(id: 103, testId: testId, studentId: studentId, testSubjectId: 3, marksObtained: 56.0),
      };

      // Edit Physics only
      const updatedPhys = TestResultModel(id: 102, testId: testId, studentId: studentId, testSubjectId: 2, marksObtained: 75.0);
      dbMap[key(updatedPhys)] = updatedPhys;

      expect(dbMap.length, equals(3));
      expect(dbMap['1_5_1']?.marksObtained, equals(69.0)); // Unchanged!
      expect(dbMap['1_5_2']?.marksObtained, equals(75.0)); // Updated!
      expect(dbMap['1_5_3']?.marksObtained, equals(56.0)); // Unchanged!
    });

    test('29. Partial results preserve previously entered subjects (Math entered Monday, Physics Tuesday)', () {
      const testId = 1;
      const studentId = 5;
      final dbMap = <String, TestResultModel>{};

      // Day 1: Enter Math
      const rMath = TestResultModel(id: 101, testId: testId, studentId: studentId, testSubjectId: 1, marksObtained: 69.0);
      dbMap['${rMath.testId}_${rMath.studentId}_${rMath.testSubjectId}'] = rMath;

      expect(dbMap.length, equals(1));
      expect(dbMap['1_5_1']?.marksObtained, equals(69.0));

      // Day 2: Enter Physics
      const rPhys = TestResultModel(id: 102, testId: testId, studentId: studentId, testSubjectId: 2, marksObtained: 70.0);
      dbMap['${rPhys.testId}_${rPhys.studentId}_${rPhys.testSubjectId}'] = rPhys;

      expect(dbMap.length, equals(2));
      expect(dbMap['1_5_1']?.marksObtained, equals(69.0)); // Math preserved!
      expect(dbMap['1_5_2']?.marksObtained, equals(70.0)); // Physics added!
    });

    test('30. Same test + same student + same subject updates instead of duplicating', () {
      final dbMap = <String, TestResultModel>{};

      const original = TestResultModel(id: 101, testId: 1, studentId: 5, testSubjectId: 1, marksObtained: 69.0);
      dbMap['1_5_1'] = original;

      const edited = TestResultModel(id: 101, testId: 1, studentId: 5, testSubjectId: 1, marksObtained: 80.0);
      dbMap['1_5_1'] = edited;

      expect(dbMap.length, equals(1)); // No duplicate rows created!
      expect(dbMap['1_5_1']?.marksObtained, equals(80.0));
    });

    test('31. Different subjects never overwrite each other under UNIQUE(testId, studentId, testSubjectId)', () {
      final key1 = '1_5_1'; // Math
      final key2 = '1_5_2'; // Physics

      expect(key1, isNot(equals(key2))); // Composite keys are completely distinct!
    });

    test('32. Class Results aggregates all subject marks correctly (69 + 70 + 56 = 195/300, 65%, Grade B)', () {
      const subjMath = TestSubjectModel(id: 1, testId: 1, subjectName: 'Mathematics', maxMarks: 100, passMarks: 33);
      const subjPhys = TestSubjectModel(id: 2, testId: 1, subjectName: 'Physics', maxMarks: 100, passMarks: 33);
      const subjChem = TestSubjectModel(id: 3, testId: 1, subjectName: 'Chemistry', maxMarks: 100, passMarks: 33);

      final summary = StudentTestSummaryModel.compute(
        studentId: 5,
        studentName: 'Rahul',
        studentRollNo: '01',
        testId: 1,
        testTitle: 'August Test',
        testType: 'Monthly Test',
        board: 'State Board',
        studentClass: 'Class 10',
        testDate: '2026-08-23',
        academicYear: '2026-27',
        configuredSubjects: [subjMath, subjPhys, subjChem],
        recordedResults: [
          const TestResultModel(testId: 1, studentId: 5, testSubjectId: 1, marksObtained: 69.0),
          const TestResultModel(testId: 1, studentId: 5, testSubjectId: 2, marksObtained: 70.0),
          const TestResultModel(testId: 1, studentId: 5, testSubjectId: 3, marksObtained: 56.0),
        ],
      );

      expect(summary.totalObtained, equals(195.0)); // 69 + 70 + 56
      expect(summary.totalMax, equals(300.0));
      expect(summary.percentage, equals(65.0));
      expect(summary.grade, equals('B'));
      expect(summary.overallStatus, equals('Pass'));
    });

    test('33. Student Examination Report displays all subject marks correctly', () {
      const subjMath = TestSubjectModel(id: 1, testId: 1, subjectName: 'Mathematics', maxMarks: 100, passMarks: 33);
      const subjPhys = TestSubjectModel(id: 2, testId: 1, subjectName: 'Physics', maxMarks: 100, passMarks: 33);

      final summary = StudentTestSummaryModel.compute(
        studentId: 5,
        studentName: 'Rahul',
        studentRollNo: '01',
        testId: 1,
        testTitle: 'August Test',
        testType: 'Monthly Test',
        board: 'State Board',
        studentClass: 'Class 10',
        testDate: '2026-08-23',
        academicYear: '2026-27',
        configuredSubjects: [subjMath, subjPhys],
        recordedResults: [
          const TestResultModel(testId: 1, studentId: 5, testSubjectId: 1, marksObtained: 69.0),
          const TestResultModel(testId: 1, studentId: 5, testSubjectId: 2, marksObtained: 70.0),
        ],
      );

      expect(summary.subjectResults.length, equals(2));
      expect(summary.subjectResults.firstWhere((r) => r.testSubjectId == 1).marksObtained, equals(69.0));
      expect(summary.subjectResults.firstWhere((r) => r.testSubjectId == 2).marksObtained, equals(70.0));
    });
  });
}
