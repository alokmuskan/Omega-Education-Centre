import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/features/dashboard/widgets/menu_card.dart';
import 'golden_test_helper.dart';

void main() {
  group('MenuCard Golden Tests', () {
    testWidgets('MenuCard - light theme', (WidgetTester tester) async {
      await GoldenTestHelper.pumpAndSettle(
        tester,
        GoldenTestHelper.wrapInApp(
          MenuCard(
            title: 'Students',
            icon: Icons.school,
            color: Colors.blue,
            onTap: () {},
          ),
        ),
      );

      await expectLater(
        find.byType(MenuCard),
        matchesGoldenFile('goldens/menu_card_light.png'),
      );
    });

    testWidgets('MenuCard - dark theme', (WidgetTester tester) async {
      await GoldenTestHelper.pumpAndSettle(
        tester,
        GoldenTestHelper.wrapInDarkApp(
          MenuCard(
            title: 'Students',
            icon: Icons.school,
            color: Colors.blue,
            onTap: () {},
          ),
        ),
      );

      await expectLater(
        find.byType(MenuCard),
        matchesGoldenFile('goldens/menu_card_dark.png'),
      );
    });

    testWidgets('MenuCard - long title', (WidgetTester tester) async {
      await GoldenTestHelper.pumpAndSettle(
        tester,
        GoldenTestHelper.wrapInApp(
          MenuCard(
            title: 'Academic Calendar',
            icon: Icons.calendar_month,
            color: Colors.brown,
            onTap: () {},
          ),
        ),
      );

      await expectLater(
        find.byType(MenuCard),
        matchesGoldenFile('goldens/menu_card_long_title.png'),
      );
    });
  });
}
