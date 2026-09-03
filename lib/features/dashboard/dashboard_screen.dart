import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/database/database_helper.dart';
import '../../shared/config/backend_config.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/utils/app_session.dart';
import '../attendance/screens/attendance_main_screen.dart';
import '../class_register/screens/daily_class_register_main_screen.dart';
import '../backup/screens/backup_restore_screen.dart';
import '../settings/screens/institute_settings_screen.dart';
import '../fees/repository/fee_repository.dart';
import '../fees/screens/admin_fee_dashboard_screen.dart';
import '../notices/repository/notice_repository.dart';
import '../notices/screens/notice_management_screen.dart';
import '../salary/repository/teacher_salary_repository.dart';
import '../salary/screens/salary_dashboard_screen.dart';
import '../students/screens/student_screen.dart';
import '../teachers/screens/teacher_screen.dart';
import '../tests/repository/test_repository.dart';
import '../tests/screens/tests_main_screen.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/menu_card.dart';
import 'widgets/summary_card.dart';
import '../../shared/services/sync_engine.dart';
import '../../shared/widgets/academic_activity_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  int _studentCount = 0;
  int _teacherCount = 0;
  int _classesTodayCount = 0;
  double _teacherHoursToday = 0.0;

  int _studentPresentCount = 0;
  int _studentAbsentCount = 0;
  int _studentLateCount = 0;
  int _studentLeaveCount = 0;

  int _teachersRecordedCount = 0;
  double _centerFeeDue = 0.0;
  double _centerSalaryDue = 0.0;

  List<Map<String, dynamic>> _todayClassesList = [];
  List<dynamic> _recentTestsList = [];
  List<dynamic> _recentNoticesList = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    if (!WidgetsBinding.instance.toString().contains('TestWidgetsFlutterBinding')) {
      SyncEngine.instance.syncAll();
    }
  }

  /// Loads dashboard data from Supabase REST API for Web platform.
  Future<void> _loadDashboardDataFromSupabase() async {
    try {
      if (!BackendConfig.isBackendConfigured) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }

      final anonKey = BackendConfig.supabaseAnonKey ?? '';
      final jwtToken = await SupabaseAuthService.instance.getValidAccessToken();
      if (jwtToken == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Not authenticated. Please log in again.';
        });
        return;
      }

      final headers = {
        'apikey': anonKey,
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      };
      final baseUrl = BackendConfig.supabaseUrl!;

      // Fetch students count
      int studentCount = 0;
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/rest/v1/students?select=id&isActive=eq.true'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List;
          studentCount = data.length;
        }
      } catch (_) {}

      // Fetch teachers count
      int teacherCount = 0;
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/rest/v1/teachers?select=id&isActive=eq.true'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List;
          teacherCount = data.length;
        }
      } catch (_) {}

      // Fetch fee due
      double feeDue = 0.0;
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/rest/v1/fee_payments?select=amountPaid'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List;
          for (final row in data) {
            feeDue += (row['amountPaid'] as num?)?.toDouble() ?? 0.0;
          }
        }
      } catch (_) {}

      // Fetch recent notices
      List<dynamic> recentNotices = [];
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/rest/v1/notices?select=*&order=createdAt.desc&limit=5'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          recentNotices = jsonDecode(res.body) as List;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _studentCount = studentCount;
        _teacherCount = teacherCount;
        _classesTodayCount = 0;
        _teacherHoursToday = 0.0;
        _studentPresentCount = 0;
        _studentAbsentCount = 0;
        _studentLateCount = 0;
        _studentLeaveCount = 0;
        _teachersRecordedCount = 0;
        _centerFeeDue = feeDue;
        _centerSalaryDue = 0.0;
        _todayClassesList = [];
        _recentTestsList = [];
        _recentNoticesList = recentNotices;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // Web: fetch data from Supabase REST API
    if (kIsWeb) {
      await _loadDashboardDataFromSupabase();
      return;
    }

    try {
      final db = await _dbHelper.database;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. Active Students Count
      final studentRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM students WHERE isActive = 1',
      );
      final studentCount = (studentRes.first['cnt'] as int?) ?? 0;

      // 2. Active Teachers Count
      final teacherRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM teachers WHERE isActive = 1',
      );
      final teacherCount = (teacherRes.first['cnt'] as int?) ?? 0;

      // 3. Classes Today Count
      final classCountRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM daily_class_records WHERE date = ?',
        [todayStr],
      );
      final classCount = (classCountRes.first['cnt'] as int?) ?? 0;

      // 4. Teacher Hours Worked Today
      final teacherHoursRes = await db.rawQuery(
        'SELECT COALESCE(SUM(hoursWorked), 0.0) as total FROM teacher_attendance WHERE date = ?',
        [todayStr],
      );
      final teacherHours = (teacherHoursRes.first['total'] as num?)?.toDouble() ?? 0.0;

      // 5. Student Attendance Today Breakdown
      final studentAttRes = await db.rawQuery(
        '''SELECT 
             SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) as present,
             SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) as absent,
             SUM(CASE WHEN status = 'Late' THEN 1 ELSE 0 END) as late,
             SUM(CASE WHEN status = 'Leave' THEN 1 ELSE 0 END) as leave
           FROM student_attendance WHERE date = ?''',
        [todayStr],
      );
      final sPresent = (studentAttRes.first['present'] as int?) ?? 0;
      final sAbsent = (studentAttRes.first['absent'] as int?) ?? 0;
      final sLate = (studentAttRes.first['late'] as int?) ?? 0;
      final sLeave = (studentAttRes.first['leave'] as int?) ?? 0;

      // 6. Teacher Attendance Today Breakdown (Recorded Count)
      final teacherAttRecordedRes = await db.rawQuery(
        'SELECT COUNT(DISTINCT teacherId) as cnt FROM teacher_attendance WHERE date = ?',
        [todayStr],
      );
      final tRecorded = (teacherAttRecordedRes.first['cnt'] as int?) ?? 0;

      // 7. Student Fee Due Center-Wide
      final feeDue = await FeeRepository().getCenterWideOutstandingFees();

      // 8. Teacher Salary Due Center-Wide (Current Month)
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      final salaryDue = await TeacherSalaryRepository().getCenterWideSalaryDue(yearMonth: currentMonth);

      // 9. Today's Classes List (limit 3)
      final classRes = await db.rawQuery(
        '''SELECT dcr.*, t.name as teacherName
           FROM daily_class_records dcr
           LEFT JOIN teachers t ON dcr.teacherId = t.id
           WHERE dcr.date = ?
           ORDER BY dcr.startTime ASC LIMIT 3''',
        [todayStr],
      );
      final todayClasses = classRes.map((c) {
        return {
          'time': c['startTime'] as String? ?? '--:--',
          'class': c['studentClass'] as String? ?? '',
          'batch': c['batch'] as String? ?? '',
          'teacher': c['teacherName'] as String? ?? 'Teacher',
          'subject': c['subject'] as String? ?? '',
          'topic': c['topic'] as String? ?? '',
          'duration': '${c['durationMinutes']} mins',
        };
      }).toList();

      // 10. Recent Tests (limit 3)
      final testsList = await TestRepository().getTests(includeArchived: false);
      final recentTests = testsList.take(3).toList();

      // 11. Recent Notices (limit 3)
      final noticesList = await NoticeRepository().getAllNoticesAdmin();
      final recentNotices = noticesList.where((n) => !n.isArchived).take(3).toList();

      if (mounted) {
        setState(() {
          _studentCount = studentCount;
          _teacherCount = teacherCount;
          _classesTodayCount = classCount;
          _teacherHoursToday = teacherHours;

          _studentPresentCount = sPresent;
          _studentAbsentCount = sAbsent;
          _studentLateCount = sLate;
          _studentLeaveCount = sLeave;

          _teachersRecordedCount = tRecorded;
          _centerFeeDue = feeDue;
          _centerSalaryDue = salaryDue;

          _todayClassesList = todayClasses;
          _recentTestsList = recentTests;
          _recentNoticesList = recentNotices;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load operational dashboard: $e';
        });
      }
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
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            const DashboardHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadDashboardData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadDashboardData,
                          child: SingleChildScrollView(
                            key: const PageStorageKey<String>('admin_dashboard_scroll_key'),
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section: Today's Overview
                                const Text(
                                  "Today's Overview",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                GridView.count(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 1.5,
                                  children: [
                                    SummaryCard(
                                      title: "Active Students",
                                      value: "$_studentCount",
                                      icon: Icons.people,
                                      color: Colors.blue,
                                    ),
                                    SummaryCard(
                                      title: "Active Teachers",
                                      value: "$_teacherCount",
                                      icon: Icons.school,
                                      color: Colors.green,
                                    ),
                                    SummaryCard(
                                      title: "Classes Today",
                                      value: "$_classesTodayCount",
                                      icon: Icons.assignment_turned_in,
                                      color: Colors.purple,
                                    ),
                                    SummaryCard(
                                      title: "Teacher Hours Today",
                                      value: "${_teacherHoursToday.toStringAsFixed(1)} hrs",
                                      icon: Icons.access_time_filled,
                                      color: Colors.orange,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Section: Attendance Breakdown Today
                                const Text(
                                  "Attendance Today",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Student Attendance Breakdown",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 8,
                                          children: [
                                            _buildBadgeChip("Present: $_studentPresentCount", Colors.green),
                                            _buildBadgeChip("Absent: $_studentAbsentCount", Colors.red),
                                            _buildBadgeChip("Late: $_studentLateCount", Colors.orange),
                                            _buildBadgeChip("Leave: $_studentLeaveCount", Colors.blueGrey),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        Text(
                                          "Teacher Attendance status",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Attendance Recorded: $_teachersRecordedCount / $_teacherCount Teachers",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          "Total teaching hours worked today: ${_teacherHoursToday.toStringAsFixed(1)} hours",
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Section: Financial Summary Dues
                                const Text(
                                  "Center Dues Summary",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                GridView.count(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 1.5,
                                  children: [
                                    SummaryCard(
                                      title: "Fee Dues",
                                      value: "₹${_centerFeeDue.toStringAsFixed(0)}",
                                      icon: Icons.currency_rupee,
                                      color: _centerFeeDue > 0 ? Colors.red : Colors.green,
                                    ),
                                    SummaryCard(
                                      title: "Salary Dues",
                                      value: "₹${_centerSalaryDue.toStringAsFixed(0)}",
                                      icon: Icons.account_balance_wallet,
                                      color: _centerSalaryDue > 0 ? Colors.orange : Colors.green,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Section: Academic Activity
                                const Text(
                                  "Academic Activity",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: AcademicActivityCard(
                                        title: "Classes Today",
                                        value: "$_classesTodayCount",
                                        icon: Icons.assignment_turned_in,
                                        color: Colors.purple,
                                        onTap: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyClassRegisterMainScreen())).then((_) => _loadDashboardData(silent: true));
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AcademicActivityCard(
                                        title: "Recent Notices",
                                        value: "${_recentNoticesList.length}",
                                        icon: Icons.campaign,
                                        color: Colors.amber.shade800,
                                        onTap: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeManagementScreen())).then((_) => _loadDashboardData(silent: true));
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AcademicActivityCard(
                                        title: "Recent Tests",
                                        value: "${_recentTestsList.length}",
                                        icon: Icons.bar_chart,
                                        color: Colors.purple,
                                        onTap: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TestsMainScreen())).then((_) => _loadDashboardData(silent: true));
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Section: Today's Classes List
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Today's Conducted Classes",
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const DailyClassRegisterMainScreen(),
                                          ),
                                        ).then((_) => _loadDashboardData(silent: true));
                                      },
                                      child: const Text("View All"),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _todayClassesList.isEmpty
                                    ? _buildEmptySectionCard("No class records logged for today.")
                                    : Card(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _todayClassesList.length,
                                          separatorBuilder: (_, _) => const Divider(height: 1),
                                          itemBuilder: (context, idx) {
                                            final c = _todayClassesList[idx];
                                            final batchStr = c['batch'] != null && c['batch'].toString().isNotEmpty
                                                ? ' (${c['batch']})'
                                                : '';
                                            return ListTile(
                                              leading: const CircleAvatar(
                                                backgroundColor: Color(0xFFE3F2FD),
                                                child: Icon(Icons.school, color: Colors.blue),
                                              ),
                                              title: Text(
                                                'Class ${c['class']}$batchStr • ${c['subject']}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Text(
                                                'Teacher: ${c['teacher']}\nTopic: ${c['topic']}\nDuration: ${c['duration']}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              trailing: Text(
                                                c['time'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                const SizedBox(height: 24),

                                // Section: Upcoming & Recent Tests
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Recent Examinations",
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const TestsMainScreen(),
                                          ),
                                        ).then((_) => _loadDashboardData(silent: true));
                                      },
                                      child: const Text("View All"),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _recentTestsList.isEmpty
                                    ? _buildEmptySectionCard("No tests/examinations configured.")
                                    : Card(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _recentTestsList.length,
                                          separatorBuilder: (_, _) => const Divider(height: 1),
                                          itemBuilder: (context, idx) {
                                            final t = _recentTestsList[idx];
                                            return ListTile(
                                              leading: const CircleAvatar(
                                                backgroundColor: Color(0xFFF3E5F5),
                                                child: Icon(Icons.bar_chart, color: Colors.purple),
                                              ),
                                              title: Text(
                                                t.title,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Text(
                                                'Class ${t.studentClass} • ${t.testType}\nDate: ${t.testDate}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                const SizedBox(height: 24),

                                // Section: Recent Notices
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Recent Notice Feed",
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const NoticeManagementScreen(),
                                          ),
                                        ).then((_) => _loadDashboardData(silent: true));
                                      },
                                      child: const Text("View All"),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _recentNoticesList.isEmpty
                                    ? _buildEmptySectionCard("No active notices published.")
                                    : Card(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _recentNoticesList.length,
                                          separatorBuilder: (_, _) => const Divider(height: 1),
                                          itemBuilder: (context, idx) {
                                            final n = _recentNoticesList[idx];
                                            final isUrgent = n.priority == 'Urgent' || n.priority == 'Important';
                                            return ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: isUrgent ? const Color(0xFFFFEBEE) : const Color(0xFFFFFDE7),
                                                child: Icon(
                                                  Icons.campaign,
                                                  color: isUrgent ? Colors.red : Colors.orange,
                                                ),
                                              ),
                                              title: Text(
                                                n.title,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Text(
                                                'Target: ${n.targetRole}\nPublished: ${n.publishDate}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                const SizedBox(height: 24),

                                // Section: Quick Actions Grid (Deferred timetable)
                                const Text(
                                  "Quick Actions",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                GridView.count(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 0.95,
                                  children: [
                                    MenuCard(
                                      title: "Students",
                                      icon: Icons.people,
                                      color: Colors.blue,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                    MenuCard(
                                      title: "Teachers",
                                      icon: Icons.school,
                                      color: Colors.green,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                    MenuCard(
                                      title: "Attendance",
                                      icon: Icons.calendar_month,
                                      color: Colors.orange,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceMainScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                    MenuCard(
                                      title: "Notices",
                                      icon: Icons.campaign,
                                      color: Colors.amber.shade800,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeManagementScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                    MenuCard(
                                      title: "Results",
                                      icon: Icons.bar_chart,
                                      color: Colors.purple,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TestsMainScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                    MenuCard(
                                      title: "Salary",
                                      icon: Icons.account_balance_wallet,
                                      color: Colors.teal,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryDashboardScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                    MenuCard(
                                      title: "Class Register",
                                      icon: Icons.assignment_outlined,
                                      color: Colors.deepOrange,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyClassRegisterMainScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                    MenuCard(
                                      title: "Fees & Dues",
                                      icon: Icons.currency_rupee,
                                      color: Colors.blueGrey,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeeDashboardScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                    MenuCard(
                                      title: "Backup & Restore",
                                      icon: Icons.settings_backup_restore,
                                      color: Colors.indigo,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                    MenuCard(
                                      title: "Institute Config",
                                      icon: Icons.settings,
                                      color: Colors.blueAccent,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstituteSettingsScreen())).then((_) => _loadDashboardData(silent: true)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        border: Border.all(color: color.withAlpha(80)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
      ),
    );
  }

  Widget _buildEmptySectionCard(String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }
}
