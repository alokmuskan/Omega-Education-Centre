import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../../../shared/utils/attendance_date_validator.dart';
import '../../teachers/models/teacher_model.dart';
import '../../teachers/repository/teacher_repository.dart';
import '../../settings/models/master_data_model.dart';
import '../../settings/services/institute_config_service.dart';
import '../models/daily_class_record_model.dart';
import '../repository/daily_class_record_repository.dart';

/// Screen for teachers to log daily classes conducted or for admins to edit logs.
class AddEditClassRecordScreen extends StatefulWidget {
  final DailyClassRecordModel? initialRecord;
  final int? preselectedTeacherId;

  const AddEditClassRecordScreen({
    super.key,
    this.initialRecord,
    this.preselectedTeacherId,
  });

  @override
  State<AddEditClassRecordScreen> createState() => _AddEditClassRecordScreenState();
}

class _AddEditClassRecordScreenState extends State<AddEditClassRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = DailyClassRecordRepository();
  final _teacherRepository = TeacherRepository();
  final _configService = InstituteConfigService();

  late DateTime _selectedDate;
  late String _selectedClass;
  late String _selectedBoard;
  late TextEditingController _batchController;

  int? _teacherId;
  TeacherModel? _resolvedTeacher;
  late String _selectedSubject;

  List<String> _classesList = AppConstants.classes;
  List<String> _boardsList = AppConstants.boards;
  List<String> _subjectsList = AppConstants.subjects;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late TextEditingController _durationController;

  late TextEditingController _topicController;
  late TextEditingController _homeworkController;
  late TextEditingController _remarksController;

  List<TeacherModel> _availableTeachers = [];
  bool _isLoadingTeachers = true;
  bool _isSaving = false;
  String? _timeError;

  bool get _isEditMode => widget.initialRecord != null;

  @override
  void initState() {
    super.initState();
    final rec = widget.initialRecord;

    // Resolve teacher ID priority:
    // 1. Initial record teacherId
    // 2. Preselected teacherId argument
    // 3. AppSession teacherId (if logged in as Teacher)
    _teacherId = rec?.teacherId ??
        widget.preselectedTeacherId ??
        AppSession.instance.currentTeacherId;

    if (rec != null) {
      DateTime dt;
      try {
        dt = DateTime.parse(rec.date);
      } catch (_) {
        dt = DateTime.now();
      }
      _selectedDate = AttendanceDateValidator.isFutureDateTime(dt) ? DateTime.now() : dt;
      _selectedClass = rec.studentClass;
      _selectedBoard = rec.board;
      _batchController = TextEditingController(text: rec.batch ?? '');
      _selectedSubject = rec.subject;
      _startTime = _parseTimeOfDay(rec.startTime);
      _endTime = _parseTimeOfDay(rec.endTime);
      _durationController = TextEditingController(text: rec.durationMinutes.toString());
      _topicController = TextEditingController(text: rec.topic);
      _homeworkController = TextEditingController(text: rec.homework ?? '');
      _remarksController = TextEditingController(text: rec.remarks ?? '');
    } else {
      _selectedDate = DateTime.now();
      _selectedClass = AppConstants.classes.contains('10') ? '10' : AppConstants.classes.first;
      _selectedBoard = AppConstants.boards.first;
      _batchController = TextEditingController();
      _selectedSubject = AppConstants.subjects.first;
      _durationController = TextEditingController(text: '60');
      _topicController = TextEditingController();
      _homeworkController = TextEditingController();
      _remarksController = TextEditingController();
    }

    _loadTeachers();
    _loadConfigMasterData();
  }

  Future<void> _loadConfigMasterData() async {
    final cList = await _configService.getActiveMasterNamesWithHistorical(MasterCategory.studentClass, _selectedClass);
    final bList = await _configService.getActiveMasterNamesWithHistorical(MasterCategory.board, _selectedBoard);
    final sList = await _configService.getActiveMasterNamesWithHistorical(MasterCategory.subject, _selectedSubject);
    if (mounted) {
      setState(() {
        if (cList.isNotEmpty) _classesList = cList;
        if (bList.isNotEmpty) _boardsList = bList;
        if (sList.isNotEmpty) _subjectsList = sList;
        if (!_classesList.contains(_selectedClass)) _selectedClass = _classesList.first;
        if (!_boardsList.contains(_selectedBoard)) _selectedBoard = _boardsList.first;
        if (!_subjectsList.contains(_selectedSubject)) _selectedSubject = _subjectsList.first;
      });
    }
  }

  @override
  void dispose() {
    _batchController.dispose();
    _durationController.dispose();
    _topicController.dispose();
    _homeworkController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final format = DateFormat.jm();
      final dt = format.parse(timeStr);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  String? _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return null;
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _loadTeachers() async {
    try {
      final allTeachers = await _teacherRepository.getTeachers();

      if (!mounted) return;

      setState(() {
        _availableTeachers = allTeachers;
        _isLoadingTeachers = false;

        // If teacherId is resolved, fetch model
        if (_teacherId != null) {
          _resolvedTeacher = allTeachers.where((t) => t.id == _teacherId).firstOrNull;
          if (_resolvedTeacher != null && !_isEditMode) {
            final tSubj = _resolvedTeacher!.subject;
            if (tSubj.isNotEmpty && AppConstants.subjects.contains(tSubj)) {
              _selectedSubject = tSubj;
            }
          }
        } else if (allTeachers.isNotEmpty && !_isEditMode) {
          // If no session teacher and Admin mode, pick first teacher by default
          _teacherId = allTeachers.first.id;
          _resolvedTeacher = allTeachers.first;
          if (allTeachers.first.subject.isNotEmpty && AppConstants.subjects.contains(allTeachers.first.subject)) {
            _selectedSubject = allTeachers.first.subject;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  void _onAdminTeacherSelect(int? newId) {
    if (newId == null) return;
    setState(() {
      _teacherId = newId;
      _resolvedTeacher = _availableTeachers.where((t) => t.id == newId).firstOrNull;
      if (_resolvedTeacher != null && _resolvedTeacher!.subject.isNotEmpty) {
        if (AppConstants.subjects.contains(_resolvedTeacher!.subject)) {
          _selectedSubject = _resolvedTeacher!.subject;
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: AttendanceDateValidator.todayNormalized,
    );

    if (picked != null) {
      if (AttendanceDateValidator.isFutureDateTime(picked)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Future dates cannot be selected for daily teaching logs.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _recalculateDuration();
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 9, minute: 30),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _recalculateDuration();
      });
    }
  }

  void _recalculateDuration() {
    _timeError = null;
    if (_startTime != null && _endTime != null) {
      final startMins = _startTime!.hour * 60 + _startTime!.minute;
      final endMins = _endTime!.hour * 60 + _endTime!.minute;
      final diff = endMins - startMins;

      if (diff <= 0) {
        setState(() {
          _timeError = 'End time cannot be before or equal to start time.';
        });
      } else {
        setState(() {
          _durationController.text = diff.toString();
        });
      }
    }
  }

  Future<void> _saveRecord() async {
    if (_isSaving) return;

    final session = AppSession.instance;
    if (session.isTeacher) {
      _teacherId = session.currentTeacherId;
      _resolvedTeacher = session.currentTeacherModel;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher identity could not be resolved. Please select a valid teacher.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_timeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_timeError!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final dateStr = AttendanceDateValidator.formatDateIso(_selectedDate);
    if (AttendanceDateValidator.isFutureDate(dateStr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Future teaching logs cannot be saved.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final durationMins = int.tryParse(_durationController.text.trim()) ?? 60;
    if (durationMins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Duration must be greater than 0 minutes.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final record = DailyClassRecordModel(
        id: widget.initialRecord?.id,
        date: dateStr,
        studentClass: _selectedClass,
        board: _selectedBoard,
        batch: _batchController.text.trim().isNotEmpty ? _batchController.text.trim() : null,
        teacherId: _teacherId!,
        teacherName: _resolvedTeacher?.name,
        subject: _selectedSubject,
        startTime: _formatTimeOfDay(_startTime),
        endTime: _formatTimeOfDay(_endTime),
        durationMinutes: durationMins,
        topic: _topicController.text.trim(),
        homework: _homeworkController.text.trim().isNotEmpty ? _homeworkController.text.trim() : null,
        remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
        createdAt: widget.initialRecord?.createdAt,
      );

      if (_isEditMode) {
        await _repository.updateRecord(record);
      } else {
        await _repository.insertRecord(record);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode ? 'Teaching log updated successfully.' : 'Teaching log saved successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving teaching log: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    if (session.isStudent) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: Students are not authorized to log classes.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (session.isTeacher) {
      if (widget.initialRecord != null && widget.initialRecord!.teacherId != session.currentTeacherId) {
        return const Scaffold(
          body: Center(
            child: Text(
              'Access Denied: You are not authorized to edit this record as it belongs to another teacher.',
              style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    }

    final theme = Theme.of(context);
    final dateDisplay = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);

    // Show locked read-only section if Teacher identity is fixed (e.g. Teacher Mode or preselected)
    final bool isTeacherIdentityLocked = widget.preselectedTeacherId != null ||
        AppSession.instance.isTeacher ||
        widget.initialRecord != null;

    final teacherDisplayName = _resolvedTeacher?.name ?? 'Teacher ID #$_teacherId';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Teaching Log' : 'Add Teaching Log'),
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
                    // Teacher Read-Only Container OR Admin Selector
                    if (isTeacherIdentityLocked)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TEACHER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    teacherDisplayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Automatically identified',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _teacherId,
                        decoration: const InputDecoration(
                          labelText: 'Teacher *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: _availableTeachers.map((t) {
                          final label = t.isActive ? t.name : '${t.name} (Inactive)';
                          return DropdownMenuItem(value: t.id, child: Text(label));
                        }).toList(),
                        onChanged: _onAdminTeacherSelect,
                        validator: (val) => val == null ? 'Please select a teacher' : null,
                      ),

                    const SizedBox(height: 16),

                    // Date Selector Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today, color: Colors.indigo),
                        title: const Text('Date Conducted', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(
                          dateDisplay,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _pickDate,
                          child: const Text('Change Date'),
                        ),
                      ),
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
                            items: _classesList.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c.startsWith('Class') ? c : 'Class $c'));
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
                            items: _boardsList.map((b) {
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

                    // Batch Field
                    TextFormField(
                      controller: _batchController,
                      decoration: const InputDecoration(
                        labelText: 'Batch Name (e.g. Udaan Batch)',
                        hintText: 'e.g. Morning Batch, Udaan',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.groups),
                      ),
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
                      items: _subjectsList.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSubject = val);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Start Time & End Time Pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickStartTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Time',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(
                                _formatTimeOfDay(_startTime) ?? '08:00 AM',
                                style: TextStyle(
                                  color: _startTime != null ? Colors.black87 : Colors.grey.shade600,
                                ),
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
                                labelText: 'End Time',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time_filled),
                              ),
                              child: Text(
                                _formatTimeOfDay(_endTime) ?? '09:30 AM',
                                style: TextStyle(
                                  color: _endTime != null ? Colors.black87 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_timeError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _timeError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Duration (Auto-calculated)
                    TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (Minutes) *',
                        hintText: 'Auto calculated (e.g. 60, 90)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter duration in minutes';
                        final mins = int.tryParse(val.trim());
                        if (mins == null || mins <= 0) return 'Duration must be > 0 minutes';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Topic Covered (Required *)
                    TextFormField(
                      controller: _topicController,
                      decoration: const InputDecoration(
                        labelText: 'Topic Covered *',
                        hintText: 'e.g. Quadratic Equations, Chapter 3 Intro',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.topic),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter topic covered';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Homework / Assignment (Optional)
                    TextFormField(
                      controller: _homeworkController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Homework / Assignment (Optional)',
                        hintText: 'e.g. Exercise 4.2 Q1 to Q10',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Remarks (Optional)
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (Optional)',
                        hintText: 'Additional notes or class feedback',
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveRecord,
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
                                  ? 'Update Teaching Log'
                                  : 'Save Teaching Log',
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
