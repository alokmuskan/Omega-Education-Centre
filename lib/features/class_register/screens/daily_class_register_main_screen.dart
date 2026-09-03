import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../../../shared/utils/attendance_date_validator.dart';
import '../../teachers/models/teacher_model.dart';
import '../../teachers/repository/teacher_repository.dart';
import '../models/daily_class_record_model.dart';
import '../repository/daily_class_record_repository.dart';
import '../widgets/class_record_details_dialog.dart';
import 'add_edit_class_record_screen.dart';

/// Role-based screen for Teacher Daily Teaching Log & Admin Monitoring Module.
class DailyClassRegisterMainScreen extends StatefulWidget {
  final int? initialTeacherId;

  const DailyClassRegisterMainScreen({
    super.key,
    this.initialTeacherId,
  });

  @override
  State<DailyClassRegisterMainScreen> createState() => _DailyClassRegisterMainScreenState();
}

class _DailyClassRegisterMainScreenState extends State<DailyClassRegisterMainScreen> {
  final _repository = DailyClassRecordRepository();
  final _teacherRepository = TeacherRepository();

  final _searchController = TextEditingController();

  List<DailyClassRecordModel> _records = [];
  List<TeacherModel> _teachers = [];
  List<TeacherModel> _pendingTeachers = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter States
  String _selectedClass = 'All';
  String _selectedBoard = 'All';
  int? _selectedTeacherId;
  String _selectedSubject = 'All';
  String _selectedDateFilter = 'All Time'; // 'All Time' | 'Today' | 'This Week' | 'This Month' | 'Custom'
  DateTimeRange? _customDateRange;

  // Daily Summary Stats
  int _dailyClassCount = 0;
  double _dailyTeachingHours = 0.0;
  int _submittedTeacherCount = 0;

  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    final session = AppSession.instance;
    if (session.isStudent || (session.isTeacher && widget.initialTeacherId != session.currentTeacherId)) {
      _accessDenied = true;
      _isLoading = false;
      return;
    }
    // Role-based teacher ID resolution
    if (AppSession.instance.isTeacher) {
      _selectedTeacherId = AppSession.instance.currentTeacherId;
    } else {
      _selectedTeacherId = widget.initialTeacherId;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final teachersList = await _teacherRepository.getTeachers();

      String? sDate;
      String? eDate;
      if (_selectedDateFilter == 'Custom' && _customDateRange != null) {
        sDate = DateFormat('yyyy-MM-dd').format(_customDateRange!.start);
        eDate = DateFormat('yyyy-MM-dd').format(_customDateRange!.end);
      }

      // Enforce Teacher isolation at repository query level
      final targetTeacherId = AppSession.instance.isTeacher
          ? AppSession.instance.currentTeacherId
          : _selectedTeacherId;

      final recordsList = await _repository.getRecordsFiltered(
        searchQuery: _searchController.text,
        studentClass: _selectedClass,
        board: _selectedBoard,
        teacherId: targetTeacherId,
        subject: _selectedSubject,
        dateFilter: _selectedDateFilter == 'All Time' ? null : _selectedDateFilter,
        startDate: sDate,
        endDate: eDate,
      );

      // Load Daily Admin Summary Stats for Today if Admin
      int classCnt = 0;
      double hours = 0.0;
      int subCount = 0;
      List<TeacherModel> pending = [];

      if (AppSession.instance.isAdmin) {
        final todayStr = AttendanceDateValidator.todayIso;
        final summary = await _repository.getDailyMonitoringSummary(todayStr);
        classCnt = summary['totalClasses'] as int? ?? 0;
        hours = (summary['totalHours'] as num? ?? 0.0).toDouble();
        subCount = summary['submittedCount'] as int? ?? 0;
        pending = (summary['pendingTeachers'] as List<TeacherModel>?) ?? [];
      } else {
        classCnt = recordsList.length;
        final totalMins = recordsList.fold<int>(0, (sum, r) => sum + r.durationMinutes);
        hours = totalMins / 60.0;
      }

      if (mounted) {
        setState(() {
          _teachers = teachersList;
          _records = recordsList;
          _dailyClassCount = classCnt;
          _dailyTeachingHours = hours;
          _submittedTeacherCount = subCount;
          _pendingTeachers = pending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load teaching logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedClass = 'All';
      _selectedBoard = 'All';
      if (!AppSession.instance.isTeacher && widget.initialTeacherId == null) {
        _selectedTeacherId = null;
      }
      _selectedSubject = 'All';
      _selectedDateFilter = 'All Time';
      _customDateRange = null;
    });
    _loadData();
  }

  bool get _hasActiveFilters {
    final defaultTeacher = AppSession.instance.isTeacher
        ? AppSession.instance.currentTeacherId
        : widget.initialTeacherId;

    return _searchController.text.isNotEmpty ||
        _selectedClass != 'All' ||
        _selectedBoard != 'All' ||
        (_selectedTeacherId != null && _selectedTeacherId != defaultTeacher) ||
        _selectedSubject != 'All' ||
        _selectedDateFilter != 'All Time';
  }

  Future<void> _openAddScreen() async {
    final targetTeacher = AppSession.instance.isTeacher
        ? AppSession.instance.currentTeacherId
        : _selectedTeacherId;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditClassRecordScreen(
          preselectedTeacherId: targetTeacher,
        ),
      ),
    );

    if (updated == true) {
      _loadData(silent: true);
    }
  }

  Future<void> _openDetailsDialog(DailyClassRecordModel record) async {
    // If teacher mode, verify teacher owns this record
    if (AppSession.instance.isTeacher && record.teacherId != AppSession.instance.currentTeacherId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only view and edit your own teaching logs.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => ClassRecordDetailsDialog(record: record),
    );

    if (updated == true) {
      _loadData(silent: true);
    }
  }

  void _showPendingTeachersDialog() {
    if (!AppSession.instance.isAdmin) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assignment_late, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pending Log Submissions (${_pendingTeachers.length})',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _pendingTeachers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('All active teachers have submitted teaching logs for today!'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _pendingTeachers.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final t = _pendingTeachers[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Text(
                          t.name.isNotEmpty ? t.name[0].toUpperCase() : 'T',
                          style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${t.subject} • ${t.mobile}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Teaching Logs',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedClass = 'All';
                            _selectedBoard = 'All';
                            if (!AppSession.instance.isTeacher) {
                              _selectedTeacherId = widget.initialTeacherId;
                            }
                            _selectedSubject = 'All';
                            _selectedDateFilter = 'All Time';
                            _customDateRange = null;
                          });
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Date Filter Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDateFilter,
                    decoration: const InputDecoration(labelText: 'Date Period', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                      DropdownMenuItem(value: 'Today', child: Text('Today')),
                      DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                      DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _selectedDateFilter = val);
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // Class Filter
                  DropdownButtonFormField<String>(
                    initialValue: _selectedClass,
                    decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                    items: AppConstants.classesWithAll.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Classes' : 'Class $c'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => _selectedClass = val);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Teacher Filter (ONLY for Admin)
                  if (AppSession.instance.isAdmin) ...[
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedTeacherId,
                      decoration: const InputDecoration(labelText: 'Teacher', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Teachers')),
                        ..._teachers.map((t) => DropdownMenuItem<int?>(value: t.id, child: Text(t.name))),
                      ],
                      onChanged: (val) {
                        setModalState(() => _selectedTeacherId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Subject Filter
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                    items: AppConstants.subjectsWithAll.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Subjects' : s));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => _selectedSubject = val);
                    },
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadData();
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accessDenied) {
      final session = AppSession.instance;
      final errorMsg = session.isStudent
          ? 'Access Denied: You are not authorized to view the Daily Class Register logs.'
          : 'Access Denied: You can only view your own class register logs.';
      return Scaffold(
        body: Center(
          child: Text(
            errorMsg,
            style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final bool isTeacherView = AppSession.instance.isTeacher || widget.initialTeacherId != null;

    final titleText = isTeacherView ? 'My Daily Teaching Log' : 'Teaching Log Monitoring';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _hasActiveFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _hasActiveFilters ? theme.colorScheme.primary : null,
            ),
            tooltip: 'Filter Records',
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),

      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search teacher, subject, topic...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadData();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => _loadData(),
                  ),
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ],
            ),
          ),

          // Admin Monitoring Banner (for Admin) OR Teacher Summary Banner (for Teacher)
          if (!_isLoading) ...[
            if (AppSession.instance.isAdmin)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TODAY\'S TEACHING MONITORING',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Flexible(child: _summaryTile('Classes Conducted', '$_dailyClassCount', Colors.indigo)),
                        Flexible(child: _summaryTile('Teaching Hours', '${_dailyTeachingHours.toStringAsFixed(1)}h', Colors.blue.shade800)),
                        Flexible(child: _summaryTile('Teachers Logged', '$_submittedTeacherCount', Colors.teal)),
                        Flexible(
                          child: InkWell(
                            onTap: _showPendingTeachersDialog,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: _pendingTeachers.isNotEmpty ? Colors.orange.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _pendingTeachers.isNotEmpty ? Colors.orange.shade300 : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${_pendingTeachers.length}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: _pendingTeachers.isNotEmpty ? Colors.orange.shade900 : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pending Logs',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _pendingTeachers.isNotEmpty ? Colors.orange.shade900 : Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryTile('Classes Logged', '$_dailyClassCount', Colors.teal.shade800),
                    _summaryTile('Teaching Hours', '${_dailyTeachingHours.toStringAsFixed(1)}h', Colors.teal.shade900),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 4),

          // Main Records List Area
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
                            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _records.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _loadData,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.5,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _hasActiveFilters ? Icons.search_off : Icons.assignment_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _hasActiveFilters ? 'No Matching Logs' : 'No Teaching Logs Recorded',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _hasActiveFilters
                                          ? 'Try changing or clearing your filters.'
                                          : 'Log your classes today to keep teaching records up to date.',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    if (_hasActiveFilters)
                                      OutlinedButton.icon(
                                        onPressed: _clearFilters,
                                        icon: const Icon(Icons.filter_alt_off),
                                        label: const Text('Clear Filters'),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        onPressed: _openAddScreen,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Teaching Log'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              key: const PageStorageKey<String>('daily_class_register_scroll_key'),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _records.length,
                              itemBuilder: (context, index) {
                                final record = _records[index];
                                return _buildRecordCard(record);
                              },
                            ),
                          ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddScreen,
        icon: const Icon(Icons.add),
        label: const Text('Add Teaching Log'),
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecordCard(DailyClassRecordModel record) {
    final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(record.date));
    final teacherName = record.teacherName ?? 'Teacher #${record.teacherId}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetailsDialog(record),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date & Duration Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, size: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          record.formattedDuration,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Class, Board & Batch Tags Row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: Colors.grey.shade200,
                    label: Text(
                      'Class ${record.studentClass}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: Colors.grey.shade100,
                    label: Text(
                      record.board,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ),
                  if (record.batch != null && record.batch!.isNotEmpty)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: Colors.amber.shade50,
                      side: BorderSide(color: Colors.amber.shade200),
                      label: Text(
                        record.batch!,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Subject & Teacher Name
              Row(
                children: [
                  Text(
                    record.subject,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '• Teacher: $teacherName',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Topic Covered
              Text(
                'Topic: ${record.topic}',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (record.homework != null && record.homework!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'HW: ${record.homework}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
