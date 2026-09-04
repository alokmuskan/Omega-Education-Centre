import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../students/models/student_model.dart';
import '../../students/repository/student_repository.dart';
import '../models/homework_model.dart';
import '../models/homework_submission_model.dart';
import '../repository/homework_repository.dart';

/// Detail screen for a homework assignment.
/// Teachers see all students with submission status.
/// Students see their own submission status.
class HomeworkDetailScreen extends StatefulWidget {
  final HomeworkModel homework;
  const HomeworkDetailScreen({super.key, required this.homework});

  @override
  State<HomeworkDetailScreen> createState() => _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends State<HomeworkDetailScreen> {
  final HomeworkRepository _repo = HomeworkRepository();
  final StudentRepository _studentRepo = StudentRepository();

  List<_StudentWithSubmission> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allStudents = await _studentRepo.getStudents();
      final classStudents = allStudents
          .where((s) => s.studentClass == widget.homework.studentClass && s.isActive)
          .toList();

      final submissions = await _repo.getSubmissionsForHomework(widget.homework.id!);
      final submissionMap = {for (var s in submissions) s.studentId: s};

      _students = classStudents.map((student) {
        return _StudentWithSubmission(
          student: student,
          submission: submissionMap[student.id],
        );
      }).toList();
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
    final hw = widget.homework;
    final isOverdue = DateTime.now().isAfter(DateTime.parse(hw.dueDate));

    return Scaffold(
      appBar: AppBar(
        title: Text(hw.subject),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Homework Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _priorityColor(hw.priority).withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(hw.priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _priorityColor(hw.priority))),
                              ),
                              const SizedBox(width: 8),
                              if (isOverdue)
                                const Chip(label: Text('Overdue', style: TextStyle(fontSize: 10, color: Colors.red)), visualDensity: VisualDensity.compact),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(hw.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (hw.description != null && hw.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(hw.description!, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _infoChip(Icons.class_, 'Class ${hw.studentClass}'),
                              const SizedBox(width: 8),
                              _infoChip(Icons.calendar_today, 'Due: ${DateFormat('dd MMM yyyy').format(DateTime.parse(hw.dueDate))}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submission Stats
                  _buildSubmissionStats(),
                  const SizedBox(height: 16),

                  // Student List
                  Text(
                    'Students (${_students.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._students.map((s) => _buildStudentTile(s)),
                ],
              ),
            ),
    );
  }

  Widget _buildSubmissionStats() {
    final submitted = _students.where((s) => s.submission?.status == 'Submitted' || s.submission?.status == 'Late').length;
    final pending = _students.where((s) => s.submission == null || s.submission?.status == 'Pending').length;
    final excused = _students.where((s) => s.submission?.status == 'Excused').length;
    final total = _students.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statColumn('Total', total, Colors.blue),
            _statColumn('Submitted', submitted, Colors.green),
            _statColumn('Pending', pending, Colors.orange),
            _statColumn('Excused', excused, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildStudentTile(_StudentWithSubmission s) {
    final status = s.submission?.status ?? 'Pending';
    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(30),
          child: Icon(_statusIcon(status), color: statusColor, size: 18),
        ),
        title: Text(s.student.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          'Roll No: ${s.student.rollNo}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(action, s),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'submitted', child: Text('Mark Submitted')),
            const PopupMenuItem(value: 'excused', child: Text('Mark Excused')),
            const PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(String action, _StudentWithSubmission s) async {
    if (s.student.id == null) return;

    switch (action) {
      case 'submitted':
        await _repo.markSubmitted(widget.homework.id!, s.student.id!);
        break;
      case 'excused':
        await _repo.markExcused(widget.homework.id!, s.student.id!);
        break;
      case 'pending':
        await _repo.markPending(widget.homework.id!, s.student.id!);
        break;
    }
    _loadData();
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Urgent': return Colors.red;
      case 'Important': return Colors.orange;
      default: return Colors.teal;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Submitted': return Colors.green;
      case 'Late': return Colors.orange;
      case 'Excused': return Colors.grey;
      default: return Colors.blue;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Submitted': return Icons.check_circle;
      case 'Late': return Icons.schedule;
      case 'Excused': return Icons.airline_seat_recline_normal;
      default: return Icons.pending;
    }
  }
}

class _StudentWithSubmission {
  final StudentModel student;
  final HomeworkSubmissionModel? submission;
  _StudentWithSubmission({required this.student, this.submission});
}
