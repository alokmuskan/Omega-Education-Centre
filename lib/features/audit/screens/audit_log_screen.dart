import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/services/audit_service.dart';

/// Admin screen to view, filter, and export the append-only audit log.
///
/// Displays: timestamp, action, entity, actor, role, old/new values.
/// Filters: date range, action type, entity type.
/// Export: CSV.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final AuditService _auditService = AuditService.instance;

  // Filters
  String? _selectedAction;
  String? _selectedEntityType;
  DateTime? _startDate;
  DateTime? _endDate;

  // Pagination
  int _currentPage = 0;
  static const int _pageSize = 30;
  List<Map<String, dynamic>> _logs = [];
  int _totalCount = 0;
  bool _isLoading = true;

  // Available filter options
  static const List<Map<String, String>> _actionOptions = [
    {'value': '', 'label': 'All Actions'},
    {'value': 'FEE_PAYMENT', 'label': 'Fee Payment'},
    {'value': 'FEE_REFUND', 'label': 'Fee Refund'},
    {'value': 'SALARY_PAYMENT', 'label': 'Salary Payment'},
    {'value': 'STUDENT_CREATE', 'label': 'Student Created'},
    {'value': 'STUDENT_UPDATE', 'label': 'Student Updated'},
    {'value': 'STUDENT_DELETE', 'label': 'Student Deleted'},
    {'value': 'TEACHER_CREATE', 'label': 'Teacher Created'},
    {'value': 'TEACHER_UPDATE', 'label': 'Teacher Updated'},
    {'value': 'TEACHER_DEACTIVATE', 'label': 'Teacher Deactivated'},
    {'value': 'PASSWORD_CHANGE', 'label': 'Password Changed'},
    {'value': 'PASSWORD_RESET', 'label': 'Password Reset'},
    {'value': 'SETTINGS_CHANGE', 'label': 'Settings Changed'},
    {'value': 'TEST_CREATE', 'label': 'Test Created'},
    {'value': 'TEST_UPDATE', 'label': 'Test Updated'},
    {'value': 'TEST_DELETE', 'label': 'Test Deleted'},
    {'value': 'NOTICE_CREATE', 'label': 'Notice Created'},
    {'value': 'NOTICE_UPDATE', 'label': 'Notice Updated'},
  ];

  static const List<Map<String, String>> _entityOptions = [
    {'value': '', 'label': 'All Entities'},
    {'value': 'fee_payments', 'label': 'Fee Payments'},
    {'value': 'teacher_payments', 'label': 'Teacher Payments'},
    {'value': 'students', 'label': 'Students'},
    {'value': 'teachers', 'label': 'Teachers'},
    {'value': 'users', 'label': 'Users'},
    {'value': 'settings', 'label': 'Settings'},
    {'value': 'tests', 'label': 'Tests'},
    {'value': 'notices', 'label': 'Notices'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    _totalCount = await _auditService.getAuditLogCount(
      action: _selectedAction?.isNotEmpty == true ? _selectedAction : null,
      entityType: _selectedEntityType?.isNotEmpty == true ? _selectedEntityType : null,
      startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
      endDate: _endDate != null ? DateFormat('yyyy-MM-dd 23:59:59').format(_endDate!) : null,
    );

    _logs = await _auditService.getAuditLogs(
      action: _selectedAction?.isNotEmpty == true ? _selectedAction : null,
      entityType: _selectedEntityType?.isNotEmpty == true ? _selectedEntityType : null,
      startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
      endDate: _endDate != null ? DateFormat('yyyy-MM-dd 23:59:59').format(_endDate!) : null,
      limit: _pageSize,
      offset: _currentPage * _pageSize,
    );

    setState(() => _isLoading = false);
  }

  int get _totalPages => (_totalCount / _pageSize).ceil();

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _currentPage++;
      _loadLogs();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _currentPage--;
      _loadLogs();
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedAction = null;
      _selectedEntityType = null;
      _startDate = null;
      _endDate = null;
      _currentPage = 0;
    });
    _loadLogs();
  }

  Future<void> _exportCsv() async {
    final logs = await _auditService.exportAuditLogs(
      action: _selectedAction?.isNotEmpty == true ? _selectedAction : null,
      entityType: _selectedEntityType?.isNotEmpty == true ? _selectedEntityType : null,
      startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
      endDate: _endDate != null ? DateFormat('yyyy-MM-dd 23:59:59').format(_endDate!) : null,
    );

    if (logs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No logs to export.')),
        );
      }
      return;
    }

    final csv = StringBuffer();
    csv.writeln('Timestamp,Action,Entity,Entity ID,Actor,Role,New Value');

    for (final log in logs) {
      final timestamp = log['createdAt'] ?? '';
      final action = log['action'] ?? '';
      final entity = log['entityType'] ?? '';
      final entityId = log['entityId'] ?? '';
      final actor = log['actorUsername'] ?? '';
      final role = log['actorRole'] ?? '';
      final newValue = log['newValueJson'] ?? '';

      // Escape CSV fields
      csv.writeln('"$timestamp","$action","$entity","$entityId","$actor","$role","$newValue"');
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/audit_log_$timestamp.csv');
      await file.writeAsString(csv.toString());

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Audit Log Export',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_off),
            tooltip: 'Reset Filters',
            onPressed: _resetFilters,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          _buildFilters(),

          // Count + pagination info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_totalCount log(s) found',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                if (_totalPages > 1)
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
              ],
            ),
          ),

          // Log list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No audit logs found',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) => _buildLogTile(_logs[index]),
                      ),
          ),

          // Pagination
          if (_totalPages > 1)
            _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Action filter
          DropdownButtonFormField<String>(
            initialValue: _selectedAction,
            decoration: const InputDecoration(
              labelText: 'Action',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: _actionOptions
                .map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedAction = val;
                _currentPage = 0;
              });
              _loadLogs();
            },
          ),
          const SizedBox(height: 8),

          // Entity filter
          DropdownButtonFormField<String>(
            initialValue: _selectedEntityType,
            decoration: const InputDecoration(
              labelText: 'Entity Type',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: _entityOptions
                .map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedEntityType = val;
                _currentPage = 0;
              });
              _loadLogs();
            },
          ),
          const SizedBox(height: 8),

          // Date range
          Row(
            children: [
              Expanded(
                child: _buildDateChip(
                  label: _startDate != null ? DateFormat('dd MMM yyyy').format(_startDate!) : 'From Date',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        _currentPage = 0;
                      });
                      _loadLogs();
                    }
                  },
                  onClear: _startDate != null
                      ? () {
                          setState(() {
                            _startDate = null;
                            _currentPage = 0;
                          });
                          _loadLogs();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateChip(
                  label: _endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : 'To Date',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _endDate = picked;
                        _currentPage = 0;
                      });
                      _loadLogs();
                    }
                  },
                  onClear: _endDate != null
                      ? () {
                          setState(() {
                            _endDate = null;
                            _currentPage = 0;
                          });
                          _loadLogs();
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: const OutlineInputBorder(),
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final action = (log['action'] as String?) ?? '';
    final entity = (log['entityType'] as String?) ?? '';
    final entityId = (log['entityId'] as String?) ?? '-';
    final actor = (log['actorUsername'] as String?) ?? 'unknown';
    final role = (log['actorRole'] as String?) ?? '';
    final createdAt = (log['createdAt'] as String?) ?? '';
    // Format timestamp
    String formattedTime = createdAt;
    try {
      final dt = DateTime.parse(createdAt);
      formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {}

    final actionColor = _actionColor(action);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: actionColor.withAlpha(30),
          child: Icon(_actionIcon(action), color: actionColor, size: 18),
        ),
        title: Text(
          action.replaceAll('_', ' '),
          style: TextStyle(fontWeight: FontWeight.w600, color: actionColor, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '$entity #$entityId',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            Text(
              'by $actor ($role)',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formattedTime,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
          ],
        ),
        isThreeLine: false,
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0 ? _prevPage : null,
          ),
          Text('Page ${_currentPage + 1} of $_totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages - 1 ? _nextPage : null,
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    if (action.contains('PAYMENT') || action.contains('SALARY')) return Colors.green;
    if (action.contains('CREATE')) return Colors.blue;
    if (action.contains('UPDATE') || action.contains('CHANGE')) return Colors.orange;
    if (action.contains('DELETE') || action.contains('DEACTIVATE')) return Colors.red;
    return Colors.grey;
  }

  IconData _actionIcon(String action) {
    if (action.contains('PAYMENT') || action.contains('SALARY')) return Icons.payment;
    if (action.contains('CREATE')) return Icons.add_circle;
    if (action.contains('UPDATE') || action.contains('CHANGE')) return Icons.edit;
    if (action.contains('DELETE') || action.contains('DEACTIVATE')) return Icons.remove_circle;
    if (action.contains('PASSWORD')) return Icons.lock;
    return Icons.info;
  }
}
