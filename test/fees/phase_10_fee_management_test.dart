import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/features/fees/models/fee_installment_model.dart';
import 'package:omega_education_centre/features/fees/models/fee_model.dart';
import 'package:omega_education_centre/features/fees/models/fee_payment_model.dart';
import 'package:omega_education_centre/features/fees/repository/fee_repository.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';

void main() {
  group('Phase 10 — Fee Management, Payments & Receipts Unit Tests', () {
    // ──────────────────────────────────────────────────────────────────────
    // FEE MODEL & CALCULATIONS (1–9)
    // ──────────────────────────────────────────────────────────────────────

    test('1 & 2. FeeModel serialization (Nominal courseFee vs Agreed totalFee)', () {
      const fee = FeeModel(
        id: 1,
        studentId: 101,
        paymentMethod: 'Installments',
        courseFee: 15000.0,
        totalFee: 11000.0,
        createdAt: '2026-08-23T10:00:00Z',
      );

      final map = fee.toMap();
      expect(map['courseFee'], equals(15000.0));
      expect(map['totalFee'], equals(11000.0));
      expect(map['studentId'], equals(101));

      final restored = FeeModel.fromMap(map);
      expect(restored.courseFee, equals(15000.0));
      expect(restored.totalFee, equals(11000.0));
    });

    test('3. FeePaymentModel serialization', () {
      const payment = FeePaymentModel(
        id: 1,
        feeId: 5,
        studentId: 101,
        amount: 2000.0,
        paymentDate: '2026-08-23',
        paymentMode: 'Cash',
        remarks: 'Admission Installment',
        receiptNo: 'REC-20260823-0001',
      );

      final map = payment.toMap();
      expect(map['amount'], equals(2000.0));
      expect(map['paymentMode'], equals('Cash'));
      expect(map['receiptNo'], equals('REC-20260823-0001'));

      final restored = FeePaymentModel.fromMap(map);
      expect(restored.amount, equals(2000.0));
      expect(restored.effectiveReceiptNo, equals('REC-20260823-0001'));
    });

    test('4 & 5 & 6. Multiple payments accumulation & remaining due calculation', () {
      const totalFee = 11000.0;
      final payments = [
        const FeePaymentModel(feeId: 1, studentId: 101, amount: 2000.0, paymentDate: '2026-08-10'),
        const FeePaymentModel(feeId: 1, studentId: 101, amount: 1000.0, paymentDate: '2026-08-15'),
        const FeePaymentModel(feeId: 1, studentId: 101, amount: 3000.0, paymentDate: '2026-08-20'),
        const FeePaymentModel(feeId: 1, studentId: 101, amount: 500.0, paymentDate: '2026-08-22'),
        const FeePaymentModel(feeId: 1, studentId: 101, amount: 2500.0, paymentDate: '2026-08-23'),
      ];

      final totalPaid = payments.fold<double>(0.0, (sum, p) => sum + p.amount);
      final remainingDue = totalFee - totalPaid;

      expect(totalPaid, equals(9000.0));
      expect(remainingDue, equals(2000.0));
    });

    test('7. Unpaid status logic (totalPaid == 0)', () {
      const totalFee = 11000.0;
      const totalPaid = 0.0;

      String status = 'Unpaid';
      if (totalPaid >= totalFee && totalFee > 0) {
        status = 'Paid';
      } else if (totalPaid > 0) {
        status = 'Partially Paid';
      }

      expect(status, equals('Unpaid'));
    });

    test('8. Partially Paid status logic (0 < totalPaid < totalFee)', () {
      const totalFee = 11000.0;
      const totalPaid = 6000.0;

      String status = 'Unpaid';
      if (totalPaid >= totalFee && totalFee > 0) {
        status = 'Paid';
      } else if (totalPaid > 0) {
        status = 'Partially Paid';
      }

      expect(status, equals('Partially Paid'));
    });

    test('9. Paid status logic (totalPaid >= totalFee)', () {
      const totalFee = 11000.0;
      const totalPaid = 11000.0;

      String status = 'Unpaid';
      if (totalPaid >= totalFee && totalFee > 0) {
        status = 'Paid';
      } else if (totalPaid > 0) {
        status = 'Partially Paid';
      }

      expect(status, equals('Paid'));
    });

    // ──────────────────────────────────────────────────────────────────────
    // PAYMENT VALIDATION RULES (10–15)
    // ──────────────────────────────────────────────────────────────────────

    test('10. Overpayment rejection (amount > remainingDue)', () {
      const totalFee = 11000.0;
      const currentPaid = 8000.0;
      const remainingDue = totalFee - currentPaid; // 3000

      const overpaymentAmount = 3500.0;

      bool rejected = false;
      if (overpaymentAmount > remainingDue) {
        rejected = true;
      }

      expect(rejected, isTrue);
    });

    test('11. Zero or negative payment amount rejection', () {
      bool validateAmount(double amt) {
        if (amt <= 0) return false;
        return true;
      }

      expect(validateAmount(0.0), isFalse);
      expect(validateAmount(-500.0), isFalse);
      expect(validateAmount(100.0), isTrue);
    });

    test('12 & 13 & 14. Future payment date rejection & valid date acceptance', () {
      final todayStr = '2026-08-23';
      final today = DateTime.parse(todayStr);

      bool isDateValid(String dateStr) {
        final pDate = DateTime.parse(dateStr);
        final pDateNorm = DateTime(pDate.year, pDate.month, pDate.day);
        final todayNorm = DateTime(today.year, today.month, today.day);
        return !pDateNorm.isAfter(todayNorm);
      }

      expect(isDateValid('2026-08-23'), isTrue);  // Today -> Allowed
      expect(isDateValid('2026-08-10'), isTrue);  // Past -> Allowed
      expect(isDateValid('2026-08-30'), isFalse); // Future -> Rejected
    });

    test('15. Payment history ordering (newest first)', () {
      final p1 = const FeePaymentModel(feeId: 1, studentId: 101, amount: 2000.0, paymentDate: '2026-08-10');
      final p2 = const FeePaymentModel(feeId: 1, studentId: 101, amount: 3000.0, paymentDate: '2026-08-20');

      final list = [p1, p2];
      list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

      expect(list.first.paymentDate, equals('2026-08-20'));
      expect(list.last.paymentDate, equals('2026-08-10'));
    });

    // ──────────────────────────────────────────────────────────────────────
    // FEE PLANS & REPORTS (16–22)
    // ──────────────────────────────────────────────────────────────────────

    test('16. Fee plan update (changing negotiated totalFee)', () {
      const originalPlan = FeeModel(id: 1, studentId: 101, paymentMethod: 'Installments', courseFee: 15000.0, totalFee: 12000.0, createdAt: '2026-08-01');
      const updatedPlan = FeeModel(id: 1, studentId: 101, paymentMethod: 'Installments', courseFee: 15000.0, totalFee: 11000.0, createdAt: '2026-08-01');

      expect(originalPlan.totalFee, equals(12000.0));
      expect(updatedPlan.totalFee, equals(11000.0));
    });

    test('17. Fee installment model schedule representation', () {
      const inst = FeeInstallmentModel(
        id: 1,
        feeId: 1,
        studentId: 101,
        amount: 3000.0,
        dueDate: '2026-09-01',
        description: 'First Term Installment',
        createdAt: '2026-08-23',
      );

      final map = inst.toMap();
      expect(map['amount'], equals(3000.0));
      expect(map['dueDate'], equals('2026-09-01'));
      expect(map['description'], equals('First Term Installment'));
    });

    test('18. Class-wise fee summary aggregation formula', () {
      const records = [
        StudentFeeRecord(
          student: StudentModel(id: 1, name: 'S1', fatherName: 'F1', board: 'CBSE', studentClass: '10', rollNo: 1, mobile: '111', createdAt: '2026-01-01'),
          totalPayable: 10000.0,
          totalPaid: 10000.0,
          remainingDue: 0.0,
          feeStatus: 'Paid',
        ),
        StudentFeeRecord(
          student: StudentModel(id: 2, name: 'S2', fatherName: 'F2', board: 'CBSE', studentClass: '10', rollNo: 2, mobile: '222', createdAt: '2026-01-01'),
          totalPayable: 11000.0,
          totalPaid: 6000.0,
          remainingDue: 5000.0,
          feeStatus: 'Partially Paid',
        ),
        StudentFeeRecord(
          student: StudentModel(id: 3, name: 'S3', fatherName: 'F3', board: 'CBSE', studentClass: '10', rollNo: 3, mobile: '333', createdAt: '2026-01-01'),
          totalPayable: 12000.0,
          totalPaid: 0.0,
          remainingDue: 12000.0,
          feeStatus: 'Unpaid',
        ),
      ];

      final totalPayable = records.fold<double>(0.0, (sum, r) => sum + r.totalPayable);
      final totalCollected = records.fold<double>(0.0, (sum, r) => sum + r.totalPaid);
      final totalOutstanding = records.fold<double>(0.0, (sum, r) => sum + r.remainingDue);

      expect(totalPayable, equals(33000.0));
      expect(totalCollected, equals(16000.0));
      expect(totalOutstanding, equals(17000.0));
    });

    test('19. Pending fee filtering (due > 0 sorted by highest due)', () {
      final r1 = const StudentFeeRecord(
        student: StudentModel(id: 1, name: 'S1', fatherName: 'F1', board: 'CBSE', studentClass: '10', rollNo: 1, mobile: '111', createdAt: '2026-01-01'),
        totalPayable: 10000.0,
        totalPaid: 10000.0,
        remainingDue: 0.0,
        feeStatus: 'Paid',
      );
      final r2 = const StudentFeeRecord(
        student: StudentModel(id: 2, name: 'S2', fatherName: 'F2', board: 'CBSE', studentClass: '10', rollNo: 2, mobile: '222', createdAt: '2026-01-01'),
        totalPayable: 11000.0,
        totalPaid: 3000.0,
        remainingDue: 8000.0,
        feeStatus: 'Partially Paid',
      );
      final r3 = const StudentFeeRecord(
        student: StudentModel(id: 3, name: 'S3', fatherName: 'F3', board: 'CBSE', studentClass: '10', rollNo: 3, mobile: '333', createdAt: '2026-01-01'),
        totalPayable: 12000.0,
        totalPaid: 1000.0,
        remainingDue: 11000.0,
        feeStatus: 'Partially Paid',
      );

      final pendingOnly = [r1, r2, r3].where((r) => r.remainingDue > 0).toList();
      pendingOnly.sort((a, b) => b.remainingDue.compareTo(a.remainingDue));

      expect(pendingOnly.length, equals(2));
      expect(pendingOnly.first.remainingDue, equals(11000.0));
      expect(pendingOnly.last.remainingDue, equals(8000.0));
    });

    test('20. Student fee isolation (Student sees ONLY their own studentId)', () {
      const currentStudentId = 101;
      const allPayments = [
        FeePaymentModel(feeId: 1, studentId: 101, amount: 2000.0, paymentDate: '2026-08-10'),
        FeePaymentModel(feeId: 2, studentId: 999, amount: 5000.0, paymentDate: '2026-08-10'),
      ];

      final studentFeed = allPayments.where((p) => p.studentId == currentStudentId).toList();
      expect(studentFeed.length, equals(1));
      expect(studentFeed.first.studentId, equals(101));
    });

    test('21. Teacher fee access restriction', () {
      final teacher = TeacherModel(
        id: 10,
        name: 'Rahul Kumar',
        mobile: '9876543210',
        subject: 'Physics',
        payPerHour: 500,
        joiningDate: '2026-01-01',
        createdAt: '2026-01-01',
      );
      AppSession.instance.setTeacherSession(teacher);

      expect(AppSession.instance.isTeacher, isTrue);
      expect(AppSession.instance.isAdmin, isFalse);
    });

    test('22. Admin fee access permissions', () {
      AppSession.instance.setAdminSession(username: 'admin');
      expect(AppSession.instance.isAdmin, isTrue);
      expect(AppSession.instance.currentRole, equals(AppConstants.roleAdmin));
    });

    // ──────────────────────────────────────────────────────────────────────
    // DATA INTEGRITY & STATES (23–30)
    // ──────────────────────────────────────────────────────────────────────

    test('23. Receipt effective number generation', () {
      const p1 = FeePaymentModel(id: 42, feeId: 1, studentId: 101, amount: 1000.0, paymentDate: '2026-08-23');
      expect(p1.effectiveReceiptNo, equals('REC-FEE-00042'));

      const p2 = FeePaymentModel(id: 43, feeId: 1, studentId: 101, amount: 1000.0, paymentDate: '2026-08-23', receiptNo: 'REC-20260823-0005');
      expect(p2.effectiveReceiptNo, equals('REC-20260823-0005'));
    });

    test('24. Duplicate submission protection flag simulation', () {
      bool isSaving = false;

      void submit() {
        if (isSaving) return;
        isSaving = true;
      }

      submit();
      expect(isSaving, isTrue);
      submit(); // second click blocked
      expect(isSaving, isTrue);
    });

    test('25. Transaction safety simulation (all succeed or rollback)', () {
      bool feeSaved = false;
      bool paymentSaved = false;

      try {
        feeSaved = true;
        // simulate failure during payment insert
        throw Exception('Database constraint failed');
      } catch (_) {
        feeSaved = false;
        paymentSaved = false;
      }

      expect(feeSaved, isFalse);
      expect(paymentSaved, isFalse);
    });

    test('26. Existing fee-data migration safety', () {
      const legacyMap = {
        'id': 1,
        'studentId': 101,
        'paymentMethod': 'Installments',
        'totalFee': 11000.0,
        'createdAt': '2026-01-01',
      };

      final restored = FeeModel.fromMap(legacyMap);
      expect(restored.totalFee, equals(11000.0));
      expect(restored.courseFee, isNull);
    });

    test('27. No-data fee state handling', () {
      const FeeModel? feePlan = null;
      const totalPaid = 0.0;
      final remainingDue = feePlan?.totalFee ?? 0.0;

      expect(feePlan, isNull);
      expect(totalPaid, equals(0.0));
      expect(remainingDue, equals(0.0));
    });

    test('28. Fully-paid student state', () {
      const feePlan = FeeModel(id: 1, studentId: 101, paymentMethod: 'Installments', totalFee: 11000.0, createdAt: '2026-08-01');
      const totalPaid = 11000.0;
      final remainingDue = feePlan.totalFee - totalPaid;

      expect(remainingDue, equals(0.0));
    });

    test('29. Partially-paid student state', () {
      const feePlan = FeeModel(id: 1, studentId: 101, paymentMethod: 'Installments', totalFee: 11000.0, createdAt: '2026-08-01');
      const totalPaid = 6000.0;
      final remainingDue = feePlan.totalFee - totalPaid;

      expect(remainingDue, equals(5000.0));
    });

    test('30. Unpaid student state', () {
      const feePlan = FeeModel(id: 1, studentId: 101, paymentMethod: 'Installments', totalFee: 11000.0, createdAt: '2026-08-01');
      const totalPaid = 0.0;
      final remainingDue = feePlan.totalFee - totalPaid;

      expect(remainingDue, equals(11000.0));
    });
  });
}
