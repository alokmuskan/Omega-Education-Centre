/// An actual payment received from a student/parent.
///
/// This is the ONLY source of truth for money paid.
/// Records are append-only.
///
/// Paid Amount   = SUM(fee_payments.amount) WHERE studentId = ?
/// Outstanding   = fees.totalFee - Paid Amount
class FeePaymentModel {
  final int? id;
  final int feeId;
  final int studentId;

  /// Actual amount paid. Must be > 0.
  final double amount;

  /// Date payment was received, stored as 'YYYY-MM-DD'.
  final String paymentDate;

  /// 'Cash' | 'UPI' | 'Bank Transfer' | 'Cheque'
  final String paymentMode;

  final String? remarks;
  final String? receiptNo;
  final String? createdAt;

  const FeePaymentModel({
    this.id,
    required this.feeId,
    required this.studentId,
    required this.amount,
    required this.paymentDate,
    this.paymentMode = 'Cash',
    this.remarks,
    this.receiptNo,
    this.createdAt,
  });

  /// Generate a display receipt number if receiptNo is not set in DB
  String get effectiveReceiptNo {
    if (receiptNo != null && receiptNo!.isNotEmpty) return receiptNo!;
    final pId = id ?? 0;
    return 'REC-FEE-${pId.toString().padLeft(5, '0')}';
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'feeId': feeId,
      'studentId': studentId,
      'amount': amount,
      'paymentDate': paymentDate,
      'paymentMode': paymentMode,
      'remarks': remarks,
      'receiptNo': receiptNo,
      'createdAt': createdAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory FeePaymentModel.fromMap(Map<String, dynamic> map) {
    return FeePaymentModel(
      id: map['id'] as int?,
      feeId: map['feeId'] as int,
      studentId: map['studentId'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: map['paymentDate'] as String,
      paymentMode: map['paymentMode'] as String? ?? 'Cash',
      remarks: map['remarks'] as String?,
      receiptNo: map['receiptNo'] as String?,
      createdAt: map['createdAt'] as String?,
    );
  }

  FeePaymentModel copyWith({
    int? id,
    int? feeId,
    int? studentId,
    double? amount,
    String? paymentDate,
    String? paymentMode,
    String? remarks,
    String? receiptNo,
    String? createdAt,
  }) {
    return FeePaymentModel(
      id: id ?? this.id,
      feeId: feeId ?? this.feeId,
      studentId: studentId ?? this.studentId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMode: paymentMode ?? this.paymentMode,
      remarks: remarks ?? this.remarks,
      receiptNo: receiptNo ?? this.receiptNo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
