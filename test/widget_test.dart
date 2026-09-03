// This is a basic Flutter widget test for Omega Education Centre ERP.
// Tests the App widget launches without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/app/app.dart';

void main() {
  testWidgets('App smoke test — widget tree builds without error',
      (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const App());

    // The app should build without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
