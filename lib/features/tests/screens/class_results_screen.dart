import 'package:flutter/material.dart';

import '../models/student_test_summary_model.dart';
import '../models/test_model.dart';
import '../reports/services/report_export_service.dart';
import '../repository/test_result_repository.dart';
import 'test_result_details_screen.dart';

/// Screen displaying class performance summary and student leaderboards for a test.
class ClassResultsScreen extends StatefulWidget {
  final TestModel test;

  const ClassResultsScreen({
    super.key,
    required this.test,
  });

  @override
  State<ClassResultsScreen> createState() => _ClassResultsScreenState();
}

class _ClassResultsScreenState extends State<ClassResultsScreen> {
  final _resultRepo = TestResultRepository();

  List<StudentTestSummaryModel> _summaries = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _sortBy = 'Rank'; // 'Rank', 'Percentage', 'Name'

  @override
  void initState() {
    super.initState();
    _loadClassSummaries();
  }

  void _showExportFormatDialog({StudentTestSummaryModel? studentSummary}) {
    final isIndividual = studentSummary != null;
    final title = isIndividual
        ? 'Generate Report Card for ${studentSummary.studentName}'
        : 'Export Class Results (${widget.test.studentClass})';

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
              title,
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
              title: const Text('PDF Document (.pdf)'),
              subtitle: Text(isIndividual ? 'A4 Portrait report card' : 'A4 Landscape notice board table'),
              onTap: () {
                Navigator.pop(ctx);
                if (isIndividual) {
                  ReportExportService.exportStudentReportCard(
                    context: context,
                    summary: studentSummary,
                    format: 'pdf',
                  );
                } else {
                  ReportExportService.exportClassResults(
                    context: context,
                    test: widget.test,
                    format: 'pdf',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green, size: 28),
              title: const Text('Excel Spreadsheet (.xlsx)'),
              subtitle: const Text('Editable spreadsheet with numeric cell data'),
              onTap: () {
                Navigator.pop(ctx);
                if (isIndividual) {
                  ReportExportService.exportStudentReportCard(
                    context: context,
                    summary: studentSummary,
                    format: 'xlsx',
                  );
                } else {
                  ReportExportService.exportClassResults(
                    context: context,
                    test: widget.test,
                    format: 'xlsx',
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue, size: 28),
              title: const Text('Word Document (.docx)'),
              subtitle: const Text('Editable OpenXML Word document table'),
              onTap: () {
                Navigator.pop(ctx);
                if (isIndividual) {
                  ReportExportService.exportStudentReportCard(
                    context: context,
                    summary: studentSummary,
                    format: 'docx',
                  );
                } else {
                  ReportExportService.exportClassResults(
                    context: context,
                    test: widget.test,
                    format: 'docx',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadClassSummaries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _resultRepo.getClassTestSummaries(widget.test.id!);
      if (mounted) {
        setState(() {
          _summaries = results;
          _sortSummaries();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load class results: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _sortSummaries() {
    if (_sortBy == 'Rank') {
      _summaries.sort((a, b) {
        // Complete results (rank > 0) first, ordered by rank ascending
        if (a.rank > 0 && b.rank > 0) return a.rank.compareTo(b.rank);
        if (a.rank > 0) return -1;
        if (b.rank > 0) return 1;
        return a.studentName.compareTo(b.studentName);
      });
    } else if (_sortBy == 'Percentage') {
      _summaries.sort((a, b) => b.percentage.compareTo(a.percentage));
    } else if (_sortBy == 'Name') {
      _summaries.sort((a, b) => a.studentName.compareTo(b.studentName));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final test = widget.test;

    // Compute Class Metrics
    final totalStudents = _summaries.length;
    final passCount = _summaries.where((s) => s.overallStatus == 'Pass').length;
    final failCount = _summaries.where((s) => s.overallStatus == 'Fail').length;
    final incompleteCount = _summaries.where((s) => s.overallStatus == 'Incomplete').length;

    final completeList = _summaries.where((s) => s.isComplete).toList();
    final classAvgPct = completeList.isNotEmpty
        ? completeList.fold(0.0, (sum, s) => sum + s.percentage) / completeList.length
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${test.title} — Class Results'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Class Results (PDF, Excel, Word)',
            onPressed: () => _showExportFormatDialog(),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Class Summary Metrics Card ──────────────────────────────
          if (!_isLoading && _summaries.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricHeaderItem('Students', '$totalStudents', Colors.black87),
                        _metricHeaderItem('Passed', '$passCount', Colors.green.shade800),
                        _metricHeaderItem('Failed', '$failCount', Colors.red.shade800),
                        _metricHeaderItem('Incomplete', '$incompleteCount', Colors.orange.shade800),
                        _metricHeaderItem('Class Avg', '${classAvgPct.toStringAsFixed(1)}%', Colors.indigo.shade800),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── Sort Control Bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${test.studentClass} (${test.board}) Leaderboard',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                DropdownButton<String>(
                  value: _sortBy,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.sort, size: 20),
                  items: ['Rank', 'Percentage', 'Name']
                      .map((s) => DropdownMenuItem(value: s, child: Text('Sort by $s')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _sortBy = val;
                        _sortSummaries();
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Student Results List ─────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _summaries.isEmpty
                        ? _buildEmptyView()
                        : RefreshIndicator(
                            onRefresh: _loadClassSummaries,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                              itemCount: _summaries.length,
                              itemBuilder: (context, index) {
                                return _buildResultTile(_summaries[index], theme);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _metricHeaderItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildResultTile(StudentTestSummaryModel s, ThemeData theme) {
    final statusColor = _getStatusColor(s.overallStatus);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Competition Rank Badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: s.rank == 1
                      ? Colors.amber.shade100
                      : s.rank == 2
                          ? Colors.grey.shade200
                          : s.rank == 3
                              ? Colors.brown.shade100
                              : theme.colorScheme.primary.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  s.rank > 0 ? '#${s.rank}' : '-',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: s.rank == 1
                        ? Colors.amber.shade900
                        : s.rank > 0
                            ? Colors.black87
                            : Colors.grey,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.studentName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Roll No: ${s.studentRollNo.isNotEmpty ? s.studentRollNo : "N/A"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              // Marks & Percentage
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.isComplete
                        ? '${s.percentage.toStringAsFixed(1)}% (${s.grade})'
                        : 'Incomplete',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: s.isComplete ? Colors.black87 : Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.totalObtained.toStringAsFixed(0)} / ${s.totalMax.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),

              const SizedBox(width: 10),

              // Status Badge & Report Card button
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.overallStatus,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.badge_outlined, size: 20, color: Colors.blue),
                    tooltip: 'Report Card',
                    onPressed: () => _showExportFormatDialog(studentSummary: s),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No student results recorded yet for ${widget.test.title}.',
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
            onPressed: _loadClassSummaries,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
