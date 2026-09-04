class HomeworkModel {
  final int? id;
  final String title;
  final String? description;
  final String studentClass;
  final String board;
  final String subject;
  final int teacherId;
  final String assignedDate;
  final String dueDate;
  final String priority; // 'Normal', 'Important', 'Urgent'
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  const HomeworkModel({
    this.id,
    required this.title,
    this.description,
    required this.studentClass,
    this.board = 'CBSE',
    required this.subject,
    required this.teacherId,
    required this.assignedDate,
    required this.dueDate,
    this.priority = 'Normal',
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'studentClass': studentClass,
        'board': board,
        'subject': subject,
        'teacherId': teacherId,
        'assignedDate': assignedDate,
        'dueDate': dueDate,
        'priority': priority,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory HomeworkModel.fromMap(Map<String, dynamic> map) => HomeworkModel(
        id: map['id'] as int?,
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        studentClass: map['studentClass'] as String? ?? '',
        board: map['board'] as String? ?? 'CBSE',
        subject: map['subject'] as String? ?? '',
        teacherId: map['teacherId'] as int? ?? 0,
        assignedDate: map['assignedDate'] as String? ?? '',
        dueDate: map['dueDate'] as String? ?? '',
        priority: map['priority'] as String? ?? 'Normal',
        isActive: (map['isActive'] as int?) == 1,
        createdAt: map['createdAt'] as String? ?? '',
        updatedAt: map['updatedAt'] as String?,
      );

  HomeworkModel copyWith({
    int? id,
    String? title,
    String? description,
    String? studentClass,
    String? board,
    String? subject,
    int? teacherId,
    String? assignedDate,
    String? dueDate,
    String? priority,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return HomeworkModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      studentClass: studentClass ?? this.studentClass,
      board: board ?? this.board,
      subject: subject ?? this.subject,
      teacherId: teacherId ?? this.teacherId,
      assignedDate: assignedDate ?? this.assignedDate,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
