import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../teachers/models/teacher_model.dart';
import '../../teachers/repository/teacher_repository.dart';
import '../models/attendance_summary_model.dart';
import '../models/teacher_attendance_model.dart';
import '../repository/teacher_attendance_repository.dart';
import '../../../shared/utils/app_session.dart';

/// Screen displaying Teacher Hours Worked History & Monthly Summaries.
///
/// Historical attendance records remain accessible for both Active & Inactive teachers.
class TeacherAttendanceHistoryScreen extends StatefulWidget {
  final int? initialTeacherId;

  const TeacherAttendanceHistoryScreen({
    super.key,
    this.initialTeacherId,
  });

  @override
  State<TeacherAttendanceHistoryScreen> createState() =>
      _TeacherAttendanceHistoryScreenState();
}

class _TeacherAttendanceHistoryScreenState
    extends State<TeacherAttendanceHistoryScreen> {
  final TeacherAttendanceRepository _attendanceRepo =
      TeacherAttendanceRepository();
  final TeacherRepository _teacherRepo = TeacherRepository();

  List<TeacherModel> _teachers = [];
  TeacherModel? _selectedTeacher;

  List<TeacherAttendanceModel> _history = [];
  TeacherAttendanceSummary _summary = TeacherAttendanceSummary.empty();

  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;

  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    final session = AppSession.instance;
    if (session.isStudent || (session.isTeacher && widget.initialTeacherId != session.currentTeacherId)) {
      _accessDenied = true;
      _isLoading = false;
      return;
    }
    _loadTeachers();
  }

  String get _yearMonth => DateFormat('yyyy-MM').format(_selectedMonth);
  String get _displayMonth => DateFormat('MMMM yyyy').format(_selectedMonth);

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    final teachers = await _teacherRepo.getTeachers(); // returns all teachers
    if (!mounted) return;

    setState(() {
      _teachers = teachers;
      if (teachers.isNotEmpty) {
        _selectedTeacher = widget.initialTeacherId != null
            ? teachers.firstWhere(
                (t) => t.id == widget.initialTeacherId,
                orElse: () => teachers.first,
              )
            : teachers.first;
      }
    });

    if (_selectedTeacher != null) {
      await _loadHistoryAndSummary();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistoryAndSummary() async {
    if (_selectedTeacher == null || _selectedTeacher!.id == null) return;

    setState(() => _isLoading = true);

    final historyList = await _attendanceRepo
        .getTeacherAttendanceHistory(_selectedTeacher!.id!);
    final monthlySummary = await _attendanceRepo.getTeacherMonthlySummary(
      teacherId: _selectedTeacher!.id!,
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
      final errorMsg = session.isStudent
          ? 'Access Denied: You are not authorized to view this teacher attendance ledger.'
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
        title: const Text('Teacher Hours History'),
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
                  // Teacher Dropdown
                  if (!AppSession.instance.isTeacher)
                    DropdownButtonFormField<int>(
                    initialValue: _selectedTeacher?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Teacher',
                      isDense: true,
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _teachers
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                '${t.name} (${t.subject}) - ${t.status}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id != null) {
                        setState(() {
                          _selectedTeacher =
                              _teachers.firstWhere((t) => t.id == id);
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

          // ── Monthly Summary Card ──────────────────────────────────────
          if (_selectedTeacher != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: _buildSummaryCard(theme),
            ),

          const SizedBox(height: 6),

          // ── History Log List ──────────────────────────────────────────
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.schedule, color: Colors.green, size: 28),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Hours ($_displayMonth)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_summary.totalHoursWorked.toStringAsFixed(1)} Total Hours',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  '${_summary.totalWorkingDays} working days recorded',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(TeacherAttendanceModel item, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: const Icon(Icons.access_time, color: Colors.green, size: 20),
        ),
        title: Text(
          _formatDate(item.date),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: item.remarks != null && item.remarks!.isNotEmpty
            ? Text('Remarks: ${item.remarks}')
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${item.hoursWorked.toStringAsFixed(1)} hrs',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
              fontSize: 14,
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
              'No attendance hours recorded for ${_selectedTeacher?.name ?? "this teacher"}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
