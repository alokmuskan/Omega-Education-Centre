import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fee_payment_model.dart';
import '../repository/fee_repository.dart';

/// Modal dialog to record a new fee payment with overpayment & future-date validations.
class RecordPaymentDialog extends StatefulWidget {
  final int feeId;
  final int studentId;
  final double remainingDue;

  const RecordPaymentDialog({
    super.key,
    required this.feeId,
    required this.studentId,
    required this.remainingDue,
  });

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repository = FeeRepository();

  late TextEditingController _amountController;
  late TextEditingController _remarksController;

  String _paymentMode = 'Cash';
  DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;

  static const List<String> paymentModes = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Future-date restriction enforced at UI level!
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submitPayment() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (amount > (widget.remainingDue + 0.01)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Overpayment Rejected: Amount (₹${amount.toStringAsFixed(2)}) exceeds remaining due (₹${widget.remainingDue.toStringAsFixed(2)}).'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pDateStr = DateFormat('yyyy-MM-dd').format(_paymentDate);

      final payment = FeePaymentModel(
        feeId: widget.feeId,
        studentId: widget.studentId,
        amount: amount,
        paymentDate: pDateStr,
        paymentMode: _paymentMode,
        remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
      );

      await _repository.recordPayment(payment);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of ₹${amount.toStringAsFixed(2)} recorded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ArgumentError: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(_paymentDate);

    return AlertDialog(
      title: const Text('Record Fee Payment'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Remaining Due Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Remaining Due:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      '₹${widget.remainingDue.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red.shade900),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Payment Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Payment Amount (₹) *',
                  hintText: 'e.g. 2000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Amount is required';
                  final amt = double.tryParse(val.trim());
                  if (amt == null || amt <= 0) return 'Enter a valid positive amount';
                  if (amt > (widget.remainingDue + 0.01)) return 'Exceeds remaining due (₹${widget.remainingDue.toStringAsFixed(2)})';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Payment Date Picker
              InkWell(
                onTap: _pickPaymentDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment Date *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(dateStr),
                ),
              ),

              const SizedBox(height: 14),

              // Payment Mode Dropdown
              DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                ),
                items: paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMode = val);
                },
              ),

              const SizedBox(height: 14),

              // Remarks (Optional)
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Transaction Ref (Optional)',
                  hintText: 'e.g. Installment 1, Cash handed over',
                  border: OutlineInputBorder(),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _submitPayment,
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle),
          label: Text(_isSaving ? 'Saving...' : 'Record Payment'),
        ),
      ],
    );
  }
}
