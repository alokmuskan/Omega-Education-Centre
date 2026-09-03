import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/shared/config/backend_config.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 26 — Multi-Device Backend Foundation Unit Tests', () {
    test('1. Verify Supabase DDL SQL script exists and contains core tables', () {
      final schemaFile = File('supabase/schema.sql');
      expect(schemaFile.existsSync(), isTrue);

      final content = schemaFile.readAsStringSync();
      expect(content, contains('CREATE TABLE IF NOT EXISTS organisations'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS users'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS admins'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS teachers'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS students'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS fees'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS fee_payments'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS student_attendance'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS teacher_attendance'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS teacher_payments'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS tests'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS test_results'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS devices'));
    });

    test('2. Verify Row Level Security (RLS) script exists and defines isolation policies', () {
      final rlsFile = File('supabase/rls_policies.sql');
      expect(rlsFile.existsSync(), isTrue);

      final content = rlsFile.readAsStringSync();
      expect(content, contains('organisations ENABLE ROW LEVEL SECURITY'));
      expect(content, contains('CREATE POLICY admin_all_organisations'));
      expect(content, contains('CREATE POLICY teacher_read_own_profile'));
      expect(content, contains('CREATE POLICY student_read_own_profile'));
      expect(content, contains('CREATE POLICY user_read_own_devices'));
    });

    test('3. Verify Supabase setup README documentation exists and highlights security rules', () {
      final readmeFile = File('supabase/README.md');
      expect(readmeFile.existsSync(), isTrue);

      final content = readmeFile.readAsStringSync();
      expect(content, contains('CRITICAL SECURITY RULES'));
      expect(content, contains('NEVER commit private keys'));
      expect(content, contains('Profile Photos'));
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
