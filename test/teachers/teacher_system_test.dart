import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/features/teachers/models/teacher_model.dart';
import 'package:omega_education_centre/shared/constants/app_constants.dart';

void main() {
  group('Teacher System Unit Tests', () {
    test('TeacherModel serialization & deserialization', () {
      final teacher = TeacherModel(
        id: 1,
        name: 'Ramesh Sharma',
        mobile: '9876543210',
        subject: 'Mathematics',
        qualification: 'M.Sc. Mathematics',
        payPerHour: 350.0,
        joiningDate: '2026-01-15',
        isActive: true,
        createdAt: '2026-01-15T10:00:00Z',
      );

      final map = teacher.toMap();
      expect(map['id'], equals(1));
      expect(map['name'], equals('Ramesh Sharma'));
      expect(map['mobile'], equals('9876543210'));
      expect(map['subject'], equals('Mathematics'));
      expect(map['payPerHour'], equals(350.0));
      expect(map['isActive'], equals(1));

      final restored = TeacherModel.fromMap(map);
      expect(restored.id, equals(1));
      expect(restored.name, equals('Ramesh Sharma'));
      expect(restored.payPerHour, equals(350.0));
      expect(restored.isActive, isTrue);
      expect(restored.status, equals('Active'));
    });

    test('TeacherModel status helper & copyWith', () {
      final activeTeacher = TeacherModel(
        id: 2,
        name: 'Suresh Kumar',
        mobile: '9123456780',
        subject: 'Physics',
        payPerHour: 400.0,
        joiningDate: '2026-02-01',
        isActive: true,
        createdAt: '2026-02-01T10:00:00Z',
      );

      expect(activeTeacher.status, equals(AppConstants.teacherStatusActive));

      final inactiveTeacher = activeTeacher.copyWith(isActive: false);
      expect(inactiveTeacher.isActive, isFalse);
      expect(inactiveTeacher.status, equals(AppConstants.teacherStatusInactive));
    });

    test('Pay Per Hour validation rule', () {
      double? validatePayPerHour(String input) {
        if (input.trim().isEmpty) return null;
        final val = double.tryParse(input.trim());
        if (val == null || val <= 0) return null;
        return val;
      }

      expect(validatePayPerHour('300'), equals(300.0));
      expect(validatePayPerHour('550.50'), equals(550.50));
      expect(validatePayPerHour('0'), isNull);
      expect(validatePayPerHour('-100'), isNull);
      expect(validatePayPerHour('abc'), isNull);
    });

    test('Teacher search and subject filter in-memory simulation', () {
      final teachers = [
        TeacherModel(
          id: 1,
          name: 'Anil Verma',
          mobile: '9870011223',
          subject: 'Mathematics',
          payPerHour: 300,
          joiningDate: '2026-01-01',
          isActive: true,
          createdAt: '',
        ),
        TeacherModel(
          id: 2,
          name: 'Priya Singh',
          mobile: '9870022334',
          subject: 'Physics',
          payPerHour: 350,
          joiningDate: '2026-01-05',
          isActive: true,
          createdAt: '',
        ),
        TeacherModel(
          id: 3,
          name: 'Rohan Mehta',
          mobile: '9870033445',
          subject: 'Mathematics',
          payPerHour: 300,
          joiningDate: '2026-02-01',
          isActive: false,
          createdAt: '',
        ),
      ];

      // Filter by subject 'Mathematics'
      final mathTeachers = teachers.where((t) => t.subject == 'Mathematics').toList();
      expect(mathTeachers.length, equals(2));

      // Filter by status 'Active'
      final activeTeachers = teachers.where((t) => t.isActive).toList();
      expect(activeTeachers.length, equals(2));

      // Search by query 'Priya'
      final searchResults = teachers.where((t) => t.name.toLowerCase().contains('priya')).toList();
      expect(searchResults.length, equals(1));
      expect(searchResults.first.name, equals('Priya Singh'));
    });
  });
}
