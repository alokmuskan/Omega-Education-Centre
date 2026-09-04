import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/data_sources/data_source_factory.dart';
import '../../core/database/database_helper.dart';
import '../config/backend_config.dart';
import 'supabase_auth_service.dart';
import 'supabase_health_service.dart';
import 'sync_queue_repository.dart';

enum SyncStatusState {
  synced,
  syncing,
  offline,
  pending,
  authError,
  error,
}

/// Controlled offline-first synchronization engine for Omega Education Centre ERP.
///
/// Scope for Phase 32: Synchronizes ONLY `users`, `teachers`, and `students`.
/// Financial, attendance, tests, results, notices, salary, and profile photos
/// are EXCLUDED and remain 100% local.
class SyncEngine {
  SyncEngine._();

  static final SyncEngine instance = SyncEngine._();

  /// Default organisation UUID fallback matching central PostgreSQL primary key.
  static const String defaultOrgUuid =
      'c6f605c5-52e4-40d4-80ad-cc81ace162fc';

  static String? _cachedOrgUuid;

  final SyncQueueRepository _queueRepo = SyncQueueRepository.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final ValueNotifier<SyncStatusState> statusNotifier =
      ValueNotifier<SyncStatusState>(SyncStatusState.synced);

  final ValueNotifier<int> pendingCountNotifier =
      ValueNotifier<int>(0);

  bool _isSyncing = false;

  /// Dynamically queries central Supabase for organisation UUID matching ORG_OMEGA_DEFAULT.
  Future<String> getOrganisationUuid() async {
    if (_cachedOrgUuid != null) return _cachedOrgUuid!;

    if (!BackendConfig.isBackendConfigured) {
      return defaultOrgUuid;
    }

    try {
      final anonKey = BackendConfig.supabaseAnonKey ?? '';

      final jwtToken =
          await SupabaseAuthService.instance.getValidAccessToken();

      final headers = <String, String>{
        'apikey': anonKey,
        if (jwtToken != null) 'Authorization': 'Bearer $jwtToken',
      };

      final url = Uri.parse(
        '${BackendConfig.supabaseUrl}/rest/v1/organisations'
        '?org_code=eq.${BackendConfig.defaultOrgCode}&select=id',
      );

      final res = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[AUTH-TRACE-14] organisation_http_status=${res.statusCode}',
        );
      }

      if (res.statusCode == 200) {
        final List<dynamic> list =
            jsonDecode(res.body) as List<dynamic>;

        if (list.isNotEmpty && list.first['id'] != null) {
          _cachedOrgUuid = list.first['id'] as String;

          if (kDebugMode) {
            print(
              '[SYNC] Organisation UUID resolved: $_cachedOrgUuid',
            );
          }

          return _cachedOrgUuid!;
        }
      }
    } catch (_) {}

    return defaultOrgUuid;
  }

  /// Trigger a full bidirectional synchronization.
  Future<void> syncAll() async {
    // Web/Chrome does not support the application's sqflite database layer.
    // Do not allow the synchronization engine to access SQLite on Web.
    if (DataSourceFactory.create().isRemote) {
      statusNotifier.value = SyncStatusState.offline;
      pendingCountNotifier.value = 0;
      return;
    }

    if (_isSyncing) return;

    _isSyncing = true;
    statusNotifier.value = SyncStatusState.syncing;

    try {
      final isOnline =
          await SupabaseHealthService.instance.checkConnectivity();

      final pendingCount = await _queueRepo.getPendingCount();

      if (kDebugMode) {
        print('[SYNC] START');
        print('[SYNC-DEBUG-01] syncAll started');
        print(
          '[SYNC] Backend configured: '
          '${BackendConfig.isBackendConfigured}',
        );
        print('[SYNC] Supabase reachable: $isOnline');
        print('[SYNC] Pending queue count: $pendingCount');
      }

      if (!isOnline) {
        final hasInternet = await _hasBasicInternetAccess();

        if (hasInternet) {
          if (kDebugMode) {
            print(
              '[SYNC ERROR] Internet available but Supabase unreachable',
            );
          }

          statusNotifier.value = SyncStatusState.error;
        } else {
          if (kDebugMode) {
            print('[SYNC] OFFLINE: Device network unavailable');
          }

          statusNotifier.value = SyncStatusState.offline;
        }

        await _updatePendingCount();

        if (kDebugMode) {
          // ignore: avoid_print
          print('[SYNC-DEBUG-07] sync finished');

          // ignore: avoid_print
          print(
            '[SYNC-DEBUG-08] final state = '
            '${statusNotifier.value.name}',
          );
        }

        return;
      }

      // Check for valid Supabase Auth User Access JWT.
      final jwtToken =
          await SupabaseAuthService.instance.getValidAccessToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          print(
            '[SYNC AUTH ERROR] Supabase authentication session '
            'unavailable. Protected CRUD skipped.',
          );
        }

        statusNotifier.value = SyncStatusState.authError;

        await _updatePendingCount();

        if (kDebugMode) {
          // ignore: avoid_print
          print('[SYNC-DEBUG-07] sync finished');

          // ignore: avoid_print
          print(
            '[SYNC-DEBUG-08] final state = '
            '${statusNotifier.value.name}',
          );
        }

        return;
      }

      // Verify /auth/v1/user endpoint with active JWT before running REST CRUD operations.
      final isAuthUserValid =
          await SupabaseAuthService.instance.verifyAuthUserEndpoint();

      if (!isAuthUserValid) {
        if (kDebugMode) {
          print(
            '[SYNC AUTH ERROR] /auth/v1/user verification failed. '
            'Token rejected by Supabase Auth.',
          );
        }

        statusNotifier.value = SyncStatusState.authError;

        await _updatePendingCount();

        if (kDebugMode) {
          // ignore: avoid_print
          print('[SYNC-DEBUG-07] sync finished');

          // ignore: avoid_print
          print(
            '[SYNC-DEBUG-08] final state = '
            '${statusNotifier.value.name}',
          );
        }

        return;
      }

      // 1. Push local queued changes to central database.
      await pushLocalChanges(jwtToken);

      // 2. Pull central changes to local SQLite.
      await pullRemoteChanges(jwtToken);

      final remaining = await _queueRepo.getPendingCount();

      pendingCountNotifier.value = remaining;

      if (remaining > 0) {
        statusNotifier.value = SyncStatusState.pending;
      } else {
        statusNotifier.value = SyncStatusState.synced;
      }

      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[SYNC COMPLETE] Remaining queue count: $remaining',
        );

        // ignore: avoid_print
        print(
          '[AUTH-TRACE-16] '
          'final_sync_state=${statusNotifier.value.name}',
        );

        // ignore: avoid_print
        print('[SYNC-DEBUG-07] sync finished');

        // ignore: avoid_print
        print(
          '[SYNC-DEBUG-08] final state = '
          '${statusNotifier.value.name}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SYNC ERROR] ${e.toString()}');
      }

      statusNotifier.value = SyncStatusState.error;

      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[AUTH-TRACE-16] '
          'final_sync_state=${statusNotifier.value.name}',
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Checks if the device has basic internet access via lightweight HTTP probe.
  Future<bool> _hasBasicInternetAccess() async {
    try {
      final res = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));

      return res.statusCode >= 200 && res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  /// Pushes local queued changes to Supabase PostgreSQL using User Access JWT.
  Future<void> pushLocalChanges(String jwtToken) async {
    final pendingItems =
        await _queueRepo.getPendingItems(limit: 20);

    if (pendingItems.isEmpty) return;

    for (final item in pendingItems) {
      try {
        if (item.id != null) {
          await _queueRepo.updateItemStatus(
            item.id!,
            'PROCESSING',
          );
        }

        await _processQueueItem(item, jwtToken);

        if (item.id != null) {
          await _queueRepo.deleteQueueItem(item.id!);
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            '[SYNC ERROR] queueId #${item.id}: ${e.toString()}',
          );
        }

        if (item.id != null) {
          await _queueRepo.incrementRetry(
            item.id!,
            e.toString(),
          );
        }
      }
    }

    await _updatePendingCount();
  }

  /// Processes a single queued change item with authenticated headers.
  Future<void> _processQueueItem(
    SyncQueueItem item,
    String jwtToken,
  ) async {
    if (!BackendConfig.isBackendConfigured) return;

    final anonKey = BackendConfig.supabaseAnonKey ?? '';

    final url = Uri.parse(
      '${BackendConfig.supabaseUrl}/rest/v1/${item.entityType}',
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'apikey': anonKey,
      'Authorization': 'Bearer $jwtToken',
      'Prefer': 'resolution=merge-duplicates',
    };

    final orgUuid = await getOrganisationUuid();

    final remotePayload =
        _mapLocalToRemote(item.entityType, item.payload);

    remotePayload['organisation_id'] = orgUuid;
    remotePayload['updated_at'] =
        DateTime.now().toIso8601String();

    final maskedQueueId =
        item.id != null ? '#${item.id}' : 'batch';

    final startTime = DateTime.now();

    if (item.operation == 'CREATE' ||
        item.operation == 'UPDATE') {
      final res = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode(remotePayload),
          )
          .timeout(const Duration(seconds: 15));

      final duration =
          DateTime.now().difference(startTime).inMilliseconds;

      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[SYNC] method=POST '
          'entity=${item.entityType} '
          'queueId=$maskedQueueId '
          'status=${res.statusCode} '
          'durationMs=$duration '
          'jwtPresent=YES',
        );

        // ignore: avoid_print
        print(
          '[AUTH-TRACE-15] '
          'students_http_status=${res.statusCode}',
        );

        // ignore: avoid_print
        print(
          '[SYNC-DEBUG-04] '
          'REST request entity = ${item.entityType}',
        );

        // ignore: avoid_print
        print(
          '[SYNC-DEBUG-05] '
          'HTTP status = ${res.statusCode}',
        );

        // ignore: avoid_print
        print(
          '[SYNC-DEBUG-06] '
          'queue ID = $maskedQueueId',
        );
      }

      if (res.statusCode >= 400 &&
          res.statusCode != 409) {
        if (kDebugMode) {
          print(
            '[SYNC ERROR] '
            'entity=${item.entityType} '
            'queueId=$maskedQueueId '
            'status=${res.statusCode}',
          );
        }

        throw Exception(
          'Server rejected sync payload '
          '(${res.statusCode}): ${res.body}',
        );
      }
    } else if (item.operation == 'DELETE') {
      remotePayload['deleted_at'] =
          DateTime.now().toIso8601String();

      final res = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode(remotePayload),
          )
          .timeout(const Duration(seconds: 15));

      final duration =
          DateTime.now().difference(startTime).inMilliseconds;

      if (kDebugMode) {
        print(
          '[SYNC] method=POST (DELETE) '
          'entity=${item.entityType} '
          'queueId=$maskedQueueId '
          'status=${res.statusCode} '
          'durationMs=$duration '
          'jwtPresent=YES',
        );
      }

      if (res.statusCode >= 400 &&
          res.statusCode != 409) {
        throw Exception(
          'Server rejected sync delete payload '
          '(${res.statusCode}): ${res.body}',
        );
      }
    }
  }

  /// Pulls remote central changes into local SQLite database safely.
  Future<void> pullRemoteChanges(String jwtToken) async {
    if (!BackendConfig.isBackendConfigured) return;

    final isOnline =
        await SupabaseHealthService.instance.checkConnectivity();

    if (!isOnline) return;

    // Pull core entities.
    await _pullEntityRecords(entityType: 'students', localTableName: 'students', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'teachers', localTableName: 'teachers', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'users', localTableName: 'users', idField: 'id', jwtToken: jwtToken);

    // Pull fee management.
    await _pullEntityRecords(entityType: 'fees', localTableName: 'fees', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'fee_payments', localTableName: 'fee_payments', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'fee_installments', localTableName: 'fee_installments', idField: 'id', jwtToken: jwtToken);

    // Pull attendance.
    await _pullEntityRecords(entityType: 'student_attendance', localTableName: 'student_attendance', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'teacher_attendance', localTableName: 'teacher_attendance', idField: 'id', jwtToken: jwtToken);

    // Pull salary.
    await _pullEntityRecords(entityType: 'teacher_payments', localTableName: 'teacher_payments', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'teacher_pay_rate_history', localTableName: 'teacher_pay_rate_history', idField: 'id', jwtToken: jwtToken);

    // Pull tests & results.
    await _pullEntityRecords(entityType: 'tests', localTableName: 'tests', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'test_subjects', localTableName: 'test_subjects', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'test_results', localTableName: 'test_results', idField: 'id', jwtToken: jwtToken);

    // Pull timetable & notices.
    await _pullEntityRecords(entityType: 'daily_class_records', localTableName: 'daily_class_records', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'timetable_entries', localTableName: 'timetable_entries', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'notices', localTableName: 'notices', idField: 'id', jwtToken: jwtToken);
    await _pullEntityRecords(entityType: 'notice_reads', localTableName: 'notice_reads', idField: 'id', jwtToken: jwtToken);

    // Pull audit log.
    await _pullEntityRecords(entityType: 'audit_log', localTableName: 'audit_log', idField: 'id', jwtToken: jwtToken);
  }

  Future<void> _pullEntityRecords({
    required String entityType,
    required String localTableName,
    required String idField,
    required String jwtToken,
  }) async {
    final anonKey = BackendConfig.supabaseAnonKey ?? '';

    final url = Uri.parse(
      '${BackendConfig.supabaseUrl}/rest/v1/$entityType?select=*',
    );

    final headers = <String, String>{
      'apikey': anonKey,
      'Authorization': 'Bearer $jwtToken',
    };

    try {
      final startTime = DateTime.now();

      final res = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      final duration =
          DateTime.now().difference(startTime).inMilliseconds;

      if (kDebugMode) {
        print(
          '[SYNC PULL] '
          'entity=$entityType '
          'status=${res.statusCode} '
          'durationMs=$duration',
        );
      }

      if (res.statusCode == 200) {
        final List<dynamic> remoteRecords =
            jsonDecode(res.body) as List<dynamic>;

        final db = await _dbHelper.database;

        int localInserts = 0;
        int localUpdates = 0;

        for (final record in remoteRecords) {
          if (record is Map<String, dynamic>) {
            final remoteId = record['id'];

            if (remoteId == null) continue;

            final existing = await db.query(
              localTableName,
              where: '$idField = ?',
              whereArgs: [remoteId],
              limit: 1,
            );

            final remoteUpdatedAt =
                record['updated_at'] as String?;

            final remoteDeletedAt =
                record['deleted_at'] as String?;

            if (existing.isEmpty) {
              if (remoteDeletedAt == null) {
                final localMap =
                    _mapRemoteToLocal(
                  localTableName,
                  record,
                );

                await db.insert(
                  localTableName,
                  localMap,
                );

                localInserts++;
              }
            } else {
              final localUpdatedAt =
                  existing.first['updatedAt'] as String?;

              if (_isRemoteNewer(
                remoteUpdatedAt,
                localUpdatedAt,
              )) {
                final localMap =
                    _mapRemoteToLocal(
                  localTableName,
                  record,
                );

                if (remoteDeletedAt != null) {
                  localMap['deletedAt'] =
                      remoteDeletedAt;

                  localMap['isActive'] = 0;
                }

                await db.update(
                  localTableName,
                  localMap,
                  where: '$idField = ?',
                  whereArgs: [remoteId],
                );

                localUpdates++;
              }
            }
          }
        }

        if (kDebugMode) {
          print(
            '[SYNC PULL SUCCESS] '
            'entity=$entityType '
            'remoteCount=${remoteRecords.length} '
            'inserts=$localInserts '
            'updates=$localUpdates',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          '[SYNC PULL ERROR] '
          'entity=$entityType '
          'exception=${e.toString()}',
        );
      }
    }
  }

  /// Translates local SQLite camelCase map payload into PostgreSQL snake_case columns.
  Map<String, dynamic> _mapLocalToRemote(
    String entityType,
    Map<String, dynamic> local,
  ) {
    final remote = <String, dynamic>{};

    local.forEach((key, value) {
      if (value == null) return;

      if (key == 'password' ||
          key == 'passwordHash' ||
          key == 'salt' ||
          key == 'profilePhotoPath' ||
          key == 'photoPath' ||
          key == 'recoveryCode' ||
          key == 'feeStatus' ||
          key == 'syncedAt') {
        return;
      }

      switch (key) {
        case 'id':
          remote['id'] = value;
          break;

        case 'rollNo':
          remote['roll_no'] = value;
          break;

        case 'name':
          remote['name'] = value;
          break;

        case 'fatherName':
          remote['father_name'] = value;
          break;

        case 'motherName':
          remote['mother_name'] = value;
          break;

        case 'mobile':
          remote['mobile'] = value;
          break;

        case 'studentClass':
          remote['student_class'] = value;
          break;

        case 'board':
          remote['board'] = value;
          break;

        case 'subject':
          remote['subject'] = value;
          break;

        case 'payPerHour':
          remote['pay_per_hour'] =
              (value as num).toDouble();
          break;

        case 'joiningDate':
          remote['joining_date'] = value;
          break;

        case 'username':
          remote['username'] = value;
          break;

        case 'role':
          remote['role'] = value;
          break;

        case 'referenceId':
          remote['reference_id'] = value;
          break;

        case 'isActive':
          remote['is_active'] =
              (value == 1 || value == true);
          break;

        case 'createdAt':
          remote['created_at'] = value;
          break;

        case 'updatedAt':
          remote['updated_at'] = value;
          break;

        case 'deletedAt':
          remote['deleted_at'] = value;
          break;

        default:
          final snakeKey = key.replaceAllMapped(
            RegExp(r'([A-Z])'),
            (match) =>
                '_${match.group(1)!.toLowerCase()}',
          );

          remote[snakeKey] = value;
      }
    });

    return remote;
  }  /// Translates remote PostgreSQL snake_case columns back into local SQLite camelCase fields.
  /// Generic conversion handles all entity types automatically.
  Map<String, dynamic> _mapRemoteToLocal(
    String table,
    Map<String, dynamic> remote,
  ) {
    final map = <String, dynamic>{};

    remote.forEach((key, value) {
      if (value == null) return;

      // Skip organisation_id (multi-tenant, not used locally)
      if (key == 'organisation_id') return;

      // Convert snake_case to camelCase
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );

      // Handle boolean fields (is_active → isActive = 1/0)
      if (key == 'is_active') {
        map['isActive'] = (value == true) ? 1 : 0;
        return;
      }

      if (key == 'is_published') {
        map['isPublished'] = (value == true) ? 1 : 0;
        return;
      }

      if (key == 'is_absent') {
        map['isAbsent'] = (value == true) ? 1 : 0;
        return;
      }

      // Handle numeric fields that need toDouble()
      if (value is num && (key.contains('amount') || key.contains('fee') || key.contains('rate') || key.contains('hours') || key.contains('marks'))) {
        map[camelKey] = value.toDouble();
        return;
      }

      map[camelKey] = value;
    });

    return map;
  }

  bool _isRemoteNewer(
    String? remoteStr,
    String? localStr,
  ) {
    if (remoteStr == null || remoteStr.isEmpty) {
      return false;
    }

    if (localStr == null || localStr.isEmpty) {
      return true;
    }

    try {
      final remoteDate = DateTime.parse(remoteStr);
      final localDate = DateTime.parse(localStr);

      return remoteDate.isAfter(localDate);
    } catch (_) {
      return true;
    }
  }

  /// Generic queue registration method for any entity type.
  Future<void> _registerEntityChange({
    required String entityType,
    required String localId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await _queueRepo.addToQueue(
      entityType: entityType,
      localId: localId,
      operation: operation,
      payload: payload,
    );
    await _updatePendingCount();
    syncAll();
  }

  /// Queues a student change and triggers background sync.
  Future<void> registerStudentChange({
    required int studentId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'students', localId: studentId.toString(), operation: operation, payload: payload);

  /// Queues a teacher change and triggers background sync.
  Future<void> registerTeacherChange({
    required int teacherId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'teachers', localId: teacherId.toString(), operation: operation, payload: payload);

  /// Queues a fee change and triggers background sync.
  Future<void> registerFeeChange({
    required int feeId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'fees', localId: feeId.toString(), operation: operation, payload: payload);

  /// Queues a fee payment change.
  Future<void> registerFeePaymentChange({
    required int paymentId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'fee_payments', localId: paymentId.toString(), operation: operation, payload: payload);

  /// Queues a student attendance change.
  Future<void> registerStudentAttendanceChange({
    required int attendanceId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'student_attendance', localId: attendanceId.toString(), operation: operation, payload: payload);

  /// Queues a teacher attendance change.
  Future<void> registerTeacherAttendanceChange({
    required int attendanceId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'teacher_attendance', localId: attendanceId.toString(), operation: operation, payload: payload);

  /// Queues a teacher payment (salary) change.
  Future<void> registerTeacherPaymentChange({
    required int paymentId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'teacher_payments', localId: paymentId.toString(), operation: operation, payload: payload);

  /// Queues a test change.
  Future<void> registerTestChange({
    required int testId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'tests', localId: testId.toString(), operation: operation, payload: payload);

  /// Queues a test result change.
  Future<void> registerTestResultChange({
    required int resultId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'test_results', localId: resultId.toString(), operation: operation, payload: payload);

  /// Queues a daily class record change.
  Future<void> registerDailyClassRecordChange({
    required int recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'daily_class_records', localId: recordId.toString(), operation: operation, payload: payload);

  /// Queues a timetable entry change.
  Future<void> registerTimetableChange({
    required int entryId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'timetable_entries', localId: entryId.toString(), operation: operation, payload: payload);

  /// Queues a notice change.
  Future<void> registerNoticeChange({
    required int noticeId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'notices', localId: noticeId.toString(), operation: operation, payload: payload);

  /// Queues an audit log entry for sync.
  Future<void> registerAuditLogChange({
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'audit_log', localId: entityId, operation: operation, payload: payload);

  /// Queues a fee installment change.
  Future<void> registerFeeInstallmentChange({
    required int installmentId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'fee_installments', localId: installmentId.toString(), operation: operation, payload: payload);

  /// Queues a teacher pay rate history change.
  Future<void> registerTeacherPayRateChange({
    required int recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'teacher_pay_rate_history', localId: recordId.toString(), operation: operation, payload: payload);

  /// Queues a test subject change.
  Future<void> registerTestSubjectChange({
    required int subjectId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'test_subjects', localId: subjectId.toString(), operation: operation, payload: payload);

  /// Queues a notice read receipt change.
  Future<void> registerNoticeReadChange({
    required int readId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => _registerEntityChange(entityType: 'notice_reads', localId: readId.toString(), operation: operation, payload: payload);

  Future<void> _updatePendingCount() async {
    final count = await _queueRepo.getPendingCount();

    pendingCountNotifier.value = count;
  }
}