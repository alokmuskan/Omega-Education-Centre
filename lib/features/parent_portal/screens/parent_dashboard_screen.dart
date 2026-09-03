import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../shared/config/backend_config.dart';
import '../../../shared/services/supabase_auth_service.dart';
import '../../students/models/student_model.dart';

/// Read-only dashboard for Parents to view their child's data.
///
/// Shows: Attendance %, Fee Dues, Exam Results, Notices.
/// Parents cannot modify any data.
class ParentDashboardScreen extends StatefulWidget {
  final StudentModel student;
  final String parentName;

  const ParentDashboardScreen({
    super.key,
    required this.student,
    this.parentName = 'Parent',
  });

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  // Data
  int _totalDays = 0;
  int _presentDays = 0;
  double _attendancePercent = 0.0;
  double _totalFee = 0.0;
  double _paidFee = 0.0;
  double _dueFee = 0.0;
  List<Map<String, dynamic>> _recentResults = [];
  List<Map<String, dynamic>> _recentNotices = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!BackendConfig.isBackendConfigured) {
        setState(() {
          _isLoading = false;
          _error = 'Cloud sync not configured. Please contact institute.';
        });
        return;
      }

      final anonKey = BackendConfig.supabaseAnonKey ?? '';
      final jwtToken = await SupabaseAuthService.instance.getValidAccessToken();
      if (jwtToken == null) {
        setState(() {
          _isLoading = false;
          _error = 'Session expired. Please log in again.';
        });
        return;
      }

      final headers = {
        'apikey': anonKey,
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      };
      final baseUrl = BackendConfig.supabaseUrl!;
      final studentId = widget.student.id;

      // 1. Attendance
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/rest/v1/student_attendance?select=status&student_id=eq.$studentId'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List;
          _totalDays = data.length;
          _presentDays = data.where((r) => r['status'] == 'Present' || r['status'] == 'Late').length;
          _attendancePercent = _totalDays > 0 ? (_presentDays / _totalDays * 100) : 0.0;
        }
      } catch (_) {}

      // 2. Fees
      try {
        final feesRes = await http.get(
          Uri.parse('$baseUrl/rest/v1/fees?select=amount&student_id=eq.$studentId'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (feesRes.statusCode == 200) {
          final feesData = jsonDecode(feesRes.body) as List;
          for (final f in feesData) {
            _totalFee += (f['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        final paidRes = await http.get(
          Uri.parse('$baseUrl/rest/v1/fee_payments?select=amount&fee_id=eq.$studentId'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (paidRes.statusCode == 200) {
          final paidData = jsonDecode(paidRes.body) as List;
          for (final p in paidData) {
            _paidFee += (p['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
        _dueFee = _totalFee - _paidFee;
        if (_dueFee < 0) _dueFee = 0;
      } catch (_) {}

      // 3. Recent test results
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/rest/v1/test_results?select=*,tests(title,test_date)&student_id=eq.$studentId&order=created_at.desc&limit=5'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          _recentResults = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        }
      } catch (_) {}

      // 4. Recent notices
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/rest/v1/notices?select=*&is_published=eq.true&order=created_at.desc&limit=5'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          _recentNotices = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        }
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load data: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.student.name}\'s Dashboard'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome
                        Text(
                          'Welcome, ${widget.parentName}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.student.name} — Class ${widget.student.studentClass} (${widget.student.board})',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),

                        // Attendance Card
                        _buildInfoCard(
                          title: 'Attendance',
                          icon: Icons.calendar_month,
                          color: Colors.blue,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Present: $_presentDays / $_totalDays days'),
                                  Text(
                                    '${_attendancePercent.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: _attendancePercent >= 75 ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: _attendancePercent / 100,
                                backgroundColor: Colors.grey.shade200,
                                color: _attendancePercent >= 75 ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Fee Card
                        _buildInfoCard(
                          title: 'Fee Status',
                          icon: Icons.account_balance_wallet,
                          color: Colors.orange,
                          child: Column(
                            children: [
                              _buildFeeRow('Total Fee', '₹${_totalFee.toStringAsFixed(0)}'),
                              _buildFeeRow('Paid', '₹${_paidFee.toStringAsFixed(0)}'),
                              const Divider(),
                              _buildFeeRow(
                                'Due',
                                '₹${_dueFee.toStringAsFixed(0)}',
                                isBold: true,
                                color: _dueFee > 0 ? Colors.red : Colors.green,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Recent Results
                        _buildInfoCard(
                          title: 'Recent Results',
                          icon: Icons.bar_chart,
                          color: Colors.purple,
                          child: _recentResults.isEmpty
                              ? const Text('No results available yet.')
                              : Column(
                                  children: _recentResults.map((r) {
                                    final testTitle = (r['tests'] as Map?)?['title'] ?? 'Test';
                                    final marks = r['marks_obtained'] ?? 0;
                                    return ListTile(
                                      dense: true,
                                      title: Text(testTitle, style: const TextStyle(fontSize: 14)),
                                      trailing: Text(
                                        '$marks',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                        const SizedBox(height: 12),

                        // Recent Notices
                        _buildInfoCard(
                          title: 'Notices',
                          icon: Icons.campaign,
                          color: Colors.teal,
                          child: _recentNotices.isEmpty
                              ? const Text('No notices.')
                              : Column(
                                  children: _recentNotices.map((n) {
                                    final title = n['title'] ?? '';
                                    final content = n['content'] ?? '';
                                    // final date = n['publish_date'] ?? '';
                                    return ListTile(
                                      dense: true,
                                      title: Text(title, style: const TextStyle(fontSize: 14)),
                                      subtitle: Text(
                                        content.length > 80 ? '${content.substring(0, 80)}...' : content,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
