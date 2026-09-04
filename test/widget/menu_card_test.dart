import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/features/dashboard/widgets/menu_card.dart';

void main() {
  group('MenuCard', () {
    testWidgets('displays title and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuCard(
              title: 'Students',
              icon: Icons.school,
              color: Colors.blue,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Students'), findsOneWidget);
      expect(find.byIcon(Icons.school), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuCard(
              title: 'Fees',
              icon: Icons.currency_rupee,
              color: Colors.green,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(MenuCard));
      expect(tapped, isTrue);
    });

    testWidgets('renders with custom color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuCard(
              title: 'Settings',
              icon: Icons.settings,
              color: Colors.purple,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('displays long title with maxLines', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuCard(
              title: 'Academic Calendar',
              icon: Icons.calendar_month,
              color: Colors.brown,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Academic Calendar'), findsOneWidget);
    });
  });
}
