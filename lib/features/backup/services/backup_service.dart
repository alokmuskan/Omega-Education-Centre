import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/backup_metadata_model.dart';
import '../repository/backup_repository.dart';
import 'org_identity_service.dart';

/// Service managing SQL-safe manual and automatic daily backups with integrity verification and retention.
class BackupService {
  final BackupRepository _repository = BackupRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final OrgIdentityService _orgIdentityService = OrgIdentityService();

  // List of authoritative tables from version 16 database schema
  static const List<String> coreTables = [
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
  ];

  /// Creates a safe SQLite database snapshot.
  /// Safely closes connection, copies the file, reopens database, and validates backup before declaring success.
  Future<BackupMetadataModel> createBackup({required String type}) async {
    // 1. Resolve paths
    final String activeDbPath = join(await getDatabasesPath(), 'omega_education.db');
    final File activeDbFile = File(activeDbPath);

    if (!await activeDbFile.exists()) {
      throw Exception('Active database file does not exist at $activeDbPath');
    }

    final Directory backupsDir = await _repository.getBackupsDirectory();
    final DateTime now = DateTime.now();
    final String dateStr = DateFormat('yyyy-MM-dd').format(now);
    final String timeStr = DateFormat('HH-mm-ss').format(now);
    final String backupFileName = 'omega_education_backup_${type}_${dateStr}_$timeStr.zip';
    final String backupPath = join(backupsDir.path, backupFileName);

    // 2. Fetch organisation identity and salted recovery code hash
    final OrgIdentityData orgData = await _orgIdentityService.getOrCreateOrgIdentity();
    final int initialSize = await activeDbFile.length();
    final String nowIso = now.toIso8601String();

    final metadataToEmbed = BackupMetadataModel(
      fileName: backupFileName,
      createdTime: nowIso,
      fileSize: initialSize,
      type: type,
      appVersion: '1.0.0',
      dbVersion: 16,
      validationStatus: 'Healthy',
      organisationId: orgData.organisationId,
      organisationName: orgData.organisationName,
      recoveryCodeHash: orgData.recoveryCodeHash,
      recoveryCodeSalt: orgData.recoveryCodeSalt,
    );

    // 3. Safely close database to flush journal and release lock
    await _dbHelper.closeDatabase();

    // 4. Perform ZIP archiving
    try {
      final archive = Archive();
      
      // Read DB file bytes
      final dbBytes = await activeDbFile.readAsBytes();
      archive.addFile(ArchiveFile('omega_education.db', dbBytes.length, dbBytes));
      
      // Embed backup_metadata.json
      final jsonStr = jsonEncode(metadataToEmbed.toMap());
      final jsonBytes = utf8.encode(jsonStr);
      archive.addFile(ArchiveFile('backup_metadata.json', jsonBytes.length, jsonBytes));

      // Read profile photos recursively
      final appDir = await getApplicationDocumentsDirectory();
      final profilePhotosDir = Directory(join(appDir.path, 'profile_photos'));
      if (await profilePhotosDir.exists()) {
        final List<FileSystemEntity> entities = profilePhotosDir.listSync(recursive: true);
        for (final entity in entities) {
          if (entity is File) {
            final relPath = relative(entity.path, from: appDir.path).replaceAll('\\', '/');
            final fileBytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile(relPath, fileBytes.length, fileBytes));
          }
        }
      }
      
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        throw Exception('Failed to encode ZIP backup archive');
      }
      await File(backupPath).writeAsBytes(zipBytes);
    } finally {
      // Reopen database immediately to minimize down-time
      await _dbHelper.database;
    }

    // 5. Validate the copy
    try {
      final validation = await validateBackupFile(backupPath);
      if (!validation.isValid) {
        final File corruptFile = File(backupPath);
        if (await corruptFile.exists()) {
          await corruptFile.delete();
        }
        throw Exception('Backup validation failed: ${validation.message}');
      }

      // 6. Save companion metadata
      final int finalSize = await File(backupPath).length();
      final finalMetadata = BackupMetadataModel(
        fileName: backupFileName,
        createdTime: nowIso,
        fileSize: finalSize,
        type: type,
        appVersion: '1.0.0',
        dbVersion: validation.dbVersion,
        validationStatus: 'Healthy',
        organisationId: orgData.organisationId,
        organisationName: orgData.organisationName,
        recoveryCodeHash: orgData.recoveryCodeHash,
        recoveryCodeSalt: orgData.recoveryCodeSalt,
      );

      await _repository.saveBackupMetadata(finalMetadata);
      return finalMetadata;
    } catch (e) {
      final File corruptFile = File(backupPath);
      if (await corruptFile.exists()) {
        await corruptFile.delete();
      }
      rethrow;
    }
  }

  /// Validates backup SQLite integrity, zip path traversal security, and verifies core tables.
  Future<BackupValidationResult> validateBackupFile(String filePath) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      return BackupValidationResult(false, 'Backup file does not exist.', -1);
    }

    final int size = await file.length();
    if (size <= 0) {
      return BackupValidationResult(false, 'Backup file is empty (0 bytes).', -1);
    }

    String dbPathToValidate = filePath;
    Directory? tempDir;
    String? orgId;
    String? orgName;
    String? hash;
    String? salt;
    bool hasPhotos = false;
    bool hasMetadata = false;

    if (filePath.endsWith('.zip')) {
      try {
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // Security check: Zip-Slip path traversal vulnerability check
        for (final entry in archive) {
          final cleanName = entry.name.replaceAll('\\', '/');
          if (cleanName.contains('..') || cleanName.startsWith('/') || cleanName.contains(':')) {
            return BackupValidationResult(
              false,
              'Security violation: Malicious path traversal detected in archive entry "${entry.name}".',
              -1,
            );
          }
          if (cleanName.startsWith('profile_photos/')) {
            hasPhotos = true;
          }
        }

        // Search for metadata file inside ZIP
        final metaFileInArchive = archive.where((f) => f.name == 'backup_metadata.json').firstOrNull;
        if (metaFileInArchive != null) {
          try {
            final contentStr = utf8.decode(metaFileInArchive.content as List<int>);
            final metaMap = jsonDecode(contentStr) as Map<String, dynamic>;
            final metaModel = BackupMetadataModel.fromMap(metaMap);
            orgId = metaModel.organisationId;
            orgName = metaModel.organisationName;
            hash = metaModel.recoveryCodeHash;
            salt = metaModel.recoveryCodeSalt;
            hasMetadata = true;
          } catch (_) {}
        }
        
        final dbFileInArchive = archive.firstWhere(
          (f) => f.name == 'omega_education.db',
          orElse: () => throw Exception('omega_education.db not found in backup archive'),
        );
        
        final systemTempDir = Directory.systemTemp;
        tempDir = await systemTempDir.createTemp('omega_backup_validation');
        final tempDbFile = File(join(tempDir.path, 'omega_education.db'));
        await tempDbFile.writeAsBytes(dbFileInArchive.content as List<int>);
        
        dbPathToValidate = tempDbFile.path;
      } catch (e) {
        if (tempDir != null && await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
        return BackupValidationResult(false, 'Failed to extract database from zip backup: $e', -1);
      }
    }

    Database? testDb;
    try {
      testDb = await openDatabase(dbPathToValidate, readOnly: true);

      // 1. Run Integrity Check
      final List<Map<String, dynamic>> integrityRes = await testDb.rawQuery('PRAGMA integrity_check');
      if (integrityRes.isEmpty || integrityRes.first.values.first != 'ok') {
        final String err = integrityRes.isNotEmpty ? integrityRes.first.values.first.toString() : 'unknown';
        return BackupValidationResult(false, 'PRAGMA integrity_check failed: $err', -1);
      }

      // 2. Fetch User Version
      final List<Map<String, dynamic>> versionRes = await testDb.rawQuery('PRAGMA user_version');
      final int dbVersion = versionRes.isNotEmpty ? versionRes.first.values.first as int : -1;

      // Check app_settings table inside backup DB if metadata wasn't in ZIP
      if (orgId == null || hash == null) {
        try {
          final appSettingsRes = await testDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='app_settings'");
          if (appSettingsRes.isNotEmpty) {
            final orgIdRes = await testDb.query('app_settings', columns: ['value'], where: "key = 'org_id'");
            if (orgIdRes.isNotEmpty) orgId = orgIdRes.first['value'] as String?;

            final orgNameRes = await testDb.query('app_settings', columns: ['value'], where: "key = 'org_name'");
            if (orgNameRes.isNotEmpty) orgName = orgNameRes.first['value'] as String?;

            final hashRes = await testDb.query('app_settings', columns: ['value'], where: "key = 'recovery_code_hash'");
            if (hashRes.isNotEmpty) hash = hashRes.first['value'] as String?;

            final saltRes = await testDb.query('app_settings', columns: ['value'], where: "key = 'recovery_code_salt'");
            if (saltRes.isNotEmpty) salt = saltRes.first['value'] as String?;
          }
        } catch (_) {}
      }

      // 3. Verify existence of core tables
      final List<Map<String, dynamic>> tablesRes = await testDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'android_%' AND name NOT LIKE 'sqlite_%'",
      );
      final Set<String> existingTables = tablesRes.map((row) => row['name'].toString()).toSet();

      for (final String requiredTable in coreTables) {
        if (!existingTables.contains(requiredTable)) {
          return BackupValidationResult(
            false,
            'Missing required core table: $requiredTable',
            dbVersion,
            organisationId: orgId,
            organisationName: orgName,
            recoveryCodeHash: hash,
            recoveryCodeSalt: salt,
            hasPhotos: hasPhotos,
            hasMetadata: hasMetadata,
          );
        }
      }

      return BackupValidationResult(
        true,
        'Healthy',
        dbVersion,
        organisationId: orgId,
        organisationName: orgName,
        recoveryCodeHash: hash,
        recoveryCodeSalt: salt,
        hasPhotos: hasPhotos,
        hasMetadata: hasMetadata,
      );
    } catch (e) {
      return BackupValidationResult(
        false,
        'Failed to open backup database: $e',
        -1,
        organisationId: orgId,
        organisationName: orgName,
        recoveryCodeHash: hash,
        recoveryCodeSalt: salt,
        hasPhotos: hasPhotos,
        hasMetadata: hasMetadata,
      );
    } finally {
      if (testDb != null && testDb.isOpen) {
        await testDb.close();
      }
      if (tempDir != null && await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Automatic daily backup on application startup, at most once per calendar day.
  /// Runs asynchronously to avoid blocking app launch.
  Future<void> runAutomaticDailyBackup() async {
    try {
      final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final Directory backupsDir = await _repository.getBackupsDirectory();

      final List<FileSystemEntity> entities = backupsDir.listSync();
      bool backupExists = false;

      for (final FileSystemEntity entity in entities) {
        if (entity is File && (entity.path.endsWith('.db') || entity.path.endsWith('.zip'))) {
          final String baseName = basename(entity.path);
          if (baseName.startsWith('omega_education_backup_automatic_$todayStr')) {
            backupExists = true;
            break;
          }
        }
      }

      if (backupExists) {
        return;
      }

      await createBackup(type: 'automatic');
      await _enforceAutomaticBackupRetention();
    } catch (_) {}
  }

  Future<void> _enforceAutomaticBackupRetention() async {
    try {
      final List<BackupMetadataModel> history = await _repository.getBackupHistory();
      final List<BackupMetadataModel> autoBackups = history.where((b) => b.type == 'automatic').toList();

      if (autoBackups.length > 7) {
        for (int i = 7; i < autoBackups.length; i++) {
          await _repository.deleteBackup(autoBackups[i].fileName);
        }
      }
    } catch (_) {}
  }

  /// Runs SQLite integrity check on the active database.
  Future<bool> checkActiveDatabaseIntegrity() async {
    try {
      final Database db = await _dbHelper.database;
      final List<Map<String, dynamic>> res = await db.rawQuery('PRAGMA integrity_check');
      if (res.isNotEmpty && res.first.values.first == 'ok') {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Helper container for backup validation results.
class BackupValidationResult {
  final bool isValid;
  final String message;
  final int dbVersion;
  final String? organisationId;
  final String? organisationName;
  final String? recoveryCodeHash;
  final String? recoveryCodeSalt;
  final bool hasPhotos;
  final bool hasMetadata;

  BackupValidationResult(
    this.isValid,
    this.message,
    this.dbVersion, {
    this.organisationId,
    this.organisationName,
    this.recoveryCodeHash,
    this.recoveryCodeSalt,
    this.hasPhotos = false,
    this.hasMetadata = false,
  });
}
