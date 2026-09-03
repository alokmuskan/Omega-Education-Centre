import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../students/models/student_model.dart';
import '../../students/repository/student_repository.dart';
import '../models/attendance_summary_model.dart';
import '../models/student_attendance_model.dart';
import '../repository/student_attendance_repository.dart';
import '../../../shared/utils/app_session.dart';

/// Screen displaying Student Attendance History & Monthly Analytics.
class StudentAttendanceHistoryScreen extends StatefulWidget {
  final int? initialStudentId;

  const StudentAttendanceHistoryScreen({
    super.key,
    this.initialStudentId,
  });

  @override
  State<StudentAttendanceHistoryScreen> createState() =>
      _StudentAttendanceHistoryScreenState();
}

class _StudentAttendanceHistoryScreenState
    extends State<StudentAttendanceHistoryScreen> {
  final StudentAttendanceRepository _attendanceRepo =
      StudentAttendanceRepository();
  final StudentRepository _studentRepo = StudentRepository();

  List<StudentModel> _students = [];
  StudentModel? _selectedStudent;

  List<StudentAttendanceModel> _history = [];
  StudentAttendanceSummary _summary = StudentAttendanceSummary.empty();

  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;

  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    final session = AppSession.instance;
    if (session.isTeacher || (session.isStudent && widget.initialStudentId != session.currentStudentId)) {
      _accessDenied = true;
      _isLoading = false;
      return;
    }
    _loadStudents();
  }

  String get _yearMonth => DateFormat('yyyy-MM').format(_selectedMonth);
  String get _displayMonth => DateFormat('MMMM yyyy').format(_selectedMonth);

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final students = await _studentRepo.getStudents();
    if (!mounted) return;

    setState(() {
      _students = students;
      if (students.isNotEmpty) {
        _selectedStudent = widget.initialStudentId != null
            ? students.firstWhere(
                (s) => s.id == widget.initialStudentId,
                orElse: () => students.first,
              )
            : students.first;
      }
    });

    if (_selectedStudent != null) {
      await _loadHistoryAndSummary();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistoryAndSummary() async {
    if (_selectedStudent == null || _selectedStudent!.id == null) return;

    setState(() => _isLoading = true);

    final historyList =
        await _attendanceRepo.getStudentAttendanceHistory(_selectedStudent!.id!);
    final monthlySummary = await _attendanceRepo.getStudentMonthlySummary(
      studentId: _selectedStudent!.id!,
      yearMonth: _yearMonth,
    );

    if (!mounted) return;

    setState(() {
      _history = historyList;
      _summary = monthlySummary;
      _isLoading = false;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECT MONTH',
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _loadHistoryAndSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accessDenied) {
      final session = AppSession.instance;
      final errorMsg = session.isTeacher
          ? 'Access Denied: You are not authorized to view this student attendance ledger.'
          : 'Access Denied: You can only view your own attendance history.';
      return Scaffold(
        body: Center(
          child: Text(
            errorMsg,
            style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Selector Controls ─────────────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // Student Dropdown
                  if (!AppSession.instance.isStudent)
                    DropdownButtonFormField<int>(
                    initialValue: _selectedStudent?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Student',
                      isDense: true,
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _students
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.name} (Class ${s.studentClass}, Roll: ${s.rollNo})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id != null) {
                        setState(() {
                          _selectedStudent =
                              _students.firstWhere((s) => s.id == id);
                        });
                        _loadHistoryAndSummary();
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // Month Picker
                  GestureDetector(
                    onTap: _pickMonth,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Filter Month',
                        isDense: true,
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      child: Text(
                        _displayMonth,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Attendance Analytics Summary Card ─────────────────────────
          if (_selectedStudent != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: _buildSummaryCard(theme),
            ),

          const SizedBox(height: 6),

          // ── Daily History Log List ─────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? _buildEmptyView()
                    : RefreshIndicator(
                        onRefresh: _loadHistoryAndSummary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            return _buildHistoryTile(item, theme);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final pct = _summary.percentage;

    Color pctColor = Colors.green;
    if (pct < 75) pctColor = Colors.red;
    if (pct >= 75 && pct < 85) pctColor = Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Attendance ($_displayMonth)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pct.toStringAsFixed(1)}% Attendance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: pctColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Percentage Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: pctColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricItem('Total Days', '${_summary.totalRecordedDays}', Colors.black87),
              _metricItem('Present', '${_summary.presentCount}', Colors.green.shade800),
              _metricItem('Absent', '${_summary.absentCount}', Colors.red.shade800),
              _metricItem('Late', '${_summary.lateCount}', Colors.orange.shade800),
              _metricItem('Leave', '${_summary.leaveCount}', Colors.blue.shade800),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricItem(String label, String value, Color color) {
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

  Widget _buildHistoryTile(StudentAttendanceModel item, ThemeData theme) {
    final statusColor = _getStatusColor(item.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(30),
          child: Icon(_getStatusIcon(item.status), color: statusColor, size: 20),
        ),
        title: Text(
          _formatDate(item.date),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: item.remarks != null && item.remarks!.isNotEmpty
            ? Text('Remarks: ${item.remarks}')
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item.status,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: statusColor,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('EEE, d MMM yyyy').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green.shade800;
      case 'Absent':
        return Colors.red.shade800;
      case 'Late':
        return Colors.orange.shade800;
      case 'Leave':
        return Colors.blue.shade800;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Present':
        return Icons.check_circle;
      case 'Absent':
        return Icons.cancel;
      case 'Late':
        return Icons.access_time_filled;
      case 'Leave':
        return Icons.event_note;
      default:
        return Icons.help;
    }
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No attendance records found for ${_selectedStudent?.name ?? "this student"}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
