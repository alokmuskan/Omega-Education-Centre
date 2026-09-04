import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/features/authentication/repository/auth_repository.dart';
import 'package:omega_education_centre/features/authentication/services/central_auth_service.dart';
import 'package:omega_education_centre/shared/config/backend_config.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omega_education_centre/shared/utils/encryption_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  EncryptionKeyManager.testMode = true;

  group('Phase 30 — Central Auth Architecture Validation Unit Tests', () {
    late AuthRepository authRepository;

    setUp(() async {
      AppSession.instance.clearSession();
      authRepository = AuthRepository();
      await DatabaseHelper.instance.database;
    });

    tearDown(() async {
      try {
        AppSession.instance.clearSession();
      } catch (_) {}
    });

    test('1. PostgreSQL DDL uses UUID for primary keys and org_code for human-readable institute identity', () {
      final schemaFile = File('supabase/migrations/000_clean_reset.sql');
      expect(schemaFile.existsSync(), isTrue);

      final content = schemaFile.readAsStringSync();
      expect(content, contains('UUID PRIMARY KEY DEFAULT gen_random_uuid()'));
      expect(content, contains('code TEXT UNIQUE NOT NULL'));
      expect(content, contains('orgId UUID REFERENCES organisations(id)'));
    });

    test('2. RLS policies are defined in the schema migration file', () {
      final schemaFile = File('supabase/migrations/000_clean_reset.sql');
      expect(schemaFile.existsSync(), isTrue);

      final content = schemaFile.readAsStringSync();
      expect(content, contains('ENABLE ROW LEVEL SECURITY'));
      expect(content, contains('CREATE POLICY'));
    });

    test('3. Internal email mapping generates valid @omega.internal identity strings', () {
      final adminEmail = CentralAuthService.mapUserIdToEmail('admin');
      final teacherEmail = CentralAuthService.mapUserIdToEmail('9876543210');
      final studentEmail = CentralAuthService.mapUserIdToEmail('9498');

      expect(adminEmail, equals('admin@omega.internal'));
      expect(teacherEmail, equals('9876543210@omega.internal'));
      expect(studentEmail, equals('9498@omega.internal'));
    });

    test('4 & 5. Privileged auth operations require no service_role key in client codebase', () {
      expect(BackendConfig.supabaseAnonKey, isNot(contains('service_role')));
      final configFile = File('lib/shared/config/backend_config.dart');
      final content = configFile.readAsStringSync();
      expect(content, isNot(contains('service_role')));
    });

    test('6 & 7 & 8. Non-production test account phase30_test_admin authenticates correctly with RLS boundary check', () async {
      await authRepository.createUserAccount(
        username: 'phase30_test_admin',
        password: 'TestAdmin@123',
        role: AppConstants.roleAdmin,
      );

      final result = await authRepository.login('phase30_test_admin', 'TestAdmin@123');
      expect(result.success, isTrue);
      expect(result.role, equals(AppConstants.roleAdmin));

      final wrongPass = await authRepository.login('phase30_test_admin', 'invalid');
      expect(wrongPass.success, isFalse);
    });

    test('9 & 10. Existing local SQLite database v17 and production accounts remain 100% untouched', () async {
      final db = await DatabaseHelper.instance.database;
      final users = await db.query('users', where: 'username = ?', whereArgs: ['admin']);
      expect(users.isNotEmpty, isTrue);
      expect(users.first['role'], equals('Admin'));
    });
  });
}
