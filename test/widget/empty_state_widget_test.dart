import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omega_education_centre/shared/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('displays title and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              title: 'No items found',
              icon: Icons.inbox,
            ),
          ),
        ),
      );

      expect(find.text('No items found'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('displays action button when provided', (WidgetTester tester) async {
      bool buttonTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              title: 'No students',
              icon: Icons.people_outline,
              actionLabel: 'Add Student',
              onAction: () => buttonTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Add Student'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.tap(find.text('Add Student'));
      expect(buttonTapped, isTrue);
    });

    testWidgets('does not show button when actionLabel is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              title: 'Nothing here',
              icon: Icons.inbox,
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('displays subtitle when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              title: 'No results',
              icon: Icons.search,
              subtitle: 'Try adjusting your filters',
            ),
          ),
        ),
      );

      expect(find.text('No results'), findsOneWidget);
      expect(find.text('Try adjusting your filters'), findsOneWidget);
    });
  });
}
