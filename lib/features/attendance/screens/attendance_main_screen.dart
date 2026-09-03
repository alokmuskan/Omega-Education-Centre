import 'package:flutter/material.dart';

import 'student_attendance_screen.dart';
import 'teacher_attendance_screen.dart';
import '../../../shared/utils/app_session.dart';

/// Main Attendance module shell hosting Student Attendance & Teacher Attendance tabs.
class AttendanceMainScreen extends StatelessWidget {
  const AttendanceMainScreen({super.key});

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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Management'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.people_alt_outlined),
                text: 'Student Attendance',
              ),
              Tab(
                icon: Icon(Icons.school_outlined),
                text: 'Teacher Attendance',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            StudentAttendanceScreen(),
            TeacherAttendanceScreen(),
          ],
        ),
      ),
    );
  }
}
