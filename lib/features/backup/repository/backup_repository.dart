import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../models/backup_metadata_model.dart';

/// Repository for handling backup files and companion JSON metadata on the local filesystem.
class BackupRepository {
  Future<Directory> getBackupsDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory backupsDir = Directory(join(appDir.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    return backupsDir;
  }

  /// Scans the backups directory and returns list of metadata objects sorted newest first.
  Future<List<BackupMetadataModel>> getBackupHistory() async {
    try {
      final Directory backupsDir = await getBackupsDirectory();
      final List<FileSystemEntity> files = backupsDir.listSync();
      final List<BackupMetadataModel> list = [];

      for (final FileSystemEntity entity in files) {
        if (entity is File && (entity.path.endsWith('.db') || entity.path.endsWith('.zip'))) {
          final String baseName = basename(entity.path);
          final String ext = extension(entity.path);
          final String jsonPath = entity.path.replaceAll(ext, '.json');
          final File jsonFile = File(jsonPath);

          if (await jsonFile.exists()) {
            try {
              final String content = await jsonFile.readAsString();
              final Map<String, dynamic> map = jsonDecode(content) as Map<String, dynamic>;
              list.add(BackupMetadataModel.fromMap(map));
            } catch (_) {
              // Fallback if metadata JSON is corrupt
              final BackupMetadataModel fallback = await _createFallbackMetadata(entity, baseName);
              list.add(fallback);
            }
          } else {
            // Generates metadata by name parsing and file length
            final BackupMetadataModel fallback = await _createFallbackMetadata(entity, baseName);
            list.add(fallback);
          }
        }
      }

      // Sort: Newest first
      list.sort((a, b) => b.createdTime.compareTo(a.createdTime));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<BackupMetadataModel> _createFallbackMetadata(File file, String baseName) async {
    final int size = await file.length();
    String type = 'manual';
    if (baseName.contains('_automatic_')) {
      type = 'automatic';
    } else if (baseName.contains('_pre_restore_')) {
      type = 'pre_restore';
    }

    // Try to parse YYYY-MM-DD_HH-mm-ss from filename
    String createdTime = DateTime.now().toIso8601String();
    final String ext = extension(baseName);
    try {
      final parts = baseName.split('_');
      // Format: omega_education_backup_[type]_YYYY-MM-DD_HH-mm-ss.[ext]
      // Find date string containing '-'
      final datePart = parts.firstWhere((p) => p.split('-').length == 3);
      final index = parts.indexOf(datePart);
      if (index != -1 && index + 1 < parts.length) {
        final timePart = parts[index + 1].replaceAll(ext, '').replaceAll('-', ':');
        createdTime = DateTime.parse('${datePart}T$timePart').toIso8601String();
      }
    } catch (_) {}

    return BackupMetadataModel(
      fileName: baseName,
      createdTime: createdTime,
      fileSize: size,
      type: type,
      appVersion: '1.0.0',
      dbVersion: 16,
      validationStatus: 'Healthy',
    );
  }

  /// Writes the companion JSON file for a given backup.
  Future<void> saveBackupMetadata(BackupMetadataModel metadata) async {
    final Directory backupsDir = await getBackupsDirectory();
    final String ext = extension(metadata.fileName);
    final String jsonPath = join(backupsDir.path, metadata.fileName.replaceAll(ext, '.json'));
    final File jsonFile = File(jsonPath);
    final String content = jsonEncode(metadata.toMap());
    await jsonFile.writeAsString(content);
  }

  /// Deletes a backup database file and its companion metadata JSON file.
  Future<void> deleteBackup(String fileName) async {
    final Directory backupsDir = await getBackupsDirectory();
    final String ext = extension(fileName);
    final File dbFile = File(join(backupsDir.path, fileName));
    final File jsonFile = File(join(backupsDir.path, fileName.replaceAll(ext, '.json')));

    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    if (await jsonFile.exists()) {
      await jsonFile.delete();
    }
  }
}
