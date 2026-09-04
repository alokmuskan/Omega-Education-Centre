import 'package:flutter/material.dart';

/// Dashboard Attendance Section
///
/// Displays student attendance breakdown:
/// - Present
/// - Absent
/// - Late
/// - Leave
class DashboardAttendanceSection extends StatelessWidget {
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final int teachersRecordedCount;

  const DashboardAttendanceSection({
    super.key,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
    required this.teachersRecordedCount,
  });

  @override
  Widget build(BuildContext context) {
    final totalStudents = presentCount + absentCount + lateCount + leaveCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Student Attendance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Attendance breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttendanceItem('Present', presentCount, Colors.green),
                    _buildAttendanceItem('Absent', absentCount, Colors.red),
                    _buildAttendanceItem('Late', lateCount, Colors.orange),
                    _buildAttendanceItem('Leave', leaveCount, Colors.blue),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                if (totalStudents > 0) ...[
                  LinearProgressIndicator(
                    value: presentCount / totalStudents,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$presentCount of $totalStudents students present (${(presentCount / totalStudents * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
                const Divider(height: 24),
                // Teachers recorded
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.teal.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Teachers Recorded',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    Text(
                      '$teachersRecordedCount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceItem(String label, int count, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withAlpha(30),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
