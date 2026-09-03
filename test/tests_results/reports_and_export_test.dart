import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/attendance/models/attendance_summary_model.dart';
import 'package:omega_education_centre/features/tests/models/student_test_summary_model.dart';
import 'package:omega_education_centre/features/tests/models/test_model.dart';
import 'package:omega_education_centre/features/tests/models/test_result_model.dart';
import 'package:omega_education_centre/features/tests/models/test_subject_model.dart';
import 'package:omega_education_centre/features/tests/reports/models/result_export_data.dart';
import 'package:omega_education_centre/features/tests/reports/services/docx_generator_service.dart';
import 'package:omega_education_centre/features/tests/reports/services/excel_generator_service.dart';
import 'package:omega_education_centre/features/tests/reports/services/pdf_generator_service.dart';

void main() {
  group('Phase 6A — Class Results Export & Student Report Card Unit Tests', () {
    final testObj = const TestModel(
      id: 1,
      title: 'August Monthly Test',
      testType: 'Monthly Test',
      board: 'State Board',
      studentClass: 'Class 10',
      testDate: '2026-08-23',
      academicYear: '2026-27',
      subjects: [
        TestSubjectModel(id: 1, testId: 1, subjectName: 'Mathematics', maxMarks: 100, passMarks: 33),
        TestSubjectModel(id: 2, testId: 1, subjectName: 'Physics', maxMarks: 100, passMarks: 33),
        TestSubjectModel(id: 3, testId: 1, subjectName: 'Chemistry', maxMarks: 100, passMarks: 33),
      ],
    );

    final sRahul = StudentTestSummaryModel.compute(
      studentId: 5,
      studentName: 'Rahul Kumar',
      studentRollNo: '12',
      testId: 1,
      testTitle: testObj.title,
      testType: testObj.testType,
      board: testObj.board,
      studentClass: testObj.studentClass,
      testDate: testObj.testDate,
      academicYear: testObj.academicYear,
      configuredSubjects: testObj.subjects,
      recordedResults: [
        const TestResultModel(testId: 1, studentId: 5, testSubjectId: 1, marksObtained: 69.0),
        const TestResultModel(testId: 1, studentId: 5, testSubjectId: 2, marksObtained: 70.0),
        const TestResultModel(testId: 1, studentId: 5, testSubjectId: 3, marksObtained: 56.0),
      ],
      rank: 1,
    );

    final sAman = StudentTestSummaryModel.compute(
      studentId: 6,
      studentName: 'Aman Sharma',
      studentRollNo: '08',
      testId: 1,
      testTitle: testObj.title,
      testType: testObj.testType,
      board: testObj.board,
      studentClass: testObj.studentClass,
      testDate: testObj.testDate,
      academicYear: testObj.academicYear,
      configuredSubjects: testObj.subjects,
      recordedResults: [
        const TestResultModel(testId: 1, studentId: 6, testSubjectId: 1, marksObtained: 85.0),
        const TestResultModel(testId: 1, studentId: 6, testSubjectId: 2, marksObtained: 90.0),
        const TestResultModel(testId: 1, studentId: 6, testSubjectId: 3, marksObtained: 87.0),
      ],
      rank: 2,
    );

    final sIncomplete = StudentTestSummaryModel.compute(
      studentId: 7,
      studentName: 'Pooja Verma',
      studentRollNo: '15',
      testId: 1,
      testTitle: testObj.title,
      testType: testObj.testType,
      board: testObj.board,
      studentClass: testObj.studentClass,
      testDate: testObj.testDate,
      academicYear: testObj.academicYear,
      configuredSubjects: testObj.subjects,
      recordedResults: [
        const TestResultModel(testId: 1, studentId: 7, testSubjectId: 1, marksObtained: 69.0),
        const TestResultModel(testId: 1, studentId: 7, testSubjectId: 3, marksObtained: 56.0),
      ],
      rank: 0,
    );

    test('1. Filename sanitization removes invalid characters correctly', () {
      expect(sanitizeFileName('Rahul/Kumar:Test*1?'), equals('Rahul_Kumar_Test_1_'));
      expect(sanitizeFileName('Class 10\\Math<Test>|'), equals('Class_10_Math_Test__'));
    });

    test('2. ClassResultExportData statistics computation matches Class Results screen', () {
      final exportData = ClassResultExportData.fromSummaries(
        test: testObj,
        summaries: [sRahul, sAman, sIncomplete],
      );

      expect(exportData.totalStudents, equals(3));
      expect(exportData.completedCount, equals(2));
      expect(exportData.incompleteCount, equals(1));
      expect(exportData.passCount, equals(2));
      expect(exportData.failCount, equals(0));
      expect(exportData.highestPct, closeTo(87.33, 0.05));
      expect(exportData.lowestPct, closeTo(65.0, 0.05));
      expect(exportData.classAvgPct, closeTo(76.17, 0.05));
    });

    test('3. Cross-Format Consistency — Rahul (69, 70, 56) totals 195/300, 65%, Grade B, Pass, Rank 1', () {
      expect(sRahul.totalObtained, equals(195.0));
      expect(sRahul.totalMax, equals(300.0));
      expect(sRahul.percentage, equals(65.0));
      expect(sRahul.grade, equals('B'));
      expect(sRahul.overallStatus, equals('Pass'));
      expect(sRahul.rank, equals(1));
    });

    test('4. PDF Class Result generation produces valid non-empty byte buffer', () async {
      final exportData = ClassResultExportData.fromSummaries(
        test: testObj,
        summaries: [sRahul, sAman, sIncomplete],
      );

      final pdfBytes = await PdfGeneratorService.generateClassResultPdf(exportData);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(100));
    });

    test('5. PDF Student Report Card generation produces valid non-empty byte buffer', () async {
      final pdfBytes = await PdfGeneratorService.generateStudentReportCardPdf(sRahul);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(100));
    });

    test('6. Excel (.xlsx) Class Result & Student Report Card generation produces non-empty bytes', () {
      final exportData = ClassResultExportData.fromSummaries(
        test: testObj,
        summaries: [sRahul, sAman],
      );

      final xlsxClassBytes = ExcelGeneratorService.generateClassResultExcel(exportData);
      expect(xlsxClassBytes, isNotNull);
      expect(xlsxClassBytes!.length, greaterThan(100));

      final xlsxStudentBytes = ExcelGeneratorService.generateStudentReportCardExcel(sRahul);
      expect(xlsxStudentBytes, isNotNull);
      expect(xlsxStudentBytes!.length, greaterThan(100));
    });

    test('7. Word (.docx) OpenXML Class Result & Student Report Card generation produces valid zip archive', () {
      final exportData = ClassResultExportData.fromSummaries(
        test: testObj,
        summaries: [sRahul, sAman],
      );

      final docxClassBytes = DocxGeneratorService.generateClassResultDocx(exportData);
      expect(docxClassBytes, isNotNull);
      expect(docxClassBytes.length, greaterThan(100));

      final docxStudentBytes = DocxGeneratorService.generateStudentReportCardDocx(sRahul);
      expect(docxStudentBytes, isNotNull);
      expect(docxStudentBytes.length, greaterThan(100));
    });

    test('8. Different Maximum Marks (Maths=100, Practical=50) computes correct total percentage', () {
      const customSubjs = [
        TestSubjectModel(id: 10, testId: 2, subjectName: 'Mathematics', maxMarks: 100, passMarks: 33),
        TestSubjectModel(id: 11, testId: 2, subjectName: 'Practical', maxMarks: 50, passMarks: 17),
      ];

      final summary = StudentTestSummaryModel.compute(
        studentId: 9,
        studentName: 'Vikram',
        studentRollNo: '03',
        testId: 2,
        testTitle: 'Midterm',
        testType: 'Term Test',
        board: 'CBSE',
        studentClass: 'Class 10',
        testDate: '2026-08-23',
        academicYear: '2026-27',
        configuredSubjects: customSubjs,
        recordedResults: [
          const TestResultModel(testId: 2, studentId: 9, testSubjectId: 10, marksObtained: 80.0),
          const TestResultModel(testId: 2, studentId: 9, testSubjectId: 11, marksObtained: 40.0),
        ],
      );

      expect(summary.totalObtained, equals(120.0));
      expect(summary.totalMax, equals(150.0));
      expect(summary.percentage, equals(80.0));
    });

    test('9. Empty class export produces valid export structure without error', () {
      final exportData = ClassResultExportData.fromSummaries(
        test: testObj,
        summaries: [],
      );

      expect(exportData.totalStudents, equals(0));
      expect(exportData.completedCount, equals(0));
      expect(exportData.classAvgPct, equals(0.0));
    });

    test('10. XML escape helper prevents malformed OpenXML tags for special characters in names', () {
      final escaped = DocxGeneratorService.xmlEscape("Aman & Co. <Students> '100%' \"Pass\"");
      expect(escaped, equals("Aman &amp; Co. &lt;Students&gt; &apos;100%&apos; &quot;Pass&quot;"));
    });

    test('11. Monthly Attendance Report with recorded data computes correct percentage & values', () {
      final attSummary = StudentAttendanceSummary(
        totalRecordedDays: 22,
        presentCount: 18,
        absentCount: 4,
        lateCount: 0,
        leaveCount: 0,
      );

      expect(attSummary.totalRecordedDays, equals(22));
      expect(attSummary.presentCount + attSummary.lateCount, equals(18));
      expect(attSummary.absentCount, equals(4));
      expect(attSummary.percentage, closeTo(81.82, 0.05));
    });

    test('12. Report Card PDF accepts StudentAttendanceSummary & attendanceMonthLabel without errors', () async {
      final attSummary = StudentAttendanceSummary(
        totalRecordedDays: 22,
        presentCount: 18,
        absentCount: 4,
        lateCount: 0,
        leaveCount: 0,
      );

      final pdfBytes = await PdfGeneratorService.generateStudentReportCardPdf(
        sRahul,
        attendanceSummary: attSummary,
        attendanceMonthLabel: 'August 2026',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(100));
    });
  });
}
