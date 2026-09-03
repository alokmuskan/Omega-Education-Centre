import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../teachers/models/teacher_model.dart';
import '../../teachers/repository/teacher_repository.dart';
import '../models/timetable_entry_model.dart';
import '../repository/timetable_repository.dart';

/// Screen for creating or editing scheduled timetable entries.
class AddEditTimetableScreen extends StatefulWidget {
  final TimetableEntryModel? initialEntry;

  const AddEditTimetableScreen({
    super.key,
    this.initialEntry,
  });

  @override
  State<AddEditTimetableScreen> createState() => _AddEditTimetableScreenState();
}

class _AddEditTimetableScreenState extends State<AddEditTimetableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = TimetableRepository();
  final _teacherRepository = TeacherRepository();

  late String _selectedDay;
  late int _selectedPeriod;
  late String _selectedClass;
  late String _selectedBoard;
  late TextEditingController _batchController;

  int? _selectedTeacherId;
  late String _selectedSubject;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  late TextEditingController _roomController;
  late TextEditingController _remarksController;

  List<TeacherModel> _availableTeachers = [];
  bool _isLoadingTeachers = true;
  bool _isSaving = false;

  bool get _isEditMode => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;

    if (entry != null) {
      _selectedDay = entry.dayOfWeek;
      _selectedPeriod = entry.periodNumber;
      _selectedClass = entry.studentClass;
      _selectedBoard = entry.board;
      _batchController = TextEditingController(text: entry.batch ?? '');
      _selectedTeacherId = entry.teacherId;
      _selectedSubject = entry.subject;
      _startTime = _parseTimeOfDay(entry.startTime);
      _endTime = _parseTimeOfDay(entry.endTime);
      _roomController = TextEditingController(text: entry.room ?? '');
      _remarksController = TextEditingController(text: entry.remarks ?? '');
    } else {
      _selectedDay = 'Monday';
      _selectedPeriod = 1;
      _selectedClass = AppConstants.classes.contains('10') ? '10' : AppConstants.classes.first;
      _selectedBoard = AppConstants.boards.first;
      _batchController = TextEditingController();
      _selectedSubject = AppConstants.subjects.first;
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 8, minute: 45);
      _roomController = TextEditingController();
      _remarksController = TextEditingController();
    }

    _loadTeachers();
  }

  @override
  void dispose() {
    _batchController.dispose();
    _roomController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final format = DateFormat.jm();
      final dt = format.parse(timeStr.trim());
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _loadTeachers() async {
    try {
      final teachers = await _teacherRepository.getTeachers();
      final activeTeachers = teachers.where((t) => t.isActive).toList();

      if (mounted) {
        setState(() {
          _availableTeachers = activeTeachers;
          _isLoadingTeachers = false;
          if (_selectedTeacherId == null && activeTeachers.isNotEmpty) {
            _selectedTeacherId = activeTeachers.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 8, minute: 45),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a teacher.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start time and End time are required.'), backgroundColor: Colors.red),
      );
      return;
    }

    final startMins = _startTime!.hour * 60 + _startTime!.minute;
    final endMins = _endTime!.hour * 60 + _endTime!.minute;
    if (startMins >= endMins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final entry = TimetableEntryModel(
        id: widget.initialEntry?.id,
        dayOfWeek: _selectedDay,
        periodNumber: _selectedPeriod,
        studentClass: _selectedClass,
        board: _selectedBoard,
        batch: _batchController.text.trim().isNotEmpty ? _batchController.text.trim() : null,
        teacherId: _selectedTeacherId!,
        subject: _selectedSubject,
        startTime: _formatTimeOfDay(_startTime!),
        endTime: _formatTimeOfDay(_endTime!),
        room: _roomController.text.trim().isNotEmpty ? _roomController.text.trim() : null,
        remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
        createdAt: widget.initialEntry?.createdAt,
      );

      if (_isEditMode) {
        await _repository.updateTimetableEntry(entry);
      } else {
        await _repository.insertTimetableEntry(entry);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Schedule updated successfully.' : 'Schedule entry added successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ArgumentError: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Schedule Entry' : 'Add Schedule Entry'),
        centerTitle: true,
      ),
      body: _isLoadingTeachers
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day of Week & Period Number Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedDay,
                            decoration: const InputDecoration(
                              labelText: 'Day of Week *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            items: TimetableRepository.daysOfWeek.map((d) {
                              return DropdownMenuItem(value: d, child: Text(d));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDay = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedPeriod,
                            decoration: const InputDecoration(
                              labelText: 'Period *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.format_list_numbered),
                            ),
                            items: List.generate(10, (i) => i + 1).map((p) {
                              return DropdownMenuItem(value: p, child: Text('Period $p'));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPeriod = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Class & Board Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedClass,
                            decoration: const InputDecoration(
                              labelText: 'Class *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.school),
                            ),
                            items: AppConstants.classes.map((c) {
                              return DropdownMenuItem(value: c, child: Text('Class $c'));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedClass = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedBoard,
                            decoration: const InputDecoration(
                              labelText: 'Board *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.account_balance),
                            ),
                            items: AppConstants.boards.map((b) {
                              return DropdownMenuItem(value: b, child: Text(b));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedBoard = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Batch (Optional)
                    TextFormField(
                      controller: _batchController,
                      decoration: const InputDecoration(
                        labelText: 'Batch Name (Optional)',
                        hintText: 'e.g. Udaan Batch, Morning Shift',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.groups),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Teacher Dropdown
                    DropdownButtonFormField<int>(
                      initialValue: _selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'Teacher *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: _availableTeachers.map((t) {
                        return DropdownMenuItem(value: t.id, child: Text('${t.name} (${t.subject})'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTeacherId = val);
                      },
                      validator: (val) => val == null ? 'Please select a teacher' : null,
                    ),

                    const SizedBox(height: 16),

                    // Subject Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSubject,
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.book),
                      ),
                      items: AppConstants.subjects.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSubject = val);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Start Time & End Time
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickStartTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Time *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(
                                _startTime != null ? _formatTimeOfDay(_startTime!) : 'Select Time',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _pickEndTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Time *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time_filled),
                              ),
                              child: Text(
                                _endTime != null ? _formatTimeOfDay(_endTime!) : 'Select Time',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Room / Location
                    TextFormField(
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room / Classroom (Optional)',
                        hintText: 'e.g. Room 101, Science Lab',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.meeting_room),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Remarks
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (Optional)',
                        hintText: 'Additional scheduling notes',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSaving ? null : _saveEntry,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : _isEditMode
                                  ? 'Update Entry'
                                  : 'Save Schedule Entry',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
