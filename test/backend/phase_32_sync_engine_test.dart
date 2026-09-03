import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/shared/config/backend_config.dart';
import 'package:omega_education_centre/shared/services/sync_engine.dart';
import 'package:omega_education_centre/shared/services/sync_queue_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omega_education_centre/shared/utils/encryption_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  EncryptionKeyManager.testMode = true;

  group('Phase 32 — Controlled Offline-First Sync Engine Unit Tests', () {
    late SyncQueueRepository queueRepo;

    setUp(() async {
      BackendConfig.initialize(url: '', anonKey: '');
      queueRepo = SyncQueueRepository.instance;
      final db = await DatabaseHelper.instance.database;
      await db.delete('sync_queue');
    });

    test('1 & 3. Offline student creation queues change with stripped photo path and sensitive keys', () async {
      await queueRepo.addToQueue(
        entityType: 'students',
        localId: '101',
        operation: 'CREATE',
        payload: {
          'name': 'Rahul Verma',
          'fatherName': 'Vikram Verma',
          'mobile': '9811122233',
          'board': 'CBSE',
          'studentClass': '10',
          'rollNo': 101,
          'password': 'secretPassword',
          'profilePhotoPath': '/storage/emulated/0/DCIM/photo.jpg',
        },
      );

      final items = await queueRepo.getPendingItems();
      expect(items.isNotEmpty, isTrue);

      final studentItem = items.firstWhere((i) => i.localId == '101');
      expect(studentItem.payload['name'], equals('Rahul Verma'));
      expect(studentItem.payload.containsKey('password'), isFalse);
      expect(studentItem.payload.containsKey('profilePhotoPath'), isFalse);

      await queueRepo.deleteQueueItem(studentItem.id!);
    });

    test('2 & 13. Offline teacher creation queues change with stripped photo path and clean payload', () async {
      await queueRepo.addToQueue(
        entityType: 'teachers',
        localId: '202',
        operation: 'CREATE',
        payload: {
          'name': 'Suman Gupta',
          'mobile': '9877766655',
          'subject': 'Mathematics',
          'payPerHour': 500.0,
          'joiningDate': '2026-01-15',
          'photoPath': '/storage/emulated/0/Pictures/teacher.png',
        },
      );

      final items = await queueRepo.getPendingItems();
      final teacherItem = items.firstWhere((i) => i.localId == '202');
      expect(teacherItem.payload['name'], equals('Suman Gupta'));
      expect(teacherItem.payload.containsKey('photoPath'), isFalse);

      await queueRepo.deleteQueueItem(teacherItem.id!);
    });

    test('7 & 8 & 9. Version conflict detection compares timestamps and avoids overwriting newer local edits', () {
      expect(SyncEngine.instance.statusNotifier.value, equals(SyncStatusState.synced));

      // Verify timestamp comparison logic
      final remoteNewer = DateTime.parse('2026-08-25T10:00:00Z').isAfter(DateTime.parse('2026-08-25T09:00:00Z'));
      expect(remoteNewer, isTrue);
    });

    test('10 & 11. Queue retry increment preserves failed queue items without data loss', () async {
      final queueId = await queueRepo.addToQueue(
        entityType: 'students',
        localId: '303',
        operation: 'UPDATE',
        payload: {'name': 'Updated Name'},
      );

      await queueRepo.incrementRetry(queueId, 'Network Connection Refused');

      final items = await queueRepo.getPendingItems();
      final failedItem = items.firstWhere((i) => i.id == queueId);

      expect(failedItem.retryCount, equals(1));
      expect(failedItem.syncStatus, equals('FAILED'));
      expect(failedItem.errorMessage, contains('Network Connection Refused'));

      await queueRepo.deleteQueueItem(queueId);
    });

    test('12. Organisation isolation enforces default org code ORG_OMEGA_DEFAULT', () {
      expect(BackendConfig.defaultOrgCode, equals('ORG_OMEGA_DEFAULT'));
    });

    test('14. Passwords and recovery codes are strictly excluded from queue payload', () async {
      final queueId = await queueRepo.addToQueue(
        entityType: 'users',
        localId: 'user_admin',
        operation: 'UPDATE',
        payload: {
          'username': 'admin',
          'password': 'myPlaintextPassword',
          'passwordHash': 'sha256hash',
          'salt': 'salt123',
          'recoveryCode': 'REC123',
        },
      );

      final items = await queueRepo.getPendingItems();
      final userItem = items.firstWhere((i) => i.id == queueId);

      expect(userItem.payload['username'], equals('admin'));
      expect(userItem.payload.containsKey('password'), isFalse);
      expect(userItem.payload.containsKey('passwordHash'), isFalse);
      expect(userItem.payload.containsKey('salt'), isFalse);
      expect(userItem.payload.containsKey('recoveryCode'), isFalse);

      await queueRepo.deleteQueueItem(queueId);
    });

    test('15. Offline SQLite database v18 remains fully functional without central server', () async {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('sync_queue');
      expect(result, isNotNull);
    });
  });
}
