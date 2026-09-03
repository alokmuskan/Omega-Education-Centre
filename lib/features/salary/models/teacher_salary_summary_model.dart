import '../../../shared/constants/app_constants.dart';

/// Computed salary summary model for a teacher in a given month.
///
/// Earned Salary = Total Hours Worked × payPerHour.
/// Paid Amount = SUM(teacher_payments.amount for month).
/// Remaining Due = MAX(0, Earned Salary - Paid Amount).
/// Status = 'Unpaid' | 'Partially Paid' | 'Paid'.
class TeacherSalarySummaryModel {
  final int teacherId;
  final String teacherName;
  final String teacherSubject;
  final String teacherMobile;
  final double payPerHour;
  final String month; // 'YYYY-MM'
  final double totalHoursWorked;
  final double earnedSalary;
  final double totalPaid;
  final double remainingDue;
  final String status;
  final bool isActive;

  const TeacherSalarySummaryModel({
    required this.teacherId,
    required this.teacherName,
    required this.teacherSubject,
    required this.teacherMobile,
    required this.payPerHour,
    required this.month,
    required this.totalHoursWorked,
    required this.earnedSalary,
    required this.totalPaid,
    required this.remainingDue,
    required this.status,
    this.isActive = true,
  });

  /// Factory helper to construct summary from total hours, pay rate, and paid amount.
  factory TeacherSalarySummaryModel.compute({
    required int teacherId,
    required String teacherName,
    required String teacherSubject,
    required String teacherMobile,
    required double payPerHour,
    required String month,
    required double totalHoursWorked,
    required double totalPaid,
    double? customEarnedSalary,
    bool isActive = true,
  }) {
    // Round monetary calculation to prevent precision issues
    final rawEarned = customEarnedSalary ?? (totalHoursWorked * payPerHour);
    final earnedSalary = (rawEarned * 100).roundToDouble() / 100.0;
    final roundedPaid = (totalPaid * 100).roundToDouble() / 100.0;

    final rawDue = earnedSalary - roundedPaid;
    final remainingDue = rawDue < 0 ? 0.0 : (rawDue * 100).roundToDouble() / 100.0;

    final status = AppConstants.computeSalaryStatus(
      earnedSalary: earnedSalary,
      totalPaid: roundedPaid,
    );

    return TeacherSalarySummaryModel(
      teacherId: teacherId,
      teacherName: teacherName,
      teacherSubject: teacherSubject,
      teacherMobile: teacherMobile,
      payPerHour: payPerHour,
      month: month,
      totalHoursWorked: totalHoursWorked,
      earnedSalary: earnedSalary,
      totalPaid: roundedPaid,
      remainingDue: remainingDue,
      status: status,
      isActive: isActive,
    );
  }
}
