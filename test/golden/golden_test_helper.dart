import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper for golden tests
///
/// Provides common utilities for visual regression testing.
class GoldenTestHelper {
  GoldenTestHelper._();

  /// Standard test size for golden tests
  static const Size testSize = Size(390, 844); // iPhone 14 size

  /// Create a MaterialApp wrapper for golden tests
  static Widget wrapInApp(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(body: child),
    );
  }

  /// Create a MaterialApp with dark theme for golden tests
  static Widget wrapInDarkApp(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: child),
    );
  }

  /// Pump and settle for golden tests
  static Future<void> pumpAndSettle(
    WidgetTester tester,
    Widget widget, {
    Size? size,
  }) async {
    tester.view.physicalSize = size ?? testSize;
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}
