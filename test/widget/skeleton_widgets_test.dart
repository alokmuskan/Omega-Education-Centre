import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:omega_education_centre/shared/widgets/skeleton_widgets.dart';

void main() {
  group('SkeletonWidgets', () {
    testWidgets('pageSkeleton renders with cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkeletonWidgets.pageSkeleton(cardCount: 3),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('pageSkeleton renders without header when hasHeader is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkeletonWidgets.pageSkeleton(
              cardCount: 2,
              hasHeader: false,
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('gridSkeleton renders with items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkeletonWidgets.gridSkeleton(itemCount: 4),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('listTileSkeleton renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkeletonWidgets.listTileSkeleton(),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('cardSkeleton renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkeletonWidgets.cardSkeleton(),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });
  });
}
