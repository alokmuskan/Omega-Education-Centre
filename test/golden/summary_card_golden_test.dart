import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/features/dashboard/widgets/summary_card.dart';
import 'golden_test_helper.dart';

void main() {
  group('SummaryCard Golden Tests', () {
    testWidgets('SummaryCard - light theme', (WidgetTester tester) async {
      await GoldenTestHelper.pumpAndSettle(
        tester,
        GoldenTestHelper.wrapInApp(
          const SummaryCard(
            title: 'Total Students',
            value: '150',
            icon: Icons.school,
            color: Colors.blue,
          ),
        ),
      );

      await expectLater(
        find.byType(SummaryCard),
        matchesGoldenFile('goldens/summary_card_light.png'),
      );
    });

    testWidgets('SummaryCard - dark theme', (WidgetTester tester) async {
      await GoldenTestHelper.pumpAndSettle(
        tester,
        GoldenTestHelper.wrapInDarkApp(
          const SummaryCard(
            title: 'Total Students',
            value: '150',
            icon: Icons.school,
            color: Colors.blue,
          ),
        ),
      );

      await expectLater(
        find.byType(SummaryCard),
        matchesGoldenFile('goldens/summary_card_dark.png'),
      );
    });

    testWidgets('SummaryCard - with currency value', (WidgetTester tester) async {
      await GoldenTestHelper.pumpAndSettle(
        tester,
        GoldenTestHelper.wrapInApp(
          const SummaryCard(
            title: 'Fee Collection',
            value: '₹50,000',
            icon: Icons.currency_rupee,
            color: Colors.green,
          ),
        ),
      );

      await expectLater(
        find.byType(SummaryCard),
        matchesGoldenFile('goldens/summary_card_currency.png'),
      );
    });
  });
}
