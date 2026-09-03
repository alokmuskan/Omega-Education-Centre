/// Fee plan for a student.
///
/// Represents the agreement at admission time — what the student is
/// expected to pay, how (Monthly / Installments), and on what schedule.
///
/// [totalFee]  = final agreed fee (source of truth for outstanding calculation).
/// [courseFee] = nominal/catalogue fee (may differ from totalFee; informational only).
///
/// The fee plan itself does NOT represent money received.
/// All money received is recorded in [fee_payments] (FeePaymentModel).
class FeeModel {
  final int? id;
  final int studentId;

  /// 'Monthly' or 'Installments'
  final String paymentMethod;

  /// Nominal catalogue fee (e.g. ₹15,000). May be null if not applicable.
  final double? courseFee;

  /// Final agreed fee — the committed payable amount (e.g. ₹11,000).
  /// Outstanding = totalFee − SUM(fee_payments.amount)
  final double totalFee;

  // ── Monthly-specific fields ──────────────────────────────────────────

  /// Monthly instalment amount (e.g. ₹600). Null for Installments method.
  final double? monthlyAmount;

  /// Day of month on which payment is due (1–28). Null for Installments method.
  final int? paymentDueDay;

  /// Start month in 'YYYY-MM' format. Null for Installments method.
  final String? startMonth;

  /// Number of months in the course. Null for Installments method.
  final int? durationMonths;

  // ── Common ────────────────────────────────────────────────────────────

  final String? description;
  final String createdAt;

  const FeeModel({
    this.id,
    required this.studentId,
    required this.paymentMethod,
    this.courseFee,
    required this.totalFee,
    this.monthlyAmount,
    this.paymentDueDay,
    this.startMonth,
    this.durationMonths,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'paymentMethod': paymentMethod,
      'courseFee': courseFee,
      'totalFee': totalFee,
      'monthlyAmount': monthlyAmount,
      'paymentDueDay': paymentDueDay,
      'startMonth': startMonth,
      'durationMonths': durationMonths,
      'description': description,
      'createdAt': createdAt,
    };
  }

  factory FeeModel.fromMap(Map<String, dynamic> map) {
    return FeeModel(
      id: map['id'] as int?,
      studentId: map['studentId'] as int,
      paymentMethod: map['paymentMethod'] as String? ?? 'Installments',
      courseFee: (map['courseFee'] as num?)?.toDouble(),
      totalFee: (map['totalFee'] as num).toDouble(),
      monthlyAmount: (map['monthlyAmount'] as num?)?.toDouble(),
      paymentDueDay: map['paymentDueDay'] as int?,
      startMonth: map['startMonth'] as String?,
      durationMonths: map['durationMonths'] as int?,
      description: map['description'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }
}
