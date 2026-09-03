import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';

/// Item model representing an operation queued for central backend synchronization.
class SyncQueueItem {
  final int? id;
  final String entityType; // 'users', 'teachers', 'students'
  final String localId;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final Map<String, dynamic> payload;
  final String createdAt;
  final int retryCount;
  final String? lastAttempt;
  final String syncStatus; // 'PENDING', 'PROCESSING', 'FAILED', 'SYNCED'
  final String? errorMessage;

  const SyncQueueItem({
    this.id,
    required this.entityType,
    required this.localId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttempt,
    this.syncStatus = 'PENDING',
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'entityType': entityType,
      'localId': localId,
      'operation': operation,
      'payloadJson': jsonEncode(payload),
      'createdAt': createdAt,
      'retryCount': retryCount,
      'lastAttempt': lastAttempt,
      'syncStatus': syncStatus,
      'errorMessage': errorMessage,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedPayload = {};
    try {
      final jsonStr = map['payloadJson'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        parsedPayload = jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (_) {}

    return SyncQueueItem(
      id: map['id'] as int?,
      entityType: map['entityType'] as String,
      localId: map['localId'] as String,
      operation: map['operation'] as String,
      payload: parsedPayload,
      createdAt: map['createdAt'] as String,
      retryCount: (map['retryCount'] as int?) ?? 0,
      lastAttempt: map['lastAttempt'] as String?,
      syncStatus: (map['syncStatus'] as String?) ?? 'PENDING',
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

/// Local SQLite repository managing the offline sync queue.
class SyncQueueRepository {
  SyncQueueRepository._();
  static final SyncQueueRepository instance = SyncQueueRepository._();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Adds a change to the offline sync queue.
  /// Automatically strips sensitive parameters (passwords, hashes, local photo paths).
  Future<int> addToQueue({
    required String entityType,
    required String localId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final cleanPayload = Map<String, dynamic>.from(payload);
    cleanPayload.remove('password');
    cleanPayload.remove('passwordHash');
    cleanPayload.remove('salt');
    cleanPayload.remove('profilePhotoPath');
    cleanPayload.remove('photoPath');
    cleanPayload.remove('recoveryCode');

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final item = SyncQueueItem(
      entityType: entityType,
      localId: localId,
      operation: operation,
      payload: cleanPayload,
      createdAt: now,
    );

    return await db.insert('sync_queue', item.toMap());
  }

  /// Recovers any queue items stuck in 'PROCESSING' state older than 30 seconds back to 'PENDING'.
  Future<void> recoverStaleProcessingItems() async {
    final db = await _dbHelper.database;
    final threshold = DateTime.now().subtract(const Duration(seconds: 30)).toIso8601String();
    await db.update(
      'sync_queue',
      {
        'syncStatus': 'PENDING',
      },
      where: "syncStatus = 'PROCESSING' AND (lastAttempt IS NULL OR lastAttempt < ?)",
      whereArgs: [threshold],
    );
  }

  /// Fetches all pending queued items in order of creation.
  Future<List<SyncQueueItem>> getPendingItems({int limit = 50}) async {
    await recoverStaleProcessingItems();
    final db = await _dbHelper.database;
    final maps = await db.query(
      'sync_queue',
      where: 'syncStatus IN (?, ?)',
      whereArgs: ['PENDING', 'FAILED'],
      orderBy: 'id ASC',
      limit: limit,
    );
    return maps.map((m) => SyncQueueItem.fromMap(m)).toList();
  }

  /// Updates status of a queue item.
  Future<void> updateItemStatus(int id, String status, {String? errorMessage}) async {
    final db = await _dbHelper.database;
    final updateData = <String, dynamic>{
      'syncStatus': status,
      'lastAttempt': DateTime.now().toIso8601String(),
    };
    if (errorMessage != null) {
      updateData['errorMessage'] = errorMessage;
    }
    await db.update(
      'sync_queue',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Increments retry count on network failure.
  Future<void> incrementRetry(int id, String error) async {
    final db = await _dbHelper.database;
    final items = await db.query('sync_queue', where: 'id = ?', whereArgs: [id]);
    if (items.isNotEmpty) {
      final currentRetry = (items.first['retryCount'] as int?) ?? 0;
      await db.update(
        'sync_queue',
        {
          'retryCount': currentRetry + 1,
          'syncStatus': 'FAILED',
          'lastAttempt': DateTime.now().toIso8601String(),
          'errorMessage': error,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Removes a successfully processed item from the queue.
  Future<void> deleteQueueItem(int id) async {
    final db = await _dbHelper.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns count of pending unsynchronized queue items.
  Future<int> getPendingCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sync_queue WHERE syncStatus IN ('PENDING', 'FAILED', 'PROCESSING')",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
