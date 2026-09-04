import 'dart:convert';

import '../utils/app_session.dart';
import '../../core/database/database_helper.dart';

/// Append-only audit trail service for Omega Education Centre ERP.
///
/// Every financial transaction, student/teacher CRUD, and settings change
/// is recorded with: action, entity, actor, timestamp, old/new values.
///
/// Audit log entries are:
///   1. Written to local SQLite `audit_log` table (for offline support).
///   2. Queued for sync to Supabase `audit_log` table.
class AuditService {
  AuditService._();

  static final AuditService instance = AuditService._();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Action Constants ────────────────────────────────────────────────

  static const String actionFeePayment = 'FEE_PAYMENT';
  static const String actionFeeRefund = 'FEE_REFUND';
  static const String actionSalaryPayment = 'SALARY_PAYMENT';
  static const String actionStudentCreate = 'STUDENT_CREATE';
  static const String actionStudentUpdate = 'STUDENT_UPDATE';
  static const String actionStudentDelete = 'STUDENT_DELETE';
  static const String actionTeacherCreate = 'TEACHER_CREATE';
  static const String actionTeacherUpdate = 'TEACHER_UPDATE';
  static const String actionTeacherDeactivate = 'TEACHER_DEACTIVATE';
  static const String actionUserCreate = 'USER_CREATE';
  static const String actionUserUpdate = 'USER_UPDATE';
  static const String actionPasswordChange = 'PASSWORD_CHANGE';
  static const String actionPasswordReset = 'PASSWORD_RESET';
  static const String actionSettingsChange = 'SETTINGS_CHANGE';
  static const String actionTestCreate = 'TEST_CREATE';
  static const String actionTestUpdate = 'TEST_UPDATE';
  static const String actionTestDelete = 'TEST_DELETE';
  static const String actionNoticeCreate = 'NOTICE_CREATE';
  static const String actionNoticeUpdate = 'NOTICE_UPDATE';
  static const String actionTimetableUpdate = 'TIMETABLE_UPDATE';
  static const String actionAttendanceRecord = 'ATTENDANCE_RECORD';

  // ── Public API ──────────────────────────────────────────────────────

  /// Logs an audit action to local SQLite.
  ///
  /// [action] — The action performed (use constants above).
  /// [entityType] — The database table affected (e.g. 'fee_payments', 'students').
  /// [entityId] — The ID of the affected record (nullable for bulk operations).
  /// [oldValue] — Previous state of the record (nullable for creates).
  /// [newValue] — New state of the record (nullable for deletes).
  Future<void> logAction({
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
  }) async {
    try {
      final session = AppSession.instance;
      final actorUsername = session.currentUsername.isNotEmpty
          ? session.currentUsername
          : 'system';
      final actorRole = session.currentRole;

      final now = DateTime.now().toIso8601String();

      final db = await _dbHelper.database;

      await db.insert('audit_log', {
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'actorUsername': actorUsername,
        'actorRole': actorRole,
        'oldValueJson': oldValue != null ? jsonEncode(oldValue) : null,
        'newValueJson': newValue != null ? jsonEncode(newValue) : null,
        'deviceId': null,
        'ipAddress': null,
        'createdAt': now,
      });

      // TODO: Queue for sync to Supabase in Phase 2 (sync engine expansion)
    } catch (e) {
      // Audit logging should never crash the app.
      // Silently fail — the operation itself still succeeds.
    }
  }

  /// Queries audit log entries with optional filters.
  ///
  /// [action] — Filter by action type (nullable = all actions).
  /// [entityType] — Filter by entity type (nullable = all entities).
  /// [startDate] — Filter by start date (nullable = no start limit).
  /// [endDate] — Filter by end date (nullable = no end limit).
  /// [limit] — Maximum number of records to return.
  /// [offset] — Number of records to skip (for pagination).
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? action,
    String? entityType,
    String? startDate,
    String? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final db = await _dbHelper.database;

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (action != null && action.isNotEmpty) {
        whereClauses.add('action = ?');
        whereArgs.add(action);
      }

      if (entityType != null && entityType.isNotEmpty) {
        whereClauses.add('entityType = ?');
        whereArgs.add(entityType);
      }

      if (startDate != null && startDate.isNotEmpty) {
        whereClauses.add('createdAt >= ?');
        whereArgs.add(startDate);
      }

      if (endDate != null && endDate.isNotEmpty) {
        whereClauses.add('createdAt <= ?');
        whereArgs.add(endDate);
      }

      final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      return await db.query(
        'audit_log',
        where: where,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'createdAt DESC',
        limit: limit,
        offset: offset,
      );
    } catch (_) {
      return [];
    }
  }

  /// Returns the total count of audit log entries matching the filters.
  Future<int> getAuditLogCount({
    String? action,
    String? entityType,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final db = await _dbHelper.database;

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (action != null && action.isNotEmpty) {
        whereClauses.add('action = ?');
        whereArgs.add(action);
      }

      if (entityType != null && entityType.isNotEmpty) {
        whereClauses.add('entityType = ?');
        whereArgs.add(entityType);
      }

      if (startDate != null && startDate.isNotEmpty) {
        whereClauses.add('createdAt >= ?');
        whereArgs.add(startDate);
      }

      if (endDate != null && endDate.isNotEmpty) {
        whereClauses.add('createdAt <= ?');
        whereArgs.add(endDate);
      }

      final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM audit_log${where != null ? ' WHERE $where' : ''}',
        whereArgs.isNotEmpty ? whereArgs : null,
      );

      return (result.first['cnt'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Exports audit log entries as a list of JSON-serializable maps.
  Future<List<Map<String, dynamic>>> exportAuditLogs({
    String? action,
    String? entityType,
    String? startDate,
    String? endDate,
  }) async {
    return getAuditLogs(
      action: action,
      entityType: entityType,
      startDate: startDate,
      endDate: endDate,
      limit: 10000, // Export all matching records
    );
  }
}
