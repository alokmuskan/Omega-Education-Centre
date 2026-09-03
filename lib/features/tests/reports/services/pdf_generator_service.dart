import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../attendance/models/attendance_summary_model.dart';
import '../../models/student_test_summary_model.dart';
import '../models/result_export_data.dart';

/// Service for generating professional, notice-board ready PDF documents for Class Results and Individual Report Cards.
class PdfGeneratorService {
  PdfGeneratorService._();

  /// Loads optional Omega Education Centre logo bytes from rootBundle (fallback to null if in unit tests).
  static Future<Uint8List?> _loadLogoBytes() async {
    try {
      final byteData = await rootBundle.load('assets/logo/logo.png');
      return byteData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Generates A4 Landscape PDF bytes for Class-wise Results (Multi-page, Notice Board layout).
  static Future<Uint8List> generateClassResultPdf(ClassResultExportData data) async {
    final pdf = pw.Document();
    final logoBytes = await _loadLogoBytes();
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final subjectCount = data.subjects.length;
    final fontSize = subjectCount > 6 ? 8.5 : 10.0;
    final headerFontSize = subjectCount > 6 ? 9.0 : 10.5;

    final headers = <String>[
      'Rank',
      'Roll No',
      'Student Name',
    ];

    for (final subj in data.subjects) {
      headers.add('${subj.subjectName}\n(${subj.maxMarks.toStringAsFixed(0)})');
    }

    headers.addAll([
      'Total',
      'Max',
      'Percent',
      'Grade',
      'Result',
    ]);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),

        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Institutional Header Block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Image(logoImage, height: 40),
                  pw.SizedBox(width: 12),
                ],
                pw.Column(
                  children: [
                    pw.Text(
                      'OMEGA EDUCATION CENTRE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'EXAMINATION CLASS RESULT SHEET',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 6),

            // Examination Metadata Card
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.indigo200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TEST: ${data.test.title.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Text('TYPE: ${data.test.testType.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  pw.Text('CLASS: ${data.test.studentClass} (${data.test.board})', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Text('ACADEMIC YEAR: ${data.academicYear}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  pw.Text('DATE: ${data.test.testDate}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                ],
              ),
            ),

            pw.SizedBox(height: 10),
          ],
        ),

        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'OMEGA EDUCATION CENTRE — Official Notice Board Result Record',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                ),
              ],
            ),
          ],
        ),

        build: (context) => [
          // Primary Result Table
          pw.TableHelper.fromTextArray(
            headers: headers,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: headerFontSize,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellAlignment: pw.Alignment.center,
            cellStyle: pw.TextStyle(fontSize: fontSize),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            data: data.studentSummaries.map((summary) {
              final row = <String>[
                summary.rank > 0 ? '#${summary.rank}' : 'N/A',
                summary.studentRollNo.isNotEmpty ? summary.studentRollNo : '-',
                summary.studentName,
              ];

              for (final subj in data.subjects) {
                final resList = summary.subjectResults.where((r) => r.testSubjectId == subj.id);
                if (resList.isNotEmpty) {
                  row.add(resList.first.marksObtained.toStringAsFixed(0));
                } else {
                  row.add('-');
                }
              }

              row.addAll([
                summary.totalObtained.toStringAsFixed(0),
                summary.totalMax.toStringAsFixed(0),
                summary.isComplete ? '${summary.percentage.toStringAsFixed(2)}%' : 'N/A',
                summary.grade,
                summary.overallStatus,
              ]);

              return row;
            }).toList(),
          ),

          pw.SizedBox(height: 14),

          // Class Performance Summary Block
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CLASS PERFORMANCE SUMMARY',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('Total Students: ${data.totalStudents}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Passed: ${data.passCount}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    pw.Text('Failed: ${data.failCount}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Text('Incomplete: ${data.incompleteCount}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                    pw.Text('Class Average: ${data.classAvgPct}%', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.Text('Highest: ${data.highestPct}%', style: const pw.TextStyle(fontSize: 9.5)),
                    pw.Text('Lowest: ${data.lowestPct}%', style: const pw.TextStyle(fontSize: 9.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generates A4 Portrait PDF bytes for an Individual Student Report Card.
  static Future<Uint8List> generateStudentReportCardPdf(
    StudentTestSummaryModel summary, {
    StudentAttendanceSummary? attendanceSummary,
    String? attendanceMonthLabel,
  }) async {
    final pdf = pw.Document();
    final logoBytes = await _loadLogoBytes();
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    pw.MemoryImage? profilePhoto;
    if (summary.profilePhotoPath != null && summary.profilePhotoPath!.isNotEmpty) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File(join(appDir.path, summary.profilePhotoPath));
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          profilePhoto = pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    final statusColor = summary.overallStatus == 'Pass'
        ? PdfColors.green800
        : summary.overallStatus == 'Fail'
            ? PdfColors.red800
            : PdfColors.orange800;

    final monthText = attendanceMonthLabel ?? 'Selected Month';
    final hasAttendance = attendanceSummary != null && attendanceSummary.totalRecordedDays > 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Institutional Header Banner
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: const pw.BoxDecoration(
                color: PdfColors.indigo900,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (logoImage != null) ...[
                    pw.Image(logoImage, height: 40),
                    pw.SizedBox(width: 12),
                  ],
                  pw.Column(
                    children: [
                      pw.Text(
                        'OMEGA EDUCATION CENTRE',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'STUDENT EXAMINATION REPORT CARD',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.amber200),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Academic Year ${summary.academicYear}',
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 10),

            // Student Information & Examination Info Grid (No duplicate Academic Year)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColors.grey50,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (profilePhoto != null) ...[
                        pw.Container(
                          width: 50,
                          height: 50,
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            image: pw.DecorationImage(
                              image: profilePhoto,
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('STUDENT INFORMATION', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                          pw.SizedBox(height: 3),
                          pw.Text('Student Name: ${summary.studentName}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text('Roll Number: ${summary.studentRollNo.isNotEmpty ? summary.studentRollNo : "N/A"}', style: const pw.TextStyle(fontSize: 9.5)),
                          pw.SizedBox(height: 2),
                          pw.Text('Class & Board: ${summary.studentClass} (${summary.board})', style: const pw.TextStyle(fontSize: 9.5)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('EXAMINATION INFORMATION', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.SizedBox(height: 3),
                      pw.Text('Examination: ${summary.testTitle}', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 2),
                      pw.Text('Test Type: ${summary.testType}', style: const pw.TextStyle(fontSize: 9.5)),
                      pw.SizedBox(height: 2),
                      pw.Text('Date: ${summary.testDate}', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 10),

            pw.Text(
              'SUBJECT-WISE PERFORMANCE',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
            ),
            pw.SizedBox(height: 4),

            // Subject Breakdown Table
            pw.TableHelper.fromTextArray(
              headers: ['Subject Name', 'Marks Obtained', 'Max Marks', 'Pass Marks', 'Percentage', 'Status'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              data: summary.configuredSubjects.map((subj) {
                final resList = summary.subjectResults.where((r) => r.testSubjectId == subj.id);
                final isRecorded = resList.isNotEmpty;
                final marks = isRecorded ? resList.first.marksObtained : null;
                final isPass = marks != null && marks >= subj.passMarks;

                return [
                  subj.subjectName,
                  marks != null ? marks.toStringAsFixed(0) : '-',
                  subj.maxMarks.toStringAsFixed(0),
                  subj.passMarks.toStringAsFixed(0),
                  marks != null ? '${((marks / subj.maxMarks) * 100).toStringAsFixed(1)}%' : '-',
                  !isRecorded ? 'Pending' : isPass ? 'Pass' : 'Fail',
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 10),

            // Monthly Attendance Report Section
            pw.Text(
              'MONTHLY ATTENDANCE REPORT (Attendance Month: $monthText)',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
            ),
            pw.SizedBox(height: 4),

            if (hasAttendance) ...[
              pw.TableHelper.fromTextArray(
                headers: ['Classes Conducted', 'Present', 'Absent', 'Attendance %'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.center,
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                data: [
                  [
                    '${attendanceSummary.totalRecordedDays}',
                    '${attendanceSummary.presentCount + attendanceSummary.lateCount}',
                    '${attendanceSummary.absentCount}',
                    '${attendanceSummary.percentage.toStringAsFixed(2)}%',
                  ],
                ],
              ),
            ] else ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Text(
                  'No attendance records available',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],

            pw.SizedBox(height: 10),

            // Overall Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.indigo900, width: 1.2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColors.indigo50,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Total Marks', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('${summary.totalObtained.toStringAsFixed(0)} / ${summary.totalMax.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Percentage', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(summary.isComplete ? '${summary.percentage.toStringAsFixed(2)}%' : 'N/A', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Grade', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(summary.grade, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Result', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(summary.overallStatus, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: statusColor)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Class Rank', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(summary.rank > 0 ? 'Rank ${summary.rank}' : 'N/A', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                    ],
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // Signature & Remarks Section
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Teacher Remarks: ___________________________________________________________', style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(children: [pw.Text('_______________________', style: const pw.TextStyle(fontSize: 8.5)), pw.Text('Parent Signature', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))]),
                    pw.Column(children: [pw.Text('_______________________', style: const pw.TextStyle(fontSize: 8.5)), pw.Text('Teacher Signature', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))]),
                    pw.Column(children: [pw.Text('_______________________', style: const pw.TextStyle(fontSize: 8.5)), pw.Text('Director Signature', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))]),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 8),

            // Footer
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('OMEGA EDUCATION CENTRE - Official Student Report Card', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.Text('Date Printed: ${summary.testDate}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}
