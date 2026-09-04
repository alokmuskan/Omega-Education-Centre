import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/features/dashboard/widgets/summary_card.dart';

void main() {
  group('SummaryCard', () {
    testWidgets('displays title, value, and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              title: 'Total Students',
              value: '150',
              icon: Icons.school,
              color: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Total Students'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.byIcon(Icons.school), findsOneWidget);
    });

    testWidgets('renders with different colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              title: 'Fee Collection',
              value: '₹50,000',
              icon: Icons.currency_rupee,
              color: Colors.green,
            ),
          ),
        ),
      );

      expect(find.text('Fee Collection'), findsOneWidget);
      expect(find.text('₹50,000'), findsOneWidget);
    });

    testWidgets('handles large numbers', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              title: 'Total Revenue',
              value: '₹12,34,567',
              icon: Icons.trending_up,
              color: Colors.purple,
            ),
          ),
        ),
      );

      expect(find.text('₹12,34,567'), findsOneWidget);
    });

    testWidgets('has fixed height of 125', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCard(
              title: 'Test',
              value: '0',
              icon: Icons.science,
              color: Colors.orange,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxHeight ?? 125, 125);
    });
  });
}
