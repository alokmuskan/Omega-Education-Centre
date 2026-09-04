import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../settings/services/institute_config_service.dart';
import '../models/student_model.dart';

/// Service for generating Student ID Card as PDF.
///
/// Generates a printable ID card with:
/// - Institute name and logo
/// - Student photo (if available)
/// - Name, class, roll number, board
/// - Emergency contact (father name, mobile)
/// - Academic year
class IdCardService {
  IdCardService._();

  static final IdCardService instance = IdCardService._();

  /// Generates a single student ID card as PDF bytes.
  Future<Uint8List> generateIdCard(StudentModel student) async {
    final pdf = pw.Document();
    final profile = await InstituteConfigService().getInstituteProfile();

    // Load logo if available
    pw.MemoryImage? logoImage;
    try {
      if (profile.logoPath.isNotEmpty) {
        final logoFile = File(profile.logoPath);
        if (await logoFile.exists()) {
          final bytes = await logoFile.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        }
      }
    } catch (_) {}

    // Load student photo if available
    pw.MemoryImage? studentPhoto;
    try {
      if (student.profilePhotoPath != null && student.profilePhotoPath!.isNotEmpty) {
        final photoFile = File(student.profilePhotoPath!);
        if (await photoFile.exists()) {
          final bytes = await photoFile.readAsBytes();
          studentPhoto = pw.MemoryImage(bytes);
        }
      }
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => _buildIdCard(
          context,
          student: student,
          instituteName: profile.name.isNotEmpty ? profile.name : 'Omega Education Centre',
          instituteAddress: profile.address,
          institutePhone: profile.phone,
          logoImage: logoImage,
          studentPhoto: studentPhoto,
          academicYear: profile.academicYear,
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildIdCard(
    pw.Context context, {
    required StudentModel student,
    required String instituteName,
    required String instituteAddress,
    required String institutePhone,
    pw.MemoryImage? logoImage,
    pw.MemoryImage? studentPhoto,
    required String academicYear,
  }) {
    final cardWidth = 500.0;
    final cardHeight = 300.0;

    return pw.Center(
      child: pw.Container(
        width: cardWidth,
        height: cardHeight,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blue900, width: 2),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Column(
          children: [
            // Header
            _buildHeader(
              instituteName: instituteName,
              logoImage: logoImage,
            ),

            // Body
            pw.Expanded(
              child: pw.Row(
                children: [
                  // Student Photo
                  pw.Container(
                    width: 100,
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Center(
                      child: studentPhoto != null
                          ? pw.ClipOval(
                              child: pw.Image(studentPhoto, width: 80, height: 80, fit: pw.BoxFit.cover),
                            )
                          : pw.Container(
                              width: 80,
                              height: 80,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey200,
                                shape: pw.BoxShape.circle,
                              ),
                              child: pw.Center(
                                child: pw.Text(
                                  student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                  style: pw.TextStyle(fontSize: 32, color: PdfColors.grey600),
                                ),
                              ),
                            ),
                    ),
                  ),

                  // Student Details
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          _detailRow('Name', student.name),
                          _detailRow('Class', 'Class ${student.studentClass}'),
                          _detailRow('Roll No', student.rollNo.toString()),
                          _detailRow('Board', student.board),
                          _detailRow('Father', student.fatherName),
                          _detailRow('Contact', student.mobile),
                        ],
                      ),
                    ),
                  ),

                  // QR / Barcode area (placeholder)
                  pw.Container(
                    width: 80,
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 60,
                          height: 60,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'ID#${student.rollNo}',
                              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Valid $academicYear',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            _buildFooter(
              instituteName: instituteName,
              institutePhone: institutePhone,
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildHeader({
    required String instituteName,
    pw.MemoryImage? logoImage,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: const pw.BoxDecoration(
        color: PdfColors.blue900,
        borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(10)),
      ),
      child: pw.Row(
        children: [
          if (logoImage != null)
            pw.Container(
              width: 36,
              height: 36,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 36,
              height: 36,
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.Text(
                  instituteName.isNotEmpty ? instituteName[0].toUpperCase() : 'O',
                  style: pw.TextStyle(fontSize: 18, color: PdfColors.blue900, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  instituteName,
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'STUDENT IDENTITY CARD',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.blue100),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter({
    required String instituteName,
    required String institutePhone,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(10)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            institutePhone.isNotEmpty ? 'Ph: $institutePhone' : '',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Signature',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Saves the PDF to a temporary file and returns the path.
  Future<String> savePdfToFile(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Shares the ID card PDF.
  Future<void> shareIdCard(StudentModel student) async {
    final bytes = await generateIdCard(student);
    final fileName = 'ID_Card_${student.name.replaceAll(' ', '_')}_${student.rollNo}.pdf';
    final path = await savePdfToFile(bytes, fileName);
    await Share.shareXFiles([XFile(path)], text: 'Student ID Card - ${student.name}');
  }
}
