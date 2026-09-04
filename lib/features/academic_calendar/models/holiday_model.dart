class HolidayModel {
  final int? id;
  final String name;
  final String date;
  final String? description;
  final bool isRecurring;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  const HolidayModel({
    this.id,
    required this.name,
    required this.date,
    this.description,
    this.isRecurring = false,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'date': date,
        'description': description,
        'isRecurring': isRecurring ? 1 : 0,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory HolidayModel.fromMap(Map<String, dynamic> map) => HolidayModel(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        date: map['date'] as String? ?? '',
        description: map['description'] as String?,
        isRecurring: (map['isRecurring'] as int?) == 1,
        isActive: (map['isActive'] as int?) == 1,
        createdAt: map['createdAt'] as String? ?? '',
        updatedAt: map['updatedAt'] as String?,
      );

  HolidayModel copyWith({
    int? id,
    String? name,
    String? date,
    String? description,
    bool? isRecurring,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return HolidayModel(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      description: description ?? this.description,
      isRecurring: isRecurring ?? this.isRecurring,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
