/// A single row in the expected fee schedule for a student.
///
/// This represents WHEN a payment is expected and HOW MUCH — it is NOT
/// proof that any money was received. Actual payments are in [fee_payments].
///
/// For Monthly method: one FeeInstallmentModel per month, auto-generated.
/// For Installments method: admin-defined rows, variable count and amounts.
class FeeInstallmentModel {
  final int? id;
  final int feeId;
  final int studentId;

  /// Expected amount for this instalment. Must be > 0.
  final double amount;

  /// Date this instalment is due, stored as 'YYYY-MM-DD'.
  final String dueDate;

  /// Optional label e.g. 'Month 1', 'Instalment 2', 'Admission'.
  final String? description;

  final String createdAt;

  const FeeInstallmentModel({
    this.id,
    required this.feeId,
    required this.studentId,
    required this.amount,
    required this.dueDate,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'feeId': feeId,
      'studentId': studentId,
      'amount': amount,
      'dueDate': dueDate,
      'description': description,
      'createdAt': createdAt,
    };
  }

  factory FeeInstallmentModel.fromMap(Map<String, dynamic> map) {
    return FeeInstallmentModel(
      id: map['id'] as int?,
      feeId: map['feeId'] as int,
      studentId: map['studentId'] as int,
      amount: (map['amount'] as num).toDouble(),
      dueDate: map['dueDate'] as String,
      description: map['description'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }

  FeeInstallmentModel copyWith({
    int? id,
    int? feeId,
    int? studentId,
    double? amount,
    String? dueDate,
    String? description,
    String? createdAt,
  }) {
    return FeeInstallmentModel(
      id: id ?? this.id,
      feeId: feeId ?? this.feeId,
      studentId: studentId ?? this.studentId,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
