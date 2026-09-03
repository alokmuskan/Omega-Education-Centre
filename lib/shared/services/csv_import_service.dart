import 'dart:io';

import '../../features/students/models/student_model.dart';
import '../../features/students/repository/student_repository.dart';
import '../../features/teachers/models/teacher_model.dart';
import '../../features/teachers/repository/teacher_repository.dart';

/// Result of a CSV import operation.
class CsvImportResult {
  final int totalRows;
  final int successCount;
  final int skipCount;
  final int errorCount;
  final List<CsvImportError> errors;
  final List<String> skippedReasons;

  const CsvImportResult({
    required this.totalRows,
    required this.successCount,
    required this.skipCount,
    required this.errorCount,
    required this.errors,
    required this.skippedReasons,
  });

  bool get hasErrors => errorCount > 0;
  bool get allSuccess => errorCount == 0 && skipCount == 0;
}

/// A single row-level error from CSV import.
class CsvImportError {
  final int rowNumber;
  final String field;
  final String message;

  const CsvImportError({
    required this.rowNumber,
    required this.field,
    required this.message,
  });
}

/// Service for bulk importing Students and Teachers from CSV files.
///
/// Expected CSV headers:
///   Students: name, fatherName, motherName, mobile, board, studentClass, rollNo
///   Teachers: name, mobile, subject, payPerHour, qualification, joiningDate
class CsvImportService {
  CsvImportService._();

  static final CsvImportService instance = CsvImportService._();

  final StudentRepository _studentRepo = StudentRepository();
  final TeacherRepository _teacherRepo = TeacherRepository();

  // ── Student CSV Import ──────────────────────────────────────────

  /// Imports students from a CSV file.
  Future<CsvImportResult> importStudents(
    String csvPath, {
    void Function(int current, int total)? onProgress,
  }) async {
    final file = File(csvPath);
    if (!await file.exists()) {
      return const CsvImportResult(
        totalRows: 0,
        successCount: 0,
        skipCount: 0,
        errorCount: 1,
        errors: [CsvImportError(rowNumber: 0, field: 'file', message: 'CSV file not found')],
        skippedReasons: [],
      );
    }

    final content = await file.readAsString();
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.length < 2) {
      return const CsvImportResult(
        totalRows: 0,
        successCount: 0,
        skipCount: 0,
        errorCount: 0,
        errors: [],
        skippedReasons: [],
      );
    }

    // First row is header
    final header = lines.first.split(',').map((e) => e.trim().toLowerCase()).toList();
    final dataLines = lines.skip(1).toList();

    // Validate required headers
    final requiredHeaders = ['name', 'fathername', 'mobile'];
    for (final h in requiredHeaders) {
      if (!header.contains(h)) {
        return CsvImportResult(
          totalRows: dataLines.length,
          successCount: 0,
          skipCount: 0,
          errorCount: 1,
          errors: [CsvImportError(rowNumber: 0, field: 'header', message: 'Missing required column: $h')],
          skippedReasons: [],
        );
      }
    }

    // Get existing students for dedup
    final existingStudents = await _studentRepo.getStudents();
    final existingMobiles = existingStudents.map((s) => s.mobile.trim().toLowerCase()).toSet();
    final existingRollNos = existingStudents.map((s) => s.rollNo).toSet();

    final errors = <CsvImportError>[];
    final skippedReasons = <String>[];
    int successCount = 0;
    int skipCount = 0;

    for (int i = 0; i < dataLines.length; i++) {
      final row = _parseCsvLine(dataLines[i]);
      final rowNum = i + 2;

      onProgress?.call(i + 1, dataLines.length);

      try {
        final map = _rowToMap(header, row);

        // Validate
        final validationError = _validateStudentRow(map, rowNum);
        if (validationError != null) {
          errors.add(validationError);
          continue;
        }

        // Dedup check
        final mobile = (map['mobile'] ?? '').toString().trim();
        final rollNoStr = (map['rollno'] ?? map['rollNo'] ?? '').toString().trim();
        final rollNo = int.tryParse(rollNoStr) ?? 0;

        if (existingMobiles.contains(mobile.toLowerCase())) {
          skipCount++;
          skippedReasons.add('Row $rowNum: Mobile $mobile already exists');
          continue;
        }

        if (rollNo > 0 && existingRollNos.contains(rollNo)) {
          skipCount++;
          skippedReasons.add('Row $rowNum: Roll number $rollNo already exists');
          continue;
        }

        // Create student
        final student = StudentModel(
          name: (map['name'] ?? '').toString().trim(),
          fatherName: (map['fathername'] ?? map['fatherName'] ?? '').toString().trim(),
          motherName: (map['mothername'] ?? map['motherName'] ?? '')?.toString().trim(),
          mobile: mobile,
          board: (map['board'] ?? 'CBSE').toString().trim(),
          studentClass: (map['studentclass'] ?? map['studentClass'] ?? '10').toString().trim(),
          rollNo: rollNo,
          createdAt: DateTime.now().toIso8601String(),
        );

        await _studentRepo.insertStudent(student);
        existingMobiles.add(mobile.toLowerCase());
        if (rollNo > 0) existingRollNos.add(rollNo);
        successCount++;
      } catch (e) {
        errors.add(CsvImportError(rowNumber: rowNum, field: 'general', message: e.toString()));
      }
    }

    return CsvImportResult(
      totalRows: dataLines.length,
      successCount: successCount,
      skipCount: skipCount,
      errorCount: errors.length,
      errors: errors,
      skippedReasons: skippedReasons,
    );
  }

  // ── Teacher CSV Import ──────────────────────────────────────────

  /// Imports teachers from a CSV file.
  Future<CsvImportResult> importTeachers(
    String csvPath, {
    void Function(int current, int total)? onProgress,
  }) async {
    final file = File(csvPath);
    if (!await file.exists()) {
      return const CsvImportResult(
        totalRows: 0,
        successCount: 0,
        skipCount: 0,
        errorCount: 1,
        errors: [CsvImportError(rowNumber: 0, field: 'file', message: 'CSV file not found')],
        skippedReasons: [],
      );
    }

    final content = await file.readAsString();
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.length < 2) {
      return const CsvImportResult(
        totalRows: 0,
        successCount: 0,
        skipCount: 0,
        errorCount: 0,
        errors: [],
        skippedReasons: [],
      );
    }

    final header = lines.first.split(',').map((e) => e.trim().toLowerCase()).toList();
    final dataLines = lines.skip(1).toList();

    final requiredHeaders = ['name', 'mobile'];
    for (final h in requiredHeaders) {
      if (!header.contains(h)) {
        return CsvImportResult(
          totalRows: dataLines.length,
          successCount: 0,
          skipCount: 0,
          errorCount: 1,
          errors: [CsvImportError(rowNumber: 0, field: 'header', message: 'Missing required column: $h')],
          skippedReasons: [],
        );
      }
    }

    final existingTeachers = await _teacherRepo.getTeachers();
    final existingMobiles = existingTeachers.map((t) => t.mobile.trim().toLowerCase()).toSet();

    final errors = <CsvImportError>[];
    final skippedReasons = <String>[];
    int successCount = 0;
    int skipCount = 0;

    for (int i = 0; i < dataLines.length; i++) {
      final row = _parseCsvLine(dataLines[i]);
      final rowNum = i + 2;

      onProgress?.call(i + 1, dataLines.length);

      try {
        final map = _rowToMap(header, row);

        final name = (map['name'] ?? '').toString().trim();
        final mobile = (map['mobile'] ?? '').toString().trim();

        if (name.isEmpty) {
          errors.add(CsvImportError(rowNumber: rowNum, field: 'name', message: 'Name is required'));
          continue;
        }
        if (mobile.isEmpty) {
          errors.add(CsvImportError(rowNumber: rowNum, field: 'mobile', message: 'Mobile is required'));
          continue;
        }

        if (existingMobiles.contains(mobile.toLowerCase())) {
          skipCount++;
          skippedReasons.add('Row $rowNum: Mobile $mobile already exists');
          continue;
        }

        final payRate = double.tryParse((map['payperhour'] ?? map['payPerHour'] ?? '300').toString()) ?? 300.0;
        final subject = (map['subject'] ?? 'General').toString().trim();
        final qualification = (map['qualification'] ?? '')?.toString().trim();
        final joiningDate = (map['joiningdate'] ?? map['joiningDate'] ?? DateTime.now().toIso8601String()).toString().trim();

        final teacher = TeacherModel(
          name: name,
          mobile: mobile,
          subject: subject,
          payPerHour: payRate,
          qualification: qualification,
          joiningDate: joiningDate,
          createdAt: DateTime.now().toIso8601String(),
        );

        await _teacherRepo.insertTeacher(teacher);
        existingMobiles.add(mobile.toLowerCase());
        successCount++;
      } catch (e) {
        errors.add(CsvImportError(rowNumber: rowNum, field: 'general', message: e.toString()));
      }
    }

    return CsvImportResult(
      totalRows: dataLines.length,
      successCount: successCount,
      skipCount: skipCount,
      errorCount: errors.length,
      errors: errors,
      skippedReasons: skippedReasons,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  /// Simple CSV line parser that handles quoted fields.
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++; // skip escaped quote
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          fields.add(buffer.toString().trim());
          buffer.clear();
        } else {
          buffer.write(c);
        }
      }
    }
    fields.add(buffer.toString().trim());
    return fields;
  }

  Map<String, dynamic> _rowToMap(List<String> header, List<dynamic> row) {
    final map = <String, dynamic>{};
    for (int i = 0; i < header.length && i < row.length; i++) {
      map[header[i]] = row[i];
    }
    return map;
  }

  CsvImportError? _validateStudentRow(Map<String, dynamic> map, int rowNum) {
    final name = (map['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      return CsvImportError(rowNumber: rowNum, field: 'name', message: 'Name is required');
    }

    final fatherName = (map['fathername'] ?? map['fatherName'] ?? '').toString().trim();
    if (fatherName.isEmpty) {
      return CsvImportError(rowNumber: rowNum, field: 'fatherName', message: 'Father name is required');
    }

    final mobile = (map['mobile'] ?? '').toString().trim();
    if (mobile.isEmpty) {
      return CsvImportError(rowNumber: rowNum, field: 'mobile', message: 'Mobile is required');
    }

    if (mobile.length < 10) {
      return CsvImportError(rowNumber: rowNum, field: 'mobile', message: 'Mobile must be at least 10 digits');
    }

    return null;
  }
}
