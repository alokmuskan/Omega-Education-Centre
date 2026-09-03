import 'package:flutter/material.dart';
import '../../attendance/models/attendance_summary_model.dart';
import '../../../shared/utils/app_session.dart';
import '../../attendance/repository/student_attendance_repository.dart';
import '../models/student_test_summary_model.dart';
import '../reports/services/report_export_service.dart';
import '../services/result_calculation_service.dart';

/// Detailed Student Examination Report Card screen.
class TestResultDetailsScreen extends StatefulWidget {
  final StudentTestSummaryModel summary;

  const TestResultDetailsScreen({
    super.key,
    required this.summary,
  });

  @override
  State<TestResultDetailsScreen> createState() => _TestResultDetailsScreenState();
}

class _TestResultDetailsScreenState extends State<TestResultDetailsScreen> {
  final _attendanceRepo = StudentAttendanceRepository();
  StudentAttendanceSummary? _attendanceSummary;
  bool _isLoadingAttendance = true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceSummary();
  }

  Future<void> _loadAttendanceSummary() async {
    final sDate = widget.summary.testDate;
    final yearMonth = sDate.length >= 7 ? sDate.substring(0, 7) : '2026-08';

    try {
      final summary = await _attendanceRepo.getStudentMonthlySummary(
        studentId: widget.summary.studentId,
        yearMonth: yearMonth,
      );
      if (mounted) {
        setState(() {
          _attendanceSummary = summary;
          _isLoadingAttendance = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAttendance = false;
        });
      }
    }
  }

  String _getMonthLabel(String dateIso) {
    try {
      final dt = DateTime.parse(dateIso);
      final monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${monthNames[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'Selected Month';
    }
  }

  void _showExportDialog(BuildContext context) {
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
              'Export Report Card for ${widget.summary.studentName}',
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
              subtitle: const Text('A4 Portrait printable report card'),
              onTap: () {
                Navigator.pop(ctx);
                ReportExportService.exportStudentReportCard(
                  context: context,
                  summary: widget.summary,
                  format: 'pdf',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green, size: 28),
              title: const Text('Excel Spreadsheet (.xlsx)'),
              subtitle: const Text('Editable spreadsheet report format'),
              onTap: () {
                Navigator.pop(ctx);
                ReportExportService.exportStudentReportCard(
                  context: context,
                  summary: widget.summary,
                  format: 'xlsx',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue, size: 28),
              title: const Text('Word Document (.docx)'),
              subtitle: const Text('Editable OpenXML Word document'),
              onTap: () {
                Navigator.pop(ctx);
                ReportExportService.exportStudentReportCard(
                  context: context,
                  summary: widget.summary,
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
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    if (session.isStudent && widget.summary.studentId != session.currentStudentId) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: You can only view your own results details.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final summary = widget.summary;
    final statusColor = _getStatusColor(summary.overallStatus);
    final monthLabel = _getMonthLabel(summary.testDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Examination Report Card'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Report Card (PDF, Excel, Word)',
            onPressed: () => _showExportDialog(context),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Student & Test Profile Card ───────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary.withAlpha(25),
                      child: Text(
                        summary.studentName.isNotEmpty
                            ? summary.studentName[0].toUpperCase()
                            : 'S',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.studentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Roll No: ${summary.studentRollNo.isNotEmpty ? summary.studentRollNo : "N/A"} • Class & Board: ${summary.studentClass} (${summary.board})',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Examination: ${summary.testTitle} (${summary.testType})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Date: ${summary.testDate}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Subject Breakdown Table ───────────────────────────────
            const Text(
              'Subject-wise Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 2, child: Text('Obtained', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Max', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Pass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    ...summary.configuredSubjects.map((subj) {
                      final resList = summary.subjectResults.where((r) => r.testSubjectId == subj.id);
                      final isRecorded = resList.isNotEmpty;
                      final marks = isRecorded ? resList.first.marksObtained : null;

                      final isPass = marks != null &&
                          ResultCalculationService.isSubjectPassed(
                            marksObtained: marks,
                            passMarks: subj.passMarks,
                          );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                subj.subjectName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                marks != null ? marks.toStringAsFixed(0) : '-',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isRecorded ? Colors.black87 : Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                subj.maxMarks.toStringAsFixed(0),
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                subj.passMarks.toStringAsFixed(0),
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: !isRecorded
                                        ? Colors.grey.shade200
                                        : isPass
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    !isRecorded
                                        ? 'Pending'
                                        : isPass
                                            ? 'Pass'
                                            : 'Fail',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !isRecorded
                                          ? Colors.grey.shade700
                                          : isPass
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Monthly Attendance Report ─────────────────────────────
            Text(
              'Monthly Attendance Report (Month: $monthLabel)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _isLoadingAttendance
                    ? const Center(child: CircularProgressIndicator())
                    : _attendanceSummary != null && _attendanceSummary!.totalRecordedDays > 0
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _metricBox(
                                'Classes Conducted',
                                '${_attendanceSummary!.totalRecordedDays}',
                                Icons.calendar_month,
                                Colors.blueGrey,
                              ),
                              _metricBox(
                                'Present',
                                '${_attendanceSummary!.presentCount + _attendanceSummary!.lateCount}',
                                Icons.check_circle_outline,
                                Colors.green,
                              ),
                              _metricBox(
                                'Absent',
                                '${_attendanceSummary!.absentCount}',
                                Icons.cancel_outlined,
                                Colors.red,
                              ),
                              _metricBox(
                                'Attendance %',
                                '${_attendanceSummary!.percentage.toStringAsFixed(1)}%',
                                Icons.pie_chart_outline,
                                Colors.indigo,
                              ),
                            ],
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            alignment: Alignment.center,
                            child: Text(
                              'No attendance records available',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Overall Performance Summary Cards ──────────────────────
            const Text(
              'Overall Performance Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _metricBox(
                    'Marks Obtained',
                    '${summary.totalObtained.toStringAsFixed(0)} / ${summary.totalMax.toStringAsFixed(0)}',
                    Icons.military_tech,
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricBox(
                    'Percentage',
                    summary.isComplete ? '${summary.percentage.toStringAsFixed(1)}%' : 'N/A',
                    Icons.percent,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _metricBox(
                    'Grade',
                    summary.grade,
                    Icons.grade,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricBox(
                    'Overall Result',
                    summary.overallStatus,
                    summary.overallStatus == 'Pass' ? Icons.check_circle : Icons.cancel,
                    statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricBox(
                    'Class Rank',
                    summary.rank > 0 ? 'Rank ${summary.rank}' : 'N/A',
                    Icons.emoji_events,
                    Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
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
            textAlign: TextAlign.center,
          ),
        ],
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
}
