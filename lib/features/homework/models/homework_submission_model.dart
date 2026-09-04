class HomeworkSubmissionModel {
  final int? id;
  final int homeworkId;
  final int studentId;
  final String status; // 'Pending', 'Submitted', 'Late', 'Excused'
  final String? submittedAt;
  final String? remarks;
  final String createdAt;
  final String? updatedAt;

  const HomeworkSubmissionModel({
    this.id,
    required this.homeworkId,
    required this.studentId,
    this.status = 'Pending',
    this.submittedAt,
    this.remarks,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'homeworkId': homeworkId,
        'studentId': studentId,
        'status': status,
        'submittedAt': submittedAt,
        'remarks': remarks,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory HomeworkSubmissionModel.fromMap(Map<String, dynamic> map) => HomeworkSubmissionModel(
        id: map['id'] as int?,
        homeworkId: map['homeworkId'] as int? ?? 0,
        studentId: map['studentId'] as int? ?? 0,
        status: map['status'] as String? ?? 'Pending',
        submittedAt: map['submittedAt'] as String?,
        remarks: map['remarks'] as String?,
        createdAt: map['createdAt'] as String? ?? '',
        updatedAt: map['updatedAt'] as String?,
      );

  HomeworkSubmissionModel copyWith({
    int? id,
    int? homeworkId,
    int? studentId,
    String? status,
    String? submittedAt,
    String? remarks,
    String? createdAt,
    String? updatedAt,
  }) {
    return HomeworkSubmissionModel(
      id: id ?? this.id,
      homeworkId: homeworkId ?? this.homeworkId,
      studentId: studentId ?? this.studentId,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
