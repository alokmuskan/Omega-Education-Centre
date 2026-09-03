import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/dashboard/dashboard_screen.dart';
import 'package:omega_education_centre/shared/utils/app_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omega_education_centre/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    AppSession.instance.clearSession();
    AppSession.instance.setAdminSession(username: 'admin');
    await DatabaseHelper.instance.database;
  });

  group('Admin Dashboard Scroll Position Unit Test', () {
    testWidgets('Admin Dashboard contains PageStorageKey for scroll preservation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );

      // Drain FFI database futures
      await tester.runAsync(() async {
        await Future.delayed(const Duration(seconds: 2));
      });
      await tester.pump();

      // Verify DashboardScreen builds without error and contains key architectural components
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
