import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../models/notice_model.dart';

/// Container for Admin Read Analytics for a notice.
class NoticeReadAnalytics {
  final int noticeId;
  final int totalTargeted;
  final int readCount;
  final int unreadCount;
  final double readPercentage;
  final List<Map<String, String>> readUsers; // [{ 'id': 'student_1', 'name': 'Rahul', 'readAt': '2026-08-23...' }]
  final List<Map<String, String>> unreadUsers; // [{ 'id': 'student_2', 'name': 'Amit' }]

  const NoticeReadAnalytics({
    required this.noticeId,
    required this.totalTargeted,
    required this.readCount,
    required this.unreadCount,
    required this.readPercentage,
    required this.readUsers,
    required this.unreadUsers,
  });
}

/// Repository for Notice & Announcement SQLite database operations and per-user read tracking.
class NoticeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ──────────────────────────────────────────────────────────────────────
  // Notice Read Tracking Methods
  // ──────────────────────────────────────────────────────────────────────

  /// Mark a notice as read by a specific user (username / userId / rollNo).
  Future<void> markNoticeAsRead(int noticeId, String userId) async {
    if (userId.trim().isEmpty) return;
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.insert(
      'notice_reads',
      {
        'noticeId': noticeId,
        'userId': userId.trim(),
        'readAt': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Get list of notice IDs that a specific user has marked as read.
  Future<Set<int>> getReadNoticeIdsForUser(String userId) async {
    if (userId.trim().isEmpty) return {};
    final db = await _dbHelper.database;
    final results = await db.query(
      'notice_reads',
      columns: ['noticeId'],
      where: 'userId = ?',
      whereArgs: [userId.trim()],
    );

    return results.map((r) => r['noticeId'] as int).toSet();
  }

  /// Unread count for Student or Teacher feed dashboard badges.
  Future<int> getUnreadNoticeCount(
    String role, {
    String? studentClass,
    String? batch,
    String? userId,
  }) async {
    if (userId == null || userId.trim().isEmpty) return 0;
    final list = await getNoticesForRole(
      role,
      studentClass: studentClass,
      batch: batch,
      userId: userId,
    );
    return list.where((n) => !n.isRead).length;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Repository Operations
  // ──────────────────────────────────────────────────────────────────────

  Future<int> insertNotice(NoticeModel notice) async {
    if (notice.title.trim().isEmpty) {
      throw ArgumentError('Notice title is required.');
    }
    if (notice.message.trim().isEmpty) {
      throw ArgumentError('Notice message is required.');
    }

    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    final map = notice.toMap();

    map['createdAt'] = notice.createdAt ?? nowIso;
    map['updatedAt'] = nowIso;

    return await db.insert('notices', map);
  }

  Future<int> updateNotice(NoticeModel notice) async {
    if (notice.id == null) {
      throw ArgumentError('Cannot update notice without an ID.');
    }
    if (notice.title.trim().isEmpty) {
      throw ArgumentError('Notice title is required.');
    }
    if (notice.message.trim().isEmpty) {
      throw ArgumentError('Notice message is required.');
    }

    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    final map = notice.toMap();

    map['updatedAt'] = nowIso;

    return await db.update(
      'notices',
      map,
      where: 'id = ?',
      whereArgs: [notice.id],
    );
  }

  Future<int> togglePublishStatus(int id, bool isPublished) async {
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    return await db.update(
      'notices',
      {
        'isPublished': isPublished ? 1 : 0,
        'updatedAt': nowIso,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> toggleArchiveStatus(int id, bool isArchived) async {
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();

    return await db.update(
      'notices',
      {
        'isActive': isArchived ? 0 : 1,
        'updatedAt': nowIso,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteNotice(int id) async {
    final db = await _dbHelper.database;
    await db.delete('notice_reads', where: 'noticeId = ?', whereArgs: [id]);
    return await db.delete('notices', where: 'id = ?', whereArgs: [id]);
  }

  Future<NoticeModel?> getNoticeById(int id, {String? userId}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'notices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;

    bool read = false;
    if (userId != null && userId.isNotEmpty) {
      final readIds = await getReadNoticeIdsForUser(userId);
      read = readIds.contains(id);
    }

    return NoticeModel.fromMap(maps.first, isRead: read);
  }

  Future<List<NoticeModel>> getAllNoticesAdmin({
    String? searchQuery,
    String? noticeType,
    String? targetRole,
    String? studentClass,
    String? board,
    String? priority,
    String? filterStatus, // 'All', 'Published', 'Draft', 'Expired', 'Archived'
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      whereClauses.add('(title LIKE ? OR message LIKE ?)');
      whereArgs.addAll([q, q]);
    }

    if (noticeType != null && noticeType != 'All' && noticeType.isNotEmpty) {
      whereClauses.add('noticeType = ?');
      whereArgs.add(noticeType);
    }

    if (targetRole != null && targetRole != 'All' && targetRole.isNotEmpty) {
      whereClauses.add('targetRole = ?');
      whereArgs.add(targetRole);
    }

    if (studentClass != null && studentClass != 'All' && studentClass.isNotEmpty) {
      whereClauses.add('(targetClass IS NULL OR targetClass = "" OR targetClass = "All" OR targetClass = ?)');
      whereArgs.add(studentClass);
    }

    if (priority != null && priority != 'All' && priority.isNotEmpty) {
      whereClauses.add('priority = ?');
      whereArgs.add(priority);
    }

    if (filterStatus != null && filterStatus != 'All') {
      if (filterStatus == 'Published') {
        whereClauses.add('isPublished = 1 AND isActive = 1');
      } else if (filterStatus == 'Draft') {
        whereClauses.add('isPublished = 0 AND isActive = 1');
      } else if (filterStatus == 'Archived') {
        whereClauses.add('isActive = 0');
      }
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final query = 'SELECT * FROM notices $whereString ORDER BY id DESC';

    final results = await db.rawQuery(query, whereArgs);
    var list = results.map((m) => NoticeModel.fromMap(m)).toList();

    if (filterStatus == 'Expired') {
      list = list.where((n) => n.isExpired && n.isActive).toList();
    }

    return list;
  }

  Future<List<NoticeModel>> getNoticesForRole(
    String role, {
    String? studentClass,
    String? board,
    String? batch,
    String? userId,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = ['isActive = 1', 'isPublished = 1'];
    final whereArgs = <dynamic>[];

    // Filter targetRole:
    // For Teachers: 'Everyone', 'All Users', 'Teachers', 'All'
    // For Students: 'Everyone', 'All Users', 'Students', 'All', 'Specific Class', 'Specific Batch'
    if (role == 'Teacher') {
      whereClauses.add('(targetRole = "Everyone" OR targetRole = "All Users" OR targetRole = "Teachers" OR targetRole = "All")');
    } else if (role == 'Student') {
      final studentRoleClauses = <String>[
        'targetRole = "Everyone"',
        'targetRole = "All Users"',
        'targetRole = "Students"',
        'targetRole = "All"',
      ];

      if (studentClass != null && studentClass.isNotEmpty) {
        studentRoleClauses.add('(targetRole = "Specific Class" AND (targetClass IS NULL OR targetClass = "" OR targetClass = "All" OR targetClass = ?))');
        whereArgs.add(studentClass);

        // Also match generic class filter if targetRole is Students
        whereClauses.add('(targetClass IS NULL OR targetClass = "" OR targetClass = "All" OR targetClass = ?)');
        whereArgs.add(studentClass);
      }

      if (batch != null && batch.isNotEmpty) {
        studentRoleClauses.add('(targetRole = "Specific Batch" AND (targetBatch IS NULL OR targetBatch = "" OR targetBatch = "All" OR targetBatch = ?))');
        whereArgs.add(batch);
      }

      whereClauses.add('(${studentRoleClauses.join(' OR ')})');
    }

    final whereString = 'WHERE ${whereClauses.join(' AND ')}';
    final query = 'SELECT * FROM notices $whereString ORDER BY id DESC';

    final results = await db.rawQuery(query, whereArgs);
    var list = results.map((m) => NoticeModel.fromMap(m)).toList();

    // Specific Class and Specific Batch final in-memory relevance filter
    if (role == 'Student') {
      list = list.where((n) {
        if (n.targetRole == 'Specific Class' && studentClass != null && studentClass.isNotEmpty) {
          if (n.targetClass != null && n.targetClass!.isNotEmpty && n.targetClass != 'All' && n.targetClass != studentClass) {
            return false;
          }
        }
        if (n.targetRole == 'Specific Batch' && batch != null && batch.isNotEmpty) {
          if (n.targetBatch != null && n.targetBatch!.isNotEmpty && n.targetBatch != 'All' && n.targetBatch != batch) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    // Filter out expired & future published notices for non-admin users
    list = list.where((n) => !n.isExpired && !n.isFuturePublish).toList();

    // Sort by priority (Urgent > Important > Normal) and then ID
    final pMap = {'Urgent': 3, 'Important': 2, 'Normal': 1};
    list.sort((a, b) {
      final pA = pMap[a.priority] ?? 1;
      final pB = pMap[b.priority] ?? 1;
      if (pA != pB) return pB.compareTo(pA);
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });

    // Attach per-user read status if userId is provided
    if (userId != null && userId.isNotEmpty) {
      final readIds = await getReadNoticeIdsForUser(userId);
      list = list.map((n) => n.copyWith(isRead: readIds.contains(n.id))).toList();
    }

    return list;
  }

  /// Calculates actual notice read analytics from SQLite tables (students, teachers, notice_reads).
  Future<NoticeReadAnalytics> getNoticeReadAnalytics(int noticeId) async {
    final db = await _dbHelper.database;
    final notice = await getNoticeById(noticeId);
    if (notice == null) {
      return const NoticeReadAnalytics(
        noticeId: 0,
        totalTargeted: 0,
        readCount: 0,
        unreadCount: 0,
        readPercentage: 0.0,
        readUsers: [],
        unreadUsers: [],
      );
    }

    // 1. Fetch read records for this notice
    final readRows = await db.query(
      'notice_reads',
      where: 'noticeId = ?',
      whereArgs: [noticeId],
    );

    final Map<String, String> readTimestamps = {};
    for (final r in readRows) {
      final uId = r['userId'].toString();
      final rAt = r['readAt'].toString();
      readTimestamps[uId] = rAt;
    }

    // 2. Fetch targeted users from database
    final List<Map<String, String>> targetedUsers = [];

    // Query students if targeted
    if (notice.targetRole == 'Everyone' ||
        notice.targetRole == 'All Users' ||
        notice.targetRole == 'All' ||
        notice.targetRole == 'Students' ||
        notice.targetRole == 'Specific Class' ||
        notice.targetRole == 'Specific Batch') {
      String studentWhere = 'isActive = 1';
      List<dynamic> studentArgs = [];

      if (notice.targetRole == 'Specific Class' && notice.targetClass != null && notice.targetClass!.isNotEmpty && notice.targetClass != 'All') {
        studentWhere += ' AND studentClass = ?';
        studentArgs.add(notice.targetClass);
      }

      final studentRows = await db.query(
        'students',
        columns: ['id', 'name', 'studentClass'],
        where: studentWhere,
        whereArgs: studentArgs,
      );

      for (final s in studentRows) {
        final idStr = 'student_${s['id']}';
        final nameStr = '${s['name']} (Class ${s['studentClass']})';
        targetedUsers.add({'id': idStr, 'name': nameStr});
      }
    }

    // Query teachers if targeted
    if (notice.targetRole == 'Everyone' ||
        notice.targetRole == 'All Users' ||
        notice.targetRole == 'All' ||
        notice.targetRole == 'Teachers') {
      final teacherRows = await db.query(
        'teachers',
        columns: ['id', 'name', 'subject'],
        where: 'isActive = ?',
        whereArgs: [1],
      );

      for (final t in teacherRows) {
        final idStr = 'teacher_${t['id']}';
        final nameStr = '${t['name']} (${t['subject']})';
        targetedUsers.add({'id': idStr, 'name': nameStr});
      }
    }

    final totalTargeted = targetedUsers.length;
    final List<Map<String, String>> readUsers = [];
    final List<Map<String, String>> unreadUsers = [];

    for (final u in targetedUsers) {
      final uId = u['id']!;
      final uName = u['name']!;
      if (readTimestamps.containsKey(uId)) {
        readUsers.add({
          'id': uId,
          'name': uName,
          'readAt': readTimestamps[uId]!,
        });
      } else {
        unreadUsers.add({
          'id': uId,
          'name': uName,
        });
      }
    }

    final readCount = readUsers.length;
    final unreadCount = totalTargeted >= readCount ? (totalTargeted - readCount) : 0;
    final readPercentage = totalTargeted > 0 ? (readCount / totalTargeted * 100.0) : 0.0;

    return NoticeReadAnalytics(
      noticeId: noticeId,
      totalTargeted: totalTargeted,
      readCount: readCount,
      unreadCount: unreadCount,
      readPercentage: readPercentage,
      readUsers: readUsers,
      unreadUsers: unreadUsers,
    );
  }
}
