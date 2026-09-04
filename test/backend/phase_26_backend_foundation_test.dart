import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/shared/config/backend_config.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omega_education_centre/shared/utils/encryption_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  EncryptionKeyManager.testMode = true;

  group('Phase 26 — Multi-Device Backend Foundation Unit Tests', () {
    test('1. Verify Supabase DDL SQL script exists and contains core tables', () {
      final schemaFile = File('supabase/migrations/000_clean_reset.sql');
      expect(schemaFile.existsSync(), isTrue);

      final content = schemaFile.readAsStringSync();
      expect(content, contains('CREATE TABLE organisations'));
      expect(content, contains('CREATE TABLE users'));
      expect(content, contains('CREATE TABLE teachers'));
      expect(content, contains('CREATE TABLE students'));
      expect(content, contains('CREATE TABLE fees'));
      expect(content, contains('CREATE TABLE fee_payments'));
      expect(content, contains('CREATE TABLE student_attendance'));
      expect(content, contains('CREATE TABLE teacher_attendance'));
      expect(content, contains('CREATE TABLE teacher_payments'));
      expect(content, contains('CREATE TABLE tests'));
      expect(content, contains('CREATE TABLE test_results'));
    });

    test('2. Verify Row Level Security (RLS) is defined in schema migration', () {
      final schemaFile = File('supabase/migrations/000_clean_reset.sql');
      expect(schemaFile.existsSync(), isTrue);

      final content = schemaFile.readAsStringSync();
      expect(content, contains('ENABLE ROW LEVEL SECURITY'));
      expect(content, contains('CREATE POLICY'));
    });

    test('3. Verify Supabase setup documentation exists', () {
      final docFile = File('docs/supabase_setup_guide.md');
      expect(docFile.existsSync(), isTrue);

      final content = docFile.readAsStringSync();
      expect(content, contains('Supabase Setup'));
      expect(content, contains('Emergency Recovery'));
    });

    test('4. BackendConfig defaults to offline-first without throwing errors', () {
      expect(BackendConfig.isBackendConfigured, isFalse);
      expect(BackendConfig.defaultOrgCode, equals('ORG_OMEGA_DEFAULT'));

      BackendConfig.initialize(url: 'https://test.supabase.co', anonKey: 'testAnonKey');
      expect(BackendConfig.isBackendConfigured, isTrue);
      expect(BackendConfig.supabaseUrl, equals('https://test.supabase.co'));

      // Reset for cleanliness
      BackendConfig.initialize(url: '', anonKey: '');
    });

    test('5. Existing SQLite database v17 and 18 tables remain 100% intact & working', () async {
      AppSession.instance.clearSession();
      final db = await DatabaseHelper.instance.database;
      expect(db.isOpen, isTrue);

      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toList();

      expect(tableNames, contains('students'));
      expect(tableNames, contains('teachers'));
      expect(tableNames, contains('users'));
      expect(tableNames, contains('fees'));
      expect(tableNames, contains('student_attendance'));
      expect(tableNames, contains('teacher_attendance'));
      expect(tableNames, contains('tests'));
      expect(tableNames, contains('notices'));
      expect(tableNames, contains('daily_class_records'));
    });
  });
}
