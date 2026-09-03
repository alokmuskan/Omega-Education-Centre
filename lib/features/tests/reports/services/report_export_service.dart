import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../attendance/models/attendance_summary_model.dart';
import '../../../attendance/repository/student_attendance_repository.dart';
import '../../models/student_test_summary_model.dart';
import '../../models/test_model.dart';
import '../../repository/test_result_repository.dart';
import '../models/result_export_data.dart';
import 'docx_generator_service.dart';
import 'excel_generator_service.dart';
import 'pdf_generator_service.dart';

/// Unified export orchestrator for generating, saving, previewing, and sharing
/// Class Results and Individual Student Report Cards in PDF, Excel, and Word formats.
class ReportExportService {
  ReportExportService._();

  static final TestResultRepository _resultRepo = TestResultRepository();
  static final StudentAttendanceRepository _attendanceRepo = StudentAttendanceRepository();

  static String _getMonthLabel(String dateIso) {
    try {
      final dt = DateTime.parse(dateIso);
      final monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${monthNames[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'Selected Month';
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Export Class-wise Results (PDF / Excel / Word)
  // ──────────────────────────────────────────────────────────────────────

  static Future<void> exportClassResults({
    required BuildContext context,
    required TestModel test,
    required String format, // 'pdf' | 'xlsx' | 'docx'
  }) async {
    if (test.id == null) return;

    try {
      // 1. Fetch authoritative class test summaries
      final summaries = await _resultRepo.getClassTestSummaries(test.id!);
      final exportData = ClassResultExportData.fromSummaries(
        test: test,
        summaries: summaries,
      );

      // 2. Build sanitized filename
      final sanitizedTitle = sanitizeFileName(test.title);
      final sanitizedClass = sanitizeFileName(test.studentClass);
      final fileName = '${sanitizedTitle}_$sanitizedClass.$format';

      Uint8List? fileBytes;

      if (format == 'pdf') {
        fileBytes = await PdfGeneratorService.generateClassResultPdf(exportData);
      } else if (format == 'xlsx') {
        final bytes = ExcelGeneratorService.generateClassResultExcel(exportData);
        if (bytes != null) fileBytes = Uint8List.fromList(bytes);
      } else if (format == 'docx') {
        final bytes = DocxGeneratorService.generateClassResultDocx(exportData);
        fileBytes = Uint8List.fromList(bytes);
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('Failed to generate $format export bytes.');
      }

      if (!context.mounted) return;

      // 3. Save file locally & present options
      await _handleFileSaveAndOpen(
        context: context,
        fileName: fileName,
        bytes: fileBytes,
        title: '${test.title} (${test.studentClass}) Export',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Export Individual Student Report Card (PDF / Excel / Word)
  // ──────────────────────────────────────────────────────────────────────

  static Future<void> exportStudentReportCard({
    required BuildContext context,
    required StudentTestSummaryModel summary,
    required String format, // 'pdf' | 'xlsx' | 'docx'
  }) async {
    try {
      final sanitizedStudent = sanitizeFileName(summary.studentName);
      final sanitizedTest = sanitizeFileName(summary.testTitle);
      final fileName = '${sanitizedStudent}_${sanitizedTest}_Report_Card.$format';

      // 1. Fetch attendance summary for the test's month from SQLite
      final yearMonth = summary.testDate.length >= 7 ? summary.testDate.substring(0, 7) : '2026-08';
      final attendanceMonthLabel = _getMonthLabel(summary.testDate);

      StudentAttendanceSummary? attendanceSummary;
      try {
        attendanceSummary = await _attendanceRepo.getStudentMonthlySummary(
          studentId: summary.studentId,
          yearMonth: yearMonth,
        );
      } catch (_) {}

      Uint8List? fileBytes;

      if (format == 'pdf') {
        fileBytes = await PdfGeneratorService.generateStudentReportCardPdf(
          summary,
          attendanceSummary: attendanceSummary,
          attendanceMonthLabel: attendanceMonthLabel,
        );
      } else if (format == 'xlsx') {
        final bytes = ExcelGeneratorService.generateStudentReportCardExcel(
          summary,
          attendanceSummary: attendanceSummary,
          attendanceMonthLabel: attendanceMonthLabel,
        );
        if (bytes != null) fileBytes = Uint8List.fromList(bytes);
      } else if (format == 'docx') {
        final bytes = DocxGeneratorService.generateStudentReportCardDocx(
          summary,
          attendanceSummary: attendanceSummary,
          attendanceMonthLabel: attendanceMonthLabel,
        );
        fileBytes = Uint8List.fromList(bytes);
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('Failed to generate report card $format bytes.');
      }

      if (!context.mounted) return;

      await _handleFileSaveAndOpen(
        context: context,
        fileName: fileName,
        bytes: fileBytes,
        title: '${summary.studentName} Report Card',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report Card export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // File Save, Native Open & Share Handler
  // ──────────────────────────────────────────────────────────────────────

  static Future<void> _handleFileSaveAndOpen({
    required BuildContext context,
    required String fileName,
    required Uint8List bytes,
    required String title,
  }) async {
    final outputDir = await getApplicationDocumentsDirectory();
    final file = File('${outputDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    if (!context.mounted) return;

    // Show completion action sheet (Open, Share, Print/Preview)
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Saved as $fileName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      OpenFilex.open(file.path);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open File'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (fileName.endsWith('.pdf')) {
                        Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
                      } else {
                        Share.shareXFiles([XFile(file.path)], text: title);
                      }
                    },
                    icon: Icon(fileName.endsWith('.pdf') ? Icons.print : Icons.share),
                    label: Text(fileName.endsWith('.pdf') ? 'Print / Preview' : 'Share File'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
