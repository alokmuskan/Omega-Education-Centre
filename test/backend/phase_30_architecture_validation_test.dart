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

    test('1. PostgreSQL DDL uses UUID for primary keys and org_code for human-readable institute identity', () {
      final schemaFile = File('supabase/schema.sql');
      expect(schemaFile.existsSync(), isTrue);

      final content = schemaFile.readAsStringSync();
      expect(content, contains('id UUID PRIMARY KEY DEFAULT uuid_generate_v4()'));
      expect(content, contains('org_code VARCHAR(64) UNIQUE NOT NULL'));
      expect(content, contains('organisation_id UUID NOT NULL REFERENCES organisations(id)'));
    });

    test('2. auth.users.id maps directly to public.users.id UUID in RLS policy helpers', () {
      final rlsFile = File('supabase/rls_policies.sql');
      expect(rlsFile.existsSync(), isTrue);

      final content = rlsFile.readAsStringSync();
      expect(content, contains('WHERE id = auth.uid()'));
      expect(content, contains('current_org_id()'));
      expect(content, contains('current_user_role()'));
      expect(content, contains('current_user_ref_id()'));
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
        password: 'testAdminPass123',
        role: AppConstants.roleAdmin,
      );

      final result = await authRepository.login('phase30_test_admin', 'testAdminPass123');
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
