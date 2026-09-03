/// Model representing offline backup metadata for Omega ERP.
/// Companion JSON files are stored alongside SQLite .db files to track status.
class BackupMetadataModel {
  final String fileName;
  final String createdTime;
  final int fileSize;
  final String type; // 'manual' | 'automatic' | 'pre_restore'
  final String appVersion;
  final int dbVersion;
  final String validationStatus; // 'Healthy' | 'Corrupted'
  final String? organisationId;
  final String? organisationName;
  final String? recoveryCodeHash;
  final String? recoveryCodeSalt;

  const BackupMetadataModel({
    required this.fileName,
    required this.createdTime,
    required this.fileSize,
    required this.type,
    required this.appVersion,
    required this.dbVersion,
    required this.validationStatus,
    this.organisationId,
    this.organisationName,
    this.recoveryCodeHash,
    this.recoveryCodeSalt,
  });

  String get formattedSize {
    if (fileSize <= 0) return '0 B';
    final double kb = fileSize / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final double mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'createdTime': createdTime,
      'fileSize': fileSize,
      'type': type,
      'appVersion': appVersion,
      'dbVersion': dbVersion,
      'validationStatus': validationStatus,
      'organisationId': organisationId,
      'organisationName': organisationName,
      'recoveryCodeHash': recoveryCodeHash,
      'recoveryCodeSalt': recoveryCodeSalt,
    };
  }

  factory BackupMetadataModel.fromMap(Map<String, dynamic> map) {
    return BackupMetadataModel(
      fileName: map['fileName'] as String,
      createdTime: map['createdTime'] as String,
      fileSize: map['fileSize'] as int,
      type: map['type'] as String? ?? 'manual',
      appVersion: map['appVersion'] as String? ?? '1.0.0',
      dbVersion: map['dbVersion'] as int? ?? 1,
      validationStatus: map['validationStatus'] as String? ?? 'Healthy',
      organisationId: map['organisationId'] as String?,
      organisationName: map['organisationName'] as String?,
      recoveryCodeHash: map['recoveryCodeHash'] as String?,
      recoveryCodeSalt: map['recoveryCodeSalt'] as String?,
    );
  }
}
