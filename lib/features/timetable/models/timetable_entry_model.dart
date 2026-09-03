/// Data model representing a scheduled class session in Omega Education Centre ERP.
class TimetableEntryModel {
  final int? id;
  final String dayOfWeek; // 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  final int periodNumber; // 1, 2, 3, etc.
  final String studentClass;
  final String board;
  final String? batch;
  final int teacherId;
  final String? teacherName; // Resolved dynamically via JOIN with teachers.id
  final String subject;
  final String startTime; // '08:00 AM'
  final String endTime;   // '09:00 AM'
  final String? room;
  final String? remarks;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  const TimetableEntryModel({
    this.id,
    required this.dayOfWeek,
    this.periodNumber = 1,
    required this.studentClass,
    required this.board,
    this.batch,
    required this.teacherId,
    this.teacherName,
    required this.subject,
    required this.startTime,
    required this.endTime,
    this.room,
    this.remarks,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  String get timeSlot => '$startTime – $endTime';
  String get periodLabel => 'Period $periodNumber';

  /// Convert startTime string (e.g., "08:00 AM") to total minutes from midnight.
  int get startMinutes => _timeToMinutes(startTime);

  /// Convert endTime string (e.g., "09:00 AM") to total minutes from midnight.
  int get endMinutes => _timeToMinutes(endTime);

  static int _timeToMinutes(String timeStr) {
    try {
      final trimmed = timeStr.trim().toUpperCase();
      final isPm = trimmed.contains('PM');
      final isAm = trimmed.contains('AM');
      final clean = trimmed.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = clean.split(':');
      if (parts.length < 2) return 0;

      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;

      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'dayOfWeek': dayOfWeek,
      'periodNumber': periodNumber,
      'studentClass': studentClass,
      'board': board,
      'batch': batch,
      'teacherId': teacherId,
      'subject': subject,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'remarks': remarks,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TimetableEntryModel.fromMap(Map<String, dynamic> map) {
    return TimetableEntryModel(
      id: map['id'] as int?,
      dayOfWeek: map['dayOfWeek'] as String,
      periodNumber: map['periodNumber'] as int? ?? 1,
      studentClass: map['studentClass'] as String,
      board: (map['board'] as String?) ?? 'CBSE',
      batch: map['batch'] as String?,
      teacherId: map['teacherId'] as int,
      teacherName: map['teacherName'] as String?,
      subject: map['subject'] as String,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      room: map['room'] as String?,
      remarks: map['remarks'] as String?,
      isActive: (map['isActive'] as int? ?? 1) == 1,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  TimetableEntryModel copyWith({
    int? id,
    String? dayOfWeek,
    int? periodNumber,
    String? studentClass,
    String? board,
    String? batch,
    int? teacherId,
    String? teacherName,
    String? subject,
    String? startTime,
    String? endTime,
    String? room,
    String? remarks,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return TimetableEntryModel(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      periodNumber: periodNumber ?? this.periodNumber,
      studentClass: studentClass ?? this.studentClass,
      board: board ?? this.board,
      batch: batch ?? this.batch,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      subject: subject ?? this.subject,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      remarks: remarks ?? this.remarks,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
