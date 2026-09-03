import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../students/models/student_model.dart';
import '../models/fee_installment_model.dart';
import '../models/fee_model.dart';
import '../models/fee_payment_model.dart';

/// Class-level fee summary statistics.
class ClassFeeSummary {
  final String studentClass;
  final String board;
  final String? batch;
  final int totalStudents;
  final double totalPayable;
  final double totalCollected;
  final double totalOutstanding;
  final int paidCount;
  final int partiallyPaidCount;
  final int unpaidCount;

  const ClassFeeSummary({
    required this.studentClass,
    required this.board,
    this.batch,
    required this.totalStudents,
    required this.totalPayable,
    required this.totalCollected,
    required this.totalOutstanding,
    required this.paidCount,
    required this.partiallyPaidCount,
    required this.unpaidCount,
  });
}

/// Student Fee Item for Pending Fees & Master Admin list views.
class StudentFeeRecord {
  final StudentModel student;
  final FeeModel? feePlan;
  final double totalPayable;
  final double totalPaid;
  final double remainingDue;
  final String feeStatus; // 'Unpaid' | 'Partially Paid' | 'Paid'

  const StudentFeeRecord({
    required this.student,
    this.feePlan,
    required this.totalPayable,
    required this.totalPaid,
    required this.remainingDue,
    required this.feeStatus,
  });
}

/// Manages all fee-related database operations for Omega Education Centre ERP.
class FeeRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ──────────────────────────────────────────────────────────────────────
  // Atomic Admission Save
  // ──────────────────────────────────────────────────────────────────────

  Future<int> saveAdmissionFee({
    required FeeModel feePlan,
    List<FeeInstallmentModel> installments = const [],
    FeePaymentModel? admissionPayment,
  }) async {
    final db = await _db.database;
    int feeId = -1;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'fees',
        where: 'studentId = ?',
        whereArgs: [feePlan.studentId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        feeId = existing.first['id'] as int;
        await txn.update(
          'fees',
          feePlan.toMap(),
          where: 'id = ?',
          whereArgs: [feeId],
        );
      } else {
        feeId = await txn.insert('fees', feePlan.toMap());
      }

      for (int i = 0; i < installments.length; i++) {
        final inst = installments[i].copyWith(feeId: feeId);
        await txn.insert('fee_installments', inst.toMap());
      }

      if (admissionPayment != null && admissionPayment.amount > 0) {
        _validatePaymentDate(admissionPayment.paymentDate);

        final nowIso = DateTime.now().toIso8601String();
        final pMap = admissionPayment.toMap();
        pMap['feeId'] = feeId;
        pMap['createdAt'] = admissionPayment.createdAt ?? nowIso;
        if (pMap['receiptNo'] == null) {
          final countRes = await txn.rawQuery('SELECT COUNT(*) as cnt FROM fee_payments');
          final cnt = (countRes.first['cnt'] as int) + 1;
          pMap['receiptNo'] = 'REC-${DateFormat('yyyyMMdd').format(DateTime.now())}-${cnt.toString().padLeft(4, '0')}';
        }

        await txn.insert('fee_payments', pMap);
      }

      await _updateStudentFeeStatusTxn(txn, feePlan.studentId);
    });

    return feeId;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Record Payment with Strict Validations
  // ──────────────────────────────────────────────────────────────────────

  Future<int> recordPayment(FeePaymentModel payment) async {
    if (payment.amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    _validatePaymentDate(payment.paymentDate);

    final db = await _db.database;
    int paymentId = -1;

    await db.transaction((txn) async {
      // 1. Get Fee Plan
      final feeMaps = await txn.query(
        'fees',
        where: 'studentId = ?',
        whereArgs: [payment.studentId],
        limit: 1,
      );

      if (feeMaps.isEmpty) {
        throw ArgumentError('No fee structure configured for this student. Set total fee first.');
      }

      final feePlan = FeeModel.fromMap(feeMaps.first);
      final totalPayable = feePlan.totalFee;

      // 2. Calculate current paid
      final paidRes = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0.0) as total FROM fee_payments WHERE studentId = ?',
        [payment.studentId],
      );
      final currentPaid = (paidRes.first['total'] as num).toDouble();
      final remainingDue = totalPayable - currentPaid;

      if (remainingDue <= 0) {
        throw ArgumentError('This student has already fully paid their fee (Remaining Due: ₹0.00).');
      }

      if (payment.amount > (remainingDue + 0.01)) {
        throw ArgumentError(
          'Overpayment Rejected: Payment amount (₹${payment.amount.toStringAsFixed(2)}) exceeds remaining due (₹${remainingDue.toStringAsFixed(2)}).',
        );
      }

      // 3. Generate Receipt Number if empty
      final countRes = await txn.rawQuery('SELECT COUNT(*) as cnt FROM fee_payments');
      final cnt = (countRes.first['cnt'] as int) + 1;
      final receiptNo = payment.receiptNo ?? 'REC-${DateFormat('yyyyMMdd').format(DateTime.now())}-${cnt.toString().padLeft(4, '0')}';

      final nowIso = DateTime.now().toIso8601String();
      final pMap = payment.toMap();
      pMap['feeId'] = feePlan.id;
      pMap['receiptNo'] = receiptNo;
      pMap['createdAt'] = payment.createdAt ?? nowIso;

      paymentId = await txn.insert('fee_payments', pMap);

      // 4. Update student fee status in database
      await _updateStudentFeeStatusTxn(txn, payment.studentId);
    });

    return paymentId;
  }

  void _validatePaymentDate(String dateStr) {
    try {
      final pDate = DateTime.parse(dateStr.trim());
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pDateNormalized = DateTime(pDate.year, pDate.month, pDate.day);

      if (pDateNormalized.isAfter(today)) {
        throw ArgumentError('Future payment dates are rejected ($dateStr). Payment date must be today or earlier.');
      }
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw ArgumentError('Invalid payment date format: $dateStr');
    }
  }

  Future<void> _updateStudentFeeStatusTxn(dynamic txn, int studentId) async {
    final feeMaps = await txn.query(
      'fees',
      where: 'studentId = ?',
      whereArgs: [studentId],
      limit: 1,
    );

    if (feeMaps.isEmpty) return;
    final totalPayable = (feeMaps.first['totalFee'] as num).toDouble();

    final paidRes = await txn.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) as total FROM fee_payments WHERE studentId = ?',
      [studentId],
    );
    final paid = (paidRes.first['total'] as num).toDouble();

    String status = 'Unpaid';
    if (paid >= totalPayable) {
      status = 'Paid';
    } else if (paid > 0) {
      status = 'Partially Paid';
    }

    await txn.update(
      'students',
      {'feeStatus': status},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Queries
  // ──────────────────────────────────────────────────────────────────────

  Future<FeeModel?> getFeeForStudent(int studentId) async {
    final db = await _db.database;
    final maps = await db.query(
      'fees',
      where: 'studentId = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return FeeModel.fromMap(maps.first);
  }

  Future<List<FeePaymentModel>> getPaymentsForStudent(int studentId) async {
    final db = await _db.database;
    final maps = await db.query(
      'fee_payments',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'paymentDate DESC, id DESC',
    );
    return maps.map(FeePaymentModel.fromMap).toList();
  }

  Future<List<FeeInstallmentModel>> getInstallmentsForStudent(int studentId) async {
    final db = await _db.database;
    final maps = await db.query(
      'fee_installments',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'dueDate ASC',
    );
    return maps.map(FeeInstallmentModel.fromMap).toList();
  }

  Future<double> getTotalPaid(int studentId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0.0) as total FROM fee_payments WHERE studentId = ?',
      [studentId],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getOutstanding(int studentId) async {
    final fee = await getFeeForStudent(studentId);
    if (fee == null) return 0.0;
    final paid = await getTotalPaid(studentId);
    final outstanding = fee.totalFee - paid;
    return outstanding < 0 ? 0.0 : outstanding;
  }

  Future<String> computeFeeStatus(int studentId) async {
    final fee = await getFeeForStudent(studentId);
    if (fee == null) return 'Unpaid';
    final paid = await getTotalPaid(studentId);
    if (paid <= 0) return 'Unpaid';
    if (paid >= fee.totalFee) return 'Paid';
    return 'Partially Paid';
  }

  // ──────────────────────────────────────────────────────────────────────
  // Fee Reports & Student Record Aggregation
  // ──────────────────────────────────────────────────────────────────────

  Future<List<StudentFeeRecord>> getAllStudentFeeRecords({
    String? searchQuery,
    String? studentClass,
    String? board,
    String? batch,
    String? feeStatus,
    bool pendingOnly = false,
  }) async {
    final db = await _db.database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      whereClauses.add('(name LIKE ? OR rollNo LIKE ? OR mobile LIKE ?)');
      whereArgs.addAll([q, q, q]);
    }

    if (studentClass != null && studentClass != 'All' && studentClass.isNotEmpty) {
      whereClauses.add('studentClass = ?');
      whereArgs.add(studentClass);
    }

    if (board != null && board != 'All' && board.isNotEmpty) {
      whereClauses.add('board = ?');
      whereArgs.add(board);
    }

    final whereStr = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final studentMaps = await db.rawQuery('SELECT * FROM students $whereStr ORDER BY name ASC', whereArgs);

    final List<StudentFeeRecord> records = [];

    for (final map in studentMaps) {
      final student = StudentModel.fromMap(map);
      final feePlan = await getFeeForStudent(student.id!);
      final totalPayable = feePlan?.totalFee ?? 0.0;
      final totalPaid = await getTotalPaid(student.id!);
      final remainingDue = totalPayable > totalPaid ? (totalPayable - totalPaid) : 0.0;

      String status = 'Unpaid';
      if (totalPaid >= totalPayable && totalPayable > 0) {
        status = 'Paid';
      } else if (totalPaid > 0) {
        status = 'Partially Paid';
      }

      if (pendingOnly && remainingDue <= 0) continue;

      if (feeStatus != null && feeStatus != 'All' && feeStatus.isNotEmpty) {
        if (status.toLowerCase() != feeStatus.toLowerCase()) continue;
      }

      records.add(StudentFeeRecord(
        student: student,
        feePlan: feePlan,
        totalPayable: totalPayable,
        totalPaid: totalPaid,
        remainingDue: remainingDue,
        feeStatus: status,
      ));
    }

    if (pendingOnly) {
      records.sort((a, b) => b.remainingDue.compareTo(a.remainingDue));
    }

    return records;
  }

  Future<ClassFeeSummary> getClassFeeSummary(
    String studentClass, {
    String? board,
    String? batch,
  }) async {
    final records = await getAllStudentFeeRecords(
      studentClass: studentClass,
      board: board,
      batch: batch,
    );

    int totalStudents = records.length;
    double totalPayable = 0.0;
    double totalCollected = 0.0;
    double totalOutstanding = 0.0;
    int paidCount = 0;
    int partiallyPaidCount = 0;
    int unpaidCount = 0;

    for (final r in records) {
      totalPayable += r.totalPayable;
      totalCollected += r.totalPaid;
      totalOutstanding += r.remainingDue;

      if (r.feeStatus == 'Paid') {
        paidCount++;
      } else if (r.feeStatus == 'Partially Paid') {
        partiallyPaidCount++;
      } else {
        unpaidCount++;
      }
    }

    return ClassFeeSummary(
      studentClass: studentClass,
      board: board ?? 'All',
      batch: batch,
      totalStudents: totalStudents,
      totalPayable: totalPayable,
      totalCollected: totalCollected,
      totalOutstanding: totalOutstanding,
      paidCount: paidCount,
      partiallyPaidCount: partiallyPaidCount,
      unpaidCount: unpaidCount,
    );
  }

  Future<double> getCenterWideOutstandingFees() async {
    final db = await _db.database;
    final totalFeeRes = await db.rawQuery('SELECT COALESCE(SUM(totalFee), 0.0) as total FROM fees');
    final totalPaidRes = await db.rawQuery('SELECT COALESCE(SUM(amount), 0.0) as total FROM fee_payments');
    final totalFee = (totalFeeRes.first['total'] as num).toDouble();
    final totalPaid = (totalPaidRes.first['total'] as num).toDouble();
    final diff = totalFee - totalPaid;
    return diff < 0 ? 0.0 : diff;
  }
}

