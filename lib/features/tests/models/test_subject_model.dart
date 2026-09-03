/// Model representing a subject configuration within a test.
class TestSubjectModel {
  final int? id;
  final int? testId;
  final String subjectName;
  final double maxMarks;
  final double passMarks;
  final String? createdAt;
  final String? updatedAt;

  const TestSubjectModel({
    this.id,
    this.testId,
    required this.subjectName,
    required this.maxMarks,
    required this.passMarks,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'subjectName': subjectName,
      'maxMarks': maxMarks,
      'passMarks': passMarks,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    if (testId != null) map['testId'] = testId;
    return map;
  }

  factory TestSubjectModel.fromMap(Map<String, dynamic> map) {
    return TestSubjectModel(
      id: map['id'] as int?,
      testId: map['testId'] as int?,
      subjectName: map['subjectName'] as String,
      maxMarks: (map['maxMarks'] as num).toDouble(),
      passMarks: (map['passMarks'] as num).toDouble(),
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  TestSubjectModel copyWith({
    int? id,
    int? testId,
    String? subjectName,
    double? maxMarks,
    double? passMarks,
    String? createdAt,
    String? updatedAt,
  }) {
    return TestSubjectModel(
      id: id ?? this.id,
      testId: testId ?? this.testId,
      subjectName: subjectName ?? this.subjectName,
      maxMarks: maxMarks ?? this.maxMarks,
      passMarks: passMarks ?? this.passMarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
