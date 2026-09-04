import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/homework_model.dart';
import '../repository/homework_repository.dart';
import 'homework_detail_screen.dart';

/// Teacher view: list all homework, assign new, track submissions.
class HomeworkListScreen extends StatefulWidget {
  const HomeworkListScreen({super.key});

  @override
  State<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends State<HomeworkListScreen> {
  final HomeworkRepository _repo = HomeworkRepository();
  List<HomeworkModel> _homeworkList = [];
  bool _isLoading = true;
  String _filterClass = 'All';

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() => _isLoading = true);
    try {
      _homeworkList = await _repo.getHomework(
        studentClass: _filterClass == 'All' ? null : _filterClass,
      );
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
        title: const Text('Homework'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Class filter
                _buildClassFilter(),
                // Homework list
                Expanded(
                  child: _homeworkList.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.assignment_outlined,
                          title: 'No homework assigned',
                          subtitle: 'Tap + to assign homework to a class',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadHomework,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _homeworkList.length,
                            itemBuilder: (context, index) => _buildHomeworkCard(_homeworkList[index]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAssignHomeworkSheet(),
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
                  _loadHomework();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHomeworkCard(HomeworkModel hw) {
    final isOverdue = DateTime.now().isAfter(DateTime.parse(hw.dueDate));
    final daysLeft = DateTime.parse(hw.dueDate).difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HomeworkDetailScreen(homework: hw)),
        ).then((_) => _loadHomework()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Priority badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _priorityColor(hw.priority).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hw.priority,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _priorityColor(hw.priority)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Subject badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(hw.subject, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                  const Spacer(),
                  // Due status
                  if (isOverdue)
                    const Text('Overdue', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold))
                  else
                    Text(
                      daysLeft == 0 ? 'Due today' : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                      style: TextStyle(
                        fontSize: 11,
                        color: daysLeft <= 1 ? Colors.orange : Colors.grey.shade600,
                        fontWeight: daysLeft <= 1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(hw.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (hw.description != null && hw.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(hw.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.class_, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('Class ${hw.studentClass}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${DateFormat('dd MMM').format(DateTime.parse(hw.dueDate))}',
                    style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignHomeworkSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignHomeworkSheet(
        onSave: (hw) async {
          Navigator.pop(context);
          await _repo.insertHomework(hw);
          _loadHomework();
        },
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Urgent': return Colors.red;
      case 'Important': return Colors.orange;
      default: return Colors.teal;
    }
  }
}

// ── Assign Homework Bottom Sheet ──────────────────────────────────

class _AssignHomeworkSheet extends StatefulWidget {
  final Function(HomeworkModel) onSave;
  const _AssignHomeworkSheet({required this.onSave});

  @override
  State<_AssignHomeworkSheet> createState() => _AssignHomeworkSheetState();
}

class _AssignHomeworkSheetState extends State<_AssignHomeworkSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedClass = AppConstants.classes.isNotEmpty ? AppConstants.classes.first : '10';
  String _selectedSubject = AppConstants.subjects.isNotEmpty ? AppConstants.subjects.first : 'General';
  String _selectedPriority = 'Normal';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  static const _priorities = ['Normal', 'Important', 'Urgent'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
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
              const Text('Assign Homework', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
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
                      initialValue: _selectedSubject,
                      decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                      items: AppConstants.subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _selectedSubject = v ?? _selectedSubject),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPriority,
                      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                      items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setState(() => _selectedPriority = v ?? 'Normal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Due Date', style: TextStyle(fontSize: 12)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(_dueDate)),
                      trailing: const Icon(Icons.calendar_today, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    final teacherId = AppSession.instance.currentTeacherId ?? 0;
                    widget.onSave(HomeworkModel(
                      title: _titleController.text.trim(),
                      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                      studentClass: _selectedClass,
                      subject: _selectedSubject,
                      teacherId: teacherId,
                      assignedDate: DateTime.now().toIso8601String().substring(0, 10),
                      dueDate: DateFormat('yyyy-MM-dd').format(_dueDate),
                      priority: _selectedPriority,
                      createdAt: DateTime.now().toIso8601String(),
                    ));
                  },
                  child: const Text('Assign Homework'),
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
