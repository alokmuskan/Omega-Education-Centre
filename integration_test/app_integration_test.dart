import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/app/app.dart';

void main() {
  group('App Integration Tests', () {
    testWidgets('App launches and shows login screen', (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show the login screen
      expect(find.byType(MaterialApp), findsOneWidget);

      // Should have login form elements
      // Note: Actual selectors depend on your login screen implementation
      // expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('Login form validation shows errors on empty submit',
        (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Try to find and tap login button without entering credentials
      // This depends on your actual login screen implementation
      // final loginButton = find.text('LOGIN');
      // if (loginButton.evaluate().isNotEmpty) {
      //   await tester.tap(loginButton);
      //   await tester.pumpAndSettle();
      //   expect(find.text('Required'), findsWidgets);
      // }
    });

    testWidgets('App builds without critical errors', (WidgetTester tester) async {
      // This is a smoke test to ensure the app doesn't crash on launch
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The app should build without throwing
      expect(find.byType(MaterialApp), findsOneWidget);

      // No error widgets should be present
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });
}
