import '../../../shared/constants/app_constants.dart';

/// Summary statistics for student attendance over a given timeframe (monthly/student-wise).
class StudentAttendanceSummary {
  final int totalRecordedDays;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;

  const StudentAttendanceSummary({
    required this.totalRecordedDays,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
  });

  /// Percentage calculated using: (Present + Late) / Total Recorded Days × 100
  double get percentage => AppConstants.computeStudentAttendancePercentage(
        presentCount: presentCount,
        lateCount: lateCount,
        totalDays: totalRecordedDays,
      );

  factory StudentAttendanceSummary.empty() => const StudentAttendanceSummary(
        totalRecordedDays: 0,
        presentCount: 0,
        absentCount: 0,
        lateCount: 0,
        leaveCount: 0,
      );
}

/// Summary statistics for teacher attendance over a given timeframe (monthly/teacher-wise).
class TeacherAttendanceSummary {
  final int totalWorkingDays;
  final double totalHoursWorked;

  const TeacherAttendanceSummary({
    required this.totalWorkingDays,
    required this.totalHoursWorked,
  });

  factory TeacherAttendanceSummary.empty() => const TeacherAttendanceSummary(
        totalWorkingDays: 0,
        totalHoursWorked: 0.0,
      );
}
