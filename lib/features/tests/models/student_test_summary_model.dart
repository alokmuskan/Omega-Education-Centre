import '../services/result_calculation_service.dart';
import 'test_result_model.dart';
import 'test_subject_model.dart';

/// Computed overall test result summary for a student in an examination.
class StudentTestSummaryModel {
  final int studentId;
  final String studentName;
  final String studentRollNo;
  final int testId;
  final String testTitle;
  final String testType;
  final String board;
  final String studentClass;
  final String testDate;
  final String academicYear;
  final String? profilePhotoPath;

  final double totalObtained;
  final double totalMax;
  final double percentage;
  final String grade;
  final String overallStatus; // 'Pass' | 'Fail' | 'Incomplete'
  final int rank; // 0 means unranked / incomplete

  final List<TestResultModel> subjectResults;
  final List<TestSubjectModel> configuredSubjects;

  const StudentTestSummaryModel({
    required this.studentId,
    required this.studentName,
    required this.studentRollNo,
    required this.testId,
    required this.testTitle,
    required this.testType,
    required this.board,
    required this.studentClass,
    required this.testDate,
    required this.academicYear,
    this.profilePhotoPath,
    required this.totalObtained,
    required this.totalMax,
    required this.percentage,
    required this.grade,
    required this.overallStatus,
    required this.rank,
    required this.subjectResults,
    required this.configuredSubjects,
  });

  bool get isComplete => overallStatus != 'Incomplete';

  /// Factory helper to construct summary from configured subjects and student's recorded marks.
  factory StudentTestSummaryModel.compute({
    required int studentId,
    required String studentName,
    required String studentRollNo,
    required int testId,
    required String testTitle,
    required String testType,
    required String board,
    required String studentClass,
    required String testDate,
    required String academicYear,
    String? profilePhotoPath,
    required List<TestSubjectModel> configuredSubjects,
    required List<TestResultModel> recordedResults,
    int rank = 0,
  }) {
    double totalObtained = 0.0;
    double totalMax = 0.0;
    final subjectPassResults = <bool>[];

    for (final subj in configuredSubjects) {
      totalMax += subj.maxMarks;

      final resList = recordedResults.where((r) => r.testSubjectId == subj.id);
      if (resList.isNotEmpty) {
        final res = resList.first;
        totalObtained += res.marksObtained;
        subjectPassResults.add(
          ResultCalculationService.isSubjectPassed(
            marksObtained: res.marksObtained,
            passMarks: subj.passMarks,
          ),
        );
      }
    }

    final overallStatus = ResultCalculationService.computeOverallStatus(
      subjectPassResults: subjectPassResults,
      totalSubjectsConfigured: configuredSubjects.length,
    );

    final percentage = overallStatus == 'Incomplete'
        ? 0.0
        : ResultCalculationService.computePercentage(
            totalObtained: totalObtained,
            totalMax: totalMax,
          );

    final grade = overallStatus == 'Incomplete'
        ? 'N/A'
        : ResultCalculationService.computeGrade(percentage);

    return StudentTestSummaryModel(
      studentId: studentId,
      studentName: studentName,
      studentRollNo: studentRollNo,
      testId: testId,
      testTitle: testTitle,
      testType: testType,
      board: board,
      studentClass: studentClass,
      testDate: testDate,
      academicYear: academicYear,
      profilePhotoPath: profilePhotoPath,
      totalObtained: totalObtained,
      totalMax: totalMax,
      percentage: percentage,
      grade: grade,
      overallStatus: overallStatus,
      rank: rank,
      subjectResults: recordedResults,
      configuredSubjects: configuredSubjects,
    );
  }
}
