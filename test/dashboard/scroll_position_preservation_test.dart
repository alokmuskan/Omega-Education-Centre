import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/students/models/student_model.dart';
import 'package:omega_education_centre/features/students/widgets/student_card.dart';

void main() {
  group('Scroll Position Preservation Unit Tests', () {
    testWidgets('ListView with PageStorageKey retains scroll position across pop', (WidgetTester tester) async {
      final List<StudentModel> mockStudents = List.generate(
        50,
        (i) => StudentModel(
          id: i + 1,
          name: 'Student ${i + 1}',
          fatherName: 'Father ${i + 1}',
          mobile: '98000000${i < 10 ? '0' : ''}$i',
          board: 'CBSE',
          studentClass: '10',
          rollNo: 100 + i,
          createdAt: '2026-08-24T00:00:00Z',
        ),
      );

      final Key scrollKey = const PageStorageKey<String>('test_scroll_key');

      Widget buildTestList() {
        return MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Scroll Test List')),
            body: ListView.builder(
              key: scrollKey,
              itemCount: mockStudents.length,
              itemBuilder: (context, index) {
                final student = mockStudents[index];
                return StudentCard(
                  student: student,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(student.name)),
                          body: Center(child: Text('Details for ${student.name}')),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTestList());
      await tester.pumpAndSettle();

      // Verify list starts at top (Student 1 visible)
      expect(find.text('Student 1'), findsOneWidget);
      expect(find.text('Student 35'), findsNothing);

      // Scroll down by 400 pixels
      final scrollable = find.byType(Scrollable);
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pumpAndSettle();

      // Verify list has scrolled down (Student 1 no longer visible, Student 5 visible)
      expect(find.text('Student 1'), findsNothing);
      final Finder targetStudent = find.text('Student 5');
      expect(targetStudent, findsOneWidget);

      // Tap student to navigate to Details
      await tester.tap(targetStudent);
      await tester.pumpAndSettle();

      // Verify Details screen is open
      expect(find.text('Details for Student 5'), findsOneWidget);

      // Press Back button to return to previous list
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Verify scroll position is PRESERVED (Student 5 is still visible, NOT back at Student 1)
      expect(find.text('Student 5'), findsOneWidget);
      expect(find.text('Student 1'), findsNothing);
    });
  });
}
