/// Teacher Attendance data model.
///
/// Stores hours worked per date by a teacher.
/// Constraint: UNIQUE(teacherId, date).
/// Used by Phase 5 Salary module: Total Hours Worked × payPerHour.
class TeacherAttendanceModel {
  final int? id;
  final int teacherId;
  final String date; // YYYY-MM-DD
  final double hoursWorked; // >= 0, <= 24
  final String? remarks;
  final String? createdAt;
  final String? updatedAt;

  // Joined/convenience fields (populated when querying with teacher details)
  final String? teacherName;
  final String? teacherSubject;
  final String? teacherMobile;
  final double? teacherPayPerHour;

  const TeacherAttendanceModel({
    this.id,
    required this.teacherId,
    required this.date,
    required this.hoursWorked,
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.teacherName,
    this.teacherSubject,
    this.teacherMobile,
    this.teacherPayPerHour,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'teacherId': teacherId,
      'date': date,
      'hoursWorked': hoursWorked,
      'remarks': remarks,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TeacherAttendanceModel.fromMap(Map<String, dynamic> map) {
    return TeacherAttendanceModel(
      id: map['id'] as int?,
      teacherId: map['teacherId'] as int,
      date: map['date'] as String,
      hoursWorked: (map['hoursWorked'] as num).toDouble(),
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
      teacherName: map['teacherName'] as String? ?? map['name'] as String?,
      teacherSubject: map['teacherSubject'] as String? ?? map['subject'] as String?,
      teacherMobile: map['teacherMobile'] as String? ?? map['mobile'] as String?,
      teacherPayPerHour: (map['payPerHour'] as num?)?.toDouble(),
    );
  }

  TeacherAttendanceModel copyWith({
    int? id,
    int? teacherId,
    String? date,
    double? hoursWorked,
    String? remarks,
    String? createdAt,
    String? updatedAt,
    String? teacherName,
    String? teacherSubject,
    String? teacherMobile,
    double? teacherPayPerHour,
  }) {
    return TeacherAttendanceModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      date: date ?? this.date,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      teacherName: teacherName ?? this.teacherName,
      teacherSubject: teacherSubject ?? this.teacherSubject,
      teacherMobile: teacherMobile ?? this.teacherMobile,
      teacherPayPerHour: teacherPayPerHour ?? this.teacherPayPerHour,
    );
  }
}
