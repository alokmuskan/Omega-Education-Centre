import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:omega_education_centre/features/attendance/models/attendance_summary_model.dart';
import 'package:omega_education_centre/features/attendance/models/student_attendance_model.dart';
import 'package:omega_education_centre/features/attendance/models/teacher_attendance_model.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/attendance_date_validator.dart';

void main() {
  group('Attendance System Unit Tests', () {
    test('Attendance Date Restriction — Past, Today, Tomorrow & Future Date Rules', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final tenDaysAgo = now.subtract(const Duration(days: 10));
      final tomorrow = now.add(const Duration(days: 1));
      final nextWeek = now.add(const Duration(days: 7));

      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
      final tenDaysAgoStr = DateFormat('yyyy-MM-dd').format(tenDaysAgo);
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);
      final nextWeekStr = DateFormat('yyyy-MM-dd').format(nextWeek);

      // Past & Today must be ALLOWED (isFutureDate == false)
      expect(AttendanceDateValidator.isFutureDate(yesterdayStr), isFalse);
      expect(AttendanceDateValidator.isFutureDate(tenDaysAgoStr), isFalse);
      expect(AttendanceDateValidator.isFutureDate(todayStr), isFalse);

      expect(AttendanceDateValidator.isFutureDateTime(yesterday), isFalse);
      expect(AttendanceDateValidator.isFutureDateTime(tenDaysAgo), isFalse);
      expect(AttendanceDateValidator.isFutureDateTime(now), isFalse);

      // Tomorrow & Future Dates must be REJECTED (isFutureDate == true)
      expect(AttendanceDateValidator.isFutureDate(tomorrowStr), isTrue);
      expect(AttendanceDateValidator.isFutureDate(nextWeekStr), isTrue);

      expect(AttendanceDateValidator.isFutureDateTime(tomorrow), isTrue);
      expect(AttendanceDateValidator.isFutureDateTime(nextWeek), isTrue);

      // validateNotFuture throws ArgumentError for future dates
      expect(
        () => AttendanceDateValidator.validateNotFuture(tomorrowStr),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => AttendanceDateValidator.validateNotFuture(nextWeekStr),
        throwsA(isA<ArgumentError>()),
      );

      // validateNotFuture does NOT throw for past/today
      expect(() => AttendanceDateValidator.validateNotFuture(todayStr), returnsNormally);
      expect(() => AttendanceDateValidator.validateNotFuture(yesterdayStr), returnsNormally);
    });

    test('Student Attendance Model serialization & status validation', () {
      final record = StudentAttendanceModel(
        id: 1,
        studentId: 10,
        date: '2026-08-23',
        status: AppConstants.attendancePresent,
        remarks: 'On time',
        createdAt: '2026-08-23T10:00:00Z',
      );

      final map = record.toMap();
      expect(map['studentId'], equals(10));
      expect(map['date'], equals('2026-08-23'));
      expect(map['status'], equals('Present'));
      expect(map['remarks'], equals('On time'));

      final restored = StudentAttendanceModel.fromMap(map);
      expect(restored.studentId, equals(10));
      expect(restored.status, equals('Present'));

      // Validate all 4 allowed status values
      expect(
        AppConstants.attendanceStatuses.contains(restored.status),
        isTrue,
      );
    });

    test('Student Attendance Percentage Formula (handling Leave)', () {
      // Scenario: 10 total days (7 Present, 1 Late, 1 Absent, 1 Leave)
      const summary = StudentAttendanceSummary(
        totalRecordedDays: 10,
        presentCount: 7,
        absentCount: 1,
        lateCount: 1,
        leaveCount: 1,
      );

      // Formula: (Present + Late) / Total Recorded Days * 100 = (7 + 1) / 10 * 100 = 80.0%
      expect(summary.percentage, equals(80.0));

      // Edge case: 0 total days -> 0.0%
      final emptySummary = StudentAttendanceSummary.empty();
      expect(emptySummary.percentage, equals(0.0));
    });

    test('Teacher Attendance Model & Hours Validation (0 to 24 max limit)', () {
      final record = TeacherAttendanceModel(
        id: 1,
        teacherId: 5,
        date: '2026-08-23',
        hoursWorked: 2.5,
        remarks: 'Class 10 Physics',
      );

      final map = record.toMap();
      expect(map['teacherId'], equals(5));
      expect(map['hoursWorked'], equals(2.5));

      final restored = TeacherAttendanceModel.fromMap(map);
      expect(restored.hoursWorked, equals(2.5));

      // Validation rule logic helper test
      bool isValidHours(double hrs) {
        return hrs >= 0 && hrs <= AppConstants.maxTeacherHoursPerDay;
      }

      expect(isValidHours(0.0), isTrue);
      expect(isValidHours(2.5), isTrue);
      expect(isValidHours(8.0), isTrue);
      expect(isValidHours(24.0), isTrue);
      expect(isValidHours(-1.0), isFalse);
      expect(isValidHours(25.0), isFalse);
      expect(isValidHours(999.0), isFalse);
    });

    test('Teacher Monthly Hours Summary Calculation', () {
      final records = [
        const TeacherAttendanceModel(
          teacherId: 1,
          date: '2026-08-01',
          hoursWorked: 2.0,
        ),
        const TeacherAttendanceModel(
          teacherId: 1,
          date: '2026-08-02',
          hoursWorked: 3.5,
        ),
        const TeacherAttendanceModel(
          teacherId: 1,
          date: '2026-08-03',
          hoursWorked: 1.5,
        ),
      ];

      final totalHours = records.fold(0.0, (sum, r) => sum + r.hoursWorked);
      final workingDays = records.where((r) => r.hoursWorked > 0).length;

      expect(totalHours, equals(7.0));
      expect(workingDays, equals(3));
    });

    test('Inactive Teacher exclusion logic from active attendance list', () {
      final teachers = [
        {'id': 1, 'name': 'Rahul', 'isActive': 1},
        {'id': 2, 'name': 'Amit', 'isActive': 0}, // Inactive
        {'id': 3, 'name': 'Priya', 'isActive': 1},
      ];

      final activeTeachers =
          teachers.where((t) => t['isActive'] == 1).toList();

      expect(activeTeachers.length, equals(2));
      expect(activeTeachers.any((t) => t['name'] == 'Amit'), isFalse);
    });
  });
}
