class TermModel {
  final int? id;
  final String name;
  final String startDate;
  final String endDate;
  final String academicYear;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;

  const TermModel({
    this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.academicYear,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'startDate': startDate,
        'endDate': endDate,
        'academicYear': academicYear,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory TermModel.fromMap(Map<String, dynamic> map) => TermModel(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        startDate: map['startDate'] as String? ?? '',
        endDate: map['endDate'] as String? ?? '',
        academicYear: map['academicYear'] as String? ?? '',
        isActive: (map['isActive'] as int?) == 1,
        createdAt: map['createdAt'] as String? ?? '',
        updatedAt: map['updatedAt'] as String?,
      );

  TermModel copyWith({
    int? id,
    String? name,
    String? startDate,
    String? endDate,
    String? academicYear,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return TermModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      academicYear: academicYear ?? this.academicYear,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
