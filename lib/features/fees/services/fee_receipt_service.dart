import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../students/models/student_model.dart';
import '../models/fee_model.dart';
import '../models/fee_payment_model.dart';

/// Professional PDF Receipt Generator for Fee Payments in Omega Education Centre ERP.
class FeeReceiptService {
  FeeReceiptService._();

  static Future<Uint8List> generateReceiptPdf({
    required StudentModel student,
    required FeeModel feePlan,
    required FeePaymentModel payment,
    required double totalPaidToDate,
    required double remainingDue,
  }) async {
    final pdf = pw.Document();

    final datePrinted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final receiptDate = DateFormat('dd MMM yyyy').format(DateTime.parse(payment.paymentDate));

    final previousPaid = totalPaidToDate - payment.amount;
    final prevPaidClamped = previousPaid < 0 ? 0.0 : previousPaid;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Card
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo900,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'OMEGA EDUCATION CENTRE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Excellence in Coaching & Academic Development',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey300,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.amber700,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'FEE PAYMENT RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Receipt Meta Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Receipt No: ${payment.effectiveReceiptNo}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                  ),
                  pw.Text(
                    'Date: $receiptDate',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),

              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 14),

              // Student Info Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('STUDENT INFORMATION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('Student Name: ${student.name}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(child: pw.Text('Roll No: ${student.rollNo}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('Class: Class ${student.studentClass}', style: const pw.TextStyle(fontSize: 10))),
                        pw.Expanded(child: pw.Text('Board: ${student.board}', style: const pw.TextStyle(fontSize: 10))),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Father\'s Name: ${student.fatherName}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Payment Details Table
              pw.Text('PAYMENT DETAILS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Payment Mode', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount Paid', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          payment.remarks != null && payment.remarks!.isNotEmpty ? 'Fee Payment (${payment.remarks})' : 'Tuition & Academic Fee Payment',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(payment.paymentMode, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs. ${payment.amount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green900),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // Financial Account Summary Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.indigo200),
                ),
                child: pw.Column(
                  children: [
                    _buildSummaryRow('Course Fee (Catalogue)', 'Rs. ${(feePlan.courseFee ?? feePlan.totalFee).toStringAsFixed(2)}'),
                    pw.SizedBox(height: 4),
                    _buildSummaryRow('Final Agreed Payable Fee', 'Rs. ${feePlan.totalFee.toStringAsFixed(2)}', isBold: true),
                    pw.SizedBox(height: 4),
                    _buildSummaryRow('Previous Paid Amount', 'Rs. ${prevPaidClamped.toStringAsFixed(2)}'),
                    pw.SizedBox(height: 4),
                    _buildSummaryRow('Current Payment Amount', 'Rs. ${payment.amount.toStringAsFixed(2)}', color: PdfColors.green900),
                    pw.Divider(color: PdfColors.indigo300),
                    _buildSummaryRow('Total Amount Paid to Date', 'Rs. ${totalPaidToDate.toStringAsFixed(2)}', isBold: true, color: PdfColors.green900),
                    pw.SizedBox(height: 4),
                    _buildSummaryRow('Remaining Balance Due', 'Rs. ${remainingDue.toStringAsFixed(2)}', isBold: true, color: remainingDue > 0 ? PdfColors.red900 : PdfColors.green900),
                  ],
                ),
              ),

              pw.Spacer(),

              // Signature Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Date Printed: $datePrinted', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.SizedBox(height: 2),
                      pw.Text('Computer Generated Receipt • Valid without Seal', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey700),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.Text('Omega Education Centre', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String title, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black)),
      ],
    );
  }

  static Future<void> printReceipt({
    required StudentModel student,
    required FeeModel feePlan,
    required FeePaymentModel payment,
    required double totalPaidToDate,
    required double remainingDue,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      student: student,
      feePlan: feePlan,
      payment: payment,
      totalPaidToDate: totalPaidToDate,
      remainingDue: remainingDue,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Receipt_${payment.effectiveReceiptNo}.pdf',
    );
  }
}
