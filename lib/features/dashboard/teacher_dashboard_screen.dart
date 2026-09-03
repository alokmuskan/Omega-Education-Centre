import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/database_helper.dart';
import '../../shared/utils/app_session.dart';
import '../attendance/screens/teacher_attendance_history_screen.dart';
import '../authentication/login/login_screen.dart';
import '../class_register/screens/daily_class_register_main_screen.dart';
import '../notices/repository/notice_repository.dart';
import '../notices/screens/notice_management_screen.dart';
import '../salary/repository/teacher_salary_repository.dart';
import '../salary/screens/teacher_payment_history_screen.dart';
import '../teachers/screens/teacher_details_screen.dart';
import 'widgets/menu_card.dart';
import 'widgets/summary_card.dart';

/// Role-Based Dashboard for authenticated Teachers.
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}


class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  int _classesRecordedToday = 0;
  double _teachingHoursToday = 0.0;
  int _classesRecordedThisMonth = 0;
  bool _attendanceRecordedToday = false;

  double _totalHoursThisMonth = 0.0;
  double _payPerHour = 0.0;
  double _estimatedEarningsThisMonth = 0.0;

  List<Map<String, dynamic>> _myClassesToday = [];
  List<dynamic> _notices = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeacherDashboardData();
  }

  Future<void> _loadTeacherDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = AppSession.instance;
      if (!session.isTeacher || session.currentTeacherId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final teacherId = session.currentTeacherId!;
      final db = await _dbHelper.database;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());

      // 1. Classes Recorded Today (daily_class_records where teacherId = authenticated teacher ID and date = today)
      final classesTodayRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM daily_class_records WHERE teacherId = ? AND date = ?',
        [teacherId, todayStr],
      );
      final classesToday = (classesTodayRes.first['cnt'] as int?) ?? 0;

      // 2. Teaching Hours Today (sum of hoursWorked from teacher_attendance today matching currentTeacherId)
      final hoursTodayRes = await db.rawQuery(
        'SELECT COALESCE(SUM(hoursWorked), 0.0) as total FROM teacher_attendance WHERE teacherId = ? AND date = ?',
        [teacherId, todayStr],
      );
      final hoursToday = (hoursTodayRes.first['total'] as num?)?.toDouble() ?? 0.0;

      // 3. Classes Recorded This Month (daily_class_records for the current month matching currentTeacherId)
      final classesMonthRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM daily_class_records WHERE teacherId = ? AND date LIKE ?',
        [teacherId, '$currentMonthStr%'],
      );
      final classesMonth = (classesMonthRes.first['cnt'] as int?) ?? 0;

      // 4. Attendance Recorded Today (Yes/No status for today)
      final attendanceTodayRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM teacher_attendance WHERE teacherId = ? AND date = ?',
        [teacherId, todayStr],
      );
      final attendanceRecorded = ((attendanceTodayRes.first['cnt'] as int?) ?? 0) > 0;

      // 5. My Earnings Section (Current month's Total Hours, Pay Per Hour, and Estimated Earned Salary)
      final salarySummary = await TeacherSalaryRepository().getTeacherMonthlySalarySummary(
        teacherId: teacherId,
        yearMonth: currentMonthStr,
      );

      // 6. My Classes Today
      final classesRes = await db.rawQuery(
        '''SELECT dcr.*
           FROM daily_class_records dcr
           WHERE dcr.teacherId = ? AND dcr.date = ?
           ORDER BY dcr.startTime ASC''',
        [teacherId, todayStr],
      );
      final myClasses = classesRes.map((c) {
        return {
          'time': c['startTime'] as String? ?? '--:--',
          'class': c['studentClass'] as String? ?? '',
          'batch': c['batch'] as String? ?? '',
          'subject': c['subject'] as String? ?? '',
          'topic': c['topic'] as String? ?? '',
          'duration': '${c['durationMinutes']} mins',
        };
      }).toList();

      // 7. My Notices (announcements targeted to Teacher or Everyone)
      final currentUserId = 'teacher_$teacherId';
      final noticesList = await NoticeRepository().getNoticesForRole(
        'Teacher',
        userId: currentUserId,
      );

      if (mounted) {
        setState(() {
          _classesRecordedToday = classesToday;
          _teachingHoursToday = hoursToday;
          _classesRecordedThisMonth = classesMonth;
          _attendanceRecordedToday = attendanceRecorded;

          _totalHoursThisMonth = salarySummary?.totalHoursWorked ?? 0.0;
          _payPerHour = salarySummary?.payPerHour ?? 0.0;
          _estimatedEarningsThisMonth = salarySummary?.earnedSalary ?? 0.0;

          _myClassesToday = myClasses;
          _notices = noticesList;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load teacher dashboard: $e';
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppSession.instance.clearSession();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    if (!session.isTeacher) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: Teacher credentials required.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final teacher = session.currentTeacherModel;
    final teacherName = teacher?.name ?? session.currentUsername;
    final teacherSubject = teacher?.subject ?? 'Teacher';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
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
                            onPressed: _loadTeacherDashboardData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTeacherDashboardData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.teal.shade700, Colors.teal.shade900],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.white24,
                                  child: Text(
                                    teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'LOGGED IN AS TEACHER',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        teacherName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        teacherSubject,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section: My Today Metrics
                          const Text(
                            "My Today Overview",
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
                                title: "Classes Recorded Today",
                                value: "$_classesRecordedToday",
                                icon: Icons.assignment,
                                color: Colors.teal,
                              ),
                              SummaryCard(
                                title: "Hours Today",
                                value: "${_teachingHoursToday.toStringAsFixed(1)} hrs",
                                icon: Icons.timer,
                                color: Colors.blue,
                              ),
                              SummaryCard(
                                title: "Classes This Month",
                                value: "$_classesRecordedThisMonth",
                                icon: Icons.calendar_month,
                                color: Colors.purple,
                              ),
                              SummaryCard(
                                title: "Attendance Marked",
                                value: _attendanceRecordedToday ? "Yes" : "No",
                                icon: Icons.check_circle,
                                color: _attendanceRecordedToday ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Section: My Classes Today
                          const Text(
                            "My Classes Today",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _myClassesToday.isEmpty
                              ? _buildEmptySectionCard("No class records logged for today.")
                              : Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _myClassesToday.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final c = _myClassesToday[idx];
                                      final batchStr = c['batch'] != null && c['batch'].toString().isNotEmpty
                                          ? ' (${c['batch']})'
                                          : '';
                                      return ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFFE0F2F1),
                                          child: Icon(Icons.school, color: Colors.teal),
                                        ),
                                        title: Text(
                                          'Class ${c['class']}$batchStr • ${c['subject']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          'Topic: ${c['topic']}\nDuration: ${c['duration']}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: Text(
                                          c['time'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                          const SizedBox(height: 24),

                          // Section: My Earnings
                          const Text(
                            "My Earnings Summary",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Current Month Overview",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildEarningsMetric("Total Hours", "${_totalHoursThisMonth.toStringAsFixed(1)} hrs"),
                                      _buildEarningsMetric("Pay Per Hour", "₹ ${_payPerHour.toStringAsFixed(0)}"),
                                      _buildEarningsMetric("Estimated Salary", "₹ ${_estimatedEarningsThisMonth.toStringAsFixed(0)}"),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section: My Notices
                          const Text(
                            "My Notices",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _notices.isEmpty
                              ? _buildEmptySectionCard("No active notices targetted to you.")
                              : Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _notices.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final n = _notices[idx];
                                      final isUrgent = n.priority == 'Urgent' || n.priority == 'Important';
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isUrgent ? const Color(0xFFFFEBEE) : const Color(0xFFE0F2F1),
                                          child: Icon(
                                            Icons.campaign,
                                            color: isUrgent ? Colors.red : Colors.teal,
                                          ),
                                        ),
                                        title: Text(
                                          n.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          'Category: ${n.noticeType} • Published: ${n.publishDate}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const NoticeManagementScreen(),
                                            ),
                                          ).then((_) => _loadTeacherDashboardData());
                                        },
                                      );
                                    },
                                  ),
                                ),
                          const SizedBox(height: 24),

                          // Section: My Quick Actions
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
                                title: "Class Register",
                                icon: Icons.assignment_outlined,
                                color: Colors.teal,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DailyClassRegisterMainScreen(initialTeacherId: teacher?.id),
                                  ),
                                ).then((_) => _loadTeacherDashboardData()),
                              ),
                              MenuCard(
                                title: "Attendance History",
                                icon: Icons.history,
                                color: Colors.blue,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeacherAttendanceHistoryScreen(initialTeacherId: teacher?.id),
                                  ),
                                ).then((_) => _loadTeacherDashboardData()),
                              ),
                              MenuCard(
                                title: "My Earnings",
                                icon: Icons.account_balance_wallet,
                                color: Colors.purple,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeacherPaymentHistoryScreen(initialTeacherId: teacher?.id),
                                  ),
                                ).then((_) => _loadTeacherDashboardData()),
                              ),
                              MenuCard(
                                title: "Notices",
                                icon: Icons.campaign,
                                color: Colors.orange,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NoticeManagementScreen(),
                                  ),
                                ).then((_) => _loadTeacherDashboardData()),
                              ),
                              MenuCard(
                                title: "My Profile",
                                icon: Icons.person,
                                color: Colors.indigo,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeacherDetailsScreen(teacher: teacher!),
                                  ),
                                ).then((_) => _loadTeacherDashboardData()),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEarningsMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
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
