import 'test_subject_model.dart';

/// Data model representing an Examination / Test entity in Omega Education Centre.
class TestModel {
  final int? id;
  final String title;
  final String testType; // 'Unit Test', 'Monthly Test', 'Half-Yearly', 'Pre-Board', 'Final Exam', 'Weekly Test', 'Other'
  final String board; // 'CBSE', 'ICSE', 'State Board', 'Other'
  final String studentClass;
  final String testDate; // YYYY-MM-DD (future dates allowed!)
  final String academicYear; // e.g. '2026-27'
  final String? remarks;
  final bool isArchived;
  final String? createdAt;
  final String? updatedAt;

  // Configuration subjects list
  final List<TestSubjectModel> subjects;

  const TestModel({
    this.id,
    required this.title,
    required this.testType,
    required this.board,
    required this.studentClass,
    required this.testDate,
    required this.academicYear,
    this.remarks,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
    this.subjects = const [],
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'testType': testType,
      'board': board,
      'studentClass': studentClass,
      'testDate': testDate,
      'academicYear': academicYear,
      'remarks': remarks,
      'isArchived': isArchived ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TestModel.fromMap(Map<String, dynamic> map, {List<TestSubjectModel> subjects = const []}) {
    final titleStr = (map['title'] as String?) ?? (map['testName'] as String?) ?? '';
    return TestModel(
      id: map['id'] as int?,
      title: titleStr,
      testType: (map['testType'] as String?) ?? 'Monthly Test',
      board: (map['board'] as String?) ?? 'CBSE',
      studentClass: map['studentClass'] as String,
      testDate: map['testDate'] as String,
      academicYear: (map['academicYear'] as String?) ?? '2026-27',
      remarks: map['remarks'] as String? ?? map['syllabus'] as String?,
      isArchived: (map['isArchived'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
      subjects: subjects,
    );
  }

  TestModel copyWith({
    int? id,
    String? title,
    String? testType,
    String? board,
    String? studentClass,
    String? testDate,
    String? academicYear,
    String? remarks,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
    List<TestSubjectModel>? subjects,
  }) {
    return TestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      testType: testType ?? this.testType,
      board: board ?? this.board,
      studentClass: studentClass ?? this.studentClass,
      testDate: testDate ?? this.testDate,
      academicYear: academicYear ?? this.academicYear,
      remarks: remarks ?? this.remarks,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subjects: subjects ?? this.subjects,
    );
  }
}
