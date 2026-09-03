/// Data model representing an institute notice, announcement, exam alert, or holiday notice.
class NoticeModel {
  final int? id;
  final String title;
  final String message;
  final String noticeType; // 'General', 'Academic', 'Exam', 'Holiday', 'Fee', 'Important', 'Event'
  final String targetRole; // 'Everyone', 'Students', 'Teachers', 'Specific Class', 'Specific Batch'
  final String? targetClass; // 'All' or specific class e.g. '10'
  final String? targetBoard; // 'All' or specific board e.g. 'CBSE'
  final String? targetBatch; // specific batch e.g. 'Udaan'
  final String publishDate; // YYYY-MM-DD
  final String? expiryDate; // YYYY-MM-DD
  final String priority; // 'Normal', 'Important', 'Urgent'
  final bool isPublished;
  final bool isActive; // isActive = false indicates Archived
  final bool isRead; // Per-user read tracking flag (from notice_reads table)
  final String? createdAt;
  final String? updatedAt;

  const NoticeModel({
    this.id,
    required this.title,
    required this.message,
    this.noticeType = 'General',
    this.targetRole = 'Everyone',
    this.targetClass,
    this.targetBoard = 'All',
    this.targetBatch,
    required this.publishDate,
    this.expiryDate,
    this.priority = 'Normal',
    this.isPublished = true,
    this.isActive = true,
    this.isRead = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Aliases and backwards compatibility getters for Phase 14 spec.
  String get description => message;
  String get category => noticeType;
  String get targetAudience => targetRole;
  bool get isArchived => !isActive;
  String? get studentClass => targetClass;
  String? get batch => targetBatch;

  /// True if the notice has an expiry date that is before today.
  bool get isExpired {
    if (expiryDate == null || expiryDate!.isEmpty) return false;
    try {
      final exp = DateTime.parse(expiryDate!);
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);
      return exp.isBefore(todayNormalized);
    } catch (_) {
      return false;
    }
  }

  /// True if the notice publish date is in the future.
  bool get isFuturePublish {
    try {
      final pub = DateTime.parse(publishDate);
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);
      return pub.isAfter(todayNormalized);
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'message': message,
      'noticeType': noticeType,
      'targetRole': targetRole,
      'targetClass': targetClass,
      'targetBoard': targetBoard,
      'targetBatch': targetBatch,
      'publishDate': publishDate,
      'expiryDate': expiryDate,
      'priority': priority,
      'isPublished': isPublished ? 1 : 0,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory NoticeModel.fromMap(Map<String, dynamic> map, {bool isRead = false}) {
    return NoticeModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      message: (map['message'] as String?) ?? (map['description'] as String? ?? ''),
      noticeType: (map['noticeType'] as String?) ?? (map['category'] as String?) ?? 'General',
      targetRole: (map['targetRole'] as String?) ?? (map['targetAudience'] as String?) ?? 'Everyone',
      targetClass: (map['targetClass'] as String?) ?? (map['studentClass'] as String?),
      targetBoard: (map['targetBoard'] as String?) ?? 'All',
      targetBatch: (map['targetBatch'] as String?) ?? (map['batch'] as String?),
      publishDate: map['publishDate'] as String,
      expiryDate: map['expiryDate'] as String?,
      priority: (map['priority'] as String?) ?? 'Normal',
      isPublished: (map['isPublished'] as int? ?? 1) == 1,
      isActive: (map['isActive'] as int? ?? 1) == 1,
      isRead: isRead,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  NoticeModel copyWith({
    int? id,
    String? title,
    String? message,
    String? noticeType,
    String? targetRole,
    String? targetClass,
    String? targetBoard,
    String? targetBatch,
    String? publishDate,
    String? expiryDate,
    String? priority,
    bool? isPublished,
    bool? isActive,
    bool? isRead,
    String? createdAt,
    String? updatedAt,
  }) {
    return NoticeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      noticeType: noticeType ?? this.noticeType,
      targetRole: targetRole ?? this.targetRole,
      targetClass: targetClass ?? this.targetClass,
      targetBoard: targetBoard ?? this.targetBoard,
      targetBatch: targetBatch ?? this.targetBatch,
      publishDate: publishDate ?? this.publishDate,
      expiryDate: expiryDate ?? this.expiryDate,
      priority: priority ?? this.priority,
      isPublished: isPublished ?? this.isPublished,
      isActive: isActive ?? this.isActive,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
