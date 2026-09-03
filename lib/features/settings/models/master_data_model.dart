import 'dart:convert';

/// Master Data Categories supported in Phase 23.
enum MasterCategory {
  studentClass,
  board,
  batch,
  subject,
  examType,
}

extension MasterCategoryExtension on MasterCategory {
  String get keyName {
    switch (this) {
      case MasterCategory.studentClass:
        return 'master_classes';
      case MasterCategory.board:
        return 'master_boards';
      case MasterCategory.batch:
        return 'master_batches';
      case MasterCategory.subject:
        return 'master_subjects';
      case MasterCategory.examType:
        return 'master_exam_types';
    }
  }

  String get displayName {
    switch (this) {
      case MasterCategory.studentClass:
        return 'Classes';
      case MasterCategory.board:
        return 'Boards';
      case MasterCategory.batch:
        return 'Batches';
      case MasterCategory.subject:
        return 'Subjects';
      case MasterCategory.examType:
        return 'Exam Types';
    }
  }
}

/// Model representing a master data item (e.g. Class "10", Subject "Physics", Exam Type "Monthly Test").
class MasterDataItemModel {
  final String id;
  final String category; // 'studentClass' | 'board' | 'batch' | 'subject' | 'examType'
  final String name;
  final bool isActive;
  final int sortOrder;

  const MasterDataItemModel({
    required this.id,
    required this.category,
    required this.name,
    this.isActive = true,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }

  factory MasterDataItemModel.fromMap(Map<String, dynamic> map) {
    return MasterDataItemModel(
      id: map['id']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      isActive: map['isActive'] == true || map['isActive'] == 1,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MasterDataItemModel.fromJson(String source) =>
      MasterDataItemModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  MasterDataItemModel copyWith({
    String? id,
    String? category,
    String? name,
    bool? isActive,
    int? sortOrder,
  }) {
    return MasterDataItemModel(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
