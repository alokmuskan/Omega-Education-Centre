import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/attendance_date_validator.dart';
import '../models/teacher_attendance_model.dart';
import '../repository/teacher_attendance_repository.dart';
import 'teacher_attendance_history_screen.dart';

/// Screen for recording and editing daily Teacher Attendance (Hours Worked per date).
///
/// Only ACTIVE teachers are shown in the daily attendance-taking list.
/// Inactive teachers are excluded from daily marking, but their historical records remain intact.
class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  final TeacherAttendanceRepository _repository =
      TeacherAttendanceRepository();

  DateTime _selectedDate = DateTime.now();
  List<_TeacherAttendanceEntry> _entries = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeacherAttendance();
  }

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _displayDate => DateFormat('d MMMM yyyy').format(_selectedDate);

  Future<void> _loadTeacherAttendance() async {
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
      final records =
          await _repository.getTeacherAttendanceByDate(_formattedDate);

      // Clean up previous controllers
      for (final e in _entries) {
        e.dispose();
      }

      if (mounted) {
        setState(() {
          _entries = records.map((r) {
            return _TeacherAttendanceEntry(
              model: r,
              hoursController: TextEditingController(
                text: r.hoursWorked > 0
                    ? r.hoursWorked.toStringAsFixed(
                        r.hoursWorked.truncateToDouble() == r.hoursWorked
                            ? 0
                            : 1)
                    : '0',
              ),
              remarksController:
                  TextEditingController(text: r.remarks ?? ''),
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load teacher attendance: $e';
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
      helpText: 'SELECT DATE FOR TEACHER HOURS',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadTeacherAttendance();
    }
  }

  void _addHours(int index, double delta) {
    final current =
        double.tryParse(_entries[index].hoursController.text) ?? 0.0;
    var updated = current + delta;
    if (updated > AppConstants.maxTeacherHoursPerDay) {
      updated = AppConstants.maxTeacherHoursPerDay;
    }
    if (updated < 0) updated = 0;

    _entries[index].hoursController.text = updated.toStringAsFixed(
      updated.truncateToDouble() == updated ? 0 : 1,
    );
    setState(() {});
  }

  void _clearHours(int index) {
    _entries[index].hoursController.text = '0';
    setState(() {});
  }

  Future<void> _saveTeacherAttendance() async {
    if (_entries.isEmpty) return;

    if (AttendanceDateValidator.isFutureDateTime(_selectedDate)) {
      _showError('Future attendance cannot be recorded.');
      return;
    }

    // Validate hours limits
    for (final e in _entries) {
      final text = e.hoursController.text.trim();
      final val = double.tryParse(text);
      if (val == null || val < 0) {
        _showError(
          'Invalid hours for ${e.model.teacherName}. Must be a non-negative number.',
        );
        return;
      }
      if (val > AppConstants.maxTeacherHoursPerDay) {
        _showError(
          'Hours for ${e.model.teacherName} cannot exceed ${AppConstants.maxTeacherHoursPerDay.toStringAsFixed(0)} hours per day.',
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final recordsToSave = _entries.map((e) {
        final hrs = double.parse(e.hoursController.text.trim());
        final rem = e.remarksController.text.trim();

        return TeacherAttendanceModel(
          id: e.model.id,
          teacherId: e.model.teacherId,
          date: _formattedDate,
          hoursWorked: hrs,
          remarks: rem.isEmpty ? null : rem,
        );
      }).toList();

      await _repository.saveOrUpdateTeacherAttendanceBatch(recordsToSave);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Teacher attendance for $_displayDate saved successfully!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadTeacherAttendance();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to save teacher attendance: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Validation Error'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate total hours recorded in current view
    final totalHoursToday = _entries.fold(0.0, (sum, e) {
      return sum + (double.tryParse(e.hoursController.text) ?? 0.0);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Attendance'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Teacher Hours History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeacherAttendanceHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Controls & Summary Card ───────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Date Picker Box
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          isDense: true,
                          prefixIcon: Icon(Icons.calendar_today, size: 18),
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

                  const SizedBox(width: 14),

                  // Total Hours Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Hours',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${totalHoursToday.toStringAsFixed(1)} hrs',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ── Teacher List Body ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _entries.isEmpty
                        ? _buildEmptyView()
                        : RefreshIndicator(
                            onRefresh: _loadTeacherAttendance,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                return _buildTeacherAttendanceCard(
                                  _entries[index],
                                  index,
                                  theme,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),

      // ── Bottom Sticky Save Button ─────────────────────────────────────
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
            onPressed: (_isSaving || _entries.isEmpty) ? null : _saveTeacherAttendance,
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
              _isSaving ? 'Saving Hours...' : 'Save Teacher Hours',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherAttendanceCard(
    _TeacherAttendanceEntry entry,
    int index,
    ThemeData theme,
  ) {
    final teacher = entry.model;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withAlpha(25),
                  child: Text(
                    teacher.teacherName != null && teacher.teacherName!.isNotEmpty
                        ? teacher.teacherName![0].toUpperCase()
                        : 'T',
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
                        teacher.teacherName ?? 'Teacher #${teacher.teacherId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Subject: ${teacher.teacherSubject ?? "N/A"} • Rate: ₹${(teacher.teacherPayPerHour ?? 0).toStringAsFixed(0)}/hr',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Hours Worked Input Field & Quick Presets
            Row(
              children: [
                // Hours Input Field
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: entry.hoursController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Hours *',
                      isDense: true,
                      suffixText: 'hrs',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(width: 10),

                // Quick Preset Buttons
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _presetButton(index, '+1h', 1.0),
                      _presetButton(index, '+2h', 2.0),
                      _presetButton(index, '+3h', 3.0),
                      ActionChip(
                        label: const Text('Clear', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _clearHours(index),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Optional Remarks Input
            TextFormField(
              controller: entry.remarksController,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetButton(int index, String label, double hours) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      onPressed: () => _addHours(index, hours),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No active teachers registered.\nAdd active teachers in Teacher Module to mark attendance.',
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
            onPressed: _loadTeacherAttendance,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _TeacherAttendanceEntry {
  final TeacherAttendanceModel model;
  final TextEditingController hoursController;
  final TextEditingController remarksController;

  _TeacherAttendanceEntry({
    required this.model,
    required this.hoursController,
    required this.remarksController,
  });

  void dispose() {
    hoursController.dispose();
    remarksController.dispose();
  }
}
