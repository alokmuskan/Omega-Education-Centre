import 'package:flutter/material.dart';

import 'summary_card.dart';

/// Dashboard Statistics Section
///
/// Displays summary cards for key metrics:
/// - Total Students
/// - Total Teachers
/// - Today's Classes
/// - Teacher Hours Today
class DashboardStatsSection extends StatelessWidget {
  final int studentCount;
  final int teacherCount;
  final int classesTodayCount;
  final double teacherHoursToday;

  const DashboardStatsSection({
    super.key,
    required this.studentCount,
    required this.teacherCount,
    required this.classesTodayCount,
    required this.teacherHoursToday,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Overview",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'Students',
                value: studentCount.toString(),
                icon: Icons.people,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: 'Teachers',
                value: teacherCount.toString(),
                icon: Icons.school,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: "Today's Classes",
                value: classesTodayCount.toString(),
                icon: Icons.class_,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                title: 'Teacher Hours',
                value: teacherHoursToday.toStringAsFixed(1),
                icon: Icons.access_time,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
