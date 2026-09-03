/// Application-wide constants for Omega Education Centre ERP.
///
/// This is the single source of truth for all lists and configuration values
/// used across modules. Updating a value here propagates everywhere — no
/// module-level duplication.
class AppConstants {
  AppConstants._();

  // ── App Info ────────────────────────────────────────────────────────────

  static const String appName = 'Omega Education Centre';
  static const String appVersion = '1.0.0';

  // ── Boards ──────────────────────────────────────────────────────────────

  static const List<String> boards = [
    'CBSE',
    'BSEB',
    'ICSE',
    'Others',
  ];

  static const List<String> boardsWithAll = [
    'All',
    'CBSE',
    'BSEB',
    'ICSE',
    'Others',
  ];

  // ── Classes ─────────────────────────────────────────────────────────────
  // studentClass is stored as TEXT so future values like "Foundation",
  // "Dropper", "Pre-Nursery" require only a constant update — no DB change.

  static const List<String> classes = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
    'Other',
  ];

  static const List<String> classesWithAll = [
    'All',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
    'Other',
  ];

  // ── Fee Status Labels ────────────────────────────────────────────────────
  // These are display-only labels computed from fee_payments.
  // students.feeStatus is a convenience cache — never used for financial math.

  static const String feeStatusPaid = 'Paid';
  static const String feeStatusPartiallyPaid = 'Partially Paid';
  static const String feeStatusDue = 'Due';

  /// Compute display status from paid and total amounts.
  /// This is the authoritative way to determine fee status.
  static String computeFeeStatus(double totalFee, double paidAmount) {
    if (paidAmount <= 0) return feeStatusDue;
    if (paidAmount >= totalFee) return feeStatusPaid;
    return feeStatusPartiallyPaid;
  }

  // ── Attendance Statuses ──────────────────────────────────────────────────

  static const List<String> attendanceStatuses = [
    'Present',
    'Absent',
    'Late',
    'Leave',
  ];

  static const String attendancePresent = 'Present';
  static const String attendanceAbsent = 'Absent';
  static const String attendanceLate = 'Late';
  static const String attendanceLeave = 'Leave';

  /// Maximum upper limit per day for teacher hours worked (to prevent input typos).
  static const double maxTeacherHoursPerDay = 24.0;

  // ── Salary Status Labels ──────────────────────────────────────────────────

  static const String salaryStatusPaid = 'Paid';
  static const String salaryStatusPartiallyPaid = 'Partially Paid';
  static const String salaryStatusUnpaid = 'Unpaid';

  /// Computes teacher salary status from earned salary and total paid amount.
  static String computeSalaryStatus({
    required double earnedSalary,
    required double totalPaid,
  }) {
    if (totalPaid <= 0) return salaryStatusUnpaid;
    if (earnedSalary > 0 && totalPaid >= earnedSalary) return salaryStatusPaid;
    if (earnedSalary <= 0 && totalPaid > 0) return salaryStatusPaid;
    return salaryStatusPartiallyPaid;
  }

  /// Calculates student attendance percentage: (Present + Late) / Total Recorded Days × 100
  /// Policy: Present = 1.0, Late = 1.0, Absent = 0.0, Leave = 0.0 (included in total recorded days).
  static double computeStudentAttendancePercentage({
    required int presentCount,
    required int lateCount,
    required int totalDays,
  }) {
    if (totalDays <= 0) return 0.0;
    final attendedDays = presentCount + lateCount;
    final pct = (attendedDays / totalDays) * 100.0;
    return pct > 100.0 ? 100.0 : (pct < 0.0 ? 0.0 : pct);
  }

  // ── Payment Modes ────────────────────────────────────────────────────────

  static const List<String> paymentModes = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
  ];

  static const String paymentModeCash = 'Cash';

  // ── User Roles ───────────────────────────────────────────────────────────

  static const String roleAdmin = 'Admin';
  static const String roleTeacher = 'Teacher';
  static const String roleStudent = 'Student';

  // ── Grade Thresholds ─────────────────────────────────────────────────────
  // Pass threshold: 35% of maximum marks (configurable here).

  static const double passPercentage = 35.0;

  /// Returns the letter grade for a given percentage score.
  static String getGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 75) return 'A';
    if (percentage >= 60) return 'B';
    if (percentage >= 45) return 'C';
    if (percentage >= 35) return 'D';
    return 'F';
  }

  /// Returns true if the percentage meets the pass threshold.
  static bool isPassed(double percentage) => percentage >= passPercentage;

  // ── Database Table Names ─────────────────────────────────────────────────

  static const String tableStudents = 'students';
  static const String tableTeachers = 'teachers';
  static const String tableTeacherAttendance = 'teacher_attendance';
  static const String tableTeacherPayments = 'teacher_payments';
  static const String tableStudentAttendance = 'student_attendance';
  static const String tableFees = 'fees';
  static const String tableFeePayments = 'fee_payments';
  static const String tableTests = 'tests';
  static const String tableTestResults = 'test_results';
  static const String tableUsers = 'users';

  // ── Subjects (common, extensible) ───────────────────────────────────────

  static const List<String> subjects = [
    'Mathematics',
    'Science',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'Hindi',
    'Social Science',
    'History',
    'Geography',
    'Computer Science',
    'Economics',
    'Accountancy',
    'Business Studies',
    'Other',
  ];

  static const List<String> subjectsWithAll = [
    'All',
    'Mathematics',
    'Science',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'Hindi',
    'Social Science',
    'History',
    'Geography',
    'Computer Science',
    'Economics',
    'Accountancy',
    'Business Studies',
    'Other',
  ];

  // ── Teacher Statuses ─────────────────────────────────────────────────────

  static const String teacherStatusActive = 'Active';
  static const String teacherStatusInactive = 'Inactive';

  static const List<String> teacherStatuses = [
    'Active',
    'Inactive',
  ];

  static const List<String> teacherStatusesWithAll = [
    'All',
    'Active',
    'Inactive',
  ];
}
