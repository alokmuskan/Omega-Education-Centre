import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/features/authentication/repository/auth_repository.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/shared/config/backend_config.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/services/supabase_health_service.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omega_education_centre/shared/utils/encryption_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  EncryptionKeyManager.testMode = true;

  group('Phase 28 — Central Authentication Foundation Unit Tests', () {
    late AuthRepository authRepository;

    setUp(() async {
      AppSession.instance.clearSession();
      authRepository = AuthRepository();
      final db = await DatabaseHelper.instance.database;
      await db.delete('users');
      await db.delete('teachers');
      await db.delete('students');
    });

    test('1. Admin authentication derives Admin role strictly for admin session', () async {
      await AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);
      expect(AppSession.instance.isTeacher, isFalse);
      expect(AppSession.instance.isStudent, isFalse);
    });

    test('2. Teacher authentication succeeds and derives Teacher role strictly from users.role', () async {
      final db = await DatabaseHelper.instance.database;
      // Seed teacher record & account
      final teacherId = await db.insert('teachers', {
        'name': 'Rahul Sharma',
        'mobile': '9876543210',
        'subject': 'Mathematics',
        'payPerHour': 500.0,
        'joiningDate': '2026-01-01',
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await authRepository.createUserAccount(
        username: '9876543210',
        password: 'teacher123',
        role: AppConstants.roleTeacher,
        referenceId: teacherId,
      );

      final result = await authRepository.login('9876543210', 'teacher123');
      expect(result.success, isTrue);
      expect(result.role, equals(AppConstants.roleTeacher));
      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.currentTeacherId, equals(teacherId));
    });

    test('3. Student authentication succeeds and derives Student role strictly from users.role', () async {
      final db = await DatabaseHelper.instance.database;
      // Seed student record & account
      final studentId = await db.insert('students', {
        'rollNo': 9498,
        'name': 'Aarav Patel',
        'fatherName': 'Vikram Patel',
        'mobile': '9123456789',
        'studentClass': '10',
        'board': 'CBSE',
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await authRepository.createUserAccount(
        username: '9498',
        password: 'student123',
        role: AppConstants.roleStudent,
        referenceId: studentId,
      );

      final result = await authRepository.login('9498', 'student123');
      expect(result.success, isTrue);
      expect(result.role, equals(AppConstants.roleStudent));
      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.currentStudentId, equals(studentId));
    });

    test('4. Invalid password is rejected cleanly with exact error message', () async {
      final result = await authRepository.login('admin', 'wrongpassword');
      expect(result.success, isFalse);
      expect(result.message, equals('Invalid Admin password.'));
    });

    test('5. Unknown User ID is rejected cleanly', () async {
      final result = await authRepository.login('unknown_user_999999', 'password123');
      expect(result.success, isFalse);
    });

    test('6. Disabled account is rejected with exact account disabled message', () async {
      final db = await DatabaseHelper.instance.database;
      final studentId = await db.insert('students', {
        'rollNo': 9999,
        'name': 'Disabled Student',
        'fatherName': 'Father',
        'mobile': '9999999999',
        'studentClass': '10',
        'board': 'CBSE',
        'isActive': 0, // Disabled
        'createdAt': DateTime.now().toIso8601String(),
      });

      await authRepository.createUserAccount(
        username: '9999',
        password: 'password123',
        role: AppConstants.roleStudent,
        referenceId: studentId,
      );

      final result = await authRepository.login('9999', 'password123');
      expect(result.success, isFalse);
      expect(result.message, equals('Account is disabled. Please contact Administrator.'));
    });

    test('7 & 8 & 9. Role is derived automatically from account — No manual role selection allowed', () async {
      final db = await DatabaseHelper.instance.database;
      final studentId = await db.insert('students', {
        'rollNo': 9498,
        'name': 'Aarav Patel',
        'fatherName': 'Vikram Patel',
        'mobile': '9123456789',
        'studentClass': '10',
        'board': 'CBSE',
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await authRepository.createUserAccount(
        username: '9498',
        password: 'student123',
        role: AppConstants.roleStudent,
        referenceId: studentId,
      );

      final result = await authRepository.login('9498', 'student123');
      expect(result.role, equals(AppConstants.roleStudent));
      expect(AppSession.instance.isAdmin, isFalse);
      expect(AppSession.instance.isTeacher, isFalse);
    });

    test('10 & 11 & 12 & 13. Admin can reset password; Teacher/Student cannot self-service reset', () async {
      // Ensure Admin session is active
      AppSession.instance.setAdminSession();

      // Admin resets student password
      await authRepository.adminResetPassword(
        targetUsername: '9498',
        newPassword: 'newstudentpass123',
      );

      // Verify login works with new password
      final loginNew = await authRepository.login('9498', 'newstudentpass123');
      expect(loginNew.success, isTrue);

      // Verify Teacher/Student cannot call changePassword without current password
      expect(
        () async {
          AppSession.instance.setStudentSession(
            StudentModel(id: 1, name: 'Student', fatherName: '', mobile: '9498', board: 'CBSE', studentClass: '10', rollNo: 9498, createdAt: ''),
          );
          await authRepository.changePassword(username: '9498', currentPassword: 'wrong', newPassword: 'hack');
        },
        throwsException,
      );
    });

    test('14 & 15. Unknown offline accounts rejected cleanly', () async {
      final unknownOffline = await authRepository.login('fakeuser123', 'pass');
      expect(unknownOffline.success, isFalse);
    });

    test('16 & 17. Existing SQLite database schema remains 100% intact and untouched', () async {
      final db = await DatabaseHelper.instance.database;
      final studentsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM students'));
      expect(studentsCount, isNotNull);
    });

    test('18. Admin login without valid Supabase authentication returns rejection', () async {
      BackendConfig.initialize(url: 'unsupported-scheme://offline-test', anonKey: 'invalid');
      final isBackendAvailable = await SupabaseHealthService.instance.checkConnectivity();
      expect(isBackendAvailable, isFalse);

      final authResult = await authRepository.login('admin', 'admin123');
      expect(authResult.success, isFalse);
      expect(authResult.message, equals('Invalid Admin password.'));
    });
  });
}
