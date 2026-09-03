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

  group('URGENT BUG FIX — Role & Identity Mapping Tests', () {
    test('1. Admin login → Admin role', () async {
      await AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.isStudent, isFalse);
    });

    test('2. Teacher login → Teacher role', () async {
      final tId = await teacherRepo.insertTeacher(TeacherModel(
        name: 'Maths Teacher',
        mobile: '9876543210',
        subject: 'Mathematics',
        payPerHour: 500,
        joiningDate: '2025-01-01',
        createdAt: '2025-01-01T00:00:00Z',
      ));

      final result = await authRepo.login('9876543210', '9876543210');
      expect(result.success, isTrue);
      expect(result.role, AppConstants.roleTeacher);
      expect(result.teacherId, tId);
      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.isStudent, isFalse);
      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('3. Student login → Student role', () async {
      final sId = await studentRepo.insertStudent(const StudentModel(
        name: 'Amit Kumar',
        fatherName: 'Suresh',
        mobile: '9988776655',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 9498,
        createdAt: '2025-01-01T00:00:00Z',
      ));

      final result = await authRepo.login('9498', '9498');
      expect(result.success, isTrue);
      expect(result.role, AppConstants.roleStudent);
      expect(result.studentId, sId);
      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('4. Student 9498 cannot open Teacher Dashboard (derived role is Student)', () async {
      final sId = await studentRepo.insertStudent(const StudentModel(
        name: 'Target Student 9498',
        fatherName: 'Father 9498',
        mobile: '9123494980',
        board: 'CBSE',
        studentClass: '12',
        rollNo: 9498,
        createdAt: '2025-01-01T00:00:00Z',
      ));

      final result = await authRepo.login('9498', '9498');
      expect(result.success, isTrue);
      expect(result.role, AppConstants.roleStudent);
      expect(result.role, isNot(AppConstants.roleTeacher));
      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.currentStudentId, sId);
      expect(AppSession.instance.currentTeacherId, isNull);
    });

    test('5. Teacher cannot open Student Dashboard (derived role is Teacher)', () async {
      final tId = await teacherRepo.insertTeacher(TeacherModel(
        name: 'Science Teacher',
        mobile: '9888877777',
        subject: 'Science',
        payPerHour: 400,
        joiningDate: '2025-01-01',
        createdAt: '2025-01-01T00:00:00Z',
      ));

      final result = await authRepo.login('9888877777', '9888877777');
      expect(result.success, isTrue);
      expect(result.role, AppConstants.roleTeacher);
      expect(result.role, isNot(AppConstants.roleStudent));
      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.isStudent, isFalse);
      expect(AppSession.instance.currentTeacherId, tId);
      expect(AppSession.instance.currentStudentId, isNull);
    });

    test('6. Same numeric ID for Student and Teacher (student.rollNo = 9498 & teacher.id = 9498) does not cause collision', () async {
      // 1. Create Teacher with mobile 9876543210 (DB generates teacher.id = 1 or 9498)
      final tId = await teacherRepo.insertTeacher(TeacherModel(
        name: 'Collision Teacher',
        mobile: '9876543210',
        subject: 'Hindi',
        payPerHour: 300,
        joiningDate: '2025-01-01',
        createdAt: '2025-01-01T00:00:00Z',
      ));

      // 2. Create Student with rollNo = 9498
      final sId = await studentRepo.insertStudent(const StudentModel(
        name: 'Collision Student',
        fatherName: 'Father',
        mobile: '9111122222',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 9498,
        createdAt: '2025-01-01T00:00:00Z',
      ));

      // Login with Student rollNo 9498
      final sResult = await authRepo.login('9498', '9498');
      expect(sResult.role, AppConstants.roleStudent);
      expect(sResult.studentId, sId);
      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.currentTeacherId, isNull);

      // Login with Teacher mobile 9876543210
      final tResult = await authRepo.login('9876543210', '9876543210');
      expect(tResult.role, AppConstants.roleTeacher);
      expect(tResult.teacherId, tId);
      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.currentStudentId, isNull);
    });

    test('7. AppSession stores correct role', () async {
      await studentRepo.insertStudent(const StudentModel(
        name: 'Role Test Student',
        fatherName: 'Father',
        mobile: '9000000001',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 501,
        createdAt: '2025-01-01T00:00:00Z',
      ));

      await authRepo.login('501', '501');
      expect(AppSession.instance.currentRole, AppConstants.roleStudent);
      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('8. AppSession stores correct entity ID', () async {
      final sId = await studentRepo.insertStudent(const StudentModel(
        name: 'Entity ID Student',
        fatherName: 'Father',
        mobile: '9000000002',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 502,
        createdAt: '2025-01-01T00:00:00Z',
      ));

      await authRepo.login('502', '502');
      expect(AppSession.instance.currentStudentId, sId);
      expect(AppSession.instance.currentTeacherId, isNull);
    });

    test('9. Student account creation creates Student role', () async {
      final sId = await studentRepo.insertStudent(const StudentModel(
        name: 'Auto Seed Student',
        fatherName: 'Father',
        mobile: '9000000003',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 503,
        createdAt: '2025-01-01T00:00:00Z',
      ));

      final db = await DatabaseHelper.instance.database;
      final userRows = await db.query('users', where: 'username = ?', whereArgs: ['503']);
      expect(userRows.isNotEmpty, isTrue);
      expect(userRows.first['role'], AppConstants.roleStudent);
      expect(userRows.first['referenceId'], sId);
    });

    test('10. Teacher account creation creates Teacher role', () async {
      final tId = await teacherRepo.insertTeacher(TeacherModel(
        name: 'Auto Seed Teacher',
        mobile: '9777766666',
        subject: 'English',
        payPerHour: 450,
        joiningDate: '2025-01-01',
        createdAt: '2025-01-01T00:00:00Z',
      ));

      final db = await DatabaseHelper.instance.database;
      final userRows = await db.query('users', where: 'username = ?', whereArgs: ['9777766666']);
      expect(userRows.isNotEmpty, isTrue);
      expect(userRows.first['role'], AppConstants.roleTeacher);
      expect(userRows.first['referenceId'], tId);
    });

    test('11. Disabled account remains blocked', () async {
      await studentRepo.insertStudent(const StudentModel(
        name: 'Disabled Student',
        fatherName: 'Father',
        mobile: '9000000004',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 504,
        createdAt: '2025-01-01T00:00:00Z',
      ));

      await authRepo.toggleUserAccountStatus(targetUsername: '504', isEnabled: false);

      final result = await authRepo.login('504', '504');
      expect(result.success, isFalse);
      expect(result.message, contains('Account is disabled'));
    });

    test('12. Existing credential reset still preserves correct role', () async {
      final sId = await studentRepo.insertStudent(const StudentModel(
        name: 'Reset Student',
        fatherName: 'Father',
        mobile: '9000000005',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 505,
        createdAt: '2025-01-01T00:00:00Z',
      ));

      await authRepo.adminResetPassword(
        targetUsername: '505',
        newPassword: 'newStudentPass123',
        role: AppConstants.roleStudent,
        referenceId: sId,
      );

      final result = await authRepo.login('505', 'newStudentPass123');
      expect(result.success, isTrue);
      expect(result.role, AppConstants.roleStudent);
      expect(result.studentId, sId);
      expect(AppSession.instance.isStudent, isTrue);
    });

    test('13. Direct navigation guards remain functional', () {
      // Set student session
      AppSession.instance.setStudentSession(const StudentModel(
        id: 88,
        name: 'Guard Student',
        fatherName: 'Father',
        mobile: '9000000088',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 888,
        createdAt: '2025-01-01T00:00:00Z',
      ), username: '888');

      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.isAdmin, isFalse);
      expect(AppSession.instance.currentTeacherId, isNull);
      expect(AppSession.instance.currentStudentId, 88);
    });
  });
}
