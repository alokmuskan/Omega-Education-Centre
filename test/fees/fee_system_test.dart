import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';
import 'package:omega_education_centre/features/fees/models/fee_model.dart';
import 'package:omega_education_centre/features/fees/models/fee_installment_model.dart';
import 'package:omega_education_centre/features/fees/models/fee_payment_model.dart';

void main() {
  group('Fee System Unit Tests', () {
    test('Fee Status Computation Helper', () {
      expect(AppConstants.computeFeeStatus(11000, 0), equals('Due'));
      expect(AppConstants.computeFeeStatus(11000, 2000), equals('Partially Paid'));
      expect(AppConstants.computeFeeStatus(11000, 11000), equals('Paid'));
      expect(AppConstants.computeFeeStatus(11000, 12000), equals('Paid'));
    });

    test('Installment Total Validation Logic (40/30/30 example)', () {
      const double agreedFee = 11000;
      final installments = [
        const FeeInstallmentModel(
          feeId: 1,
          studentId: 1,
          amount: 4400,
          dueDate: '2026-08-23',
          description: 'Admission (40%)',
          createdAt: '2026-08-23T10:00:00Z',
        ),
        const FeeInstallmentModel(
          feeId: 1,
          studentId: 1,
          amount: 3300,
          dueDate: '2026-09-23',
          description: '2nd Instalment (30%)',
          createdAt: '2026-08-23T10:00:00Z',
        ),
        const FeeInstallmentModel(
          feeId: 1,
          studentId: 1,
          amount: 3300,
          dueDate: '2026-10-23',
          description: '3rd Instalment (30%)',
          createdAt: '2026-08-23T10:00:00Z',
        ),
      ];

      final double totalScheduled = installments.fold(0.0, (sum, i) => sum + i.amount);
      expect(totalScheduled, equals(agreedFee));
      expect((totalScheduled - agreedFee).abs() < 0.01, isTrue);
    });

    test('Monthly Schedule Fee Calculation', () {
      const double monthlyAmt = 600;
      const int months = 12;
      final feePlan = FeeModel(
        studentId: 1,
        paymentMethod: 'Monthly',
        totalFee: monthlyAmt * months,
        monthlyAmount: monthlyAmt,
        paymentDueDay: 5,
        startMonth: '2026-09',
        durationMonths: months,
        createdAt: '2026-08-23T10:00:00Z',
      );

      expect(feePlan.totalFee, equals(7200));
    });

    test('Actual Payments Sum & Outstanding Calculation', () {
      const double agreedFee = 11000;
      final payments = [
        const FeePaymentModel(
          feeId: 1,
          studentId: 1,
          amount: 2000,
          paymentDate: '2026-08-23',
          paymentMode: 'Cash',
          remarks: 'Admission partial payment',
        ),
        const FeePaymentModel(
          feeId: 1,
          studentId: 1,
          amount: 1000,
          paymentDate: '2026-08-30',
          paymentMode: 'UPI',
        ),
        const FeePaymentModel(
          feeId: 1,
          studentId: 1,
          amount: 3000,
          paymentDate: '2026-09-15',
          paymentMode: 'Cash',
        ),
      ];

      final double paidTotal = payments.fold(0.0, (sum, p) => sum + p.amount);
      final double outstanding = agreedFee - paidTotal;

      expect(paidTotal, equals(6000));
      expect(outstanding, equals(5000));
      expect(AppConstants.computeFeeStatus(agreedFee, paidTotal), equals('Partially Paid'));
    });
  });
}
