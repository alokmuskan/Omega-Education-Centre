import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/app_session.dart';
import '../../teachers/models/teacher_model.dart';
import '../../teachers/repository/teacher_repository.dart';
import '../dialogs/record_payment_dialog.dart';
import '../models/teacher_payment_model.dart';
import '../models/teacher_salary_summary_model.dart';
import '../repository/teacher_salary_repository.dart';

/// Screen displaying Teacher Salary Payment History and recording cash payments.
class TeacherPaymentHistoryScreen extends StatefulWidget {
  final int? initialTeacherId;
  final String? initialMonth;

  const TeacherPaymentHistoryScreen({
    super.key,
    this.initialTeacherId,
    this.initialMonth,
  });

  @override
  State<TeacherPaymentHistoryScreen> createState() =>
      _TeacherPaymentHistoryScreenState();
}

class _TeacherPaymentHistoryScreenState
    extends State<TeacherPaymentHistoryScreen> {
  final TeacherSalaryRepository _salaryRepo = TeacherSalaryRepository();
  final TeacherRepository _teacherRepo = TeacherRepository();

  List<TeacherModel> _teachers = [];
  TeacherModel? _selectedTeacher;

  DateTime _selectedMonth = DateTime.now();
  TeacherSalarySummaryModel? _summary;
  List<TeacherPaymentModel> _payments = [];

  bool _isLoading = true;

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
    if (widget.initialMonth != null) {
      try {
        final parts = widget.initialMonth!.split('-');
        _selectedMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      } catch (_) {}
    }
    _loadTeachers();
  }

  String get _yearMonth => DateFormat('yyyy-MM').format(_selectedMonth);
  String get _displayMonth => DateFormat('MMMM yyyy').format(_selectedMonth);

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    final teachers = await _teacherRepo.getTeachers(); // returns all (active & inactive)
    if (!mounted) return;

    setState(() {
      _teachers = teachers;
      if (teachers.isNotEmpty) {
        _selectedTeacher = widget.initialTeacherId != null
            ? teachers.firstWhere(
                (t) => t.id == widget.initialTeacherId,
                orElse: () => teachers.first,
              )
            : teachers.first;
      }
    });

    if (_selectedTeacher != null) {
      await _loadSummaryAndPayments();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSummaryAndPayments() async {
    if (_selectedTeacher == null || _selectedTeacher!.id == null) return;

    setState(() => _isLoading = true);

    final summary = await _salaryRepo.getTeacherMonthlySalarySummary(
      teacherId: _selectedTeacher!.id!,
      yearMonth: _yearMonth,
    );

    final paymentList = await _salaryRepo.getTeacherPaymentHistory(
      _selectedTeacher!.id!,
      yearMonth: _yearMonth,
    );

    if (!mounted) return;

    setState(() {
      _summary = summary;
      _payments = paymentList;
      _isLoading = false;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECT SALARY MONTH',
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _loadSummaryAndPayments();
    }
  }

  Future<void> _openRecordPaymentDialog() async {
    if (_summary == null) return;

    if (_summary!.remainingDue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salary for this month is already fully paid!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await showDialog<bool>(
      context: context,
      builder: (_) => RecordPaymentDialog(summary: _summary!),
    );

    if (success == true) {
      _loadSummaryAndPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accessDenied) {
      final session = AppSession.instance;
      final errorMsg = session.isStudent
          ? 'Access Denied: Students are not authorized to view teacher payments.'
          : 'Access Denied: You are not authorized to view another teacher\'s earnings.';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Salary Payments'),
        centerTitle: true,
      ),

      floatingActionButton: AppSession.instance.isAdmin && _summary != null && _summary!.remainingDue > 0
          ? FloatingActionButton.extended(
              onPressed: _openRecordPaymentDialog,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.add),
              label: const Text('Record Cash Payment'),
            )
          : null,

      body: Column(
        children: [
          // ── Selector Controls ─────────────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // Teacher Dropdown
                  if (!AppSession.instance.isTeacher)
                    DropdownButtonFormField<int>(
                    initialValue: _selectedTeacher?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Teacher',
                      isDense: true,
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _teachers
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                '${t.name} (${t.subject}) - ${t.status}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id != null) {
                        setState(() {
                          _selectedTeacher =
                              _teachers.firstWhere((t) => t.id == id);
                        });
                        _loadSummaryAndPayments();
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // Month Picker
                  GestureDetector(
                    onTap: _pickMonth,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Salary Month',
                        isDense: true,
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      child: Text(
                        _displayMonth,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Financial Summary Card ─────────────────────────────────────
          if (_summary != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: _buildSummaryCard(theme),
            ),

          const SizedBox(height: 6),

          // ── Payment Transaction History List ──────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _payments.isEmpty
                    ? _buildEmptyView()
                    : RefreshIndicator(
                        onRefresh: _loadSummaryAndPayments,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                          itemCount: _payments.length,
                          itemBuilder: (context, index) {
                            final payment = _payments[index];
                            return _buildPaymentTile(payment, theme);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final s = _summary!;
    final statusColor = _getStatusColor(s.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.teacherName} — $_displayMonth',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${s.earnedSalary.toStringAsFixed(0)} Earned',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      '${s.totalHoursWorked.toStringAsFixed(1)} hrs × ₹${s.payPerHour.toStringAsFixed(0)}/hr',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricItem('Earned', '₹${s.earnedSalary.toStringAsFixed(0)}', Colors.black87),
              _metricItem('Paid', '₹${s.totalPaid.toStringAsFixed(0)}', Colors.green.shade800),
              _metricItem('Remaining', '₹${s.remainingDue.toStringAsFixed(0)}', Colors.red.shade800),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildPaymentTile(TeacherPaymentModel item, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: const Icon(Icons.payments, color: Colors.green, size: 20),
        ),
        title: Text(
          '₹${item.amount.toStringAsFixed(0)} — ${item.paymentMethod}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${_formatDate(item.paymentDate)}'),
            if (item.remarks != null && item.remarks!.isNotEmpty)
              Text('Remarks: ${item.remarks}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Paid',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green.shade800;
      case 'Partially Paid':
        return Colors.orange.shade800;
      case 'Unpaid':
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No payment transactions recorded for ${_selectedTeacher?.name ?? "this teacher"} in $_displayMonth.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
