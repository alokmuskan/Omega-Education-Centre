import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

import '../../../shared/services/analytics_service.dart';

/// Analytics & Reports Dashboard for Admin.
///
/// Tabs:
/// 1. Fee Trends — monthly collection chart
/// 2. Attendance Trends — daily attendance %
/// 3. Teacher Metrics — hours taught, classes conducted
/// 4. Summary Overview
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AnalyticsService _analyticsService = AnalyticsService.instance;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _endDate = DateTime.now();
  AnalyticsSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    _summary = await _analyticsService.getAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );
    setState(() => _isLoading = false);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAnalytics();
    }
  }

  Future<void> _exportReport() async {
    if (_summary == null) return;
    final report = _analyticsService.exportAsText(_summary!);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/analytics_report_${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString(report);
    await Share.shareXFiles([XFile(file.path)], text: 'Analytics Report');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics & Reports'),
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Fee Trends'),
              Tab(text: 'Attendance'),
              Tab(text: 'Teachers'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.date_range),
              tooltip: 'Date Range',
              onPressed: _pickDateRange,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export Report',
              onPressed: _exportReport,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _summary == null
                ? const Center(child: Text('No data available'))
                : TabBarView(
                    children: [
                      _buildOverviewTab(),
                      _buildFeeTrendsTab(),
                      _buildAttendanceTab(),
                      _buildTeacherTab(),
                    ],
                  ),
      ),
    );
  }

  // ── Overview Tab ──────────────────────────────────────────────

  Widget _buildOverviewTab() {
    final s = _summary!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('dd MMM').format(_startDate)} — ${DateFormat('dd MMM yyyy').format(_endDate)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Students', '${s.totalStudents}', Icons.people, Colors.blue),
              _buildStatCard('Teachers', '${s.totalTeachers}', Icons.school, Colors.green),
              _buildStatCard('Classes', '${s.totalClasses}', Icons.class_, Colors.purple),
              _buildStatCard('Attendance', '${s.averageAttendance.toStringAsFixed(1)}%', Icons.calendar_month, Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fee Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _buildFeeRow('Collected', '₹${s.totalFeeCollected.toStringAsFixed(0)}', Colors.green),
                  _buildFeeRow('Pending', '₹${s.totalFeePending.toStringAsFixed(0)}', Colors.red),
                  const Divider(),
                  _buildFeeRow('Total', '₹${(s.totalFeeCollected + s.totalFeePending).toStringAsFixed(0)}', Colors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fee Trends Tab ──────────────────────────────────────────

  Widget _buildFeeTrendsTab() {
    final feeData = _summary!.feeTrend;
    if (feeData.isEmpty) return const Center(child: Text('No fee data for this period'));

    final maxVal = feeData.map((f) => f.collected > f.pending ? f.collected : f.pending).reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const Center(child: Text('No fee data'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Fee Collection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          // Simple bar chart using Row + FractionallySizedBox
          ...feeData.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.month, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.green.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              widthFactor: maxVal > 0 ? (f.collected / maxVal).clamp(0.0, 1.0) : 0,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: Text('₹${f.collected.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              widthFactor: maxVal > 0 ? (f.pending / maxVal).clamp(0.0, 1.0) : 0,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.shade300,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: Text('₹${f.pending.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLegend(Colors.green, 'Collected'),
              const SizedBox(width: 16),
              _buildLegend(Colors.red.shade300, 'Pending'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Attendance Tab ──────────────────────────────────────────

  Widget _buildAttendanceTab() {
    final attData = _summary!.attendanceTrend;
    if (attData.isEmpty) return const Center(child: Text('No attendance data for this period'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Attendance %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _AttendanceChartPainter(attData),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Average: ${_summary!.averageAttendance.toStringAsFixed(1)}%',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Teacher Tab ─────────────────────────────────────────────

  Widget _buildTeacherTab() {
    final teacherData = _summary!.teacherMetrics;
    if (teacherData.isEmpty) return const Center(child: Text('No teacher data'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: teacherData.length,
      itemBuilder: (context, index) {
        final t = teacherData[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(t.name.isNotEmpty ? t.name[0].toUpperCase() : 'T', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${t.classesConducted} classes conducted'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${t.hoursWorked.toStringAsFixed(1)} hrs', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Simple painter for attendance line chart.
class _AttendanceChartPainter extends CustomPainter {
  final List<AttendanceTrendData> data;
  _AttendanceChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.blue.withAlpha(30)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1).clamp(1, data.length);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i].presentPercent / 100 * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw 75% threshold line
    final thresholdPaint = Paint()
      ..color = Colors.red.withAlpha(100)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final thresholdY = size.height * 0.25;
    canvas.drawLine(Offset(0, thresholdY), Offset(size.width, thresholdY), thresholdPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
