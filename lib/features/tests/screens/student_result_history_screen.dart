import 'package:flutter/material.dart';
import '../../../shared/utils/app_session.dart';

import '../../students/models/student_model.dart';
import '../../students/repository/student_repository.dart';
import '../models/student_test_summary_model.dart';
import '../reports/services/report_export_service.dart';
import '../repository/test_result_repository.dart';
import 'test_result_details_screen.dart';

/// Screen displaying all examination results and report history for a student.
class StudentResultHistoryScreen extends StatefulWidget {
  final int studentId;

  const StudentResultHistoryScreen({
    super.key,
    required this.studentId,
  });

  @override
  State<StudentResultHistoryScreen> createState() => _StudentResultHistoryScreenState();
}

class _StudentResultHistoryScreenState extends State<StudentResultHistoryScreen> {
  final _resultRepo = TestResultRepository();
  final _studentRepo = StudentRepository();

  StudentModel? _student;
  List<StudentTestSummaryModel> _history = [];

  bool _isLoading = true;
  String? _errorMessage;

  void _showExportDialog(StudentTestSummaryModel summary) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate Report Card for ${summary.studentName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Select file format:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
              title: const Text('PDF Report Card (.pdf)'),
              subtitle: const Text('A4 Portrait printable report card'),
              onTap: () {
                Navigator.pop(ctx);
                ReportExportService.exportStudentReportCard(
                  context: context,
                  summary: summary,
                  format: 'pdf',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green, size: 28),
              title: const Text('Excel Report Data (.xlsx)'),
              subtitle: const Text('Editable spreadsheet report format'),
              onTap: () {
                Navigator.pop(ctx);
                ReportExportService.exportStudentReportCard(
                  context: context,
                  summary: summary,
                  format: 'xlsx',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue, size: 28),
              title: const Text('Word Report Card (.docx)'),
              subtitle: const Text('Editable OpenXML Word document'),
              onTap: () {
                Navigator.pop(ctx);
                ReportExportService.exportStudentReportCard(
                  context: context,
                  summary: summary,
                  format: 'docx',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final student = await _studentRepo.getStudentById(widget.studentId);
      final historyList = await _resultRepo.getStudentResultHistory(widget.studentId);

      if (mounted) {
        setState(() {
          _student = student;
          _history = historyList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load student result history: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    if (session.isStudent && widget.studentId != session.currentStudentId) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: You can only view your own result history.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_student != null ? '${_student!.name}\'s Test Results' : 'Student Result History'),
        centerTitle: true,
      ),

      body: Column(
        children: [
          // ── Student Header Card ─────────────────────────────────────
          if (_student != null)
            Card(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.primary.withAlpha(25),
                      child: Text(
                        _student!.name.isNotEmpty ? _student!.name[0].toUpperCase() : 'S',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _student!.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Roll No: ${_student!.rollNo} • ${_student!.studentClass} (${_student!.board})',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Examination History List ────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _history.isEmpty
                        ? _buildEmptyView()
                        : RefreshIndicator(
                            onRefresh: _loadHistory,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                              itemCount: _history.length,
                              itemBuilder: (context, index) {
                                return _buildHistoryCard(_history[index], theme);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(StudentTestSummaryModel s, ThemeData theme) {
    final statusColor = _getStatusColor(s.overallStatus);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestResultDetailsScreen(summary: s),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test Title & Date
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.testTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s.overallStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.badge_outlined, color: Colors.blue, size: 22),
                    tooltip: 'Generate Report Card',
                    onPressed: () => _showExportDialog(s),
                  ),
                ],
              ),

              const SizedBox(height: 2),
              Text(
                'Type: ${s.testType} • Date: ${s.testDate} • Year: ${s.academicYear}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Metrics Row: Marks | % | Grade | Rank
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricTile('Marks', '${s.totalObtained.toStringAsFixed(0)}/${s.totalMax.toStringAsFixed(0)}', Colors.indigo.shade800),
                  _metricTile('Percentage', s.isComplete ? '${s.percentage.toStringAsFixed(1)}%' : 'N/A', Colors.blue.shade800),
                  _metricTile('Grade', s.grade, Colors.purple.shade800),
                  _metricTile('Class Rank', s.rank > 0 ? '#${s.rank}' : 'N/A', Colors.amber.shade900),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pass':
        return Colors.green.shade800;
      case 'Fail':
        return Colors.red.shade800;
      case 'Incomplete':
        return Colors.orange.shade800;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No test results recorded for ${_student?.name ?? "this student"} yet.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'An error occurred.', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
