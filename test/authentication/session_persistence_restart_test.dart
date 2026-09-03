import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/features/authentication/repository/auth_repository.dart';
import 'package:omega_education_centre/features/dashboard/dashboard_screen.dart';
import 'package:omega_education_centre/features/dashboard/student_dashboard_screen.dart';
import 'package:omega_education_centre/features/dashboard/teacher_dashboard_screen.dart';
import 'package:omega_education_centre/shared/config/backend_config.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omega_education_centre/shared/utils/encryption_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  EncryptionKeyManager.testMode = true;

  group('Session Persistence & Process Termination Unit Tests', () {
    late AuthRepository authRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppSession.instance.clearSession();
      authRepository = AuthRepository();
      final db = await DatabaseHelper.instance.database;
      await db.delete('users');
      await db.delete('teachers');
      await db.delete('students');
    });

    test('1 & 2 & 3. Admin login establishes session correctly', () async {
      await AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);
      expect(AppSession.instance.currentUsername, equals('admin'));
    });

    test('4. Teacher login persists session and restores TeacherDashboardScreen after app restart', () async {
      final db = await DatabaseHelper.instance.database;
      final teacherId = await db.insert('teachers', {
        'name': 'Priya Singh',
        'mobile': '9888877777',
        'subject': 'Physics',
        'payPerHour': 600.0,
        'joiningDate': '2026-01-01',
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await authRepository.createUserAccount(
        username: '9888877777',
        password: 'teacherPass123',
        role: AppConstants.roleTeacher,
        referenceId: teacherId,
      );

      final loginResult = await authRepository.login('9888877777', 'teacherPass123');
      expect(loginResult.success, isTrue);

      // Simulate process termination
      AppSession.instance.resetInMemoryStateForTestOnly();

      // Restore session
      final restoredWidget = await authRepository.restorePersistedSession();
      expect(restoredWidget, isA<TeacherDashboardScreen>());
      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.currentTeacherId, equals(teacherId));
    });

    test('5. Student login persists session and restores StudentDashboardScreen after app restart', () async {
      final db = await DatabaseHelper.instance.database;
      final studentId = await db.insert('students', {
        'rollNo': 8888,
        'name': 'Rohan Das',
        'fatherName': 'Sunil Das',
        'mobile': '9777766666',
        'studentClass': '10',
        'board': 'CBSE',
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await authRepository.createUserAccount(
        username: '8888',
        password: 'studentPass123',
        role: AppConstants.roleStudent,
        referenceId: studentId,
      );

      final loginResult = await authRepository.login('8888', 'studentPass123');
      expect(loginResult.success, isTrue);

      // Simulate process termination
      AppSession.instance.resetInMemoryStateForTestOnly();

      // Restore session
      final restoredWidget = await authRepository.restorePersistedSession();
      expect(restoredWidget, isA<StudentDashboardScreen>());
      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.currentStudentId, equals(studentId));
    });

    test('6 & 7. Explicit logout removes persisted session payload and requires login on restart', () async {
      await AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);

      // Explicit logout
      authRepository.logout();
      expect(AppSession.instance.currentUsername, equals(''));

      // Reopen app -> restoration returns null
      final restoredWidget = await authRepository.restorePersistedSession();
      expect(restoredWidget, isNull);
    });

    test('8. Offline Admin session validation requires Supabase token', () async {
      await AppSession.instance.setAdminSession(username: 'admin');
      AppSession.instance.resetInMemoryStateForTestOnly();

      final restoredWidget = await authRepository.restorePersistedSession();
      expect(restoredWidget, isNull);
    });

    test('9 & 10. Disabled account is rejected on app restart and session is revoked', () async {
      final db = await DatabaseHelper.instance.database;
      final studentId = await db.insert('students', {
        'rollNo': 7777,
        'name': 'Revoked Student',
        'fatherName': 'Father',
        'mobile': '9666655555',
        'studentClass': '10',
        'board': 'CBSE',
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await authRepository.createUserAccount(
        username: '7777',
        password: 'studentPass123',
        role: AppConstants.roleStudent,
        referenceId: studentId,
      );

      await authRepository.login('7777', 'studentPass123');

      // Disable account while user is away
      await db.update(
        'users',
        {'isActive': 0},
        where: 'username = ?',
        whereArgs: ['7777'],
      );

      // Simulate process termination & reopen
      AppSession.instance.resetInMemoryStateForTestOnly();
      final restoredWidget = await authRepository.restorePersistedSession();

      // Session must be rejected and cleared
      expect(restoredWidget, isNull);
      expect(AppSession.instance.currentUsername, equals(''));
    });

    test('11. Zero plaintext passwords or password hashes are saved in SharedPreferences', () async {
      await AppSession.instance.setAdminSession(username: 'admin');
      final prefs = await SharedPreferences.getInstance();

      final username = prefs.getString('app_session_username');
      final role = prefs.getString('app_session_role');

      expect(username, equals('admin'));
      expect(role, equals('Admin'));

      // Verify no password keys exist in SharedPreferences
      expect(prefs.containsKey('password'), isFalse);
      expect(prefs.containsKey('passwordHash'), isFalse);
      expect(prefs.containsKey('admin123'), isFalse);
    });

    test('12. Unknown user in SharedPreferences fails restoration safely', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_session_username', 'non_existent_ghost_user');
      await prefs.setString('app_session_role', 'Admin');

      final restoredWidget = await authRepository.restorePersistedSession();
      expect(restoredWidget, isNull);
    });
  });
}
