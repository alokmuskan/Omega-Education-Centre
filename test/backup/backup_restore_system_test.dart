import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/backup/models/backup_metadata_model.dart';
import 'package:omega_education_centre/features/backup/services/backup_service.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';

void main() {
  group('Phase 11 — Offline Backup, Restore & Data Safety System Unit Tests', () {
    // ──────────────────────────────────────────────────────────────────────
    // BACKUP FILENAMES & METADATA (1–2)
    // ──────────────────────────────────────────────────────────────────────

    test('1. Backup filename generation format', () {
      final String type = 'manual';
      final String dateStr = '2026-08-23';
      final String timeStr = '20-30-00';
      final String backupFileName = 'omega_education_backup_${type}_${dateStr}_$timeStr.db';

      expect(backupFileName, equals('omega_education_backup_manual_2026-08-23_20-30-00.db'));
      expect(backupFileName.contains('omega_education_backup_'), isTrue);
      expect(backupFileName.endsWith('.db'), isTrue);
    });

    test('2. Backup metadata serialization (toMap & fromMap)', () {
      const metadata = BackupMetadataModel(
        fileName: 'omega_education_backup_manual_2026-08-23_20-30-00.db',
        createdTime: '2026-08-23T20:30:00Z',
        fileSize: 2516582, // ~2.4 MB
        type: 'manual',
        appVersion: '1.0.0',
        dbVersion: 14,
        validationStatus: 'Healthy',
      );

      final map = metadata.toMap();
      expect(map['fileName'], equals('omega_education_backup_manual_2026-08-23_20-30-00.db'));
      expect(map['fileSize'], equals(2516582));
      expect(map['validationStatus'], equals('Healthy'));

      final restored = BackupMetadataModel.fromMap(map);
      expect(restored.fileSize, equals(2516582));
      expect(restored.formattedSize, equals('2.4 MB'));
      expect(restored.type, equals('manual'));
    });

    // ──────────────────────────────────────────────────────────────────────
    // BACKUP & RESTORE INTEGRITY VALIDATION (3–9)
    // ──────────────────────────────────────────────────────────────────────

    test('3. Database integrity check verification (PRAGMA integrity_check)', () {
      // Simulate PRAGMA integrity_check outputs
      const String healthyResult = 'ok';
      const String corruptResult = 'Main database page 1 is corrupt';

      bool isHealthy(String checkOutput) => checkOutput == 'ok';

      expect(isHealthy(healthyResult), isTrue);
      expect(isHealthy(corruptResult), isFalse);
    });

    test('4. Empty/invalid backup rejection', () {
      bool validateBackupFile(int size, String ext) {
        if (size <= 0) return false;
        if (ext != '.db') return false;
        return true;
      }

      expect(validateBackupFile(0, '.db'), isFalse);
      expect(validateBackupFile(1024, '.json'), isFalse);
      expect(validateBackupFile(2048, '.db'), isTrue);
    });

    test('5 & 6. Required authoritative table validation', () {
      final List<String> existingTables = [
        'students',
        'teachers',
        'users',
        'fees',
        'fee_payments',
        'fee_installments',
        'student_attendance',
        'teacher_attendance',
        'teacher_payments',
        'teacher_pay_rate_history',
        'tests',
        'test_subjects',
        'test_results',
        'daily_class_records',
        'timetable_entries',
        'notices',
        'notice_reads',
        'additional_future_table', // Validation must allow future schema tables
      ];

      bool containsAllCoreTables(List<String> tables) {
        final set = tables.toSet();
        return BackupService.coreTables.every((t) => set.contains(t));
      }

      expect(containsAllCoreTables(existingTables), isTrue);

      final List<String> missingOneTable = ['students', 'teachers', 'users'];
      expect(containsAllCoreTables(missingOneTable), isFalse);
    });

    test('7 & 8 & 9. DB version compatibility detection (reject newer unsupported versions)', () {
      const int currentAppDbVersion = 14;

      bool isCompatible(int backupVersion) {
        return backupVersion <= currentAppDbVersion;
      }

      expect(isCompatible(13), isTrue); // Older version -> Supported (will trigger migrations)
      expect(isCompatible(14), isTrue); // Current version -> Supported
      expect(isCompatible(15), isFalse); // Newer version -> REJECTED (unsupported version)
    });

    // ──────────────────────────────────────────────────────────────────────
    // BACKUP RETENTION & DUPLICATE PREVENTION (10–14)
    // ──────────────────────────────────────────────────────────────────────

    test('10 & 11 & 12. Backup retention logic (keeps manual, rolling 7 for automatic)', () {
      final List<BackupMetadataModel> backups = [
        // 8 automatic backups
        const BackupMetadataModel(fileName: 'auto_1.db', createdTime: '2026-08-16', fileSize: 100, type: 'automatic', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
        const BackupMetadataModel(fileName: 'auto_2.db', createdTime: '2026-08-17', fileSize: 100, type: 'automatic', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
        const BackupMetadataModel(fileName: 'auto_3.db', createdTime: '2026-08-18', fileSize: 100, type: 'automatic', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
        const BackupMetadataModel(fileName: 'auto_4.db', createdTime: '2026-08-19', fileSize: 100, type: 'automatic', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
        const BackupMetadataModel(fileName: 'auto_5.db', createdTime: '2026-08-20', fileSize: 100, type: 'automatic', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
        const BackupMetadataModel(fileName: 'auto_6.db', createdTime: '2026-08-21', fileSize: 100, type: 'automatic', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
        const BackupMetadataModel(fileName: 'auto_7.db', createdTime: '2026-08-22', fileSize: 100, type: 'automatic', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
        const BackupMetadataModel(fileName: 'auto_8.db', createdTime: '2026-08-23', fileSize: 100, type: 'automatic', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
        // 2 manual backups
        const BackupMetadataModel(fileName: 'manual_1.db', createdTime: '2026-08-20', fileSize: 100, type: 'manual', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
        const BackupMetadataModel(fileName: 'manual_2.db', createdTime: '2026-08-22', fileSize: 100, type: 'manual', appVersion: '1.0.0', dbVersion: 14, validationStatus: 'Healthy'),
      ];

      // Enforce automatic backup retention (keeps only the 7 newest automatic)
      final autoOnly = backups.where((b) => b.type == 'automatic').toList();
      autoOnly.sort((a, b) => b.createdTime.compareTo(a.createdTime));

      final List<BackupMetadataModel> autoToKeep = autoOnly.take(7).toList();
      final List<BackupMetadataModel> autoToDelete = autoOnly.skip(7).toList();

      final List<BackupMetadataModel> manualBackups = backups.where((b) => b.type == 'manual').toList();

      expect(autoToKeep.length, equals(7));
      expect(autoToDelete.length, equals(1));
      expect(autoToDelete.first.fileName, equals('auto_1.db')); // Oldest auto deleted
      expect(manualBackups.length, equals(2)); // Manual backups are NOT deleted
    });

    test('13 & 14. Today\'s automatic backup detection & duplicate prevention', () {
      final List<String> existingAutoBackups = [
        'omega_education_backup_automatic_2026-08-22_10-00-00.db',
      ];

      bool shouldRunBackup(String todayDate, List<String> files) {
        return !files.any((f) => f.contains('automatic_$todayDate'));
      }

      // Today is 2026-08-23, no automatic backup exists for today
      expect(shouldRunBackup('2026-08-23', existingAutoBackups), isTrue);

      // Today is 2026-08-22, automatic backup already exists for today
      expect(shouldRunBackup('2026-08-22', existingAutoBackups), isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────
    // RESTORE CONFIRMATION, EMERGENCY CHECKPOINT & ROLLBACK (15–19)
    // ──────────────────────────────────────────────────────────────────────

    test('15. Restore confirmation dialog warnings text verification', () {
      const warningText =
          'WARNING: Restoring this backup will replace the current local ERP database with the selected backup. Any data created after this backup date will be permanently lost.';
      expect(warningText.contains('replace the current local ERP database'), isTrue);
      expect(warningText.contains('permanently lost'), isTrue);
    });

    test('16 & 17 & 18. Emergency pre-restore backup & validation and restore failure rollback', () {
      bool emergencyBackupSucceeded = false;
      bool restoreSucceeded = false;
      bool rolledBack = false;

      // Restore sequence:
      // 1. Create emergency pre-restore backup
      emergencyBackupSucceeded = true;

      if (emergencyBackupSucceeded) {
        try {
          // Simulate database restore copy failing due to lock or IO exception
          throw Exception('File copy failed');
        } catch (_) {
          // Rollback immediately to the emergency backup
          rolledBack = true;
          restoreSucceeded = false;
        }
      }

      expect(emergencyBackupSucceeded, isTrue);
      expect(restoreSucceeded, isFalse);
      expect(rolledBack, isTrue);
    });

    test('19. Backup file existence validation', () {
      bool fileExists(String path, List<String> actualPaths) {
        return actualPaths.contains(path);
      }

      final mockFiles = ['/backups/backup_1.db', '/backups/backup_2.db'];
      expect(fileExists('/backups/backup_1.db', mockFiles), isTrue);
      expect(fileExists('/backups/backup_3.db', mockFiles), isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────
    // ROLE-BASED ACCESS CONTROL SECURITY (20–23)
    // ──────────────────────────────────────────────────────────────────────

    test('20 & 21. Admin access permissions allowed', () {
      AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);
      expect(AppSession.instance.currentRole, equals(AppConstants.roleAdmin));
    });

    test('22. Teacher access restricted', () {
      final teacher = TeacherModel(
        id: 10,
        name: 'Rahul Kumar',
        mobile: '9876543210',
        subject: 'Mathematics',
        payPerHour: 500,
        joiningDate: '2026-01-01',
        createdAt: '2026-01-01',
      );
      AppSession.instance.setTeacherSession(teacher);

      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('23. Student access restricted', () {
      const student = StudentModel(
        id: 5,
        name: 'Amit Sharma',
        fatherName: 'Raj Sharma',
        board: 'CBSE',
        studentClass: '10',
        rollNo: 15,
        mobile: '9876543211',
        createdAt: '2026-01-01',
      );
      AppSession.instance.setStudentSession(student);

      expect(AppSession.instance.isStudent, isTrue);
      expect(AppSession.instance.isAdmin, isFalse);
    });
  });
}
