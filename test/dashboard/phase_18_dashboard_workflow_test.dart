import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/features/dashboard/dashboard_screen.dart';
import 'package:omega_education_centre/features/dashboard/teacher_dashboard_screen.dart';
import 'package:omega_education_centre/features/dashboard/student_dashboard_screen.dart';

import 'package:omega_education_centre/features/attendance/screens/attendance_main_screen.dart';
import 'package:omega_education_centre/features/attendance/screens/student_attendance_history_screen.dart';
import 'package:omega_education_centre/features/attendance/screens/teacher_attendance_history_screen.dart';

import 'package:omega_education_centre/features/class_register/screens/daily_class_register_main_screen.dart';
import 'package:omega_education_centre/features/class_register/screens/add_edit_class_record_screen.dart';
import 'package:omega_education_centre/features/class_register/models/daily_class_record_model.dart';

import 'package:omega_education_centre/features/students/screens/student_screen.dart';
import 'package:omega_education_centre/features/students/screens/student_details_screen.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';

import 'package:omega_education_centre/features/teachers/screens/teacher_screen.dart';
import 'package:omega_education_centre/features/teachers/screens/teacher_details_screen.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';

import 'package:omega_education_centre/features/fees/screens/admin_fee_dashboard_screen.dart';
import 'package:omega_education_centre/features/fees/screens/student_fee_details_screen.dart';

import 'package:omega_education_centre/features/salary/screens/salary_dashboard_screen.dart';
import 'package:omega_education_centre/features/salary/screens/teacher_payment_history_screen.dart';

import 'package:omega_education_centre/features/tests/screens/tests_main_screen.dart';
import 'package:omega_education_centre/features/tests/screens/student_result_history_screen.dart';
import 'package:omega_education_centre/features/tests/screens/test_result_details_screen.dart';
import 'package:omega_education_centre/features/tests/models/student_test_summary_model.dart';

import 'package:omega_education_centre/features/backup/screens/backup_restore_screen.dart';
import 'package:omega_education_centre/features/notices/screens/add_edit_notice_screen.dart';
import 'package:omega_education_centre/features/notices/screens/notice_read_status_screen.dart';
import 'package:omega_education_centre/features/notices/models/notice_model.dart';

import 'package:omega_education_centre/shared/utils/app_session.dart';

void main() {
  group('Phase 18 — Role-Specific Dashboards & Operational Workflows Tests', () {
    const studentMe = StudentModel(
      id: 101,
      name: 'Aarav Sharma',
      fatherName: 'Rajesh Sharma',
      board: 'CBSE',
      studentClass: '10',
      rollNo: 1,
      mobile: '9876543210',
      isActive: true,
      createdAt: '2026-08-01T00:00:00Z',
    );

    const studentOther = StudentModel(
      id: 102,
      name: 'Vihaan Patel',
      fatherName: 'Dev Patel',
      board: 'CBSE',
      studentClass: '10',
      rollNo: 2,
      mobile: '9876543212',
      isActive: true,
      createdAt: '2026-08-01T00:00:00Z',
    );

    final teacherMe = TeacherModel(
      id: 201,
      name: 'Sunita Rao',
      subject: 'Mathematics',
      mobile: '9876543210',
      payPerHour: 500.0,
      isActive: true,
      joiningDate: '2026-08-01',
      createdAt: '2026-08-01T00:00:00Z',
    );

    final teacherOther = TeacherModel(
      id: 202,
      name: 'Rohan Deshmukh',
      subject: 'Science',
      mobile: '9876543211',
      payPerHour: 600.0,
      isActive: true,
      joiningDate: '2026-08-01',
      createdAt: '2026-08-01T00:00:00Z',
    );

    const mockNotice = NoticeModel(
      id: 1,
      title: 'Holiday Notice',
      message: 'Happy holidays!',
      noticeType: 'Holiday',
      targetRole: 'Everyone',
      publishDate: '2026-08-20',
      priority: 'Normal',
      isPublished: true,
      isActive: true,
    );

    testWidgets('1. Admin Dashboard — Deny Access for non-Admins', (WidgetTester tester) async {
      AppSession.instance.setTeacherSession(teacherMe);
      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      expect(find.textContaining('Access Denied'), findsWidgets);

      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('2. Teacher Dashboard — Deny Access for non-Teachers', (WidgetTester tester) async {
      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(const MaterialApp(home: TeacherDashboardScreen()));
      expect(find.textContaining('Access Denied'), findsWidgets);

      AppSession.instance.setAdminSession();
      await tester.pumpWidget(const MaterialApp(home: TeacherDashboardScreen()));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('3. Student Dashboard — Deny Access for non-Students', (WidgetTester tester) async {
      AppSession.instance.setTeacherSession(teacherMe);
      await tester.pumpWidget(const MaterialApp(home: StudentDashboardScreen()));
      expect(find.textContaining('Access Denied'), findsWidgets);

      AppSession.instance.setAdminSession();
      await tester.pumpWidget(const MaterialApp(home: StudentDashboardScreen()));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('4. Admin-Only screens — Direct Navigation Guards blocking Teacher & Student', (WidgetTester tester) async {
      final screens = [
        const StudentScreen(),
        const TeacherScreen(),
        const AttendanceMainScreen(),
        const TestsMainScreen(),
        const SalaryDashboardScreen(),
        const AdminFeeDashboardScreen(),
        const BackupRestoreScreen(),
        const AddEditNoticeScreen(),
        const NoticeReadStatusScreen(notice: mockNotice),
      ];

      AppSession.instance.setStudentSession(studentMe);
      for (final s in screens) {
        await tester.pumpWidget(MaterialApp(home: s));
        expect(find.textContaining('Access Denied'), findsWidgets);
      }

      AppSession.instance.setTeacherSession(teacherMe);
      for (final s in screens) {
        await tester.pumpWidget(MaterialApp(home: s));
        expect(find.textContaining('Access Denied'), findsWidgets);
      }
    });

    testWidgets('5. Attendance Screens — Role Guards', (WidgetTester tester) async {
      // Student Attendance History Screen: Student Me cannot view studentOther
      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(const MaterialApp(
        home: StudentAttendanceHistoryScreen(initialStudentId: 102),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);

      // Teacher Attendance History Screen: Teacher Me cannot view teacherOther
      AppSession.instance.setTeacherSession(teacherMe);
      await tester.pumpWidget(const MaterialApp(
        home: TeacherAttendanceHistoryScreen(initialTeacherId: 202),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('6. Class Register Screens — Role Guards', (WidgetTester tester) async {
      // DailyClassRegisterMainScreen: Reject Student
      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(const MaterialApp(
        home: DailyClassRegisterMainScreen(),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);

      // DailyClassRegisterMainScreen: Reject Teacher initialTeacherId mismatch
      AppSession.instance.setTeacherSession(teacherMe);
      await tester.pumpWidget(const MaterialApp(
        home: DailyClassRegisterMainScreen(initialTeacherId: 202),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);

      // AddEditClassRecordScreen: Reject Student
      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(const MaterialApp(
        home: AddEditClassRecordScreen(),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);

      // AddEditClassRecordScreen: Reject Teacher editing another teacher's record
      AppSession.instance.setTeacherSession(teacherMe);
      const recordOther = DailyClassRecordModel(
        id: 50,
        date: '2026-08-20',
        studentClass: '10',
        board: 'CBSE',
        teacherId: 202,
        subject: 'Science',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        durationMinutes: 60,
        topic: 'Gravity',
      );
      await tester.pumpWidget(const MaterialApp(
        home: AddEditClassRecordScreen(initialRecord: recordOther),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('7. StudentDetailsScreen — Identity Guard', (WidgetTester tester) async {
      // Student Me cannot view studentOther details
      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(const MaterialApp(
        home: StudentDetailsScreen(student: studentOther),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('8. StudentFeeDetailsScreen — Teacher block & Student Isolation', (WidgetTester tester) async {
      // Block Teacher
      AppSession.instance.setTeacherSession(teacherMe);
      await tester.pumpWidget(const MaterialApp(
        home: StudentFeeDetailsScreen(studentId: 101),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);

      // Reject Student other fees
      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(const MaterialApp(
        home: StudentFeeDetailsScreen(studentId: 102, isStudentView: true),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('9. StudentResultHistoryScreen — Student Isolation', (WidgetTester tester) async {
      // Reject other results
      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(const MaterialApp(
        home: StudentResultHistoryScreen(studentId: 102),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('10. TestResultDetailsScreen — Student Isolation', (WidgetTester tester) async {
      AppSession.instance.setStudentSession(studentMe);

      const summaryOther = StudentTestSummaryModel(
        studentId: 102,
        studentName: 'Vihaan Patel',
        studentRollNo: '2',
        testId: 5,
        testTitle: 'Unit Test 1',
        testType: 'Unit Test',
        board: 'CBSE',
        studentClass: '10',
        testDate: '2026-08-20',
        academicYear: '2026-2027',
        configuredSubjects: [],
        subjectResults: [],
        totalObtained: 90.0,
        totalMax: 100.0,
        percentage: 90.0,
        grade: 'A',
        overallStatus: 'Pass',
        rank: 1,
      );

      // Reject other detail report card
      await tester.pumpWidget(const MaterialApp(
        home: TestResultDetailsScreen(summary: summaryOther),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('11. TeacherDetailsScreen — Student Block & Teacher Isolation', (WidgetTester tester) async {
      // Block student
      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(MaterialApp(
        home: TeacherDetailsScreen(teacher: teacherMe),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);

      // Reject other teacher details
      AppSession.instance.setTeacherSession(teacherMe);
      await tester.pumpWidget(MaterialApp(
        home: TeacherDetailsScreen(teacher: teacherOther),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });

    testWidgets('12. TeacherPaymentHistoryScreen — Student Block & Teacher Isolation', (WidgetTester tester) async {
      // Block student
      AppSession.instance.setStudentSession(studentMe);
      await tester.pumpWidget(const MaterialApp(
        home: TeacherPaymentHistoryScreen(initialTeacherId: 201),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);

      // Reject other teacher payment history
      AppSession.instance.setTeacherSession(teacherMe);
      await tester.pumpWidget(const MaterialApp(
        home: TeacherPaymentHistoryScreen(initialTeacherId: 202),
      ));
      expect(find.textContaining('Access Denied'), findsWidgets);
    });
  });
}
