import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/database_helper.dart';
import '../../shared/utils/app_session.dart';
import '../../shared/widgets/profile_photo_widget.dart';
import '../attendance/repository/student_attendance_repository.dart';
import '../attendance/screens/student_attendance_history_screen.dart';
import '../authentication/login/login_screen.dart';
import '../fees/repository/fee_repository.dart';
import '../fees/screens/student_fee_details_screen.dart';
import '../notices/repository/notice_repository.dart';
import '../notices/screens/notice_management_screen.dart';
import '../students/screens/student_details_screen.dart';
import '../tests/repository/test_result_repository.dart';
import '../tests/screens/student_result_history_screen.dart';
import 'widgets/menu_card.dart';
import '../../shared/widgets/skeleton_widgets.dart';

/// Role-Based Dashboard for authenticated Students.
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  double _attendancePercentage = 0.0;
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;
  int _leaveCount = 0;

  String _latestExamTitle = 'N/A';
  double _latestExamPercentage = 0.0;
  String _latestExamStatus = 'N/A';

  double _totalFee = 0.0;
  double _paidFee = 0.0;
  double _dueFee = 0.0;
  String _feeStatus = 'Unpaid';

  List<Map<String, dynamic>> _conductedClassesToday = [];
  List<dynamic> _notices = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudentDashboardData();
  }

  Future<void> _loadStudentDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = AppSession.instance;
      if (!session.isStudent || session.currentStudentId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final studentId = session.currentStudentId!;
      final student = session.currentStudentModel!;
      final db = await _dbHelper.database;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. My Attendance overall summary (percentage, Present, Absent, Late, Leave)
      final attSummary = await StudentAttendanceRepository().getStudentOverallSummary(studentId);

      // 2. My Results (latest examination percentage, title, status)
      final resultHistory = await TestResultRepository().getStudentResultHistory(studentId);
      String latestExam = 'N/A';
      double latestPct = 0.0;
      String latestStatus = 'N/A';
      if (resultHistory.isNotEmpty) {
        final latest = resultHistory.first;
        latestExam = latest.testTitle;
        latestPct = latest.percentage;
        latestStatus = latest.overallStatus;
      }

      // 3. My Fees Ledger (Agreed, Paid, Due, Status)
      final feePlan = await FeeRepository().getFeeForStudent(studentId);
      final paidAmount = await FeeRepository().getTotalPaid(studentId);
      final totalAmount = feePlan?.totalFee ?? 0.0;
      final remainingDue = totalAmount > paidAmount ? (totalAmount - paidAmount) : 0.0;
      final computedStatus = await FeeRepository().computeFeeStatus(studentId);

      // 4. Classes Conducted Today (daily_class_records matching class, board, batch, date=today)
      final classRecordsRes = await db.rawQuery(
        '''SELECT dcr.*, t.name as teacherName
           FROM daily_class_records dcr
           LEFT JOIN teachers t ON dcr.teacherId = t.id
           WHERE dcr.studentClass = ? AND dcr.board = ? AND dcr.date = ?
           ORDER BY dcr.startTime ASC''',
        [student.studentClass, student.board, todayStr],
      );

      final List<Map<String, dynamic>> conductedClasses = [];
      for (final row in classRecordsRes) {
        conductedClasses.add({
          'time': row['startTime'] as String? ?? '--:--',
          'subject': row['subject'] as String? ?? '',
          'teacher': row['teacherName'] as String? ?? 'Teacher',
          'topic': row['topic'] as String? ?? '',
          'duration': '${row['durationMinutes']} mins',
          'homework': row['homework'] as String? ?? '',
        });
      }

      // 5. Notices targeted to Student
      final currentUserId = 'student_$studentId';
      final noticesList = await NoticeRepository().getNoticesForRole(
        'Student',
        studentClass: student.studentClass,
        board: student.board,
        userId: currentUserId,
      );

      if (mounted) {
        setState(() {
          _attendancePercentage = attSummary.percentage;
          _presentCount = attSummary.presentCount;
          _absentCount = attSummary.absentCount;
          _lateCount = attSummary.lateCount;
          _leaveCount = attSummary.leaveCount;

          _latestExamTitle = latestExam;
          _latestExamPercentage = latestPct;
          _latestExamStatus = latestStatus;

          _totalFee = totalAmount;
          _paidFee = paidAmount;
          _dueFee = remainingDue;
          _feeStatus = computedStatus;

          _conductedClassesToday = conductedClasses;
          _notices = noticesList;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load student dashboard: $e';
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
    if (!session.isStudent) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: Student credentials required.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final student = session.currentStudentModel;
    final studentName = student?.name ?? session.currentUsername;
    final studentClass = student?.studentClass ?? 'N/A';
    final rollNo = student?.rollNo ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.indigo.shade700,
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
            ? SkeletonWidgets.pageSkeleton(cardCount: 3, hasHeader: false)
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
                            onPressed: _loadStudentDashboardData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadStudentDashboardData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Student Profile Banner Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.indigo.shade700, Colors.indigo.shade900],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                ProfilePhotoWidget(
                                  relativePath: student?.profilePhotoPath,
                                  fallbackLetter: studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                  radius: 28,
                                  isEditable: false,
                                  onPhotoSelected: (_) {},
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'LOGGED IN AS STUDENT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        studentName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'Class $studentClass • Roll No: $rollNo',
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

                          // Section: My Attendance
                          const Text(
                            "My Attendance Overview",
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Overall Attendance Pct",
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        "${_attendancePercentage.toStringAsFixed(1)}%",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: _attendancePercentage >= 75 ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      _buildStatusItem("Present", "$_presentCount", Colors.green),
                                      _buildStatusItem("Absent", "$_absentCount", Colors.red),
                                      _buildStatusItem("Late", "$_lateCount", Colors.orange),
                                      _buildStatusItem("Leave", "$_leaveCount", Colors.blueGrey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section: My Results
                          const Text(
                            "My Latest Exam Results",
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
                                    _latestExamTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Overall Percentage",
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                          Text(
                                            _latestExamTitle == 'N/A' ? 'N/A' : "${_latestExamPercentage.toStringAsFixed(1)}%",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "Status",
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                          Text(
                                            _latestExamStatus,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: _latestExamStatus == 'Passed' ? Colors.green : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section: My Fees Ledger
                          const Text(
                            "My Fees Ledger",
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Payment Status",
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      _buildFeeStatusBadge(_feeStatus),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildAmountMetric("Agreed Fee", _totalFee),
                                      _buildAmountMetric("Paid", _paidFee),
                                      _buildAmountMetric("Due", _dueFee),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section: Conducted Classes Today
                          const Text(
                            "Classes Conducted Today",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _conductedClassesToday.isEmpty
                              ? _buildEmptySectionCard("No classes have been recorded for your class today.")
                              : Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _conductedClassesToday.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final c = _conductedClassesToday[idx];
                                      return ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFFE8EAF6),
                                          child: Icon(Icons.school, color: Colors.indigo),
                                        ),
                                        title: Text(
                                          c['subject'],
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
                                            color: Colors.indigo,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                          const SizedBox(height: 24),

                          // Section: Notices
                          const Text(
                            "Notices Feed",
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
                                          backgroundColor: isUrgent ? const Color(0xFFFFEBEE) : const Color(0xFFE8EAF6),
                                          child: Icon(
                                            Icons.campaign,
                                            color: isUrgent ? Colors.red : Colors.indigo,
                                          ),
                                        ),
                                        title: Text(
                                          n.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          'Category: ${n.noticeType} • Date: ${n.publishDate}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const NoticeManagementScreen(),
                                            ),
                                          ).then((_) => _loadStudentDashboardData());
                                        },
                                      );
                                    },
                                  ),
                                ),
                          const SizedBox(height: 24),

                          // Section: Quick Actions
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
                                title: "My Attendance",
                                icon: Icons.history,
                                color: Colors.blue,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudentAttendanceHistoryScreen(initialStudentId: student?.id),
                                  ),
                                ).then((_) => _loadStudentDashboardData()),
                              ),
                              MenuCard(
                                title: "My Results",
                                icon: Icons.bar_chart,
                                color: Colors.purple,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudentResultHistoryScreen(studentId: student!.id!),
                                  ),
                                ).then((_) => _loadStudentDashboardData()),
                              ),
                              MenuCard(
                                title: "My Fees",
                                icon: Icons.account_balance_wallet,
                                color: Colors.teal,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudentFeeDetailsScreen(studentId: student!.id!, isStudentView: true),
                                  ),
                                ).then((_) => _loadStudentDashboardData()),
                              ),
                              MenuCard(
                                title: "Notice Board",
                                icon: Icons.campaign,
                                color: Colors.orange,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NoticeManagementScreen(),
                                  ),
                                ).then((_) => _loadStudentDashboardData()),
                              ),
                              MenuCard(
                                title: "My Profile",
                                icon: Icons.person,
                                color: Colors.indigo,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudentDetailsScreen(student: student!),
                                  ),
                                ).then((_) => _loadStudentDashboardData()),
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

  Widget _buildStatusItem(String label, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 4),
        Text(
          "$label: $count",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildAmountMetric(String label, double amount) {
    return Column(
      children: [
        Text(
          "₹ ${amount.toStringAsFixed(0)}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildFeeStatusBadge(String status) {
    Color badgeColor = Colors.red;
    if (status == 'Paid') {
      badgeColor = Colors.green;
    } else if (status == 'Partially Paid') {
      badgeColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(25),
        border: Border.all(color: badgeColor.withAlpha(80)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: badgeColor),
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
