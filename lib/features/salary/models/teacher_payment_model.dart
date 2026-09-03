/// Teacher Salary Payment transaction data model.
///
/// Stores individual payment transaction records.
/// Preserves complete payment history — multiple payments do NOT overwrite each other.
class TeacherPaymentModel {
  final int? id;
  final int teacherId;
  final String month; // 'YYYY-MM'
  final int? year;
  final double amount;
  final String paymentDate; // YYYY-MM-DD
  final String paymentMethod; // Default: 'Cash'
  final String? remarks;
  final String? createdAt;
  final String? updatedAt;

  // Joined/convenience field
  final String? teacherName;

  const TeacherPaymentModel({
    this.id,
    required this.teacherId,
    required this.month,
    this.year,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = 'Cash',
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.teacherName,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'teacherId': teacherId,
      'month': month,
      'year': year ?? (month.contains('-') ? int.tryParse(month.split('-')[0]) : null),
      'amount': amount,
      'paymentDate': paymentDate,
      'paymentMode': paymentMethod,
      'paymentMethod': paymentMethod,
      'remarks': remarks,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TeacherPaymentModel.fromMap(Map<String, dynamic> map) {
    final monthStr = map['month'] as String;
    int? parsedYear = map['year'] as int?;
    if (parsedYear == null && monthStr.contains('-')) {
      parsedYear = int.tryParse(monthStr.split('-')[0]);
    }

    return TeacherPaymentModel(
      id: map['id'] as int?,
      teacherId: map['teacherId'] as int,
      month: monthStr,
      year: parsedYear,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: map['paymentDate'] as String,
      paymentMethod: (map['paymentMethod'] as String?) ??
          (map['paymentMode'] as String?) ??
          'Cash',
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
      teacherName: map['teacherName'] as String? ?? map['name'] as String?,
    );
  }

  TeacherPaymentModel copyWith({
    int? id,
    int? teacherId,
    String? month,
    int? year,
    double? amount,
    String? paymentDate,
    String? paymentMethod,
    String? remarks,
    String? createdAt,
    String? updatedAt,
    String? teacherName,
  }) {
    return TeacherPaymentModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      month: month ?? this.month,
      year: year ?? this.year,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      teacherName: teacherName ?? this.teacherName,
    );
  }
}
