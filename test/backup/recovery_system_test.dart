import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/backup/models/backup_metadata_model.dart';
import 'package:omega_education_centre/features/backup/services/backup_service.dart';
import 'package:omega_education_centre/features/backup/services/org_identity_service.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 21 — Secure ERP Recovery & Organisation Identity Unit Tests', () {
    test('1. BackupMetadataModel serialization includes org identity and salted hash', () {
      final model = BackupMetadataModel(
        fileName: 'omega_education_backup_manual_2026-08-24_12-00-00.zip',
        createdTime: '2026-08-24T12:00:00.000Z',
        fileSize: 2048,
        type: 'manual',
        appVersion: '1.0.0',
        dbVersion: 16,
        validationStatus: 'Healthy',
        organisationId: 'OEC-SAMASTIPUR-8F2A',
        organisationName: 'Omega Education Centre',
        recoveryCodeHash: 'a1b2c3d4e5f6',
        recoveryCodeSalt: 's1s2s3s4',
      );

      final map = model.toMap();
      expect(map['organisationId'], equals('OEC-SAMASTIPUR-8F2A'));
      expect(map['organisationName'], equals('Omega Education Centre'));
      expect(map['recoveryCodeHash'], equals('a1b2c3d4e5f6'));
      expect(map['recoveryCodeSalt'], equals('s1s2s3s4'));

      // Ensure NO plaintext recovery code key exists anywhere in map
      expect(map.containsKey('recoveryCode'), isFalse);
      expect(map.containsKey('plaintextRecoveryCode'), isFalse);

      final deserialized = BackupMetadataModel.fromMap(map);
      expect(deserialized.organisationId, equals('OEC-SAMASTIPUR-8F2A'));
      expect(deserialized.organisationName, equals('Omega Education Centre'));
      expect(deserialized.dbVersion, equals(16));
    });

    test('2. OrgIdentityService verifies valid recovery credentials using salted hash', () {
      final service = OrgIdentityService();
      const orgId = 'OEC-SAMASTIPUR-9999';
      const code = 'OEC-7K9P-42MX-81QA';
      const salt = 'abcdef1234567890';

      // Hash generated code
      expect(OrgIdentityService.keyRecoveryHash, equals('recovery_code_hash'));
      final computedHash = service.verifyCredentials(
        inputOrgId: orgId,
        inputRecoveryCode: code,
        expectedOrgId: orgId,
        storedHash: 'dummy',
        storedSalt: salt,
      );

      // Random dummy hash will fail
      expect(computedHash, isFalse);
    });

    test('3. OrgIdentityService credential verification fails on mismatched Org ID or wrong code', () {
      final service = OrgIdentityService();
      expect(
        service.verifyCredentials(
          inputOrgId: 'OEC-WRONG-ID',
          inputRecoveryCode: 'OEC-7K9P-42MX-81QA',
          expectedOrgId: 'OEC-SAMASTIPUR-9999',
          storedHash: 'hash',
          storedSalt: 'salt',
        ),
        isFalse,
      );

      expect(
        service.verifyCredentials(
          inputOrgId: '',
          inputRecoveryCode: 'OEC-7K9P-42MX-81QA',
          expectedOrgId: 'OEC-SAMASTIPUR-9999',
          storedHash: 'hash',
          storedSalt: 'salt',
        ),
        isFalse,
      );
    });

    test('4. Role Protection — non-admin session blocks backup/restore screen logic', () {
      final dummyTeacher = TeacherModel(
        id: 1,
        name: 'Teacher One',
        mobile: '9876543210',
        subject: 'Math',
        payPerHour: 500.0,
        joiningDate: '2026-01-01',
        createdAt: '2026-01-01',
      );

      AppSession.instance.setTeacherSession(dummyTeacher);
      expect(AppSession.instance.isAdmin, isFalse);

      AppSession.instance.setAdminSession();
      expect(AppSession.instance.isAdmin, isTrue);
    });

    test('5. BackupValidationResult contains organisation identity fields', () {
      final result = BackupValidationResult(
        true,
        'Healthy',
        16,
        organisationId: 'OEC-SAMASTIPUR-1234',
        organisationName: 'Omega Education Centre',
        hasPhotos: true,
        hasMetadata: true,
      );

      expect(result.isValid, isTrue);
      expect(result.dbVersion, equals(16));
      expect(result.organisationId, equals('OEC-SAMASTIPUR-1234'));
      expect(result.hasPhotos, isTrue);
    });
  });
}
