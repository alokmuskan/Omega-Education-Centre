import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/services/audit_service.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/utils/attendance_date_validator.dart';
import '../models/teacher_payment_model.dart';
import '../models/teacher_salary_summary_model.dart';

/// Repository for Teacher Salary calculation and Cash Payment SQLite operations.
///
/// Financial Rules Enforced:
/// 1. Earned Salary = Total Hours Worked in Month × teacher.payPerHour.
/// 2. Actual Payments = Separate transaction records in teacher_payments.
/// 3. Overpayment Prevention = Amount cannot exceed remaining due for selected month.
/// 4. Future Months = Returns 0 hours and 0 earned salary to prevent fake future earnings.
/// 5. Inactive Teachers = Historical attendance and payment records remain 100% accessible.
class TeacherSalaryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ──────────────────────────────────────────────────────────────────────
  // Get Monthly Salary Summary List for All Teachers
  // yearMonth format: 'YYYY-MM'
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TeacherSalarySummaryModel>> getMonthlySalarySummaryList({
    required String yearMonth,
  }) async {
    final db = await _dbHelper.database;
    final currentYearMonth = DateFormat('yyyy-MM').format(DateTime.now());

    final isFutureMonth = yearMonth.compareTo(currentYearMonth) > 0;

    // Fetch all teachers (active and inactive)
    final teacherMaps = await db.query(
      'teachers',
      orderBy: 'name ASC',
    );

    final summaryList = <TeacherSalarySummaryModel>[];

    for (final tMap in teacherMaps) {
      final teacherId = tMap['id'] as int;
      final teacherName = tMap['name'] as String;
      final teacherSubject = tMap['subject'] as String;
      final teacherMobile = tMap['mobile'] as String;
      final payPerHour = (tMap['payPerHour'] as num).toDouble();
      final isActive = (tMap['isActive'] as int? ?? 1) == 1;

      double totalHours = 0.0;
      double computedEarnedSalary = 0.0;

      if (!isFutureMonth) {
        // Fetch all attendance records for teacher in selected month
        final attendanceRows = await db.query(
          'teacher_attendance',
          where: 'teacherId = ? AND date LIKE ?',
          whereArgs: [teacherId, '$yearMonth%'],
        );

        for (final row in attendanceRows) {
          final attDate = row['date'] as String;
          final hrs = (row['hoursWorked'] as num).toDouble();
          totalHours += hrs;

          // Find applicable pay rate for this date from teacher_pay_rate_history
          final rateRows = await db.rawQuery(
            '''
            SELECT payPerHour FROM teacher_pay_rate_history
            WHERE teacherId = ? AND effectiveFrom <= ? AND (effectiveTo IS NULL OR effectiveTo >= ?)
            ORDER BY effectiveFrom DESC LIMIT 1
            ''',
            [teacherId, attDate, attDate],
          );

          final applicableRate = rateRows.isNotEmpty
              ? (rateRows.first['payPerHour'] as num).toDouble()
              : payPerHour;

          computedEarnedSalary += (hrs * applicableRate);
        }
      }

      // Sum payments recorded for this teacher & month
      double totalPaid = 0.0;
      final paidResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0.0) AS totalPaid
        FROM teacher_payments
        WHERE teacherId = ? AND month = ?
        ''',
        [teacherId, yearMonth],
      );
      if (paidResult.isNotEmpty) {
        totalPaid = (paidResult.first['totalPaid'] as num).toDouble();
      }

      // If teacher is inactive and has 0 hours and 0 paid in this month, skip from summary list
      if (!isActive && totalHours <= 0 && totalPaid <= 0) {
        continue;
      }

      final summary = TeacherSalarySummaryModel.compute(
        teacherId: teacherId,
        teacherName: teacherName,
        teacherSubject: teacherSubject,
        teacherMobile: teacherMobile,
        payPerHour: payPerHour,
        month: yearMonth,
        totalHoursWorked: totalHours,
        customEarnedSalary: computedEarnedSalary,
        totalPaid: totalPaid,
        isActive: isActive,
      );

      summaryList.add(summary);
    }

    return summaryList;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Salary Summary for a Specific Teacher & Month
  // ──────────────────────────────────────────────────────────────────────

  Future<TeacherSalarySummaryModel?> getTeacherMonthlySalarySummary({
    required int teacherId,
    required String yearMonth,
  }) async {
    final list = await getMonthlySalarySummaryList(yearMonth: yearMonth);
    try {
      return list.firstWhere((s) => s.teacherId == teacherId);
    } catch (_) {
      // If teacher wasn't included (e.g. inactive with no records), fetch directly
      final db = await _dbHelper.database;
      final maps = await db.query(
        'teachers',
        where: 'id = ?',
        whereArgs: [teacherId],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      final tMap = maps.first;

      return TeacherSalarySummaryModel.compute(
        teacherId: teacherId,
        teacherName: tMap['name'] as String,
        teacherSubject: tMap['subject'] as String,
        teacherMobile: tMap['mobile'] as String,
        payPerHour: (tMap['payPerHour'] as num).toDouble(),
        month: yearMonth,
        totalHoursWorked: 0.0,
        totalPaid: 0.0,
        isActive: (tMap['isActive'] as int? ?? 1) == 1,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Payment History for a Teacher
  // ──────────────────────────────────────────────────────────────────────

  Future<List<TeacherPaymentModel>> getTeacherPaymentHistory(
    int teacherId, {
    String? yearMonth,
  }) async {
    final db = await _dbHelper.database;

    final conditions = ['teacherId = ?'];
    final args = <dynamic>[teacherId];

    if (yearMonth != null && yearMonth.isNotEmpty) {
      conditions.add('month = ?');
      args.add(yearMonth);
    }

    final maps = await db.query(
      'teacher_payments',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'paymentDate DESC, id DESC',
    );

    return maps.map(TeacherPaymentModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Record Cash Salary Payment
  // Validates amount > 0, non-future payment date, and amount <= remaining due.
  // ──────────────────────────────────────────────────────────────────────

  Future<int> recordSalaryPayment(TeacherPaymentModel payment) async {
    if (payment.amount <= 0) {
      throw ArgumentError('Payment amount must be greater than ₹0.');
    }

    // Validate non-future payment date
    AttendanceDateValidator.validateNotFuture(payment.paymentDate);

    // Get current remaining due to prevent overpayment
    final summary = await getTeacherMonthlySalarySummary(
      teacherId: payment.teacherId,
      yearMonth: payment.month,
    );

    final remainingDue = summary?.remainingDue ?? 0.0;

    // Prevent payment exceeding remaining salary (round to 2 decimal places)
    final roundedAmount = (payment.amount * 100).roundToDouble() / 100.0;
    final roundedDue = (remainingDue * 100).roundToDouble() / 100.0;

    if (roundedAmount > roundedDue) {
      throw ArgumentError(
        'Payment cannot exceed remaining salary (Remaining Due: ₹${roundedDue.toStringAsFixed(0)}).',
      );
    }

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final map = payment.toMap();
    map['createdAt'] = now;
    map['updatedAt'] = now;

    final paymentId = await db.insert('teacher_payments', map);

    // Audit log
    await AuditService.instance.logAction(
      action: AuditService.actionSalaryPayment,
      entityType: 'teacher_payments',
      entityId: paymentId.toString(),
      newValue: {
        'teacherId': payment.teacherId,
        'amount': payment.amount,
        'month': payment.month,
        'paymentMethod': payment.paymentMethod,
      },
    );

    // Sync to cloud
    SyncEngine.instance.registerTeacherPaymentChange(
      paymentId: paymentId,
      operation: 'CREATE',
      payload: map,
    );

    return paymentId;
  }

  Future<double> getCenterWideSalaryDue({required String yearMonth}) async {
    final list = await getMonthlySalarySummaryList(yearMonth: yearMonth);
    return list.fold<double>(0.0, (sum, s) => sum + s.remainingDue);
  }
}

