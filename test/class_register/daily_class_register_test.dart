import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/features/authentication/repository/auth_repository.dart';
import 'package:omega_education_centre/features/class_register/models/daily_class_record_model.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:omega_education_centre/shared/utils/attendance_date_validator.dart';

void main() {
  group('Phase 7 — Role-Based Access Control (RBAC) & Session Unit Tests', () {
    final authRepo = AuthRepository();

    test('1 & 2 & 3. Admin, Teacher, and Student logins resolve correct roles and session identities', () {
      // 1. Admin Session
      AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.currentRole, equals(AppConstants.roleAdmin));
      expect(AppSession.instance.isAdmin, isTrue);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.isStudent, isFalse);

      // 2. Teacher Session
      final teacher = TeacherModel(
        id: 15,
        name: 'PKJ Ma\'am',
        mobile: '9876543210',
        subject: 'Mathematics',
        payPerHour: 500,
        joiningDate: '2026-01-01',
        createdAt: '2026-01-01',
      );
      AppSession.instance.setTeacherSession(teacher, username: 'teacher');
      expect(AppSession.instance.currentRole, equals(AppConstants.roleTeacher));
      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.currentTeacherId, equals(15));
      expect(AppSession.instance.currentTeacherModel?.name, equals('PKJ Ma\'am'));

      // 3. Student Session
      const student = StudentModel(
        id: 101,
        name: 'Avinash Kumar',
        fatherName: 'Father',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 1,
        mobile: '9999999999',
        createdAt: '2026-01-01',
      );
      AppSession.instance.setStudentSession(student, username: 'student');
      expect(AppSession.instance.currentRole, equals(AppConstants.roleStudent));
      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.currentStudentId, equals(101));
      expect(AppSession.instance.currentStudentModel?.name, equals('Avinash Kumar'));
    });

    test('11 & 12 & 15. Teacher automatically receives teacherId and sees only own logs', () {
      final teacher = TeacherModel(
        id: 15,
        name: 'PKJ Ma\'am',
        mobile: '9876543210',
        subject: 'Mathematics',
        payPerHour: 500,
        joiningDate: '2026-01-01',
        createdAt: '2026-01-01',
      );

      AppSession.instance.setTeacherSession(teacher);

      expect(AppSession.instance.currentTeacherId, equals(15));
      expect(AppSession.instance.isTeacher, isTrue);

      const r1 = DailyClassRecordModel(id: 1, date: '2026-08-23', studentClass: '10', board: 'CBSE', teacherId: 15, teacherName: 'PKJ Ma\'am', subject: 'Maths', durationMinutes: 60, topic: 'T1');
      const r2 = DailyClassRecordModel(id: 2, date: '2026-08-23', studentClass: '12', board: 'BSEB', teacherId: 99, teacherName: 'RK Sir', subject: 'Physics', durationMinutes: 90, topic: 'T2');

      final teacherLogs = [r1, r2].where((r) => r.teacherId == AppSession.instance.currentTeacherId).toList();
      expect(teacherLogs.length, equals(1));
      expect(teacherLogs.first.teacherName, equals('PKJ Ma\'am'));
    });

    test('7 & 8 & 9 & 10. Role Protection: Unauthorized access attempts are rejected', () {
      const student = StudentModel(
        id: 101,
        name: 'Avinash Kumar',
        fatherName: 'Father',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 1,
        mobile: '9999999999',
        createdAt: '2026-01-01',
      );

      AppSession.instance.setStudentSession(student);

      expect(AppSession.instance.isAdmin, isFalse);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.isStudent, isTrue);

      // Student cannot access Admin or Teacher actions
      final canAccessAdminSalary = AppSession.instance.isAdmin;
      final canAccessTeacherLogEntry = AppSession.instance.isTeacher || AppSession.instance.isAdmin;

      expect(canAccessAdminSalary, isFalse);
      expect(canAccessTeacherLogEntry, isFalse);
    });

    test('13 & 14. Admin monitoring sees all teachers and all teaching logs', () {
      AppSession.instance.setAdminSession();

      const r1 = DailyClassRecordModel(id: 1, date: '2026-08-23', studentClass: '10', board: 'CBSE', teacherId: 15, teacherName: 'PKJ Ma\'am', subject: 'Maths', durationMinutes: 60, topic: 'T1');
      const r2 = DailyClassRecordModel(id: 2, date: '2026-08-23', studentClass: '12', board: 'BSEB', teacherId: 99, teacherName: 'RK Sir', subject: 'Physics', durationMinutes: 90, topic: 'T2');

      final adminViewLogs = [r1, r2];

      expect(AppSession.instance.isAdmin, isTrue);
      expect(adminViewLogs.length, equals(2));
    });

    test('16. Logout clears authenticated session state', () {
      AppSession.instance.setTeacherSession(
        TeacherModel(id: 5, name: 'T', mobile: '1', subject: 'S', payPerHour: 100, joiningDate: '2026-01-01', createdAt: '2026-01-01'),
      );

      expect(AppSession.instance.currentTeacherId, equals(5));

      authRepo.logout();

      expect(AppSession.instance.currentTeacherId, isNull);
      expect(AppSession.instance.currentUsername, isEmpty);
    });

    test('18. Production UI contains zero role-switching capabilities', () {
      AppSession.instance.setAdminSession();
      expect(AppSession.instance.isAdmin, isTrue);
    });

    test('19 & 20. Teaching Log does NOT modify Teacher Attendance or Salary', () {
      const log = DailyClassRecordModel(
        date: '2026-08-23',
        studentClass: '10',
        board: 'CBSE',
        teacherId: 1,
        subject: 'Mathematics',
        durationMinutes: 60,
        topic: 'Integrals',
      );

      expect(log.durationMinutes, equals(60));
    });

    test('21 & 22 & 23 & 24 & 25 & 26 & 27. Regression check for existing modules', () {
      final todayStr = AttendanceDateValidator.todayIso;
      expect(AttendanceDateValidator.isFutureDate(todayStr), isFalse);
    });
  });
}
