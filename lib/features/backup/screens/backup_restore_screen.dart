import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../shared/utils/app_session.dart';
import '../models/backup_metadata_model.dart';
import '../repository/backup_repository.dart';
import '../services/backup_service.dart';
import '../services/org_identity_service.dart';
import '../services/restore_service.dart';

/// Role-gated Admin screen for Manual Backups, Restores, Sharing, Database Integrity checks, and history log.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupRepository _repository = BackupRepository();
  final BackupService _backupService = BackupService();
  final RestoreService _restoreService = RestoreService();
  final OrgIdentityService _orgIdentityService = OrgIdentityService();

  List<BackupMetadataModel> _history = [];
  OrgIdentityData? _orgIdentity;
  bool _isLoading = true;
  bool _isWorking = false; // blocks UI double-tapping during backup/restore
  String _workingMessage = '';

  bool _dbHealthy = true;
  String _lastBackupTime = 'No backup available';
  String _lastBackupStatus = 'Healthy';

  @override
  void initState() {
    super.initState();
    _loadBackupState();
  }

  Future<void> _loadBackupState() async {
    setState(() => _isLoading = true);
    try {
      final healthy = await _backupService.checkActiveDatabaseIntegrity();
      final list = await _repository.getBackupHistory();
      final orgData = await _orgIdentityService.getOrCreateOrgIdentity();

      String lastTime = 'No backup available';
      String lastStatus = 'Healthy';

      if (list.isNotEmpty) {
        final newest = list.firstWhere(
          (b) => b.type != 'pre_restore',
          orElse: () => list.first,
        );
        final dt = DateTime.parse(newest.createdTime);
        lastTime = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
        lastStatus = newest.validationStatus;
      }

      if (!mounted) return;
      setState(() {
        _dbHealthy = healthy;
        _history = list;
        _orgIdentity = orgData;
        _lastBackupTime = lastTime;
        _lastBackupStatus = lastStatus;
        _isLoading = false;
      });

      // If a brand-new recovery code was generated on first setup/upgrade, present it once to the Admin
      if (orgData.newlyGeneratedCode != null) {
        _showNewlyGeneratedCodeDialog(orgData.newlyGeneratedCode!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dbHealthy = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _backupNow() async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _workingMessage = 'Creating database backup...';
    });

    try {
      await _backupService.createBackup(type: 'manual');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual backup created successfully!'), backgroundColor: Colors.green),
      );
      await _loadBackupState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _checkIntegrity() async {
    if (_isWorking) return;
    setState(() {
      _isWorking = true;
      _workingMessage = 'Executing database integrity check...';
    });

    final healthy = await _backupService.checkActiveDatabaseIntegrity();

    if (!mounted) return;
    setState(() {
      _dbHealthy = healthy;
      _isWorking = false;
    });

    if (healthy) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Integrity Check'),
            ],
          ),
          content: const Text('Database Integrity: Healthy\nNo issues or corruption detected.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Integrity Check'),
            ],
          ),
          content: const Text(
            'Database Integrity: Problems detected!\nDatabase file may be corrupted or locked. Please backup and seek developer review.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _validateBackup(BackupMetadataModel backup) async {
    final Directory backupsDir = await _repository.getBackupsDirectory();
    final String path = p.join(backupsDir.path, backup.fileName);

    final res = await _backupService.validateBackupFile(path);
    if (!mounted) return;
    if (res.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup file is healthy. Version: v${res.dbVersion}'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Validation failed: ${res.message}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _shareBackup(BackupMetadataModel backup) async {
    final Directory backupsDir = await _repository.getBackupsDirectory();
    final String path = p.join(backupsDir.path, backup.fileName);
    final File file = File(path);

    if (await file.exists()) {
      await Share.shareXFiles([XFile(path)], text: 'Omega ERP Backup: ${backup.fileName}');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup file does not exist.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmRestore(BackupMetadataModel backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Restore'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WARNING: Restoring this backup will replace the current local ERP database with the selected backup.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Any data created or modified after this backup date will be permanently lost.'),
            const SizedBox(height: 14),
            Text('Backup File: ${backup.fileName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Database'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      _executeRestore(backup);
    }
  }

  Future<void> _executeRestore(BackupMetadataModel backup) async {
    setState(() {
      _isWorking = true;
      _workingMessage = 'Restoring database backup...\nAn emergency checkpoint backup is being created.';
    });

    try {
      final Directory backupsDir = await _repository.getBackupsDirectory();
      final String path = p.join(backupsDir.path, backup.fileName);

      final res = await _restoreService.restoreDatabase(path);

      if (!mounted) return;
      if (res.success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Restore Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Database restored successfully.'),
                const SizedBox(height: 10),
                Text('Backup: ${res.fileName}'),
                Text('Database Version: v${res.dbVersion}'),
                const Text('Integrity: Healthy'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Refresh screen
                  _loadBackupState();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Restore Failed'),
            ],
          ),
          content: Text(e.toString().replaceAll('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _confirmDelete(BackupMetadataModel backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Are you sure you want to permanently delete this backup file? (${backup.fileName})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      await _repository.deleteBackup(backup.fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup file deleted.')),
      );
      _loadBackupState();
    }
  }

  void _showNewlyGeneratedCodeDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Disaster Recovery Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A Disaster Recovery Code has been generated for your ERP installation.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Keep this recovery code safe. It is required to restore your ERP on a new device if your phone is lost or damaged.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SelectableText(
                    code,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.indigo),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recovery code copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Security Notice: This code is NOT stored as plaintext anywhere on your phone or backups.',
              style: TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Have Saved This Code'),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateRecoveryCode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Regenerate Recovery Code'),
          ],
        ),
        content: const Text(
          'Regenerating will invalidate your previous recovery code. Make sure to save the new code securely.\n\nDo you want to proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate New Code'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final newCode = await _orgIdentityService.regenerateRecoveryCode();
      if (!mounted) return;
      _showNewlyGeneratedCodeDialog(newCode);
      _loadBackupState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to regenerate code: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importExternalBackup() async {
    if (_isWorking) return;

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'db'],
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) return;
      final String path = result.files.first.path!;

      setState(() {
        _isWorking = true;
        _workingMessage = 'Validating external backup file...';
      });

      final validation = await _backupService.validateBackupFile(path);

      if (!mounted) return;
      setState(() => _isWorking = false);

      if (!validation.isValid) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Backup Invalid'),
              ],
            ),
            content: Text(validation.message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return;
      }

      // Confirm restore
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Import External Backup'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WARNING: Restoring this external backup file will replace the current local database on this device.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 12),
              Text('Organisation: ${validation.organisationName ?? "Omega Education Centre"}'),
              Text('Organisation ID: ${validation.organisationId ?? "Legacy Backup"}'),
              Text('Database Version: v${validation.dbVersion}'),
              Text('File: ${p.basename(path)}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import & Restore'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      setState(() {
        _isWorking = true;
        _workingMessage = 'Importing and restoring backup...\nCreating emergency checkpoint...';
      });

      final res = await _restoreService.restoreDatabase(path);

      if (!mounted) return;
      setState(() => _isWorking = false);

      if (res.success) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Import Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('External backup restored successfully.'),
                const SizedBox(height: 10),
                Text('File: ${res.fileName}'),
                Text('Students: ${res.studentCount}'),
                Text('Teachers: ${res.teacherCount}'),
                Text('Tests: ${res.testCount}'),
                Text('Notices: ${res.noticeCount}'),
                Text('Profile Photos: ${res.photosRestored ? "Restored" : "Up to date"}'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadBackupState();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.instance.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gpp_bad, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only logged-in administrators/directors are authorized to access database backup and restore features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Organisation Identity Card
                      _buildOrgIdentityCard(),

                      const SizedBox(height: 16),

                      // Database Status Header Card
                      _buildDbStatusCard(),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _isWorking ? null : _backupNow,
                              icon: const Icon(Icons.backup),
                              label: const Text('Backup Now', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _isWorking ? null : _importExternalBackup,
                              icon: const Icon(Icons.file_download),
                              label: const Text('Import Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Automatic Backup Status Banner
                      _buildAutoBackupBanner(),

                      const SizedBox(height: 24),

                      // History Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Backup History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Chip(
                            label: Text('${_history.length} Files'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (_history.isEmpty)
                        Card(
                          color: Colors.grey.shade50,
                          child: const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('No local backups found. Trigger "Backup Now" above.'),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final b = _history[index];
                            return _buildBackupHistoryCard(b);
                          },
                        ),

                      const SizedBox(height: 20),

                      // Bottom actions
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _isWorking ? null : _checkIntegrity,
                          icon: const Icon(Icons.analytics),
                          label: const Text('Check Database Integrity'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

          // Working Spinner overlay
          if (_isWorking)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _workingMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrgIdentityCard() {
    final orgId = _orgIdentity?.organisationId ?? 'Loading...';
    final orgName = _orgIdentity?.organisationName ?? 'Omega Education Centre';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified, color: Colors.indigo, size: 20),
                SizedBox(width: 8),
                Text('ORGANISATION IDENTITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
            const SizedBox(height: 10),
            Text(orgName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('ID: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                SelectableText(orgId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy Org ID',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: orgId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Organisation ID copied to clipboard!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 30)),
              onPressed: _isWorking ? null : _regenerateRecoveryCode,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Regenerate Disaster Recovery Code', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDbStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('DATABASE STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                Row(
                  children: [
                    Icon(
                      _dbHealthy ? Icons.check_circle : Icons.error,
                      color: _dbHealthy ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _dbHealthy ? 'HEALTHY' : 'PROBLEM DETECTED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _dbHealthy ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Database Engine', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const Text('SQLite (Authoritative, Offline-first)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last Backup', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(_lastBackupTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last Status', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(_lastBackupStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.update, color: Colors.indigo),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AUTOMATIC DAILY BACKUPS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                SizedBox(height: 2),
                Text(
                  'Enabled on application startup (at most once per calendar day). Keeps a rolling history of the last 7 daily automatic backups.',
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupHistoryCard(BackupMetadataModel backup) {
    final dt = DateTime.parse(backup.createdTime);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);

    Color typeColor = Colors.grey;
    String typeLabel = 'Manual';
    if (backup.type == 'automatic') {
      typeColor = Colors.blue.shade800;
      typeLabel = 'Auto';
    } else if (backup.type == 'pre_restore') {
      typeColor = Colors.deepOrange.shade800;
      typeLabel = 'Pre-Restore';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: typeColor, width: 0.5),
                      ),
                      child: Text(
                        typeLabel.toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: typeColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  backup.formattedSize,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              backup.fileName,
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _isWorking ? null : () => _validateBackup(backup),
                  icon: const Icon(Icons.verified_user, size: 16),
                  label: const Text('Validate', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 30)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _isWorking ? null : () => _shareBackup(backup),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 30)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _isWorking ? null : () => _confirmRestore(backup),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Restore', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 30)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isWorking ? null : () => _confirmDelete(backup),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  tooltip: 'Delete',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
