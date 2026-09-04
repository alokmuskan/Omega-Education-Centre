import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../shared/services/csv_export_service.dart';
import '../../../../shared/services/csv_import_service.dart';

/// Screen for bulk importing Students or Teachers from CSV files.
///
/// Flow:
/// 1. Choose entity type (Student/Teacher)
/// 2. Pick CSV file
/// 3. Preview row count
/// 4. Import with progress
/// 5. Show results (success/skip/error counts)
class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  String _selectedEntity = 'student'; // 'student' or 'teacher'
  PlatformFile? _selectedFile;
  bool _isImporting = false;
  CsvImportResult? _result;
  int _progressCurrent = 0;
  int _progressTotal = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk CSV Import'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entity type selector
            const Text('Import Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'student', label: Text('Students'), icon: Icon(Icons.people)),
                ButtonSegment(value: 'teacher', label: Text('Teachers'), icon: Icon(Icons.school)),
              ],
              selected: {_selectedEntity},
              onSelectionChanged: (sel) => setState(() {
                _selectedEntity = sel.first;
                _selectedFile = null;
                _result = null;
              }),
            ),
            const SizedBox(height: 20),

            // Download template
            Card(
              child: ListTile(
                leading: const Icon(Icons.download, color: Colors.blue),
                title: const Text('Download CSV Template'),
                subtitle: Text('Get a blank $_selectedEntity CSV template with headers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (_selectedEntity == 'student') {
                    await CsvExportService.instance.generateStudentTemplate();
                  } else {
                    await CsvExportService.instance.generateTeacherTemplate();
                  }
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Template downloaded!')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),

            // Pick file
            Card(
              child: ListTile(
                leading: const Icon(Icons.file_upload, color: Colors.green),
                title: Text(_selectedFile != null ? _selectedFile!.name : 'Select CSV File'),
                subtitle: Text(_selectedFile != null
                    ? '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB'
                    : 'Tap to choose a CSV file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickFile,
              ),
            ),
            const SizedBox(height: 20),

            // Import button
            if (_selectedFile != null && !_isImporting && _result == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startImport,
                  icon: const Icon(Icons.upload),
                  label: const Text('Start Import'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

            // Progress
            if (_isImporting) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _progressTotal > 0 ? _progressCurrent / _progressTotal : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Importing $_progressCurrent of $_progressTotal rows...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],

            // Results
            if (_result != null) ...[
              const SizedBox(height: 20),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _result = null;
      });
    }
  }

  Future<void> _startImport() async {
    if (_selectedFile == null) return;

    setState(() {
      _isImporting = true;
      _progressCurrent = 0;
      _progressTotal = 0;
      _result = null;
    });

    final filePath = _selectedFile!.path;
    if (filePath == null) {
      setState(() {
        _isImporting = false;
        _result = const CsvImportResult(
          totalRows: 0,
          successCount: 0,
          skipCount: 0,
          errorCount: 1,
          errors: [CsvImportError(rowNumber: 0, field: 'file', message: 'File path not available')],
          skippedReasons: [],
        );
      });
      return;
    }

    try {
      CsvImportResult result;
      if (_selectedEntity == 'student') {
        result = await CsvImportService.instance.importStudents(
          filePath,
          onProgress: (current, total) {
            setState(() {
              _progressCurrent = current;
              _progressTotal = total;
            });
          },
        );
      } else {
        result = await CsvImportService.instance.importTeachers(
          filePath,
          onProgress: (current, total) {
            setState(() {
              _progressCurrent = current;
              _progressTotal = total;
            });
          },
        );
      }

      setState(() {
        _isImporting = false;
        _result = result;
      });
    } catch (e) {
      setState(() {
        _isImporting = false;
        _result = CsvImportResult(
          totalRows: 0,
          successCount: 0,
          skipCount: 0,
          errorCount: 1,
          errors: [CsvImportError(rowNumber: 0, field: 'general', message: e.toString())],
          skippedReasons: [],
        );
      });
    }
  }

  Widget _buildResultCard() {
    final r = _result!;
    return Card(
      color: r.allSuccess ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  r.allSuccess ? Icons.check_circle : Icons.info,
                  color: r.allSuccess ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Import Complete',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: r.allSuccess ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildStatRow('Total Rows', '${r.totalRows}', Colors.grey),
            _buildStatRow('Imported', '${r.successCount}', Colors.green),
            _buildStatRow('Skipped (duplicates)', '${r.skipCount}', Colors.orange),
            _buildStatRow('Errors', '${r.errorCount}', Colors.red),

            // Show errors
            if (r.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...r.errors.take(10).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Row ${e.rowNumber}: ${e.field} — ${e.message}',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  )),
              if (r.errors.length > 10)
                Text('... and ${r.errors.length - 10} more errors', style: TextStyle(color: Colors.red.shade500, fontSize: 12)),
            ],

            // Show skipped reasons
            if (r.skippedReasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Skipped:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...r.skippedReasons.take(10).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(s, style: TextStyle(color: Colors.orange.shade700, fontSize: 12)),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
