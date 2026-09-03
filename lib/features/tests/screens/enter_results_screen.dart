import 'package:flutter/material.dart';

import '../../students/models/student_model.dart';
import '../../students/repository/student_repository.dart';
import '../models/test_model.dart';
import '../models/test_result_model.dart';
import '../repository/test_result_repository.dart';

/// Screen for entering student marks for a test (Supports bulk & gradual entry).
class EnterResultsScreen extends StatefulWidget {
  final TestModel test;

  const EnterResultsScreen({
    super.key,
    required this.test,
  });

  @override
  State<EnterResultsScreen> createState() => _EnterResultsScreenState();
}

class _EnterResultsScreenState extends State<EnterResultsScreen> {
  final _resultRepo = TestResultRepository();
  final _studentRepo = StudentRepository();

  List<_StudentMarkEntry> _entries = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudentsAndExistingMarks();
  }

  Future<void> _loadStudentsAndExistingMarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch active students in class
      final studentsList = await _studentRepo.searchStudents(
        studentClass: widget.test.studentClass,
      );

      // 2. Fetch existing recorded results for this test
      final recordedResults = await _resultRepo.getResultsByTest(widget.test.id!);

      final entriesList = <_StudentMarkEntry>[];

      for (final s in studentsList) {
        final subjectControllers = <int, TextEditingController>{};

        for (final subj in widget.test.subjects) {
          final resList = recordedResults.where(
            (r) => r.studentId == s.id && r.testSubjectId == subj.id,
          );

          final initialValue = resList.isNotEmpty
              ? resList.first.marksObtained.toStringAsFixed(
                  resList.first.marksObtained.truncateToDouble() == resList.first.marksObtained ? 0 : 1,
                )
              : '';

          subjectControllers[subj.id!] = TextEditingController(text: initialValue);
        }

        entriesList.add(_StudentMarkEntry(
          student: s,
          subjectControllers: subjectControllers,
        ));
      }

      if (mounted) {
        setState(() {
          _entries = entriesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load test results: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAllResults() async {
    // Validate marks inputs
    final resultsToSave = <TestResultModel>[];

    for (final entry in _entries) {
      for (final subj in widget.test.subjects) {
        final controller = entry.subjectControllers[subj.id!];
        final text = controller?.text.trim() ?? '';
        if (text.isEmpty) continue; // Gradual entry: skip empty fields

        final marks = double.tryParse(text);
        if (marks == null || marks < 0) {
          _showError('Invalid marks for ${entry.student.name} in ${subj.subjectName}.');
          return;
        }

        if (marks > subj.maxMarks) {
          _showError(
            '${entry.student.name}\'s ${subj.subjectName} marks ($text) exceed Max Marks (${subj.maxMarks.toStringAsFixed(0)}).',
          );
          return;
        }

        resultsToSave.add(TestResultModel(
          testId: widget.test.id!,
          studentId: entry.student.id!,
          testSubjectId: subj.id!,
          marksObtained: marks,
        ));
      }
    }

    if (resultsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No marks entered to save.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _resultRepo.saveOrUpdateResultsBatch(resultsToSave);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${resultsToSave.length} mark entries saved successfully!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      _showError('Failed to save results: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final test = widget.test;

    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Results — ${test.title}'),
        centerTitle: true,
      ),

      body: Column(
        children: [
          // ── Header Summary Card ───────────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${test.studentClass} • ${test.board} • ${test.testType}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Date: ${test.testDate} • Year: ${test.academicYear}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Subjects (${test.subjects.length}): ${test.subjects.map((s) => '${s.subjectName} (${s.maxMarks.toStringAsFixed(0)})').join(', ')}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Students Marks Entry List ────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _entries.isEmpty
                        ? _buildEmptyView()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              return _buildStudentMarkTile(_entries[index], theme);
                            },
                          ),
          ),
        ],
      ),

      // ── Sticky Save Bar ──────────────────────────────────────────────
      bottomSheet: _isLoading || _entries.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAllResults,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving Marks...' : 'Save All Entered Marks'),
                ),
              ),
            ),
    );
  }

  Widget _buildStudentMarkTile(_StudentMarkEntry entry, ThemeData theme) {
    final s = entry.student;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Title & Roll
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary.withAlpha(20),
                  child: Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${s.name} (Roll ${s.rollNo})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Marks Input per subject
            Column(
              children: widget.test.subjects.map((subj) {
                final controller = entry.subjectControllers[subj.id!];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${subj.subjectName} (Max: ${subj.maxMarks.toStringAsFixed(0)}, Pass: ${subj.passMarks.toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '0 - ${subj.maxMarks.toStringAsFixed(0)}',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            suffixText: '/ ${subj.maxMarks.toStringAsFixed(0)}',
                            suffixStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No active students found in ${widget.test.studentClass}.',
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
            onPressed: _loadStudentsAndExistingMarks,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _StudentMarkEntry {
  final StudentModel student;
  final Map<int, TextEditingController> subjectControllers;

  _StudentMarkEntry({
    required this.student,
    required this.subjectControllers,
  });
}
