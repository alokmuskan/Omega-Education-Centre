class EventModel {
  final int? id;
  final String title;
  final String? description;
  final String eventType; // 'Exam', 'PTM', 'Annual Day', 'Sports', 'General'
  final String startDate;
  final String? endDate;
  final String? targetClass;
  final String? targetBoard;
  final String priority; // 'Normal', 'Important', 'Urgent'
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  const EventModel({
    this.id,
    required this.title,
    this.description,
    this.eventType = 'General',
    required this.startDate,
    this.endDate,
    this.targetClass,
    this.targetBoard = 'All',
    this.priority = 'Normal',
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'eventType': eventType,
        'startDate': startDate,
        'endDate': endDate,
        'targetClass': targetClass,
        'targetBoard': targetBoard,
        'priority': priority,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory EventModel.fromMap(Map<String, dynamic> map) => EventModel(
        id: map['id'] as int?,
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        eventType: map['eventType'] as String? ?? 'General',
        startDate: map['startDate'] as String? ?? '',
        endDate: map['endDate'] as String?,
        targetClass: map['targetClass'] as String?,
        targetBoard: map['targetBoard'] as String?,
        priority: map['priority'] as String? ?? 'Normal',
        isActive: (map['isActive'] as int?) == 1,
        createdAt: map['createdAt'] as String? ?? '',
        updatedAt: map['updatedAt'] as String?,
      );

  EventModel copyWith({
    int? id,
    String? title,
    String? description,
    String? eventType,
    String? startDate,
    String? endDate,
    String? targetClass,
    String? targetBoard,
    String? priority,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      targetClass: targetClass ?? this.targetClass,
      targetBoard: targetBoard ?? this.targetBoard,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
