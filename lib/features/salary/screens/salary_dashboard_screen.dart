import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/teacher_salary_summary_model.dart';
import '../repository/teacher_salary_repository.dart';
import '../../../shared/utils/app_session.dart';
import 'teacher_payment_history_screen.dart';

/// Main Salary Dashboard screen displaying monthly teacher salary summaries,
/// overall center financial totals, and payment status badges.
class SalaryDashboardScreen extends StatefulWidget {
  const SalaryDashboardScreen({super.key});

  @override
  State<SalaryDashboardScreen> createState() => _SalaryDashboardScreenState();
}

class _SalaryDashboardScreenState extends State<SalaryDashboardScreen> {
  final TeacherSalaryRepository _repository = TeacherSalaryRepository();

  DateTime _selectedMonth = DateTime.now();
  List<TeacherSalarySummaryModel> _summaries = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSalaryData();
  }

  String get _yearMonth => DateFormat('yyyy-MM').format(_selectedMonth);
  String get _displayMonth => DateFormat('MMMM yyyy').format(_selectedMonth);

  Future<void> _loadSalaryData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _repository.getMonthlySalarySummaryList(
        yearMonth: _yearMonth,
      );

      if (mounted) {
        setState(() {
          _summaries = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load salary data: $e';
          _isLoading = false;
        });
      }
    }
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
      _loadSalaryData();
    }
  }

  void _openPaymentHistory(TeacherSalarySummaryModel summary) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherPaymentHistoryScreen(
          initialTeacherId: summary.teacherId,
          initialMonth: summary.month,
        ),
      ),
    );
    _loadSalaryData(); // Refresh on return
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

    final theme = Theme.of(context);

    // Compute Overall Totals
    final totalHoursAll = _summaries.fold(0.0, (sum, s) => sum + s.totalHoursWorked);
    final totalEarnedAll = _summaries.fold(0.0, (sum, s) => sum + s.earnedSalary);
    final totalPaidAll = _summaries.fold(0.0, (sum, s) => sum + s.totalPaid);
    final totalDueAll = _summaries.fold(0.0, (sum, s) => sum + s.remainingDue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Salary & Payments'),
        centerTitle: true,
      ),

      body: Column(
        children: [
          // ── Month Selector Header ─────────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickMonth,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Select Month',
                          isDense: true,
                          prefixIcon: Icon(Icons.calendar_month),
                        ),
                        child: Text(
                          _displayMonth,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _loadSalaryData,
                  ),
                ],
              ),
            ),
          ),

          // ── Overall Financial Totals Cards ─────────────────────────────
          if (!_isLoading && _summaries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _totalCard(
                          'Total Hours',
                          '${totalHoursAll.toStringAsFixed(1)} hrs',
                          Icons.schedule,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _totalCard(
                          'Total Earned',
                          '₹${totalEarnedAll.toStringAsFixed(0)}',
                          Icons.account_balance_wallet,
                          Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _totalCard(
                          'Total Paid',
                          '₹${totalPaidAll.toStringAsFixed(0)}',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _totalCard(
                          'Total Due',
                          '₹${totalDueAll.toStringAsFixed(0)}',
                          Icons.pending,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // ── Teacher List / Table ──────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _summaries.isEmpty
                        ? _buildEmptyView()
                        : RefreshIndicator(
                            onRefresh: _loadSalaryData,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                              itemCount: _summaries.length,
                              itemBuilder: (context, index) {
                                return _buildTeacherSalaryCard(
                                  _summaries[index],
                                  theme,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _totalCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherSalaryCard(
    TeacherSalarySummaryModel summary,
    ThemeData theme,
  ) {
    final statusColor = _getStatusColor(summary.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPaymentHistory(summary),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Teacher Header & Status Badge
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary.withAlpha(25),
                    child: Text(
                      summary.teacherName.isNotEmpty
                          ? summary.teacherName[0].toUpperCase()
                          : 'T',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                summary.teacherName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!summary.isActive)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Inactive',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${summary.teacherSubject} • Rate: ₹${summary.payPerHour.toStringAsFixed(0)}/hr',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      summary.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Metrics Row: Hours | Earned | Paid | Due
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _tileMetric('Hours', '${summary.totalHoursWorked.toStringAsFixed(1)} h', Colors.blue.shade800),
                  _tileMetric('Earned', '₹${summary.earnedSalary.toStringAsFixed(0)}', Colors.indigo.shade800),
                  _tileMetric('Paid', '₹${summary.totalPaid.toStringAsFixed(0)}', Colors.green.shade800),
                  _tileMetric('Due', '₹${summary.remainingDue.toStringAsFixed(0)}', Colors.red.shade800),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
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
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No teacher salary records for $_displayMonth.\n(Attendance hours or payments will appear here).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
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
          Text(_errorMessage ?? 'An error occurred.',
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadSalaryData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
