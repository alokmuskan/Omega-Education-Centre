import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/profile_photo_helper.dart';
import '../../../shared/widgets/profile_photo_widget.dart';
import '../../settings/models/master_data_model.dart';
import '../../settings/services/institute_config_service.dart';
import '../models/teacher_model.dart';
import '../repository/teacher_repository.dart';

/// Form screen to edit an existing teacher in Omega Education Centre ERP.
class EditTeacherScreen extends StatefulWidget {
  final TeacherModel teacher;

  const EditTeacherScreen({
    super.key,
    required this.teacher,
  });

  @override
  State<EditTeacherScreen> createState() => _EditTeacherScreenState();
}

class _EditTeacherScreenState extends State<EditTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = TeacherRepository();
  final _configService = InstituteConfigService();

  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _qualificationController;
  late TextEditingController _payPerHourController;
  final TextEditingController _customSubjectController = TextEditingController();

  late List<String> _selectedSubjects;
  final List<String> _subjectsList = List.from(AppConstants.subjects);
  late DateTime _joiningDate;
  late bool _isActive;
  String? _subjectError;

  File? _tempPhotoFile;
  bool _photoRemoved = false;
  String? _profilePhotoPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.teacher.name);
    _mobileController = TextEditingController(text: widget.teacher.mobile);
    _qualificationController =
        TextEditingController(text: widget.teacher.qualification ?? '');
    _payPerHourController =
        TextEditingController(text: widget.teacher.payPerHour.toStringAsFixed(0));

    _selectedSubjects = List.from(widget.teacher.subjects);
    for (final s in _selectedSubjects) {
      if (!_subjectsList.contains(s)) _subjectsList.add(s);
    }

    try {
      _joiningDate = DateTime.parse(widget.teacher.joiningDate);
    } catch (_) {
      _joiningDate = DateTime.now();
    }

    _isActive = widget.teacher.isActive;
    _profilePhotoPath = widget.teacher.profilePhotoPath;
    _loadConfigSubjects();
  }

  Future<void> _loadConfigSubjects() async {
    final sList = await _configService.getActiveMasterNamesWithHistorical(MasterCategory.subject, null);
    if (mounted && sList.isNotEmpty) {
      setState(() {
        for (final s in sList) {
          if (!_subjectsList.contains(s)) _subjectsList.add(s);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _qualificationController.dispose();
    _payPerHourController.dispose();
    _customSubjectController.dispose();
    super.dispose();
  }

  void _addCustomSubject() {
    final text = _customSubjectController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_subjectsList.contains(text)) _subjectsList.add(text);
      if (!_selectedSubjects.contains(text)) _selectedSubjects.add(text);
      _customSubjectController.clear();
      _subjectError = null;
    });
  }

  Future<void> _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
      helpText: 'SELECT JOINING DATE',
    );
    if (picked != null) {
      setState(() => _joiningDate = picked);
    }
  }

  Future<void> _updateTeacher() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjects.isEmpty) {
      setState(() {
        _subjectError = 'Please select at least one subject';
      });
      return;
    }

    setState(() {
      _subjectError = null;
      _isSaving = true;
    });

    try {
      final now = DateTime.now().toIso8601String();
      final joiningDateStr = DateFormat('yyyy-MM-dd').format(_joiningDate);

      String? oldPhotoPath = widget.teacher.profilePhotoPath;
      String? newPhotoPath = _profilePhotoPath;

      if (_tempPhotoFile != null) {
        newPhotoPath = await ProfilePhotoHelper.saveImage(
          _tempPhotoFile!,
          'teachers',
          'teacher_${widget.teacher.id}',
        );
      } else if (_photoRemoved) {
        newPhotoPath = null;
      }

      final updatedTeacher = widget.teacher.copyWith(
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        subjects: _selectedSubjects,
        qualification: _qualificationController.text.trim().isEmpty
            ? null
            : _qualificationController.text.trim(),
        payPerHour: double.parse(_payPerHourController.text.trim()),
        joiningDate: joiningDateStr,
        isActive: _isActive,
        updatedAt: now,
        profilePhotoPath: newPhotoPath,
      );

      await _repository.updateTeacher(updatedTeacher);

      if (_tempPhotoFile != null || _photoRemoved) {
        if (oldPhotoPath != null && oldPhotoPath.isNotEmpty && oldPhotoPath != newPhotoPath) {
          await ProfilePhotoHelper.deleteImage(oldPhotoPath);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_nameController.text.trim()} updated successfully!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true); // true triggers list refresh
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update teacher: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPhotoSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_a_photo,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Teacher Photo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ProfilePhotoWidget(
              relativePath: _profilePhotoPath,
              previewFile: _tempPhotoFile,
              fallbackLetter: _nameController.text.isNotEmpty ? _nameController.text[0] : 'T',
              radius: 50,
              isEditable: true,
              onPhotoSelected: (File file) {
                setState(() {
                  _tempPhotoFile = file;
                  _photoRemoved = false;
                });
              },
              onPhotoRemoved: () {
                setState(() {
                  _tempPhotoFile = null;
                  _profilePhotoPath = null;
                  _photoRemoved = true;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              _tempPhotoFile != null || _profilePhotoPath != null
                  ? 'Photo set'
                  : 'No photo set (Optional)',
              style: TextStyle(
                color: _tempPhotoFile != null || _profilePhotoPath != null
                    ? Colors.green
                    : Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Teacher'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPhotoSection(theme),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.edit_note,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Edit Teacher Info',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Name
                      TextFormField(
                        controller: _nameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Teacher name is required';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Teacher Name *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Mobile
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          if (value.trim().length != 10) {
                            return 'Enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number *',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Multi-Select Subjects
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.subject, size: 20, color: Colors.indigo),
                              SizedBox(width: 8),
                              Text(
                                'Assigned Subjects *',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _subjectsList.map((sub) {
                              final isSelected = _selectedSubjects.contains(sub);
                              return FilterChip(
                                label: Text(sub),
                                selected: isSelected,
                                selectedColor: theme.colorScheme.primary.withAlpha(50),
                                checkmarkColor: theme.colorScheme.primary,
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      if (!_selectedSubjects.contains(sub)) _selectedSubjects.add(sub);
                                    } else {
                                      _selectedSubjects.remove(sub);
                                    }
                                    if (_selectedSubjects.isNotEmpty) _subjectError = null;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customSubjectController,
                                  decoration: const InputDecoration(
                                    hintText: 'Add another subject...',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _addCustomSubject(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 28),
                                tooltip: 'Add Subject',
                                onPressed: _addCustomSubject,
                              ),
                            ],
                          ),
                          if (_subjectError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _subjectError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Qualification
                      TextFormField(
                        controller: _qualificationController,
                        decoration: const InputDecoration(
                          labelText: 'Qualification (e.g. M.Sc. Physics)',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Pay per hour
                      TextFormField(
                        controller: _payPerHourController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Pay per hour is required';
                          }
                          final numVal = double.tryParse(value.trim());
                          if (numVal == null || numVal <= 0) {
                            return 'Pay per hour must be greater than 0';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Pay Per Hour (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee),
                          helperText:
                              'Used by Salary module: Hours Worked × Pay Per Hour',
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Joining date picker
                      GestureDetector(
                        onTap: _pickJoiningDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Joining Date *',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('d MMMM yyyy').format(_joiningDate),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Status switch
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Active Status',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(_isActive
                            ? 'Teacher is actively teaching'
                            : 'Teacher is currently inactive'),
                        value: _isActive,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _updateTeacher,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSaving ? 'Updating...' : 'Update Teacher',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
