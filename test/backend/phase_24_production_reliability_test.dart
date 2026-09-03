import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omega_education_centre/shared/utils/encryption_key_manager.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/features/authentication/repository/auth_repository.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/students/repository/student_repository.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/features/teachers/repository/teacher_repository.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:omega_education_centre/shared/utils/attendance_date_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  EncryptionKeyManager.testMode = true;

  late StudentRepository studentRepo;
  late TeacherRepository teacherRepo;
  late AuthRepository authRepo;

  setUp(() async {
    AppSession.instance.clearSession();
    final db = await DatabaseHelper.instance.database;
    await db.delete('users');
    await db.delete('students');
    await db.delete('teachers');
    await db.delete('notices');
    await db.delete('notice_reads');
    await db.delete('app_settings');

    studentRepo = StudentRepository();
    teacherRepo = TeacherRepository();
    authRepo = AuthRepository();
  });

  group('Phase 24 — Production UX & Reliability Audit Suite', () {
    test('1. Database schema v17 notice column auto-repair verification', () async {
      final db = await DatabaseHelper.instance.database;
      final columnsInfo = await db.rawQuery("PRAGMA table_info(notices)");
      final colNames = columnsInfo.map((c) => (c['name'] as String).toLowerCase()).toSet();

      expect(colNames.contains('targetclass'), isTrue);
      expect(colNames.contains('noticetype'), isTrue);
      expect(colNames.contains('targetrole'), isTrue);
      expect(colNames.contains('targetboard'), isTrue);
      expect(colNames.contains('targetbatch'), isTrue);
      expect(colNames.contains('priority'), isTrue);
      expect(colNames.contains('publishdate'), isTrue);
      expect(colNames.contains('ispublished'), isTrue);
      expect(colNames.contains('isactive'), isTrue);
    });

    test('2. Student search & filter combination & clearing behavior', () async {
      await studentRepo.insertStudent(const StudentModel(
        name: 'Aarav Sharma',
        fatherName: 'Rajesh',
        mobile: '9800000001',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 101,
        createdAt: '2026-08-24T00:00:00Z',
      ));

      await studentRepo.insertStudent(const StudentModel(
        name: 'Bhavya Verma',
        fatherName: 'Suresh',
        mobile: '9800000002',
        board: 'ICSE',
        studentClass: '9',
        rollNo: 102,
        createdAt: '2026-08-24T00:00:00Z',
      ));

      // Filter CBSE
      final cbseList = await studentRepo.searchStudents(board: 'CBSE');
      expect(cbseList.length, equals(1));
      expect(cbseList.first.name, equals('Aarav Sharma'));

      // Filter Class 9
      final class9List = await studentRepo.searchStudents(studentClass: '9');
      expect(class9List.length, equals(1));
      expect(class9List.first.name, equals('Bhavya Verma'));

      // Search text 'Aarav'
      final searchList = await studentRepo.searchStudents(query: 'Aarav');
      expect(searchList.length, equals(1));
      expect(searchList.first.name, equals('Aarav Sharma'));

      // Clear filters (All)
      final allList = await studentRepo.searchStudents();
      expect(allList.length, equals(2));
    });

    test('3. Teacher search & filter combination & status filter', () async {
      await teacherRepo.insertTeacher(TeacherModel(
        name: 'Vikram Singh',
        mobile: '9811111111',
        subject: 'Physics',
        payPerHour: 350,
        joiningDate: '2025-01-01',
        isActive: true,
        createdAt: '2026-08-24T00:00:00Z',
      ));

      await teacherRepo.insertTeacher(TeacherModel(
        name: 'Anjali Gupta',
        mobile: '9822222222',
        subject: 'Chemistry',
        payPerHour: 400,
        joiningDate: '2025-01-01',
        isActive: false,
        createdAt: '2026-08-24T00:00:00Z',
      ));

      final activeList = await teacherRepo.searchTeachers(statusFilter: 'Active');
      expect(activeList.length, equals(1));
      expect(activeList.first.name, equals('Vikram Singh'));

      final inactiveList = await teacherRepo.searchTeachers(statusFilter: 'Inactive');
      expect(inactiveList.length, equals(1));
      expect(inactiveList.first.name, equals('Anjali Gupta'));

      final allList = await teacherRepo.searchTeachers(statusFilter: 'All');
      expect(allList.length, equals(2));
    });

    test('4. Date validator future date & today date formatting check', () {
      final todayStr = AttendanceDateValidator.todayIso;
      expect(todayStr.length, equals(10));
      expect(todayStr.contains('-'), isTrue);

      final futureDate = DateTime.now().add(const Duration(days: 5));
      final futureStr = AttendanceDateValidator.formatDateIso(futureDate);
      expect(AttendanceDateValidator.isFutureDate(futureStr), isTrue);

      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final pastStr = AttendanceDateValidator.formatDateIso(pastDate);
      expect(AttendanceDateValidator.isFutureDate(pastStr), isFalse);
    });

    test('5. Admin-only password reset security enforcement at repository layer', () async {
      final mockTeacher = TeacherModel(
        id: 55,
        name: 'Teacher Security Audit',
        mobile: '9876543210',
        subject: 'Mathematics',
        payPerHour: 300,
        joiningDate: '2025-01-01',
        createdAt: '2026-08-24T00:00:00Z',
      );
      AppSession.instance.setTeacherSession(mockTeacher, username: '9876543210');

      expect(
        () => authRepo.adminResetPassword(
          targetUsername: '9876543210',
          newPassword: 'unauthorizedPassword',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unauthorized'))),
      );

      expect(
        () => authRepo.changePassword(
          username: '9876543210',
          currentPassword: '9876543210',
          newPassword: 'unauthorizedPassword',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unauthorized'))),
      );
    });

    test('6. Student role isolation prevents Teacher/Admin area access', () {
      const mockStudent = StudentModel(
        id: 99,
        name: 'Isolation Student',
        fatherName: 'Father',
        mobile: '9123456789',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 9498,
        createdAt: '2026-08-24T00:00:00Z',
      );
      AppSession.instance.setStudentSession(mockStudent, username: '9498');

      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.isAdmin, isFalse);
      expect(AppSession.instance.currentRole, equals(AppConstants.roleStudent));
    });

    test('7. Offline-first local SQLite database transaction integrity', () async {
      final sId = await studentRepo.insertStudent(const StudentModel(
        name: 'Offline Test Student',
        fatherName: 'Father',
        mobile: '9000000000',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 777,
        createdAt: '2026-08-24T00:00:00Z',
      ));

      final retrieved = await studentRepo.getStudentById(sId);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Offline Test Student'));
      expect(retrieved.rollNo, equals(777));
    });
  });
}
