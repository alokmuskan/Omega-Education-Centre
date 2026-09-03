import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/attendance_date_validator.dart';
import '../models/student_attendance_model.dart';
import '../repository/student_attendance_repository.dart';
import 'student_attendance_history_screen.dart';

/// Screen for marking and editing daily Student Attendance by Class and Date.
class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final StudentAttendanceRepository _repository = StudentAttendanceRepository();

  String _selectedClass = '10';
  DateTime _selectedDate = DateTime.now();

  List<StudentAttendanceModel> _attendanceList = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _displayDate => DateFormat('d MMMM yyyy').format(_selectedDate);

  Future<void> _loadAttendance() async {
    if (!mounted) return;

    if (AttendanceDateValidator.isFutureDateTime(_selectedDate)) {
      setState(() {
        _errorMessage = 'Future attendance cannot be recorded.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _repository.getAttendanceByClassAndDate(
        studentClass: _selectedClass,
        date: _formattedDate,
      );

      if (mounted) {
        setState(() {
          _attendanceList = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load attendance: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'SELECT ATTENDANCE DATE',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadAttendance();
    }
  }

  void _markAll(String status) {
    setState(() {
      _attendanceList = _attendanceList
          .map((item) => item.copyWith(status: status))
          .toList();
    });
  }

  void _updateItemStatus(int index, String status) {
    setState(() {
      _attendanceList[index] = _attendanceList[index].copyWith(status: status);
    });
  }

  void _updateItemRemarks(int index, String remarks) {
    _attendanceList[index] = _attendanceList[index].copyWith(
      remarks: remarks.trim().isEmpty ? null : remarks.trim(),
    );
  }

  Future<void> _saveAttendance() async {
    if (_attendanceList.isEmpty) return;

    if (AttendanceDateValidator.isFutureDateTime(_selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Future attendance cannot be recorded.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _repository.saveOrUpdateAttendanceBatch(_attendanceList);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance for Class $_selectedClass on $_displayDate saved successfully!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadAttendance();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Summary counts for current batch
    final presentCount = _attendanceList.where((e) => e.status == 'Present').length;
    final absentCount = _attendanceList.where((e) => e.status == 'Absent').length;
    final lateCount = _attendanceList.where((e) => e.status == 'Late').length;
    final leaveCount = _attendanceList.where((e) => e.status == 'Leave').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Attendance History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StudentAttendanceHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Controls Header Card ───────────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Class Selector Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedClass,
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            isDense: true,
                            prefixIcon: Icon(Icons.school, size: 20),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          items: AppConstants.classes
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c == 'Other' ? 'Other' : 'Class $c'),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedClass = val);
                              _loadAttendance();
                            }
                          },
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Date Picker Box
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              isDense: true,
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              _formattedDate,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Bulk Actions Row
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _markAll('Present'),
                        icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        label: const Text('Mark All Present', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Total: ${_attendanceList.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Quick Summary Bar ─────────────────────────────────────────
          if (_attendanceList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statusBadge('Present', presentCount, Colors.green),
                  _statusBadge('Absent', absentCount, Colors.red),
                  _statusBadge('Late', lateCount, Colors.orange),
                  _statusBadge('Leave', leaveCount, Colors.blue),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // ── Attendance Student List ───────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _attendanceList.isEmpty
                        ? _buildEmptyView()
                        : RefreshIndicator(
                            onRefresh: _loadAttendance,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                              itemCount: _attendanceList.length,
                              itemBuilder: (context, index) {
                                final item = _attendanceList[index];
                                return _buildStudentAttendanceTile(item, index, theme);
                              },
                            ),
                          ),
          ),
        ],
      ),

      // ── Bottom Save Sticky Button ─────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: (_isSaving || _attendanceList.isEmpty) ? null : _saveAttendance,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(
              _isSaving ? 'Saving Attendance...' : 'Save Attendance',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStudentAttendanceTile(
    StudentAttendanceModel item,
    int index,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withAlpha(25),
                  child: Text(
                    item.studentRollNo ?? '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
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
                        item.studentName ?? 'Student #${item.studentId}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Roll No: ${item.studentRollNo ?? "N/A"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Status Selector Toggle Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: AppConstants.attendanceStatuses.map((status) {
                final isSelected = item.status == status;
                final color = _getStatusColor(status);

                return ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  selectedColor: color.withAlpha(50),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : Colors.grey.shade700,
                  ),
                  onSelected: (selected) {
                    if (selected) _updateItemStatus(index, status);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 8),

            // Optional Remarks Field
            TextFormField(
              initialValue: item.remarks ?? '',
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (val) => _updateItemRemarks(index, val),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No active students found in Class $_selectedClass.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
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
            onPressed: _loadAttendance,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
