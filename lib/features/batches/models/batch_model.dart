class BatchModel {
  final int? id;
  final String name;
  final String studentClass;
  final String board;
  final String? startTime;
  final String? endTime;
  final int? teacherId;
  final String? description;
  final int maxStudents;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  const BatchModel({
    this.id,
    required this.name,
    required this.studentClass,
    this.board = 'CBSE',
    this.startTime,
    this.endTime,
    this.teacherId,
    this.description,
    this.maxStudents = 40,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'studentClass': studentClass,
        'board': board,
        'startTime': startTime,
        'endTime': endTime,
        'teacherId': teacherId,
        'description': description,
        'maxStudents': maxStudents,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory BatchModel.fromMap(Map<String, dynamic> map) => BatchModel(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        studentClass: map['studentClass'] as String? ?? '',
        board: map['board'] as String? ?? 'CBSE',
        startTime: map['startTime'] as String?,
        endTime: map['endTime'] as String?,
        teacherId: map['teacherId'] as int?,
        description: map['description'] as String?,
        maxStudents: map['maxStudents'] as int? ?? 40,
        isActive: (map['isActive'] as int?) == 1,
        createdAt: map['createdAt'] as String? ?? '',
        updatedAt: map['updatedAt'] as String?,
      );

  BatchModel copyWith({
    int? id,
    String? name,
    String? studentClass,
    String? board,
    String? startTime,
    String? endTime,
    int? teacherId,
    String? description,
    int? maxStudents,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return BatchModel(
      id: id ?? this.id,
      name: name ?? this.name,
      studentClass: studentClass ?? this.studentClass,
      board: board ?? this.board,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      teacherId: teacherId ?? this.teacherId,
      description: description ?? this.description,
      maxStudents: maxStudents ?? this.maxStudents,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
