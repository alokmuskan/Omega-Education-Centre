import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../models/teacher_model.dart';
import '../repository/teacher_repository.dart';
import 'add_teacher_screen.dart';
import 'teacher_details_screen.dart';
import '../widgets/teacher_card.dart';
import '../widgets/teacher_search_bar.dart';

/// Main screen for managing Teachers in Omega Education Centre ERP.
class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  final TeacherRepository _repository = TeacherRepository();

  String _searchQuery = '';
  String _selectedSubject = 'All';
  String _selectedStatus = 'All'; // 'All', 'Active', 'Inactive'

  List<TeacherModel> _teachers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await _repository.searchTeachers(
        query: _searchQuery.isEmpty ? null : _searchQuery,
        subject: _selectedSubject,
        statusFilter: _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _teachers = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load teachers: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _loadTeachers();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedSubject = 'All';
      _selectedStatus = 'All';
    });
    _loadTeachers();
  }

  Future<void> _openAddTeacher() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddTeacherScreen()),
    );

    if (result == true) {
      _loadTeachers(); // Refresh list after adding teacher
    }
  }

  Future<void> _openTeacherDetails(TeacherModel teacher) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherDetailsScreen(teacher: teacher),
      ),
    );
    _loadTeachers(silent: true); // Refresh on return preserving scroll position
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

    final hasActiveFilters =
        _searchQuery.isNotEmpty || _selectedSubject != 'All' || _selectedStatus != 'All';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '${_teachers.length} teachers',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTeacher,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Teacher'),
      ),

      body: Column(
        children: [
          // ── Search & Filter Bar ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TeacherSearchBar(onChanged: _onSearchChanged),

                const SizedBox(height: 10),

                // Filter Dropdowns Row
                Row(
                  children: [
                    // Subject Filter Dropdown
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSubject,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: AppConstants.subjectsWithAll
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedSubject = val);
                            _loadTeachers();
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Status Filter Dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: AppConstants.teacherStatusesWithAll
                            .map((st) => DropdownMenuItem(
                                  value: st,
                                  child: Text(st),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                            _loadTeachers();
                          }
                        },
                      ),
                    ),
                  ],
                ),

                if (hasActiveFilters) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Clear Filters', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Teacher List Body ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _teachers.isEmpty
                        ? _buildEmptyView(hasActiveFilters)
                        : RefreshIndicator(
                            onRefresh: _loadTeachers,
                            child: ListView.builder(
                              key: const PageStorageKey<String>('teacher_list_scroll_key'),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: _teachers.length,
                              itemBuilder: (context, index) {
                                final teacher = _teachers[index];
                                return TeacherCard(
                                  teacher: teacher,
                                  onTap: () => _openTeacherDetails(teacher),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(bool hasFilters) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No teachers match your search filters.'
                  : 'No teachers added yet.\nTap "+ Add Teacher" to add your first faculty member.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Reset Filters'),
              )
            else
              ElevatedButton.icon(
                onPressed: _openAddTeacher,
                icon: const Icon(Icons.add),
                label: const Text('Add First Teacher'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadTeachers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}