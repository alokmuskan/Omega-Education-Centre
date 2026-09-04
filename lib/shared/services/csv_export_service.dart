import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/students/repository/student_repository.dart';
import '../../features/teachers/repository/teacher_repository.dart';

/// Service for exporting Students and Teachers to CSV files.
class CsvExportService {
  CsvExportService._();

  static final CsvExportService instance = CsvExportService._();

  final StudentRepository _studentRepo = StudentRepository();
  final TeacherRepository _teacherRepo = TeacherRepository();

  /// Exports all active students to a CSV file and shares it.
  Future<String> exportStudents() async {
    final students = await _studentRepo.getStudents();

    final sb = StringBuffer();
    sb.writeln('Name,Father Name,Mother Name,Mobile,Board,Class,Roll No,Fee Status');

    for (final s in students) {
      final feeStatus = s.feeStatus;
      sb.writeln('${_escape(s.name)},${_escape(s.fatherName)},${_escape(s.motherName ?? '')},${_escape(s.mobile)},${_escape(s.board)},${_escape(s.studentClass)},${s.rollNo},${_escape(feeStatus)}');
    }

    return _saveAndShare(sb.toString(), 'students_export');
  }

  /// Exports all active teachers to a CSV file and shares it.
  Future<String> exportTeachers() async {
    final teachers = await _teacherRepo.getTeachers();

    final sb = StringBuffer();
    sb.writeln('Name,Mobile,Subject,Pay Per Hour,Qualification,Joining Date,Active');

    for (final t in teachers) {
      sb.writeln('${_escape(t.name)},${_escape(t.mobile)},${_escape(t.subject)},${t.payPerHour},${_escape(t.qualification ?? '')},${_escape(t.joiningDate)},${t.isActive ? 'Yes' : 'No'}');
    }

    return _saveAndShare(sb.toString(), 'teachers_export');
  }

  /// Generates a blank CSV template for student import.
  Future<String> generateStudentTemplate() async {
    final sb = StringBuffer();
    sb.writeln('Name,Father Name,Mother Name,Mobile,Board,Class,Roll No');
    sb.writeln('Rahul Kumar,Ramesh Kumar,Sunita Devi,9876543210,CBSE,10,101');

    return _saveAndShare(sb.toString(), 'student_import_template');
  }

  /// Generates a blank CSV template for teacher import.
  Future<String> generateTeacherTemplate() async {
    final sb = StringBuffer();
    sb.writeln('Name,Mobile,Subject,Pay Per Hour,Qualification,Joining Date');
    sb.writeln('Priya Sharma,9876543211,Mathematics,500,M.Sc Mathematics,2026-01-15');

    return _saveAndShare(sb.toString(), 'teacher_import_template');
  }

  String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<String> _saveAndShare(String csv, String prefix) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/${prefix}_$timestamp.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '$prefix CSV Export',
    );

    return file.path;
  }
}
