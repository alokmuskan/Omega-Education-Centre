/// Student Attendance data model.
///
/// Stores daily attendance status for a student.
/// [status] must be one of: 'Present' | 'Absent' | 'Late' | 'Leave'.
/// Constraint: UNIQUE(studentId, date).
class StudentAttendanceModel {
  final int? id;
  final int studentId;
  final String date; // YYYY-MM-DD
  final String status; // Present, Absent, Late, Leave
  final String? remarks;
  final String? createdAt;
  final String? updatedAt;

  // Joined/convenience fields (populated when querying with student details)
  final String? studentName;
  final String? studentRollNo;
  final String? studentClass;

  const StudentAttendanceModel({
    this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.studentName,
    this.studentRollNo,
    this.studentClass,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'studentId': studentId,
      'date': date,
      'status': status,
      'remarks': remarks,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory StudentAttendanceModel.fromMap(Map<String, dynamic> map) {
    return StudentAttendanceModel(
      id: map['id'] as int?,
      studentId: map['studentId'] as int,
      date: map['date'] as String,
      status: map['status'] as String,
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
      studentName: map['studentName'] as String? ?? map['name'] as String?,
      studentRollNo: map['studentRollNo']?.toString() ?? map['rollNo']?.toString(),
      studentClass: map['studentClass'] as String?,
    );
  }

  StudentAttendanceModel copyWith({
    int? id,
    int? studentId,
    String? date,
    String? status,
    String? remarks,
    String? createdAt,
    String? updatedAt,
    String? studentName,
    String? studentRollNo,
    String? studentClass,
  }) {
    return StudentAttendanceModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      studentName: studentName ?? this.studentName,
      studentRollNo: studentRollNo ?? this.studentRollNo,
      studentClass: studentClass ?? this.studentClass,
    );
  }
}
