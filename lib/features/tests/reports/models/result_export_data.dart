import '../../models/student_test_summary_model.dart';
import '../../models/test_model.dart';
import '../../models/test_subject_model.dart';

/// Reusable data structure for Class-wise Result Exports and Individual Report Cards.
///
/// Both class exports and individual report cards extract values from this authoritative structure.
class ClassResultExportData {
  final TestModel test;
  final List<TestSubjectModel> subjects;
  final List<StudentTestSummaryModel> studentSummaries;

  final int totalStudents;
  final int completedCount;
  final int incompleteCount;
  final int passCount;
  final int failCount;
  final double classAvgPct;
  final double highestPct;
  final double lowestPct;

  String get academicYear => test.academicYear;

  ClassResultExportData({
    required this.test,
    required this.subjects,
    required this.studentSummaries,
    required this.totalStudents,
    required this.completedCount,
    required this.incompleteCount,
    required this.passCount,
    required this.failCount,
    required this.classAvgPct,
    required this.highestPct,
    required this.lowestPct,
  });

  factory ClassResultExportData.fromSummaries({
    required TestModel test,
    required List<StudentTestSummaryModel> summaries,
  }) {
    final totalStudents = summaries.length;
    final completedList = summaries.where((s) => s.isComplete).toList();
    final incompleteCount = summaries.where((s) => !s.isComplete).length;
    final passCount = summaries.where((s) => s.overallStatus == 'Pass').length;
    final failCount = summaries.where((s) => s.overallStatus == 'Fail').length;

    final classAvgPct = completedList.isNotEmpty
        ? completedList.fold(0.0, (sum, s) => sum + s.percentage) / completedList.length
        : 0.0;

    final highestPct = completedList.isNotEmpty
        ? completedList.map((s) => s.percentage).reduce((a, b) => a > b ? a : b)
        : 0.0;

    final lowestPct = completedList.isNotEmpty
        ? completedList.map((s) => s.percentage).reduce((a, b) => a < b ? a : b)
        : 0.0;

    return ClassResultExportData(
      test: test,
      subjects: test.subjects,
      studentSummaries: summaries,
      totalStudents: totalStudents,
      completedCount: completedList.length,
      incompleteCount: incompleteCount,
      passCount: passCount,
      failCount: failCount,
      classAvgPct: (classAvgPct * 100).roundToDouble() / 100.0,
      highestPct: (highestPct * 100).roundToDouble() / 100.0,
      lowestPct: (lowestPct * 100).roundToDouble() / 100.0,
    );
  }
}

/// Helper for filesystem-safe filename sanitization
String sanitizeFileName(String input) {
  return input
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
}
