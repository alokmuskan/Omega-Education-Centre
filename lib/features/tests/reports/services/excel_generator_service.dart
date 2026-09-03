import 'package:excel/excel.dart';

import '../../../attendance/models/attendance_summary_model.dart';
import '../../models/student_test_summary_model.dart';
import '../models/result_export_data.dart';

/// Service for generating editable Excel (.xlsx) workbooks for Class Results and Individual Report Cards.
class ExcelGeneratorService {
  ExcelGeneratorService._();

  /// Generates editable Excel (.xlsx) bytes for Class-wise Results.
  static List<int>? generateClassResultExcel(ClassResultExportData exportData) {
    final excel = Excel.createExcel();
    final sheetName = 'Class Result';
    excel.rename('Sheet1', sheetName);

    final sheet = excel[sheetName];

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontFamily: getFontFamily(FontFamily.Calibri),
    );

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: getFontFamily(FontFamily.Calibri),
      backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
    );

    final boldStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: getFontFamily(FontFamily.Calibri),
    );

    // 1. Title Block
    sheet.appendRow([TextCellValue('OMEGA EDUCATION CENTRE')]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet.appendRow([TextCellValue('EXAMINATION CLASS RESULT SHEET')]);
    sheet.appendRow([
      TextCellValue(
        'Test: ${exportData.test.title} | Type: ${exportData.test.testType} | Class: ${exportData.test.studentClass} (${exportData.test.board}) | Date: ${exportData.test.testDate} | Year: ${exportData.academicYear}',
      ),
    ]);
    sheet.appendRow([]); // Empty spacer row

    // 2. Table Header
    final headers = <CellValue>[
      TextCellValue('Rank'),
      TextCellValue('Roll No'),
      TextCellValue('Student Name'),
    ];

    for (final subj in exportData.subjects) {
      headers.add(TextCellValue('${subj.subjectName} (${subj.maxMarks.toStringAsFixed(0)})'));
    }

    headers.addAll([
      TextCellValue('Total Obtained'),
      TextCellValue('Max Marks'),
      TextCellValue('Percentage'),
      TextCellValue('Grade'),
      TextCellValue('Result'),
    ]);

    sheet.appendRow(headers);
    final headerRowIdx = 4;
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRowIdx)).cellStyle = headerStyle;
    }

    // 3. Data Rows
    for (final summary in exportData.studentSummaries) {
      final row = <CellValue>[
        summary.rank > 0 ? IntCellValue(summary.rank) : TextCellValue('N/A'),
        TextCellValue(summary.studentRollNo.isNotEmpty ? summary.studentRollNo : '-'),
        TextCellValue(summary.studentName),
      ];

      for (final subj in exportData.subjects) {
        final resList = summary.subjectResults.where((r) => r.testSubjectId == subj.id);
        if (resList.isNotEmpty) {
          final m = resList.first.marksObtained;
          row.add(DoubleCellValue(m));
        } else {
          row.add(TextCellValue('-'));
        }
      }

      row.addAll([
        DoubleCellValue(summary.totalObtained),
        DoubleCellValue(summary.totalMax),
        summary.isComplete ? TextCellValue('${summary.percentage.toStringAsFixed(2)}%') : TextCellValue('N/A'),
        TextCellValue(summary.grade),
        TextCellValue(summary.overallStatus),
      ]);

      sheet.appendRow(row);
    }

    // 4. Statistics Block at Bottom
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('CLASS PERFORMANCE STATISTICS')]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1)).cellStyle = boldStyle;

    sheet.appendRow([TextCellValue('Total Students'), IntCellValue(exportData.totalStudents)]);
    sheet.appendRow([TextCellValue('Completed Results'), IntCellValue(exportData.completedCount)]);
    sheet.appendRow([TextCellValue('Incomplete Results'), IntCellValue(exportData.incompleteCount)]);
    sheet.appendRow([TextCellValue('Passed Students'), IntCellValue(exportData.passCount)]);
    sheet.appendRow([TextCellValue('Failed Students'), IntCellValue(exportData.failCount)]);
    sheet.appendRow([TextCellValue('Class Average %'), TextCellValue('${exportData.classAvgPct}%')]);
    sheet.appendRow([TextCellValue('Highest %'), TextCellValue('${exportData.highestPct}%')]);
    sheet.appendRow([TextCellValue('Lowest %'), TextCellValue('${exportData.lowestPct}%')]);

    return excel.encode();
  }

  /// Generates editable Excel (.xlsx) bytes for an Individual Student Report Card.
  static List<int>? generateStudentReportCardExcel(
    StudentTestSummaryModel summary, {
    StudentAttendanceSummary? attendanceSummary,
    String? attendanceMonthLabel,
  }) {
    final excel = Excel.createExcel();
    final sheetName = 'Report Card';
    excel.rename('Sheet1', sheetName);

    final sheet = excel[sheetName];

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontFamily: getFontFamily(FontFamily.Calibri),
    );

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
    );

    // Profile Block
    sheet.appendRow([TextCellValue('OMEGA EDUCATION CENTRE')]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
    sheet.appendRow([TextCellValue('STUDENT EXAMINATION REPORT CARD')]);
    sheet.appendRow([TextCellValue('Academic Year ${summary.academicYear}')]);
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('Student Name:'), TextCellValue(summary.studentName)]);
    sheet.appendRow([TextCellValue('Roll Number:'), TextCellValue(summary.studentRollNo.isNotEmpty ? summary.studentRollNo : 'N/A')]);
    sheet.appendRow([TextCellValue('Class & Board:'), TextCellValue('${summary.studentClass} (${summary.board})')]);
    sheet.appendRow([TextCellValue('Examination:'), TextCellValue(summary.testTitle)]);
    sheet.appendRow([TextCellValue('Test Type:'), TextCellValue(summary.testType)]);
    sheet.appendRow([TextCellValue('Date:'), TextCellValue(summary.testDate)]);
    sheet.appendRow([]);

    // Table Header
    final headers = [
      TextCellValue('Subject Name'),
      TextCellValue('Marks Obtained'),
      TextCellValue('Max Marks'),
      TextCellValue('Pass Marks'),
      TextCellValue('Percentage'),
      TextCellValue('Status'),
    ];
    sheet.appendRow(headers);
    final headerRowIdx = 10;
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRowIdx)).cellStyle = headerStyle;
    }

    // Subject Rows
    for (final subj in summary.configuredSubjects) {
      final resList = summary.subjectResults.where((r) => r.testSubjectId == subj.id);
      final isRecorded = resList.isNotEmpty;
      final marks = isRecorded ? resList.first.marksObtained : null;
      final isPass = marks != null && marks >= subj.passMarks;

      sheet.appendRow([
        TextCellValue(subj.subjectName),
        marks != null ? DoubleCellValue(marks) : TextCellValue('-'),
        DoubleCellValue(subj.maxMarks),
        DoubleCellValue(subj.passMarks),
        marks != null ? TextCellValue('${((marks / subj.maxMarks) * 100).toStringAsFixed(1)}%') : TextCellValue('-'),
        TextCellValue(!isRecorded ? 'Pending' : isPass ? 'Pass' : 'Fail'),
      ]);
    }

    // Monthly Attendance Report Block
    final monthText = attendanceMonthLabel ?? 'Selected Month';
    final hasAttendance = attendanceSummary != null && attendanceSummary.totalRecordedDays > 0;

    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('MONTHLY ATTENDANCE REPORT (Attendance Month: $monthText)')]);
    if (hasAttendance) {
      sheet.appendRow([
        TextCellValue('Classes Conducted'),
        TextCellValue('Present'),
        TextCellValue('Absent'),
        TextCellValue('Attendance %'),
      ]);
      sheet.appendRow([
        IntCellValue(attendanceSummary.totalRecordedDays),
        IntCellValue(attendanceSummary.presentCount + attendanceSummary.lateCount),
        IntCellValue(attendanceSummary.absentCount),
        TextCellValue('${attendanceSummary.percentage.toStringAsFixed(2)}%'),
      ]);
    } else {
      sheet.appendRow([TextCellValue('No attendance records available')]);
    }

    // Total Summary Block
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('OVERALL PERFORMANCE SUMMARY')]);
    sheet.appendRow([TextCellValue('Total Marks:'), TextCellValue('${summary.totalObtained.toStringAsFixed(0)} / ${summary.totalMax.toStringAsFixed(0)}')]);
    sheet.appendRow([TextCellValue('Percentage:'), summary.isComplete ? TextCellValue('${summary.percentage.toStringAsFixed(2)}%') : TextCellValue('N/A')]);
    sheet.appendRow([TextCellValue('Grade:'), TextCellValue(summary.grade)]);
    sheet.appendRow([TextCellValue('Overall Result:'), TextCellValue(summary.overallStatus)]);
    sheet.appendRow([TextCellValue('Class Rank:'), summary.rank > 0 ? TextCellValue('Rank ${summary.rank}') : TextCellValue('N/A')]);

    return excel.encode();
  }
}
