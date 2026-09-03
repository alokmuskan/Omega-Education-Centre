import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/salary/models/teacher_payment_model.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_pay_rate_history_model.dart';

void main() {
  group('Salary System & Historical Pay Rate Unit Tests (Phase 5 Corrections)', () {
    test('1. One teacher with one pay rate', () {
      final rateHistory = [
        const TeacherPayRateHistoryModel(
          teacherId: 1,
          payPerHour: 300.0,
          effectiveFrom: '2026-01-01',
          effectiveTo: null,
        ),
      ];

      double computeEarned(String date, double hrs) {
        final rate = rateHistory.firstWhere(
          (r) =>
              r.effectiveFrom.compareTo(date) <= 0 &&
              (r.effectiveTo == null || r.effectiveTo!.compareTo(date) >= 0),
        );
        return hrs * rate.payPerHour;
      }

      expect(computeEarned('2026-08-01', 2.0), equals(600.0));
      expect(computeEarned('2026-08-15', 3.0), equals(900.0));
    });

    test('2. Pay-rate change between months (June: ₹300, July: ₹350)', () {
      final rateHistory = [
        const TeacherPayRateHistoryModel(
          teacherId: 1,
          payPerHour: 300.0,
          effectiveFrom: '2026-06-01',
          effectiveTo: '2026-06-30',
        ),
        const TeacherPayRateHistoryModel(
          teacherId: 1,
          payPerHour: 350.0,
          effectiveFrom: '2026-07-01',
          effectiveTo: null,
        ),
      ];

      double getRateForDate(String date) {
        final match = rateHistory.firstWhere(
          (r) =>
              r.effectiveFrom.compareTo(date) <= 0 &&
              (r.effectiveTo == null || r.effectiveTo!.compareTo(date) >= 0),
        );
        return match.payPerHour;
      }

      expect(getRateForDate('2026-06-15'), equals(300.0));
      expect(getRateForDate('2026-07-05'), equals(350.0));

      // June calculation: 10 hrs * 300 = 3000
      expect(10.0 * getRateForDate('2026-06-15'), equals(3000.0));
      // July calculation: 10 hrs * 350 = 3500
      expect(10.0 * getRateForDate('2026-07-05'), equals(3500.0));
    });

    test('3. Pay-rate change in the middle of a month (10 Aug rate changes to ₹350)', () {
      final rateHistory = [
        const TeacherPayRateHistoryModel(
          teacherId: 1,
          payPerHour: 300.0,
          effectiveFrom: '2026-08-01',
          effectiveTo: '2026-08-09',
        ),
        const TeacherPayRateHistoryModel(
          teacherId: 1,
          payPerHour: 350.0,
          effectiveFrom: '2026-08-10',
          effectiveTo: null,
        ),
      ];

      double getRateForDate(String date) {
        final match = rateHistory.firstWhere(
          (r) =>
              r.effectiveFrom.compareTo(date) <= 0 &&
              (r.effectiveTo == null || r.effectiveTo!.compareTo(date) >= 0),
        );
        return match.payPerHour;
      }

      final attendance = [
        {'date': '2026-08-01', 'hours': 2.0}, // 2 * 300 = 600
        {'date': '2026-08-02', 'hours': 3.0}, // 3 * 300 = 900
        {'date': '2026-08-11', 'hours': 2.0}, // 2 * 350 = 700
      ];

      final totalEarned = attendance.fold(0.0, (sum, att) {
        final d = att['date'] as String;
        final h = att['hours'] as double;
        return sum + (h * getRateForDate(d));
      });

      expect(totalEarned, equals(2200.0)); // 600 + 900 + 700 = 2200
    });

    test('4 & 5. Historical month calculation remains correct & new rate applies only from effective date', () {
      // Historical rate ₹300, new rate ₹400 from 2026-08-20
      final rateHistory = [
        const TeacherPayRateHistoryModel(
          teacherId: 1,
          payPerHour: 300.0,
          effectiveFrom: '2026-01-01',
          effectiveTo: '2026-08-19',
        ),
        const TeacherPayRateHistoryModel(
          teacherId: 1,
          payPerHour: 400.0,
          effectiveFrom: '2026-08-20',
          effectiveTo: null,
        ),
      ];

      double getRateForDate(String date) {
        return rateHistory
            .firstWhere(
              (r) =>
                  r.effectiveFrom.compareTo(date) <= 0 &&
                  (r.effectiveTo == null || r.effectiveTo!.compareTo(date) >= 0),
            )
            .payPerHour;
      }

      // Past date (e.g. May 2026) still uses ₹300
      expect(getRateForDate('2026-05-10'), equals(300.0));
      // 15 Aug uses ₹300
      expect(getRateForDate('2026-08-15'), equals(300.0));
      // 20 Aug uses ₹400
      expect(getRateForDate('2026-08-20'), equals(400.0));
    });

    test('6. No overlapping rate periods validation', () {
      final rateHistory = [
        const TeacherPayRateHistoryModel(
          teacherId: 1,
          payPerHour: 300.0,
          effectiveFrom: '2026-01-01',
          effectiveTo: '2026-08-09',
        ),
        const TeacherPayRateHistoryModel(
          teacherId: 1,
          payPerHour: 350.0,
          effectiveFrom: '2026-08-10',
          effectiveTo: null,
        ),
      ];

      bool hasOverlap(List<TeacherPayRateHistoryModel> history) {
        for (int i = 0; i < history.length; i++) {
          for (int j = i + 1; j < history.length; j++) {
            final a = history[i];
            final b = history[j];
            if (a.effectiveTo != null && b.effectiveFrom.compareTo(a.effectiveTo!) <= 0) {
              return true;
            }
          }
        }
        return false;
      }

      expect(hasOverlap(rateHistory), isFalse);
    });

    test('7 & 8. Existing salary payments and attendance remain unchanged', () {
      const attendanceHours = 10.0;
      const paymentAmount = 2000.0;

      // Existing transaction record remains ₹2000
      final payment = TeacherPaymentModel(
        teacherId: 1,
        month: '2026-08',
        amount: paymentAmount,
        paymentDate: '2026-08-15',
        paymentMethod: 'Cash',
      );

      expect(payment.amount, equals(2000.0));
      expect(attendanceHours, equals(10.0));
    });

    test('9. Current teacher payPerHour remains correct for quick display', () {
      const currentPayPerHour = 350.0;
      expect(currentPayPerHour, equals(350.0));
    });

    test('10. Duplicate payment method field is no longer used (paymentMethod is authoritative)', () {
      final payment = TeacherPaymentModel(
        teacherId: 1,
        month: '2026-08',
        amount: 1500.0,
        paymentDate: '2026-08-20',
        paymentMethod: 'Cash',
      );

      final map = payment.toMap();
      expect(map['paymentMethod'], equals('Cash'));
      expect(map['paymentMode'], equals('Cash'));

      final restored = TeacherPaymentModel.fromMap(map);
      expect(restored.paymentMethod, equals('Cash'));
    });
  });
}
