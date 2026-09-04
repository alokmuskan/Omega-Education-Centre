import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../models/timetable_entry_model.dart';
import '../repository/timetable_repository.dart';
import 'add_edit_timetable_screen.dart';
import '../../../shared/widgets/empty_state_widget.dart';

/// Role-based screen for Timetable Management & Viewing.
class TimetableManagementScreen extends StatefulWidget {
  final int? initialTeacherId;
  final String? initialClass;
  final String? initialBatch;

  const TimetableManagementScreen({
    super.key,
    this.initialTeacherId,
    this.initialClass,
    this.initialBatch,
  });

  @override
  State<TimetableManagementScreen> createState() => _TimetableManagementScreenState();
}

class _TimetableManagementScreenState extends State<TimetableManagementScreen> {
  final _repository = TimetableRepository();

  List<TimetableEntryModel> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedDay = TimetableRepository.todayDayOfWeek;
  String _selectedClass = 'All';
  String _selectedSubject = 'All';

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<TimetableEntryModel> list = [];

      if (AppSession.instance.isTeacher) {
        final tId = AppSession.instance.currentTeacherId ?? widget.initialTeacherId;
        if (tId != null) {
          list = await _repository.getTimetableByTeacher(tId, dayOfWeek: _selectedDay);
        }
      } else if (AppSession.instance.isStudent) {
        final sClass = widget.initialClass ?? AppSession.instance.currentStudentModel?.studentClass ?? '10';
        final sBoard = AppSession.instance.currentStudentModel?.board;
        final sBatch = widget.initialBatch;
        list = await _repository.getTimetableForStudent(
          sClass,
          board: sBoard,
          batch: sBatch,
          dayOfWeek: _selectedDay,
        );
      } else {
        // Admin View
        final all = await _repository.getAllTimetableEntries();
        list = all.where((e) {
          if (_selectedDay != 'All' && e.dayOfWeek != _selectedDay) return false;
          if (_selectedClass != 'All' && e.studentClass != _selectedClass) return false;
          if (_selectedSubject != 'All' && e.subject != _selectedSubject) return false;
          return true;
        }).toList();
      }

      if (mounted) {
        setState(() {
          _entries = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load timetable: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddScreen() async {
    if (!AppSession.instance.isAdmin) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditTimetableScreen()),
    );

    if (updated == true) {
      _loadTimetable();
    }
  }

  Future<void> _openEditScreen(TimetableEntryModel entry) async {
    if (!AppSession.instance.isAdmin) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditTimetableScreen(initialEntry: entry)),
    );

    if (updated == true) {
      _loadTimetable();
    }
  }

  Future<void> _deleteEntry(TimetableEntryModel entry) async {
    if (!AppSession.instance.isAdmin) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule Entry?'),
        content: Text('Remove ${entry.subject} (Period ${entry.periodNumber}) for Class ${entry.studentClass} on ${entry.dayOfWeek}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repository.deleteTimetableEntry(entry.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted.'), backgroundColor: Colors.green),
      );
      _loadTimetable();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting entry: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = AppSession.instance.isAdmin
        ? 'Timetable Management'
        : AppSession.instance.isTeacher
            ? 'My Timetable'
            : 'My Class Timetable';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Day Selector Horizontal Bar
          Container(
            height: 48,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (AppSession.instance.isAdmin)
                  _dayChip('All'),
                ...TimetableRepository.daysOfWeek.map((d) => _dayChip(d)),
              ],
            ),
          ),

          // Admin Filter Row
          if (AppSession.instance.isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedClass,
                      decoration: const InputDecoration(labelText: 'Class', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), border: OutlineInputBorder()),
                      items: AppConstants.classesWithAll.map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Classes' : 'Class $c'))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedClass = val);
                          _loadTimetable();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSubject,
                      decoration: const InputDecoration(labelText: 'Subject', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), border: OutlineInputBorder()),
                      items: AppConstants.subjectsWithAll.map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Subjects' : s))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSubject = val);
                          _loadTimetable();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Main Timetable List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            Text(_errorMessage!),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadTimetable, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _entries.isEmpty
                        ? Center(
                            child: EmptyStateWidget(
                              icon: Icons.table_chart_outlined,
                              title: 'No timetable entries',
                              subtitle: 'No classes scheduled for $_selectedDay',
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              return _buildTimetableCard(entry);
                            },
                          ),
          ),
        ],
      ),

      floatingActionButton: AppSession.instance.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openAddScreen,
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
            )
          : null,
    );
  }

  Widget _dayChip(String day) {
    final isSelected = _selectedDay == day;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(day),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedDay = day);
            _loadTimetable();
          }
        },
      ),
    );
  }

  Widget _buildTimetableCard(TimetableEntryModel entry) {
    final teacherName = entry.teacherName ?? 'Teacher #${entry.teacherId}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PERIOD ${entry.periodNumber}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.indigo),
                          const SizedBox(width: 4),
                          Text(
                            entry.timeSlot,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (entry.room != null && entry.room!.isNotEmpty)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.purple.shade50,
                    label: Text(entry.room!, style: TextStyle(fontSize: 11, color: Colors.purple.shade900)),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.subject,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                if (AppSession.instance.isAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                    onPressed: () => _openEditScreen(entry),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _deleteEntry(entry),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 4),

            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.grey.shade200,
                  label: Text('Class ${entry.studentClass} (${entry.board})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                if (entry.batch != null && entry.batch!.isNotEmpty)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.amber.shade50,
                    label: Text(entry.batch!, style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                  ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.teal.shade50,
                  label: Text('Teacher: $teacherName', style: TextStyle(fontSize: 11, color: Colors.teal.shade900)),
                ),
              ],
            ),

            if (entry.remarks != null && entry.remarks!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Remarks: ${entry.remarks}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
