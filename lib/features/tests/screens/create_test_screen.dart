import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../settings/models/master_data_model.dart';
import '../../settings/services/institute_config_service.dart';
import '../models/test_model.dart';
import '../models/test_subject_model.dart';
import '../repository/test_repository.dart';

/// Screen to configure and create a new Examination / Test with dynamic subjects.
class CreateTestScreen extends StatefulWidget {
  final TestModel? existingTest;

  const CreateTestScreen({
    super.key,
    this.existingTest,
  });

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = TestRepository();
  final _configService = InstituteConfigService();

  late TextEditingController _titleController;
  late TextEditingController _academicYearController;
  late TextEditingController _remarksController;

  String _selectedTestType = 'Monthly Test';
  String _selectedBoard = 'CBSE';
  String _selectedClass = AppConstants.classes.first;
  DateTime _testDate = DateTime.now();

  final List<_SubjectInputRow> _subjectRows = [];
  bool _isSaving = false;

  List<String> _testTypesList = [
    'Unit Test',
    'Monthly Test',
    'Half-Yearly',
    'Pre-Board',
    'Final Exam',
    'Weekly Test',
    'Other',
  ];

  List<String> _boardsList = AppConstants.boards;
  List<String> _classesList = AppConstants.classes;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTest;
    _titleController = TextEditingController(text: t?.title ?? '');
    _academicYearController = TextEditingController(text: t?.academicYear ?? '2026-27');
    _remarksController = TextEditingController(text: t?.remarks ?? '');

    if (t != null) {
      _selectedTestType = t.testType;
      _selectedBoard = t.board;
      _selectedClass = t.studentClass;
      try {
        _testDate = DateTime.parse(t.testDate);
      } catch (_) {}

      for (final s in t.subjects) {
        _subjectRows.add(_SubjectInputRow(
          nameController: TextEditingController(text: s.subjectName),
          maxController: TextEditingController(text: s.maxMarks.toStringAsFixed(0)),
          passController: TextEditingController(text: s.passMarks.toStringAsFixed(0)),
        ));
      }
    }

    // If fresh, add 3 default subject rows
    if (_subjectRows.isEmpty) {
      _addSubjectRow(name: 'Mathematics', maxMarks: '100', passMarks: '33');
      _addSubjectRow(name: 'Physics', maxMarks: '100', passMarks: '33');
      _addSubjectRow(name: 'Chemistry', maxMarks: '100', passMarks: '33');
    }

    _loadConfigMasterData();
  }

  Future<void> _loadConfigMasterData() async {
    final activeYr = await _configService.getAcademicYear();
    if (widget.existingTest == null && activeYr.isNotEmpty) {
      _academicYearController.text = activeYr;
    }

    final ttList = await _configService.getActiveMasterNamesWithHistorical(MasterCategory.examType, _selectedTestType);
    final bList = await _configService.getActiveMasterNamesWithHistorical(MasterCategory.board, _selectedBoard);
    final cList = await _configService.getActiveMasterNamesWithHistorical(MasterCategory.studentClass, _selectedClass);

    if (mounted) {
      setState(() {
        if (ttList.isNotEmpty) _testTypesList = ttList;
        if (bList.isNotEmpty) _boardsList = bList;
        if (cList.isNotEmpty) _classesList = cList;
        if (!_testTypesList.contains(_selectedTestType)) _selectedTestType = _testTypesList.first;
        if (!_boardsList.contains(_selectedBoard)) _selectedBoard = _boardsList.first;
        if (!_classesList.contains(_selectedClass)) _selectedClass = _classesList.first;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _academicYearController.dispose();
    _remarksController.dispose();
    for (final row in _subjectRows) {
      row.nameController.dispose();
      row.maxController.dispose();
      row.passController.dispose();
    }
    super.dispose();
  }

  void _addSubjectRow({String name = '', String maxMarks = '100', String passMarks = '33'}) {
    setState(() {
      _subjectRows.add(_SubjectInputRow(
        nameController: TextEditingController(text: name),
        maxController: TextEditingController(text: maxMarks),
        passController: TextEditingController(text: passMarks),
      ));
    });
  }

  void _removeSubjectRow(int index) {
    if (_subjectRows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one subject is required for a test.')),
      );
      return;
    }
    setState(() {
      final removed = _subjectRows.removeAt(index);
      removed.nameController.dispose();
      removed.maxController.dispose();
      removed.passController.dispose();
    });
  }

  Future<void> _pickDate() async {
    // Note: Future test dates are explicitly allowed!
    final picked = await showDatePicker(
      context: context,
      initialDate: _testDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECT TEST DATE',
    );
    if (picked != null) {
      setState(() => _testDate = picked);
    }
  }

  Future<void> _saveTest() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_subjectRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one subject.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final testDateStr = DateFormat('yyyy-MM-dd').format(_testDate);

      final subjectsList = <TestSubjectModel>[];
      final subjectNamesSet = <String>{};

      for (final row in _subjectRows) {
        final name = row.nameController.text.trim();
        final lowerName = name.toLowerCase();

        if (subjectNamesSet.contains(lowerName)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Duplicate subject "$name" is not allowed in the same test.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
        subjectNamesSet.add(lowerName);

        final maxM = double.parse(row.maxController.text.trim());
        final passM = double.parse(row.passController.text.trim());

        subjectsList.add(TestSubjectModel(
          subjectName: name,
          maxMarks: maxM,
          passMarks: passM,
        ));
      }

      final test = TestModel(
        id: widget.existingTest?.id,
        title: _titleController.text.trim(),
        testType: _selectedTestType,
        board: _selectedBoard,
        studentClass: _selectedClass,
        testDate: testDateStr,
        academicYear: _academicYearController.text.trim(),
        remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
        subjects: subjectsList,
      );

      if (widget.existingTest != null) {
        await _repository.updateTestWithSubjects(test, subjectsList);
      } else {
        await _repository.insertTestWithSubjects(test, subjectsList);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test "${test.title}" saved successfully!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save test: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTest != null ? 'Edit Test' : 'Create New Test'),
        centerTitle: true,
      ),

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── General Test Info Card ───────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Information',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),

                      // Test Name
                      TextFormField(
                        controller: _titleController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Test name is required';
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Test Name / Title *',
                          prefixIcon: Icon(Icons.assignment),
                          hintText: 'e.g. August Monthly Examination',
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Row: Test Type & Board
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedTestType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Test Type *',
                                isDense: true,
                              ),
                              items: _testTypesList
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedTestType = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedBoard,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Board *',
                                isDense: true,
                              ),
                              items: _boardsList
                                  .map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedBoard = val);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Row: Class & Academic Year
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedClass,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Class *',
                                isDense: true,
                              ),
                              items: _classesList
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c.startsWith('Class') ? c : 'Class $c', overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedClass = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _academicYearController,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Academic year required';
                                return null;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Academic Year *',
                                isDense: true,
                                hintText: '2026-27',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Test Date Picker (Future allowed!)
                      GestureDetector(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Test Date *',
                            prefixIcon: Icon(Icons.calendar_month),
                            isDense: true,
                          ),
                          child: Text(
                            DateFormat('EEEE, d MMMM yyyy').format(_testDate),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Remarks
                      TextFormField(
                        controller: _remarksController,
                        decoration: const InputDecoration(
                          labelText: 'Remarks / Syllabus (optional)',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Subjects Configuration Section ────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Configured Subjects',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addSubjectRow(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Subject'),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subjectRows.length,
                itemBuilder: (context, index) {
                  return _buildSubjectRowCard(index, theme);
                },
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveTest,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_isSaving ? 'Saving Test...' : 'Save Test Configuration'),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectRowCard(int index, ThemeData theme) {
    final row = _subjectRows[index];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary.withAlpha(20),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: row.nameController,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Subject required';
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Subject Name *',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove subject',
                  onPressed: () => _removeSubjectRow(index),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.maxController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Max marks required';
                      final numVal = double.tryParse(val.trim());
                      if (numVal == null || numVal <= 0) return 'Must be > 0';
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Max Marks *',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: TextFormField(
                    controller: row.passController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Pass mark required';
                      final passVal = double.tryParse(val.trim());
                      final maxVal = double.tryParse(row.maxController.text.trim());
                      if (passVal == null || passVal < 0) return 'Must be >= 0';
                      if (maxVal != null && passVal > maxVal) {
                        return 'Cannot exceed Max (${maxVal.toStringAsFixed(0)})';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Pass Marks *',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectInputRow {
  final TextEditingController nameController;
  final TextEditingController maxController;
  final TextEditingController passController;

  _SubjectInputRow({
    required this.nameController,
    required this.maxController,
    required this.passController,
  });
}
