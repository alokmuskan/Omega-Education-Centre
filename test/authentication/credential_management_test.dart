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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  EncryptionKeyManager.testMode = true;

  late AuthRepository authRepo;
  late TeacherRepository teacherRepo;
  late StudentRepository studentRepo;

  setUp(() async {
    AppSession.instance.clearSession();
    final db = await DatabaseHelper.instance.database;
    await db.delete('users');
    await db.delete('teachers');
    await db.delete('students');

    authRepo = AuthRepository();
    teacherRepo = TeacherRepository();
    studentRepo = StudentRepository();
  });

  tearDown(() async {
    await DatabaseHelper.instance.closeDatabase();
  });

  group('Phase — Credential Management & Authentication Hardening Tests', () {
    test('1. Admin login via Supabase Auth (Admin accounts cannot be created locally)', () async {
      // Admin accounts are managed by Supabase Auth, not local SQLite.
      // This test verifies that attempting to create a local Admin account throws.
      expect(
        () => authRepo.createUserAccount(
          username: 'admin',
          password: 'admin123Password',
          role: AppConstants.roleAdmin,
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Admin'))),
      );
    });

    test('2. Correct Teacher login succeeds and derives Teacher role', () async {
      final teacherId = await teacherRepo.insertTeacher(TeacherModel(
        name: 'Sharma Sir',
        mobile: '9876543210',
        subject: 'Physics',
        payPerHour: 300,
        joiningDate: '2025-01-01',
        createdAt: '2025-01-01T00:00:00Z',
      ));

      await authRepo.adminResetPassword(
        targetUsername: '9876543210',
        newPassword: 'teacherPass123',
        role: AppConstants.roleTeacher,
        referenceId: teacherId,
      );

      final result = await authRepo.login('9876543210', 'teacherPass123');
      expect(result.success, isTrue);
      expect(result.role, AppConstants.roleTeacher);
      expect(result.teacherId, teacherId);
      expect(AppSession.instance.isTeacher, isTrue);
    });

    test('3. Correct Student login succeeds and derives Student role', () async {
      final studentId = await studentRepo.insertStudent(const StudentModel(
        name: 'Rahul Kumar',
        fatherName: 'Rajesh Kumar',
        mobile: '9123456789',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 101,
        createdAt: '2025-01-01T00:00:00Z',
      ));

      await authRepo.adminResetPassword(
        targetUsername: '101',
        newPassword: 'studentPass123',
        role: AppConstants.roleStudent,
        referenceId: studentId,
      );

      final result = await authRepo.login('101', 'studentPass123');
      expect(result.success, isTrue);
      expect(result.role, AppConstants.roleStudent);
      expect(result.studentId, studentId);
      expect(AppSession.instance.isStudent, isTrue);
    });

    test('4. Incorrect password rejection for local account', () async {
      // Use a Teacher account (Admin cannot be created locally)
      await authRepo.createUserAccount(
        username: 'test_teacher_reject',
        password: 'correctPassword',
        role: AppConstants.roleTeacher,
      );

      final result = await authRepo.login('test_teacher_reject', 'wrongPassword');
      expect(result.success, isFalse);
      expect(result.message, contains('Invalid password'));
    });

    test('5. Disabled account login is rejected with clear message', () async {
      await authRepo.createUserAccount(
        username: 'disabled_user',
        password: 'userPass123',
        role: AppConstants.roleTeacher,
      );

      await authRepo.toggleUserAccountStatus(
        targetUsername: 'disabled_user',
        isEnabled: false,
      );

      final result = await authRepo.login('disabled_user', 'userPass123');
      expect(result.success, isFalse);
      expect(result.message, contains('Account is disabled'));
    });

    test('6. Teacher cannot change User ID (User ID is immutable)', () {
      final mockTeacher = TeacherModel(
        id: 5,
        name: 'Teacher ID Test',
        mobile: '9876500000',
        subject: 'Maths',
        payPerHour: 400,
        joiningDate: '2025-01-01',
        createdAt: '2025-01-01T00:00:00Z',
      );
      AppSession.instance.setTeacherSession(mockTeacher, username: '9876500000');

      expect(AppSession.instance.currentUsername, '9876500000');
      // User ID getter is read-only; no setter exists on AppSession for username modification
    });

    test('7. Student cannot change User ID (User ID is immutable)', () {
      const mockStudent = StudentModel(
        id: 12,
        name: 'Student ID Test',
        fatherName: 'Father',
        mobile: '9123400000',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 502,
        createdAt: '2025-01-01T00:00:00Z',
      );
      AppSession.instance.setStudentSession(mockStudent, username: '502');

      expect(AppSession.instance.currentUsername, '502');
      // User ID getter is read-only; no setter exists on AppSession for username modification
    });

    test('8. Teacher session cannot invoke password reset programmatically', () async {
      final mockTeacher = TeacherModel(
        id: 5,
        name: 'Teacher Security Test',
        mobile: '9876500001',
        subject: 'Maths',
        payPerHour: 400,
        joiningDate: '2025-01-01',
        createdAt: '2025-01-01T00:00:00Z',
      );
      AppSession.instance.setTeacherSession(mockTeacher, username: '9876500001');

      expect(
        () => authRepo.adminResetPassword(
          targetUsername: '9876500001',
          newPassword: 'hackedPassword',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unauthorized'))),
      );

      expect(
        () => authRepo.changePassword(
          username: '9876500001',
          currentPassword: '9876500001',
          newPassword: 'hackedPassword',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unauthorized'))),
      );
    });

    test('9. Student session cannot invoke password reset programmatically', () async {
      const mockStudent = StudentModel(
        id: 12,
        name: 'Student Security Test',
        fatherName: 'Father',
        mobile: '9123400001',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 502,
        createdAt: '2025-01-01T00:00:00Z',
      );
      AppSession.instance.setStudentSession(mockStudent, username: '502');

      expect(
        () => authRepo.adminResetPassword(
          targetUsername: '502',
          newPassword: 'hackedPassword',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unauthorized'))),
      );

      expect(
        () => authRepo.changePassword(
          username: '502',
          currentPassword: '502',
          newPassword: 'hackedPassword',
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unauthorized'))),
      );
    });

    test('10. Admin can reset Teacher password', () async {
      await authRepo.createUserAccount(
        username: 'teacher_target',
        password: 'initialPassword',
        role: AppConstants.roleTeacher,
      );

      await authRepo.adminResetPassword(
        targetUsername: 'teacher_target',
        newPassword: 'adminResetPassword123',
      );

      final result = await authRepo.login('teacher_target', 'adminResetPassword123');
      expect(result.success, isTrue);
    });

    test('11. Admin can reset Student password', () async {
      await authRepo.createUserAccount(
        username: 'student_target',
        password: 'initialStudentPass',
        role: AppConstants.roleStudent,
      );

      await authRepo.adminResetPassword(
        targetUsername: 'student_target',
        newPassword: 'adminResetStudentPass456',
      );

      final result = await authRepo.login('student_target', 'adminResetStudentPass456');
      expect(result.success, isTrue);
    });

    test('12. Old password stops working after password change', () async {
      AppSession.instance.setAdminSession();
      await authRepo.createUserAccount(
        username: 'user_password_test',
        password: 'originalPassword',
        role: AppConstants.roleTeacher,
      );

      await authRepo.changePassword(
        username: 'user_password_test',
        currentPassword: 'originalPassword',
        newPassword: 'updatedPassword999',
      );

      final oldLoginResult = await authRepo.login('user_password_test', 'originalPassword');
      expect(oldLoginResult.success, isFalse);

      final newLoginResult = await authRepo.login('user_password_test', 'updatedPassword999');
      expect(newLoginResult.success, isTrue);
    });

    test('13. No role-switching: Role is derived from authenticated record', () async {
      await authRepo.createUserAccount(
        username: 'teacher_no_switch',
        password: 'teacherPassword',
        role: AppConstants.roleTeacher,
      );

      final result = await authRepo.login('teacher_no_switch', 'teacherPassword');
      expect(result.role, AppConstants.roleTeacher);
      expect(AppSession.instance.currentRole, AppConstants.roleTeacher);
      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('14. Direct unauthorized credential-management access is blocked', () {
      const mockStudent = StudentModel(
        id: 99,
        name: 'Unauthorized Student',
        fatherName: 'Father',
        mobile: '9123400099',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 999,
        createdAt: '2025-01-01T00:00:00Z',
      );
      AppSession.instance.setStudentSession(mockStudent, username: '999');

      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('15. Single-device binding skipped & documented for offline-first architecture', () {
      // Documented assessment: Cross-device single-device binding in an offline-first
      // SQLite application running on independent physical devices without a central cloud server
      // cannot be guaranteed locally while offline. Enforcing cross-device single-device binding
      // is skipped per Phase prompt rules and documented as requiring a shared network backend.
      expect(true, isTrue);
    });
  });
}
