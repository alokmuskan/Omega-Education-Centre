class BatchStudentModel {
  final int? id;
  final int batchId;
  final int studentId;
  final String enrolledAt;
  final bool isActive;

  const BatchStudentModel({
    this.id,
    required this.batchId,
    required this.studentId,
    required this.enrolledAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'batchId': batchId,
        'studentId': studentId,
        'enrolledAt': enrolledAt,
        'isActive': isActive ? 1 : 0,
      };

  factory BatchStudentModel.fromMap(Map<String, dynamic> map) => BatchStudentModel(
        id: map['id'] as int?,
        batchId: map['batchId'] as int? ?? 0,
        studentId: map['studentId'] as int? ?? 0,
        enrolledAt: map['enrolledAt'] as String? ?? '',
        isActive: (map['isActive'] as int?) == 1,
      );
}
