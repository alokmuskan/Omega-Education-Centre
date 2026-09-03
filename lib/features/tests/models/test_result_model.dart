/// Data model representing a student's marks entry for a specific test subject.
///
/// Enforces UNIQUE(testId, studentId, testSubjectId) via upsert safety.
class TestResultModel {
  final int? id;
  final int testId;
  final int studentId;
  final int testSubjectId;
  final double marksObtained;
  final String? remarks;
  final String? createdAt;
  final String? updatedAt;

  // Joined convenience fields
  final String? studentName;
  final String? studentRollNo;
  final String? subjectName;
  final double? maxMarks;
  final double? passMarks;

  const TestResultModel({
    this.id,
    required this.testId,
    required this.studentId,
    required this.testSubjectId,
    required this.marksObtained,
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.studentName,
    this.studentRollNo,
    this.subjectName,
    this.maxMarks,
    this.passMarks,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'testId': testId,
      'studentId': studentId,
      'testSubjectId': testSubjectId,
      'marksObtained': marksObtained,
      'remarks': remarks,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TestResultModel.fromMap(Map<String, dynamic> map) {
    return TestResultModel(
      id: map['id'] as int?,
      testId: map['testId'] as int,
      studentId: map['studentId'] as int,
      testSubjectId: map['testSubjectId'] as int,
      marksObtained: (map['marksObtained'] as num).toDouble(),
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
      studentName: map['studentName'] as String?,
      studentRollNo: map['studentRollNo']?.toString(),
      subjectName: map['subjectName'] as String?,
      maxMarks: map['maxMarks'] != null ? (map['maxMarks'] as num).toDouble() : null,
      passMarks: map['passMarks'] != null ? (map['passMarks'] as num).toDouble() : null,
    );
  }

  TestResultModel copyWith({
    int? id,
    int? testId,
    int? studentId,
    int? testSubjectId,
    double? marksObtained,
    String? remarks,
    String? createdAt,
    String? updatedAt,
    String? studentName,
    String? studentRollNo,
    String? subjectName,
    double? maxMarks,
    double? passMarks,
  }) {
    return TestResultModel(
      id: id ?? this.id,
      testId: testId ?? this.testId,
      studentId: studentId ?? this.studentId,
      testSubjectId: testSubjectId ?? this.testSubjectId,
      marksObtained: marksObtained ?? this.marksObtained,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      studentName: studentName ?? this.studentName,
      studentRollNo: studentRollNo ?? this.studentRollNo,
      subjectName: subjectName ?? this.subjectName,
      maxMarks: maxMarks ?? this.maxMarks,
      passMarks: passMarks ?? this.passMarks,
    );
  }
}
