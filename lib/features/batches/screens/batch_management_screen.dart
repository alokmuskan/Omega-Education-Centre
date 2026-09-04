import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../students/models/student_model.dart';
import '../../students/repository/student_repository.dart';
import '../../teachers/models/teacher_model.dart';
import '../../teachers/repository/teacher_repository.dart';
import '../models/batch_model.dart';
import '../repository/batch_repository.dart';

/// Batch Management screen for creating batches and assigning students.
class BatchManagementScreen extends StatefulWidget {
  const BatchManagementScreen({super.key});

  @override
  State<BatchManagementScreen> createState() => _BatchManagementScreenState();
}

class _BatchManagementScreenState extends State<BatchManagementScreen> {
  final BatchRepository _batchRepo = BatchRepository();
  final TeacherRepository _teacherRepo = TeacherRepository();
  List<BatchModel> _batches = [];
  List<TeacherModel> _teachers = [];
  bool _isLoading = true;
  String _filterClass = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _batches = await _batchRepo.getBatches(
        studentClass: _filterClass == 'All' ? null : _filterClass,
      );
      _teachers = await _teacherRepo.getTeachers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Management'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildClassFilter(),
                Expanded(
                  child: _batches.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.groups_outlined,
                          title: 'No batches created',
                          subtitle: 'Create batches to organize students by timing or group',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _batches.length,
                            itemBuilder: (context, index) => _buildBatchCard(_batches[index]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBatchForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildClassFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ['All', ...AppConstants.classes].map((cls) {
          final isSelected = _filterClass == cls;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: ChoiceChip(
              label: Text(cls, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _filterClass = cls);
                  _loadData();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBatchCard(BatchModel batch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showBatchDetail(batch),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      batch.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton(
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'students', child: Text('Manage Students')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (v) => _handleBatchAction(v, batch),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.class_, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('Class ${batch.studentClass} • ${batch.board}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                  if (batch.startTime != null) ...[
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('${batch.startTime} — ${batch.endTime ?? '?'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ],
              ),
              if (batch.description != null && batch.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(batch.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
              const SizedBox(height: 6),
              FutureBuilder<int>(
                future: _batchRepo.getStudentCount(batch.id!),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '$count / ${batch.maxStudents} students',
                        style: TextStyle(
                          fontSize: 12,
                          color: count >= batch.maxStudents ? Colors.red : Colors.grey.shade600,
                          fontWeight: count >= batch.maxStudents ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBatchForm({BatchModel? batch}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BatchFormSheet(
        batch: batch,
        teachers: _teachers,
        onSave: (b) async {
          Navigator.pop(context);
          if (batch == null) {
            await _batchRepo.insertBatch(b);
          } else {
            await _batchRepo.updateBatch(b);
          }
          _loadData();
        },
      ),
    );
  }

  void _showBatchDetail(BatchModel batch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BatchDetailScreen(
          batch: batch,
          onUpdated: _loadData,
        ),
      ),
    );
  }

  void _handleBatchAction(String action, BatchModel batch) async {
    if (action == 'edit') {
      _showBatchForm(batch: batch);
    } else if (action == 'students') {
      _showBatchDetail(batch);
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Batch?'),
          content: Text('Delete "${batch.name}"? Students will not be removed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _batchRepo.deleteBatch(batch.id!);
        _loadData();
      }
    }
  }
}

// ── Batch Form Sheet ─────────────────────────────────────────────

class _BatchFormSheet extends StatefulWidget {
  final BatchModel? batch;
  final List<TeacherModel> teachers;
  final Function(BatchModel) onSave;
  const _BatchFormSheet({this.batch, required this.teachers, required this.onSave});

  @override
  State<_BatchFormSheet> createState() => _BatchFormSheetState();
}

class _BatchFormSheetState extends State<_BatchFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _maxStudentsController = TextEditingController(text: '40');
  String _selectedClass = AppConstants.classes.isNotEmpty ? AppConstants.classes.first : '10';
  String _selectedBoard = 'CBSE';
  int? _selectedTeacherId;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    if (widget.batch != null) {
      _nameController.text = widget.batch!.name;
      _descController.text = widget.batch!.description ?? '';
      _maxStudentsController.text = widget.batch!.maxStudents.toString();
      _selectedClass = widget.batch!.studentClass;
      _selectedBoard = widget.batch!.board;
      _selectedTeacherId = widget.batch!.teacherId;
      if (widget.batch!.startTime != null) {
        _startTime = _parseTime(widget.batch!.startTime!);
      }
      if (widget.batch!.endTime != null) {
        _endTime = _parseTime(widget.batch!.endTime!);
      }
    }
  }

  TimeOfDay? _parseTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _maxStudentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.batch == null ? 'Create Batch' : 'Edit Batch',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Batch Name *', hintText: 'e.g. Morning Batch A', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedClass,
                      decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                      items: AppConstants.classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedClass = v ?? _selectedClass),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedBoard,
                      decoration: const InputDecoration(labelText: 'Board', border: OutlineInputBorder()),
                      items: AppConstants.boards.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) => setState(() => _selectedBoard = v ?? _selectedBoard),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start Time', style: TextStyle(fontSize: 12)),
                      subtitle: Text(_startTime != null ? _formatTime(_startTime!) : 'Not set'),
                      trailing: const Icon(Icons.access_time, size: 20),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0));
                        if (picked != null) setState(() => _startTime = picked);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End Time', style: TextStyle(fontSize: 12)),
                      subtitle: Text(_endTime != null ? _formatTime(_endTime!) : 'Not set'),
                      trailing: const Icon(Icons.access_time, size: 20),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0));
                        if (picked != null) setState(() => _endTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedTeacherId,
                decoration: const InputDecoration(labelText: 'Assigned Teacher (optional)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...widget.teachers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                ],
                onChanged: (v) => setState(() => _selectedTeacherId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxStudentsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Students', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    widget.onSave(BatchModel(
                      id: widget.batch?.id,
                      name: _nameController.text.trim(),
                      studentClass: _selectedClass,
                      board: _selectedBoard,
                      startTime: _startTime != null ? _formatTime(_startTime!) : null,
                      endTime: _endTime != null ? _formatTime(_endTime!) : null,
                      teacherId: _selectedTeacherId,
                      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                      maxStudents: int.tryParse(_maxStudentsController.text) ?? 40,
                      createdAt: widget.batch?.createdAt ?? DateTime.now().toIso8601String(),
                    ));
                  },
                  child: Text(widget.batch == null ? 'Create Batch' : 'Save Changes'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Batch Detail Screen (Student Management) ─────────────────────

class _BatchDetailScreen extends StatefulWidget {
  final BatchModel batch;
  final VoidCallback onUpdated;
  const _BatchDetailScreen({required this.batch, required this.onUpdated});

  @override
  State<_BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<_BatchDetailScreen> {
  final BatchRepository _batchRepo = BatchRepository();
  final StudentRepository _studentRepo = StudentRepository();
  List<StudentModel> _allStudents = [];
  Set<int> _enrolledIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _allStudents = await _studentRepo.getStudents();
      final enrolledIds = await _batchRepo.getStudentIdsInBatch(widget.batch.id!);
      _enrolledIds = enrolledIds.toSet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.batch.name} — Students'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allStudents.isEmpty
              ? const EmptyStateWidget.noStudents()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allStudents.length,
                  itemBuilder: (context, index) {
                    final student = _allStudents[index];
                    final isEnrolled = _enrolledIds.contains(student.id);
                    return CheckboxListTile(
                      value: isEnrolled,
                      onChanged: (val) => _toggleStudent(student.id!, val ?? false),
                      title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Roll #${student.rollNo} • Class ${student.studentClass}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    );
                  },
                ),
    );
  }

  Future<void> _toggleStudent(int studentId, bool enroll) async {
    if (enroll) {
      await _batchRepo.addStudentToBatch(widget.batch.id!, studentId);
    } else {
      await _batchRepo.removeStudentFromBatch(widget.batch.id!, studentId);
    }
    _loadData();
    widget.onUpdated();
  }
}
