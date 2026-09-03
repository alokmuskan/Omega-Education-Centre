/// Model representing a historical pay-rate period for a teacher.
///
/// Ensures historical salary calculations use the pay rate that was active
/// on the exact date attendance was recorded.
class TeacherPayRateHistoryModel {
  final int? id;
  final int teacherId;
  final double payPerHour;
  final String effectiveFrom; // YYYY-MM-DD
  final String? effectiveTo; // YYYY-MM-DD (null means currently active)
  final String? createdAt;
  final String? updatedAt;

  const TeacherPayRateHistoryModel({
    this.id,
    required this.teacherId,
    required this.payPerHour,
    required this.effectiveFrom,
    this.effectiveTo,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'teacherId': teacherId,
      'payPerHour': payPerHour,
      'effectiveFrom': effectiveFrom,
      'effectiveTo': effectiveTo,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TeacherPayRateHistoryModel.fromMap(Map<String, dynamic> map) {
    return TeacherPayRateHistoryModel(
      id: map['id'] as int?,
      teacherId: map['teacherId'] as int,
      payPerHour: (map['payPerHour'] as num).toDouble(),
      effectiveFrom: map['effectiveFrom'] as String,
      effectiveTo: map['effectiveTo'] as String?,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
    );
  }
}
