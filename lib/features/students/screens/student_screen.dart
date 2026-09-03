import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../models/student_model.dart';
import '../repository/student_repository.dart';
import '../widgets/board_filter.dart';
import '../widgets/class_filter.dart';
import '../widgets/search_bar.dart';
import '../widgets/student_card.dart';
import 'add_student_screen.dart';
import 'student_details_screen.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final StudentRepository _repo = StudentRepository();

  String _selectedBoard = 'All';
  String _selectedClass = 'All';
  String _searchQuery = '';

  List<StudentModel> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final results = await _repo.searchStudents(
        query: _searchQuery.isEmpty ? null : _searchQuery,
        board: _selectedBoard,
        studentClass: _selectedClass,
      );
      if (mounted) {
        setState(() {
          _students = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    _loadStudents();
  }

  Future<void> _openAddStudent() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
    );
    if (result == true) {
      _loadStudents(); // refresh list after successful admission
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.instance.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: Administrator privileges required.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${_students.length} students',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStudent,
        icon: const Icon(Icons.person_add),
        label: const Text('New Admission'),
      ),

      body: Column(
        children: [
          // ── Search + Filters ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                StudentSearchBar(onChanged: _onSearchChanged),
                const SizedBox(height: 10),
                BoardFilter(
                  boards: AppConstants.boardsWithAll,
                  selectedBoard: _selectedBoard,
                  onSelected: (v) {
                    setState(() => _selectedBoard = v);
                    _loadStudents();
                  },
                ),
                const SizedBox(height: 8),
                ClassFilter(
                  classes: AppConstants.classesWithAll,
                  selectedClass: _selectedClass,
                  onSelected: (v) {
                    setState(() => _selectedClass = v);
                    _loadStudents();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Student List ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadStudents,
                        child: ListView.builder(
                          key: const PageStorageKey<String>('student_list_scroll_key'),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final student = _students[index];
                            return StudentCard(
                              student: student,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StudentDetailsScreen(student: student),
                                  ),
                                );
                                _loadStudents(silent: true);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty &&
                    _selectedBoard == 'All' &&
                    _selectedClass == 'All'
                ? 'No students enrolled yet.\nTap + to add the first student.'
                : 'No students match your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}