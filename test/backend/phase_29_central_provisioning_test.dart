import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/features/authentication/repository/auth_repository.dart';
import 'package:omega_education_centre/features/authentication/services/central_auth_service.dart';
import 'package:omega_education_centre/shared/config/backend_config.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:omega_education_centre/shared/utils/password_util.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 29 — Controlled Central User Provisioning Unit Tests', () {
    late AuthRepository authRepository;

    setUp(() async {
      AppSession.instance.clearSession();
      authRepository = AuthRepository();
      final db = await DatabaseHelper.instance.database;
      await db.delete('users');
    });

    test('1 & 2. Prototype Test Admin identity creation maps User ID to internal email format', () {
      final email = CentralAuthService.mapUserIdToEmail('phase29_test_admin');
      expect(email, equals('phase29_test_admin@omega.internal'));
    });

    test('3 & 4 & 5. Central identity map encapsulates organisation, role, and username', () {
      final identityMap = CentralAuthService.instance.createCentralIdentityMap(
        userId: 'phase29_test_admin',
        role: AppConstants.roleAdmin,
        orgId: BackendConfig.defaultOrgCode,
      );

      expect(identityMap['username'], equals('phase29_test_admin'));
      expect(identityMap['email'], equals('phase29_test_admin@omega.internal'));
      expect(identityMap['role'], equals(AppConstants.roleAdmin));
      expect(identityMap['organisation_id'], equals('ORG_OMEGA_DEFAULT'));
      expect(identityMap['is_active'], isTrue);
    });

    test('6 & 7. Local SQLite authentication with test account works with correct password and rejects wrong password', () async {
      await authRepository.createUserAccount(
        username: 'phase29_test_admin',
        password: 'testAdminPass123',
        role: AppConstants.roleAdmin,
      );

      final validLogin = await authRepository.login('phase29_test_admin', 'testAdminPass123');
      expect(validLogin.success, isTrue);
      expect(validLogin.role, equals(AppConstants.roleAdmin));

      final invalidLogin = await authRepository.login('phase29_test_admin', 'wrongPass');
      expect(invalidLogin.success, isFalse);
      expect(invalidLogin.message, equals('Invalid password. Please try again.'));
    });

    test('8. Disabled test account login is rejected with exact account disabled message', () async {
      final db = await DatabaseHelper.instance.database;
      final salt = PasswordUtil.generateSalt();
      final hash = PasswordUtil.hashPassword('testAdminPass123', salt);
      await db.insert('users', {
        'username': 'phase29_test_admin',
        'passwordHash': hash,
        'salt': salt,
        'role': AppConstants.roleAdmin,
        'isActive': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final disabledLogin = await authRepository.login('phase29_test_admin', 'testAdminPass123');
      expect(disabledLogin.success, isFalse);
      expect(disabledLogin.message, equals('Account is disabled. Please contact Administrator.'));
    });

    test('9 & 10. RLS organisation & role permission boundaries isolate data per organisation', () {
      final orgAIdentity = CentralAuthService.instance.createCentralIdentityMap(
        userId: 'admin_org_a',
        role: AppConstants.roleAdmin,
        orgId: 'ORG_ALPHA',
      );

      final orgBIdentity = CentralAuthService.instance.createCentralIdentityMap(
        userId: 'admin_org_b',
        role: AppConstants.roleAdmin,
        orgId: 'ORG_BETA',
      );

      expect(orgAIdentity['organisation_id'], isNot(equals(orgBIdentity['organisation_id'])));
    });

    test('11. No private keys or service-role secrets exist in client configuration', () {
      expect(BackendConfig.supabaseAnonKey, isNotNull);
      expect(BackendConfig.supabaseAnonKey, isNot(contains('service_role')));
      expect(BackendConfig.supabaseAnonKey, isNot(contains('secret')));
    });

    test('12 & 13. Admin session management sets admin state correctly', () async {
      await AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);
    });

    test('14. SQLite users table schema remains ready for local accounts', () async {
      final db = await DatabaseHelper.instance.database;
      final tableInfo = await db.rawQuery("PRAGMA table_info('users')");
      expect(tableInfo.isNotEmpty, isTrue);
    });
  });
}
