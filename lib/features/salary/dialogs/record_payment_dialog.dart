import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/teacher_payment_model.dart';
import '../models/teacher_salary_summary_model.dart';
import '../repository/teacher_salary_repository.dart';

/// Form dialog to record a Cash Salary Payment for a Teacher.
class RecordPaymentDialog extends StatefulWidget {
  final TeacherSalarySummaryModel summary;

  const RecordPaymentDialog({
    super.key,
    required this.summary,
  });

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repository = TeacherSalaryRepository();

  late TextEditingController _amountController;
  final TextEditingController _remarksController = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default amount to remaining due (or 0 if fully paid)
    final due = widget.summary.remainingDue;
    _amountController = TextEditingController(
      text: due > 0 ? due.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate.isAfter(now) ? now : _paymentDate,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'SELECT PAYMENT DATE',
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submitPayment() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final paymentDateStr = DateFormat('yyyy-MM-dd').format(_paymentDate);

      final payment = TeacherPaymentModel(
        teacherId: widget.summary.teacherId,
        month: widget.summary.month,
        amount: amount,
        paymentDate: paymentDateStr,
        paymentMethod: 'Cash',
        remarks: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
      );

      await _repository.recordSalaryPayment(payment);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cash payment of ₹${amount.toStringAsFixed(0)} recorded for ${widget.summary.teacherName}!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true); // true triggers UI refresh
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;

      final errMsg = e is ArgumentError ? e.message.toString() : 'Failed to record payment: $e';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment Validation Error'),
          content: Text(errMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments, color: Colors.green, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('Record Salary Payment', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Teacher info summary box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.teacherName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Month: ${summary.month} • Earned: ₹${summary.earnedSalary.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Remaining Due: ₹${summary.remainingDue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Payment Method (Read-only Cash)
              TextFormField(
                initialValue: 'Cash',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  prefixIcon: Icon(Icons.money),
                  helperText: 'Omega Education Centre salary mode: Cash',
                ),
              ),

              const SizedBox(height: 14),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Payment amount is required';
                  }
                  final numVal = double.tryParse(val.trim());
                  if (numVal == null || numVal <= 0) {
                    return 'Amount must be greater than ₹0';
                  }
                  if (numVal > summary.remainingDue) {
                    return 'Amount cannot exceed remaining due (₹${summary.remainingDue.toStringAsFixed(0)})';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Payment Amount (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),

              const SizedBox(height: 14),

              // Payment Date Picker
              GestureDetector(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment Date *',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('d MMMM yyyy').format(_paymentDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Remarks
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: _isSaving ? null : _submitPayment,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.check),
          label: Text(_isSaving ? 'Saving...' : 'Record Payment'),
        ),
      ],
    );
  }
}
