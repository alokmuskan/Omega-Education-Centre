import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';
import 'package:omega_education_centre/features/dashboard/widgets/dashboard_header.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/features/teachers/repository/teacher_repository.dart';
import 'package:omega_education_centre/shared/config/backend_config.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omega_education_centre/shared/utils/encryption_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  EncryptionKeyManager.testMode = true;

  late TeacherRepository repository;

  setUp(() async {
    BackendConfig.initialize(url: '', anonKey: '');
    AppSession.instance.clearSession();
    AppSession.instance.setAdminSession(username: 'admin');
    final db = await DatabaseHelper.instance.database;
    await db.delete('teachers');
    repository = TeacherRepository();
  });

  group('Teacher Multiple Subjects & Migration Tests', () {
    test('1-4. Create teacher with single subject, reload, and verify model deserialization', () async {
      final now = DateTime.now().toIso8601String();
      final teacher = TeacherModel(
        name: 'Single Subject Teacher',
        mobile: '9876543210',
        subjects: const ['Mathematics'],
        payPerHour: 400.0,
        joiningDate: '2026-01-01',
        createdAt: now,
      );

      final id = await repository.insertTeacher(teacher);
      expect(id, isNotNull);

      final reloaded = await repository.getTeacherById(id);
      expect(reloaded, isNotNull);
      expect(reloaded!.subjects, equals(['Mathematics']));
      expect(reloaded.subject, equals('Mathematics'));
    });

    test('5-8. Create/Edit teacher with multiple subjects (Math, Physics, Chemistry)', () async {
      final now = DateTime.now().toIso8601String();
      final teacher = TeacherModel(
        name: 'Rahul Kumar',
        mobile: '9876543211',
        subjects: const ['Mathematics', 'Physics', 'Chemistry'],
        payPerHour: 500.0,
        joiningDate: '2026-01-01',
        createdAt: now,
      );

      final id = await repository.insertTeacher(teacher);
      final reloaded = await repository.getTeacherById(id);

      expect(reloaded, isNotNull);
      expect(reloaded!.subjects.length, equals(3));
      expect(reloaded.subjects, containsAll(['Mathematics', 'Physics', 'Chemistry']));
      expect(reloaded.subject, equals('Mathematics • Physics • Chemistry'));
    });

    test('9-11. Edit existing single-subject teacher and add another subject', () async {
      final now = DateTime.now().toIso8601String();
      final teacher = TeacherModel(
        name: 'Amit Singh',
        mobile: '9876543212',
        subjects: const ['English'],
        payPerHour: 350.0,
        joiningDate: '2026-01-01',
        createdAt: now,
      );

      final id = await repository.insertTeacher(teacher);
      final initial = await repository.getTeacherById(id);
      expect(initial!.subjects, equals(['English']));

      final updatedTeacher = initial.copyWith(
        subjects: ['English', 'Computer Science'],
        updatedAt: now,
      );
      await repository.updateTeacher(updatedTeacher);

      final reloaded = await repository.getTeacherById(id);
      expect(reloaded!.subjects.length, equals(2));
      expect(reloaded.subjects, containsAll(['English', 'Computer Science']));
      expect(reloaded.subject, equals('English • Computer Science'));
    });

    test('12-13. Remove one subject from a multi-subject teacher', () async {
      final now = DateTime.now().toIso8601String();
      final teacher = TeacherModel(
        name: 'Priya Sharma',
        mobile: '9876543213',
        subjects: const ['Biology', 'Chemistry', 'Science'],
        payPerHour: 450.0,
        joiningDate: '2026-01-01',
        createdAt: now,
      );

      final id = await repository.insertTeacher(teacher);
      final initial = await repository.getTeacherById(id);
      expect(initial!.subjects.length, equals(3));

      // Remove 'Science'
      final updatedSubjects = List<String>.from(initial.subjects)..remove('Science');
      final updatedTeacher = initial.copyWith(
        subjects: updatedSubjects,
        updatedAt: now,
      );
      await repository.updateTeacher(updatedTeacher);

      final reloaded = await repository.getTeacherById(id);
      expect(reloaded!.subjects.length, equals(2));
      expect(reloaded.subjects, equals(['Biology', 'Chemistry']));
      expect(reloaded.subject, equals('Biology • Chemistry'));
    });

    test('Data Migration — Legacy single subject string parses seamlessly into List<String>', () {
      final legacyMap = {
        'id': 99,
        'name': 'Legacy Teacher',
        'mobile': '9876543214',
        'subject': 'Mathematics',
        'payPerHour': 300.0,
        'joiningDate': '2025-05-10',
        'isActive': 1,
        'createdAt': '2025-05-10T00:00:00.000',
      };

      final legacyModel = TeacherModel.fromMap(legacyMap);
      expect(legacyModel.subjects, equals(['Mathematics']));
      expect(legacyModel.subject, equals('Mathematics'));
    });
  });

  group('Logout Confirmation Dialog Tests', () {
    testWidgets('Tapping Logout shows Logout Confirmation dialog and Cancel keeps user logged in', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardHeader(),
          ),
        ),
      );

      // Verify header loaded
      expect(find.byType(DashboardHeader), findsOneWidget);

      // Tap Logout button icon
      final logoutButton = find.byIcon(Icons.logout);
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Verify Logout Confirmation Dialog is displayed
      expect(find.text('Logout Confirmation'), findsOneWidget);
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('LOGOUT'), findsOneWidget);

      // Tap CANCEL button
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      // Verify dialog closed and Admin remains logged in
      expect(find.text('Logout Confirmation'), findsNothing);
      expect(AppSession.instance.isAdmin, isTrue);
    });
  });
}
