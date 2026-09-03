/// Data model representing a Daily Class Record in Omega Education Centre ERP.
///
/// Records actual teaching sessions conducted by teachers.
/// Stores [teacherId] as the authoritative foreign key reference to teachers.id.
class DailyClassRecordModel {
  final int? id;
  final String date; // YYYY-MM-DD
  final String studentClass;
  final String board;
  final String? batch;
  final int teacherId;
  final String? teacherName; // Resolved dynamically via JOIN with teachers.id
  final String subject;
  final String? startTime;
  final String? endTime;
  final int durationMinutes;
  final String topic;
  final String? homework;
  final String? remarks;
  final String? createdAt;
  final String? updatedAt;

  const DailyClassRecordModel({
    this.id,
    required this.date,
    required this.studentClass,
    required this.board,
    this.batch,
    required this.teacherId,
    this.teacherName,
    required this.subject,
    this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.topic,
    this.homework,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  /// Formatted duration string for UI display (e.g. "1 hr 30 min", "45 min", "2 hrs").
  String get formattedDuration {
    if (durationMinutes <= 0) return '0 min';
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours == 0) return '$mins min';
    if (mins == 0) return hours == 1 ? '1 hr' : '$hours hrs';
    return '$hours hr $mins min';
  }

  // ── Serialization ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'date': date,
      'studentClass': studentClass,
      'board': board,
      'batch': batch,
      'teacherId': teacherId,
      'subject': subject,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'topic': topic,
      'homework': homework,
      'remarks': remarks,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory DailyClassRecordModel.fromMap(Map<String, dynamic> map) {
    return DailyClassRecordModel(
      id: map['id'] as int?,
      date: map['date'] as String,
      studentClass: map['studentClass'] as String,
      board: (map['board'] as String?) ?? 'CBSE',
      batch: map['batch'] as String?,
      teacherId: map['teacherId'] as int,
      teacherName: map['teacherName'] as String?,
      subject: map['subject'] as String,
      startTime: map['startTime'] as String?,
      endTime: map['endTime'] as String?,
      durationMinutes: (map['durationMinutes'] as num? ?? 60).toInt(),
      topic: map['topic'] as String,
      homework: map['homework'] as String?,
      remarks: map['remarks'] as String?,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  // ── copyWith ─────────────────────────────────────────────────────────

  DailyClassRecordModel copyWith({
    int? id,
    String? date,
    String? studentClass,
    String? board,
    String? batch,
    int? teacherId,
    String? teacherName,
    String? subject,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    String? topic,
    String? homework,
    String? remarks,
    String? createdAt,
    String? updatedAt,
  }) {
    return DailyClassRecordModel(
      id: id ?? this.id,
      date: date ?? this.date,
      studentClass: studentClass ?? this.studentClass,
      board: board ?? this.board,
      batch: batch ?? this.batch,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      subject: subject ?? this.subject,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      topic: topic ?? this.topic,
      homework: homework ?? this.homework,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
