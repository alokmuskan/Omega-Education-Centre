import 'package:flutter/material.dart';

import '../../academic_calendar/screens/academic_calendar_screen.dart';
import '../../analytics/screens/analytics_dashboard_screen.dart';
import '../../attendance/screens/attendance_main_screen.dart';
import '../../backup/screens/backup_restore_screen.dart';
import '../../batches/screens/batch_management_screen.dart';
import '../../branches/screens/branch_management_screen.dart';
import '../../class_register/screens/daily_class_register_main_screen.dart';
import '../../fees/screens/admin_fee_dashboard_screen.dart';
import '../../homework/screens/homework_list_screen.dart';
import '../../library/screens/library_screen.dart';
import '../../notices/screens/notice_management_screen.dart';
import '../../salary/screens/salary_dashboard_screen.dart';
import '../../settings/screens/institute_settings_screen.dart';
import '../../students/screens/student_screen.dart';
import '../../teachers/screens/teacher_screen.dart';
import '../../tests/screens/tests_main_screen.dart';
import '../../transport/screens/transport_management_screen.dart';
import '../../../shared/screens/license_screen.dart';
import '../../../shared/screens/notification_center_screen.dart';
import '../../audit/screens/audit_log_screen.dart';
import 'menu_card.dart';

/// Dashboard Quick Actions Grid
///
/// Displays a grid of navigation cards for quick access to all modules.
class DashboardQuickActions extends StatelessWidget {
  final VoidCallback? onDataRefresh;

  const DashboardQuickActions({
    super.key,
    this.onDataRefresh,
  });

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => onDataRefresh?.call());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
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
            // Core Modules
            MenuCard(
              title: "Students",
              icon: Icons.people,
              color: Colors.blue,
              onTap: () => _navigateTo(context, const StudentScreen()),
            ),
            MenuCard(
              title: "Teachers",
              icon: Icons.school,
              color: Colors.green,
              onTap: () => _navigateTo(context, const TeacherScreen()),
            ),
            MenuCard(
              title: "Attendance",
              icon: Icons.calendar_month,
              color: Colors.orange,
              onTap: () => _navigateTo(context, const AttendanceMainScreen()),
            ),
            MenuCard(
              title: "Notices",
              icon: Icons.campaign,
              color: Colors.amber.shade800,
              onTap: () => _navigateTo(context, const NoticeManagementScreen()),
            ),
            MenuCard(
              title: "Results",
              icon: Icons.bar_chart,
              color: Colors.purple,
              onTap: () => _navigateTo(context, const TestsMainScreen()),
            ),
            MenuCard(
              title: "Salary",
              icon: Icons.account_balance_wallet,
              color: Colors.teal,
              onTap: () => _navigateTo(context, const SalaryDashboardScreen()),
            ),
            MenuCard(
              title: "Class Register",
              icon: Icons.assignment_outlined,
              color: Colors.deepOrange,
              onTap: () => _navigateTo(context, const DailyClassRegisterMainScreen()),
            ),
            MenuCard(
              title: "Fees",
              icon: Icons.currency_rupee,
              color: Colors.blueGrey,
              onTap: () => _navigateTo(context, const AdminFeeDashboardScreen()),
            ),
            MenuCard(
              title: "Timetable",
              icon: Icons.schedule,
              color: Colors.indigo,
              onTap: () => _navigateTo(context, const DailyClassRegisterMainScreen()),
            ),

            // Academic Modules
            MenuCard(
              title: "Academic Calendar",
              icon: Icons.calendar_month,
              color: Colors.brown,
              onTap: () => _navigateTo(context, const AcademicCalendarScreen()),
            ),
            MenuCard(
              title: "Homework",
              icon: Icons.school,
              color: Colors.cyan,
              onTap: () => _navigateTo(context, const HomeworkListScreen()),
            ),
            MenuCard(
              title: "Notifications",
              icon: Icons.notifications,
              color: Colors.pink,
              onTap: () => _navigateTo(context, const NotificationCenterScreen()),
            ),

            // Operations
            MenuCard(
              title: "Library",
              icon: Icons.menu_book,
              color: Colors.brown.shade700,
              onTap: () => _navigateTo(context, const LibraryScreen()),
            ),
            MenuCard(
              title: "Transport",
              icon: Icons.directions_bus,
              color: Colors.green.shade700,
              onTap: () => _navigateTo(context, const TransportManagementScreen()),
            ),
            MenuCard(
              title: "Batches",
              icon: Icons.groups,
              color: Colors.cyan,
              onTap: () => _navigateTo(context, const BatchManagementScreen()),
            ),
            MenuCard(
              title: "Branches",
              icon: Icons.location_city,
              color: Colors.teal,
              onTap: () => _navigateTo(context, const BranchManagementScreen()),
            ),

            // Analytics & Reports
            MenuCard(
              title: "Analytics",
              icon: Icons.analytics,
              color: Colors.deepPurple,
              onTap: () => _navigateTo(context, const AnalyticsDashboardScreen()),
            ),
            MenuCard(
              title: "Backup & Restore",
              icon: Icons.settings_backup_restore,
              color: Colors.indigo,
              onTap: () => _navigateTo(context, const BackupRestoreScreen()),
            ),
            MenuCard(
              title: "Institute Config",
              icon: Icons.settings,
              color: Colors.blueAccent,
              onTap: () => _navigateTo(context, const InstituteSettingsScreen()),
            ),
            MenuCard(
              title: "Audit Log",
              icon: Icons.history,
              color: Colors.teal,
              onTap: () => _navigateTo(context, const AuditLogScreen()),
            ),
            MenuCard(
              title: "License",
              icon: Icons.vpn_key,
              color: Colors.amber,
              onTap: () => _navigateTo(context, const LicenseScreen()),
            ),
          ],
        ),
      ],
    );
  }
}
