import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../settings/services/institute_config_service.dart';
import '../models/student_model.dart';

/// Service for generating Transfer Certificate (TC) as PDF.
///
/// Generates a formal TC with:
/// - Institute letterhead
/// - Student details (name, class, roll no, board, parent)
/// - Reason for leaving
/// - Conduct and character remarks
/// - Date of issue
/// - Principal signature block
class TcService {
  TcService._();

  static final TcService instance = TcService._();

  /// Generates a Transfer Certificate as PDF bytes.
  Future<Uint8List> generateTc({
    required StudentModel student,
    String? reason,
    String? conduct,
    String? remarks,
    DateTime? issueDate,
  }) async {
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

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (context) => _buildTcContent(
          context,
          student: student,
          instituteName: profile.name.isNotEmpty ? profile.name : 'Omega Education Centre',
          instituteAddress: profile.address,
          institutePhone: profile.phone,
          principalName: profile.principalName,
          logoImage: logoImage,
          reason: reason,
          conduct: conduct,
          remarks: remarks,
          issueDate: issueDate ?? DateTime.now(),
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildTcContent(
    pw.Context context, {
    required StudentModel student,
    required String instituteName,
    required String instituteAddress,
    required String institutePhone,
    required String principalName,
    pw.MemoryImage? logoImage,
    String? reason,
    String? conduct,
    String? remarks,
    required DateTime issueDate,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Letterhead
        _buildLetterhead(instituteName, instituteAddress, institutePhone, logoImage),
        pw.SizedBox(height: 20),

        // Title
        pw.Center(
          child: pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900, width: 1.5),
            ),
            child: pw.Text(
              'TRANSFER CERTIFICATE',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 20),

        // Certificate Number
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Ref No: TC/${student.rollNo}/${issueDate.year}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              'Date: ${DateFormat('dd MMMM yyyy').format(issueDate)}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // Body
        pw.RichText(
          text: pw.TextSpan(
            text: 'This is to certify that ',
            style: pw.TextStyle(fontSize: 12),
            children: [
              pw.TextSpan(
                text: student.name,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
              ),
              pw.TextSpan(
                text: ', S/o ${student.fatherName}',
                style: pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // Student Details Table
        _buildDetailsTable(student, instituteName),
        pw.SizedBox(height: 16),

        // Conduct
        pw.RichText(
          text: pw.TextSpan(
            text: 'Conduct: ',
            style: pw.TextStyle(fontSize: 12),
            children: [
              pw.TextSpan(
                text: conduct ?? 'Good',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // Reason for leaving
        if (reason != null && reason.isNotEmpty) ...[
          pw.RichText(
            text: pw.TextSpan(
              text: 'Reason for leaving: ',
              style: pw.TextStyle(fontSize: 12),
              children: [
                pw.TextSpan(
                  text: reason,
                  style: pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
        ],

        // Remarks
        if (remarks != null && remarks.isNotEmpty) ...[
          pw.RichText(
            text: pw.TextSpan(
              text: 'Remarks: ',
              style: pw.TextStyle(fontSize: 12),
              children: [
                pw.TextSpan(
                  text: remarks,
                  style: pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
        ],

        // Dues clearance
        pw.RichText(
          text: pw.TextSpan(
            text: 'All dues of the institute have been cleared.',
            style: pw.TextStyle(fontSize: 12),
          ),
        ),
        pw.SizedBox(height: 16),

        // Declaration
        pw.RichText(
          text: pw.TextSpan(
            text: 'The above information is correct to the best of our knowledge and belief.',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ),
        pw.SizedBox(height: 40),

        // Signatures
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 4),
                pw.Text('Class Teacher', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 4),
                pw.Text(
                  principalName.isNotEmpty ? principalName : 'Principal',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
                pw.Text('(Principal/Director)', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // Institute Seal placeholder
        pw.Center(
          child: pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1, style: pw.BorderStyle.dashed),
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text('Seal', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildLetterhead(String name, String address, String phone, pw.MemoryImage? logo) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 40,
                height: 40,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'O',
                    style: pw.TextStyle(fontSize: 18, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  name,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                ),
                if (address.isNotEmpty)
                  pw.Text(address, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                if (phone.isNotEmpty)
                  pw.Text('Ph: $phone', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.blue900, thickness: 1.5),
      ],
    );
  }

  pw.Widget _buildDetailsTable(StudentModel student, String instituteName) {
    return pw.Table(
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
      },
      children: [
        _tableRow('Student Name', student.name),
        _tableRow('Father\'s Name', student.fatherName),
        if (student.motherName != null && student.motherName!.isNotEmpty)
          _tableRow('Mother\'s Name', student.motherName!),
        _tableRow('Class', 'Class ${student.studentClass}'),
        _tableRow('Roll Number', student.rollNo.toString()),
        _tableRow('Board', student.board),
        _tableRow('Date of Birth', student.createdAt.substring(0, 10)),
        if (student.mobile.isNotEmpty)
          _tableRow('Contact', student.mobile),
        _tableRow('Institute', instituteName),
      ],
    );
  }

  pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text('$label:', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  /// Saves the PDF to a temporary file and returns the path.
  Future<String> savePdfToFile(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Shares the TC PDF.
  Future<void> shareTc(StudentModel student, {String? reason, String? conduct, String? remarks}) async {
    final bytes = await generateTc(student: student, reason: reason, conduct: conduct, remarks: remarks);
    final fileName = 'TC_${student.name.replaceAll(' ', '_')}_${student.rollNo}.pdf';
    final path = await savePdfToFile(bytes, fileName);
    await Share.shareXFiles([XFile(path)], text: 'Transfer Certificate - ${student.name}');
  }
}
