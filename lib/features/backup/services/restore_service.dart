import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../repository/backup_repository.dart';
import 'backup_service.dart';
import 'org_identity_service.dart';

/// Service managing SQL-safe restores, emergency pre-restore checkpoints, version compatibility checks, and rollback recovery.
class RestoreService {
  final BackupService _backupService = BackupService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final OrgIdentityService _orgIdentityService = OrgIdentityService();

  /// Restores a selected backup file.
  /// Generates a mandatory pre-restore emergency checkpoint, shuts down DB, swaps the file, and runs post-restore validation.
  /// Automatically rolls back to the emergency checkpoint on any failure.
  Future<RestoreResult> restoreDatabase(
    String backupPath, {
    String? inputOrgId,
    String? inputRecoveryCode,
  }) async {
    final File backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw Exception('Selected backup file does not exist.');
    }

    final String activeDbPath = join(await getDatabasesPath(), 'omega_education.db');

    // 1. Validate chosen backup
    final backupValidation = await _backupService.validateBackupFile(backupPath);
    if (!backupValidation.isValid) {
      throw Exception('Selected backup file is invalid: ${backupValidation.message}');
    }

    // 2. Database version compatibility check
    const int currentAppDbVersion = 16;
    if (backupValidation.dbVersion > currentAppDbVersion) {
      throw Exception(
        'This backup was created by a newer version of Omega Education Centre ERP (v${backupValidation.dbVersion}) and cannot be restored by this app version (v$currentAppDbVersion).',
      );
    }

    // 3. Credential & Organisation ID verification (if credentials provided)
    if (inputOrgId != null && inputRecoveryCode != null) {
      if (backupValidation.organisationId != null && backupValidation.recoveryCodeHash != null && backupValidation.recoveryCodeSalt != null) {
        final isValidCreds = _orgIdentityService.verifyCredentials(
          inputOrgId: inputOrgId,
          inputRecoveryCode: inputRecoveryCode,
          expectedOrgId: backupValidation.organisationId!,
          storedHash: backupValidation.recoveryCodeHash!,
          storedSalt: backupValidation.recoveryCodeSalt!,
        );

        if (!isValidCreds) {
          throw Exception(
            'Recovery verification failed: Invalid Organisation ID or Recovery Code. The backup does not belong to this organisation or the code is incorrect.',
          );
        }
      }
    }

    // 4. Capture current device Organisation Identity prior to DB swap
    final OrgIdentityData currentDeviceOrg = await _orgIdentityService.getOrCreateOrgIdentity();

    // 5. Create mandatory Emergency Pre-Restore Backup (ZIP format)
    final BackupValidationResult emergencyValidation;
    final String emergencyBackupPath;
    try {
      final emergencyMetadata = await _backupService.createBackup(type: 'pre_restore');
      final Directory backupsDir = await BackupRepository().getBackupsDirectory();
      emergencyBackupPath = join(backupsDir.path, emergencyMetadata.fileName);
      emergencyValidation = await _backupService.validateBackupFile(emergencyBackupPath);
    } catch (e) {
      throw Exception('Restore cancelled because the current database could not be safely backed up: $e');
    }

    if (!emergencyValidation.isValid) {
      throw Exception('Restore cancelled because the current database could not be safely backed up.');
    }

    // 6. Close database safely to swap files
    await _dbHelper.closeDatabase();

    // 7. Replace active database file & restore profile photos
    bool photosRestored = false;
    try {
      photosRestored = await _performExtractRestore(backupPath, activeDbPath);
    } catch (e) {
      await _rollbackToEmergencyBackup(emergencyBackupPath);
      throw Exception('Failed to replace database files. System rolled back to previous state. Error: $e');
    }

    // 8. Reopen database and verify
    try {
      final Database db = await _dbHelper.database;

      // Post-restore validation
      final List<Map<String, dynamic>> integrityRes = await db.rawQuery('PRAGMA integrity_check');
      if (integrityRes.isEmpty || integrityRes.first.values.first != 'ok') {
        throw Exception('Post-restore database integrity check failed.');
      }

      // Verify core tables exist
      final List<Map<String, dynamic>> tablesRes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'android_%' AND name NOT LIKE 'sqlite_%'",
      );
      final Set<String> existingTables = tablesRes.map((row) => row['name'].toString()).toSet();

      for (final String requiredTable in BackupService.coreTables) {
        if (!existingTables.contains(requiredTable)) {
          throw Exception('Post-restore validation failed: missing core table $requiredTable.');
        }
      }

      // 9. Preserve existing device Org ID or set restored Org ID
      if (currentDeviceOrg.organisationId.isNotEmpty) {
        // Keep current device Org ID & salt/hash
        await _orgIdentityService.saveRestoredOrgIdentity(
          orgId: currentDeviceOrg.organisationId,
          orgName: currentDeviceOrg.organisationName,
          recoveryCodeHash: currentDeviceOrg.recoveryCodeHash,
          recoveryCodeSalt: currentDeviceOrg.recoveryCodeSalt,
        );
      } else if (backupValidation.organisationId != null && backupValidation.recoveryCodeHash != null && backupValidation.recoveryCodeSalt != null) {
        // New disaster recovery device: apply restored org settings
        await _orgIdentityService.saveRestoredOrgIdentity(
          orgId: backupValidation.organisationId!,
          orgName: backupValidation.organisationName ?? 'Omega Education Centre',
          recoveryCodeHash: backupValidation.recoveryCodeHash!,
          recoveryCodeSalt: backupValidation.recoveryCodeSalt!,
        );
      }

      // 10. Fetch summary statistics
      final studentCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM students')) ?? 0;
      final teacherCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM teachers')) ?? 0;
      final testCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tests')) ?? 0;
      final resultCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM test_results')) ?? 0;
      final noticeCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM notices')) ?? 0;

      return RestoreResult(
        success: true,
        fileName: basename(backupPath),
        dbVersion: backupValidation.dbVersion,
        message: 'Database restored successfully.',
        studentCount: studentCount,
        teacherCount: teacherCount,
        testCount: testCount,
        resultCount: resultCount,
        noticeCount: noticeCount,
        photosRestored: photosRestored,
      );
    } catch (postRestoreError) {
      try {
        await _rollbackToEmergencyBackup(emergencyBackupPath);
        throw Exception('Restore failed. Your previous database has been restored successfully. Details: $postRestoreError');
      } catch (rollbackError) {
        throw Exception(
          'CRITICAL ERROR: Restore failed, and rollback to emergency backup also failed. Your local database may be corrupt. Details: $rollbackError',
        );
      }
    }
  }

  Future<bool> _performExtractRestore(String backupPath, String activeDbPath) async {
    final File backupFile = File(backupPath);
    bool photosExtracted = false;

    if (backupPath.endsWith('.zip')) {
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Security check: Zip-Slip path traversal protection
      for (final archiveFile in archive) {
        final cleanName = archiveFile.name.replaceAll('\\', '/');
        if (cleanName.contains('..') || cleanName.startsWith('/') || cleanName.contains(':')) {
          throw Exception('Security violation: Malicious path traversal detected in entry "$cleanName".');
        }
      }

      // Clean current profile photos directory before writing restored files
      final appDir = await getApplicationDocumentsDirectory();
      final profilePhotosDir = Directory(join(appDir.path, 'profile_photos'));
      if (await profilePhotosDir.exists()) {
        await profilePhotosDir.delete(recursive: true);
      }

      for (final archiveFile in archive) {
        final cleanName = archiveFile.name.replaceAll('\\', '/');
        final data = archiveFile.content as List<int>;
        if (cleanName == 'omega_education.db') {
          final dbFile = File(activeDbPath);
          await dbFile.writeAsBytes(data);
        } else if (cleanName.startsWith('profile_photos/')) {
          final photoFile = File(join(appDir.path, cleanName));
          await photoFile.create(recursive: true);
          await photoFile.writeAsBytes(data);
          photosExtracted = true;
        }
      }
    } else {
      // Legacy .db file restore
      await backupFile.copy(activeDbPath);
    }

    return photosExtracted;
  }

  Future<void> _rollbackToEmergencyBackup(String emergencyPath) async {
    await _dbHelper.closeDatabase();
    final String activeDbPath = join(await getDatabasesPath(), 'omega_education.db');
    await _performExtractRestore(emergencyPath, activeDbPath);
    await _dbHelper.database;
  }
}

/// Helper container for restore results.
class RestoreResult {
  final bool success;
  final String fileName;
  final int dbVersion;
  final String message;
  final int studentCount;
  final int teacherCount;
  final int testCount;
  final int resultCount;
  final int noticeCount;
  final bool photosRestored;

  RestoreResult({
    required this.success,
    required this.fileName,
    required this.dbVersion,
    required this.message,
    this.studentCount = 0,
    this.teacherCount = 0,
    this.testCount = 0,
    this.resultCount = 0,
    this.noticeCount = 0,
    this.photosRestored = false,
  });
}
