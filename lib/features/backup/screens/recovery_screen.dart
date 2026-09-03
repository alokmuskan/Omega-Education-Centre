import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../authentication/login/login_screen.dart';
import '../services/backup_service.dart';
import '../services/org_identity_service.dart';
import '../services/restore_service.dart';

/// Disaster Recovery screen for users restoring existing ERP data on a new device.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final TextEditingController _orgIdController = TextEditingController();
  final TextEditingController _recoveryCodeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final BackupService _backupService = BackupService();
  final RestoreService _restoreService = RestoreService();
  final OrgIdentityService _orgIdentityService = OrgIdentityService();

  bool _isCodeObscured = true;
  bool _isWorking = false;
  String _workingMessage = '';

  File? _selectedFile;
  BackupValidationResult? _validationResult;
  RestoreResult? _restoreSuccessResult;

  @override
  void dispose() {
    _orgIdController.dispose();
    _recoveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickBackupFile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'db'],
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }

      final String filePath = result.files.first.path!;
      final File file = File(filePath);

      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected file does not exist.'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() {
        _isWorking = true;
        _workingMessage = 'Validating selected backup archive...';
      });

      final validation = await _backupService.validateBackupFile(filePath);

      if (!mounted) return;
      setState(() {
        _isWorking = false;
      });

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

      // Verify Org ID & Recovery Code if backup contains metadata
      if (validation.organisationId != null && validation.recoveryCodeHash != null && validation.recoveryCodeSalt != null) {
        final bool isCredValid = _orgIdentityService.verifyCredentials(
          inputOrgId: _orgIdController.text,
          inputRecoveryCode: _recoveryCodeController.text,
          expectedOrgId: validation.organisationId!,
          storedHash: validation.recoveryCodeHash!,
          storedSalt: validation.recoveryCodeSalt!,
        );

        if (!isCredValid) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.gpp_bad, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Verification Failed'),
                ],
              ),
              content: const Text(
                'Recovery verification failed!\n\nReason: The Organisation ID or Recovery Code does not match the backup archive.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            ),
          );
          return;
        }
      }

      setState(() {
        _selectedFile = file;
        _validationResult = validation;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmAndRestore() async {
    if (_selectedFile == null || _validationResult == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm ERP Recovery'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WARNING: Restoring this backup will replace the current local database on this device with the selected backup file.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 12),
            const Text('A mandatory pre-restore emergency backup will be created automatically before restoring.'),
            const SizedBox(height: 12),
            Text('Backup File: ${p.basename(_selectedFile!.path)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            child: const Text('Restore ERP Data'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isWorking = true;
      _workingMessage = 'Restoring Omega ERP data & profile photos...\nCreating emergency checkpoint...';
    });

    try {
      final res = await _restoreService.restoreDatabase(
        _selectedFile!.path,
        inputOrgId: _orgIdController.text,
        inputRecoveryCode: _recoveryCodeController.text,
      );

      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _restoreSuccessResult = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Existing ERP'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _restoreSuccessResult != null
                ? _buildSuccessCard(_restoreSuccessResult!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DISASTER RECOVERY',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Restore ERP Data on New Device',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your Organisation ID and Disaster Recovery Code to verify ownership before selecting your backup archive.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),

                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _orgIdController,
                              decoration: InputDecoration(
                                labelText: 'Organisation ID',
                                hintText: 'e.g. OEC-SAMASTIPUR-8F2A',
                                prefixIcon: const Icon(Icons.business),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Organisation ID is required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _recoveryCodeController,
                              obscureText: _isCodeObscured,
                              decoration: InputDecoration(
                                labelText: 'Recovery Code',
                                hintText: 'e.g. OEC-7K9P-42MX-81QA',
                                prefixIcon: const Icon(Icons.vpn_key),
                                suffixIcon: IconButton(
                                  icon: Icon(_isCodeObscured ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _isCodeObscured = !_isCodeObscured),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Recovery Code is required' : null,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isWorking ? null : _pickBackupFile,
                          icon: const Icon(Icons.folder_open),
                          label: Text(_selectedFile == null ? 'Select Backup File (.zip)' : 'Change Selected File'),
                        ),
                      ),

                      if (_selectedFile != null && _validationResult != null) ...[
                        const SizedBox(height: 24),
                        _buildVerifiedCard(_selectedFile!, _validationResult!),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade800,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isWorking ? null : _confirmAndRestore,
                            icon: const Icon(Icons.restore),
                            label: const Text('RESTORE ERP BACKUP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

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
                        Text(_workingMessage, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildVerifiedCard(File file, BackupValidationResult validation) {
    final sizeKb = (file.lengthSync() / 1024.0).toStringAsFixed(1);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                const Text('BACKUP VERIFIED', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const Divider(height: 20),
            Text('Organisation: ${validation.organisationName ?? "Omega Education Centre"}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Organisation ID: ${validation.organisationId ?? _orgIdController.text}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            Text('File: ${p.basename(file.path)} ($sizeKb KB)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Database Version: v${validation.dbVersion}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Profile Photos: ${validation.hasPhotos ? "Included" : "None"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(RestoreResult res) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('RESTORE SUCCESSFUL', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Omega Education Centre ERP data has been restored successfully on this device.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _buildStatRow('Students', '${res.studentCount}'),
            _buildStatRow('Teachers', '${res.teacherCount}'),
            _buildStatRow('Tests', '${res.testCount}'),
            _buildStatRow('Test Results', '${res.resultCount}'),
            _buildStatRow('Notices', '${res.noticeCount}'),
            _buildStatRow('Profile Photos', res.photosRestored ? 'Restored' : 'Up to date'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('CONTINUE TO LOGIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
