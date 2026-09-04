import 'package:intl/intl.dart';

import '../../core/database/database_helper.dart';

/// Aggregated analytics data for the admin dashboard.
class FeeTrendData {
  final String month;
  final double collected;
  final double pending;

  const FeeTrendData({required this.month, required this.collected, required this.pending});
}

class AttendanceTrendData {
  final String date;
  final double presentPercent;
  final int totalStudents;

  const AttendanceTrendData({required this.date, required this.presentPercent, required this.totalStudents});
}

class TeacherMetricData {
  final String name;
  final double hoursWorked;
  final int classesConducted;

  const TeacherMetricData({required this.name, required this.hoursWorked, required this.classesConducted});
}

class AnalyticsSummary {
  final double totalFeeCollected;
  final double totalFeePending;
  final double averageAttendance;
  final int totalStudents;
  final int totalTeachers;
  final int totalClasses;
  final List<FeeTrendData> feeTrend;
  final List<AttendanceTrendData> attendanceTrend;
  final List<TeacherMetricData> teacherMetrics;

  const AnalyticsSummary({
    required this.totalFeeCollected,
    required this.totalFeePending,
    required this.averageAttendance,
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalClasses,
    required this.feeTrend,
    required this.attendanceTrend,
    required this.teacherMetrics,
  });
}

/// Service for computing analytics from local SQLite or Supabase.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Fetches analytics for a given date range from local SQLite.
  Future<AnalyticsSummary> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 90));
    final end = endDate ?? DateTime.now();
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    // 1. Fee trends (monthly for last 6 months)
    final feeTrend = await _getFeeTrend(db, start, end);

    // 2. Total collected and pending
    double totalCollected = 0;
    double totalPending = 0;
    for (final f in feeTrend) {
      totalCollected += f.collected;
      totalPending += f.pending;
    }

    // 3. Attendance trend (daily for last 30 days)
    final attendanceTrend = await _getAttendanceTrend(db, start, end);

    // 4. Average attendance
    double avgAttendance = 0;
    if (attendanceTrend.isNotEmpty) {
      avgAttendance = attendanceTrend.map((a) => a.presentPercent).reduce((a, b) => a + b) / attendanceTrend.length;
    }

    // 5. Counts
    final studentCount = (await db.rawQuery('SELECT COUNT(*) as cnt FROM students WHERE isActive = 1')).first['cnt'] as int? ?? 0;
    final teacherCount = (await db.rawQuery('SELECT COUNT(*) as cnt FROM teachers WHERE isActive = 1')).first['cnt'] as int? ?? 0;
    final classCount = (await db.rawQuery('SELECT COUNT(*) as cnt FROM daily_class_records WHERE date >= ? AND date <= ?', [startStr, endStr])).first['cnt'] as int? ?? 0;

    // 6. Teacher metrics
    final teacherMetrics = await _getTeacherMetrics(db, start, end);

    return AnalyticsSummary(
      totalFeeCollected: totalCollected,
      totalFeePending: totalPending,
      averageAttendance: avgAttendance,
      totalStudents: studentCount,
      totalTeachers: teacherCount,
      totalClasses: classCount,
      feeTrend: feeTrend,
      attendanceTrend: attendanceTrend,
      teacherMetrics: teacherMetrics,
    );
  }

  Future<List<FeeTrendData>> _getFeeTrend(dynamic db, DateTime start, DateTime end) async {
    final result = <FeeTrendData>[];
    var current = DateTime(start.year, start.month);
    final endMonth = DateTime(end.year, end.month);

    while (!current.isAfter(endMonth)) {
      final monthStr = DateFormat('yyyy-MM').format(current);

      // Collected this month
      final collectedRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0.0) as total FROM fee_payments WHERE strftime('%Y-%m', paymentDate) = ?",
        [monthStr],
      );
      final collected = (collectedRes.first['total'] as num?)?.toDouble() ?? 0.0;

      // Pending (fees due this month minus collected)
      final feeRes = await db.rawQuery(
        "SELECT COALESCE(SUM(courseFee), 0.0) as total FROM fees WHERE strftime('%Y-%m', startMonth) = ? OR startMonth IS NULL",
        [monthStr],
      );
      final totalFee = (feeRes.first['total'] as num?)?.toDouble() ?? 0.0;
      final pending = totalFee > collected ? totalFee - collected : 0.0;

      result.add(FeeTrendData(
        month: DateFormat('MMM yyyy').format(current),
        collected: collected,
        pending: pending,
      ));

      current = DateTime(current.year, current.month + 1);
    }

    return result;
  }

  Future<List<AttendanceTrendData>> _getAttendanceTrend(dynamic db, DateTime start, DateTime end) async {
    final result = <AttendanceTrendData>[];
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    final rows = await db.rawQuery(
      '''SELECT date,
                COUNT(*) as total,
                SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) as present
         FROM student_attendance
         WHERE date >= ? AND date <= ?
         GROUP BY date
         ORDER BY date ASC''',
      [startStr, endStr],
    );

    for (final row in rows) {
      final total = (row['total'] as int?) ?? 0;
      final present = (row['present'] as int?) ?? 0;
      final percent = total > 0 ? (present / total * 100) : 0.0;

      result.add(AttendanceTrendData(
        date: row['date'] as String? ?? '',
        presentPercent: percent,
        totalStudents: total,
      ));
    }

    return result;
  }

  Future<List<TeacherMetricData>> _getTeacherMetrics(dynamic db, DateTime start, DateTime end) async {
    final result = <TeacherMetricData>[];
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    final teachers = await db.rawQuery('SELECT id, name FROM teachers WHERE isActive = 1');

    for (final t in teachers) {
      final tId = t['id'];
      final name = t['name'] as String? ?? 'Teacher';

      // Hours worked
      final hoursRes = await db.rawQuery(
        "SELECT COALESCE(SUM(hoursWorked), 0.0) as total FROM teacher_attendance WHERE teacherId = ? AND date >= ? AND date <= ?",
        [tId, startStr, endStr],
      );
      final hours = (hoursRes.first['total'] as num?)?.toDouble() ?? 0.0;

      // Classes conducted
      final classRes = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM daily_class_records WHERE teacherId = ? AND date >= ? AND date <= ?",
        [tId, startStr, endStr],
      );
      final classes = (classRes.first['cnt'] as int?) ?? 0;

      result.add(TeacherMetricData(name: name, hoursWorked: hours, classesConducted: classes));
    }

    return result;
  }

  /// Exports analytics summary as a formatted text report.
  String exportAsText(AnalyticsSummary summary) {
    final sb = StringBuffer();
    sb.writeln('=== Omega Education Centre — Analytics Report ===');
    sb.writeln('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}');
    sb.writeln();
    sb.writeln('--- Overview ---');
    sb.writeln('Total Students: ${summary.totalStudents}');
    sb.writeln('Total Teachers: ${summary.totalTeachers}');
    sb.writeln('Total Classes: ${summary.totalClasses}');
    sb.writeln('Average Attendance: ${summary.averageAttendance.toStringAsFixed(1)}%');
    sb.writeln();
    sb.writeln('--- Fee Summary ---');
    sb.writeln('Total Collected: ₹${summary.totalFeeCollected.toStringAsFixed(0)}');
    sb.writeln('Total Pending: ₹${summary.totalFeePending.toStringAsFixed(0)}');
    sb.writeln();
    sb.writeln('--- Fee Trend ---');
    for (final f in summary.feeTrend) {
      sb.writeln('  ${f.month}: Collected ₹${f.collected.toStringAsFixed(0)} | Pending ₹${f.pending.toStringAsFixed(0)}');
    }
    sb.writeln();
    sb.writeln('--- Teacher Performance ---');
    for (final t in summary.teacherMetrics) {
      sb.writeln('  ${t.name}: ${t.hoursWorked.toStringAsFixed(1)} hrs, ${t.classesConducted} classes');
    }

    return sb.toString();
  }
}
