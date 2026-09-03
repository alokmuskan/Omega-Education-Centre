import 'package:flutter/material.dart';

import '../models/fee_model.dart';
import '../repository/fee_repository.dart';

/// Modal dialog for Admin to create or edit a student's Fee Structure (Course Fee & Agreed Final Payable Fee).
class SetFeePlanDialog extends StatefulWidget {
  final int studentId;
  final FeeModel? existingFeePlan;

  const SetFeePlanDialog({
    super.key,
    required this.studentId,
    this.existingFeePlan,
  });

  @override
  State<SetFeePlanDialog> createState() => _SetFeePlanDialogState();
}

class _SetFeePlanDialogState extends State<SetFeePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repository = FeeRepository();

  late TextEditingController _courseFeeController;
  late TextEditingController _totalFeeController;
  late TextEditingController _descriptionController;

  String _paymentMethod = 'Installments';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.existingFeePlan;
    _courseFeeController = TextEditingController(text: f?.courseFee?.toStringAsFixed(2) ?? '');
    _totalFeeController = TextEditingController(text: f?.totalFee.toStringAsFixed(2) ?? '');
    _descriptionController = TextEditingController(text: f?.description ?? '');
    _paymentMethod = f?.paymentMethod ?? 'Installments';
  }

  @override
  void dispose() {
    _courseFeeController.dispose();
    _totalFeeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveFeePlan() async {
    if (!_formKey.currentState!.validate()) return;

    final cFee = double.tryParse(_courseFeeController.text.trim());
    final tFee = double.tryParse(_totalFeeController.text.trim());

    if (tFee == null || tFee <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid final agreed payable fee.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final nowIso = DateTime.now().toIso8601String();

      final feePlan = FeeModel(
        id: widget.existingFeePlan?.id,
        studentId: widget.studentId,
        paymentMethod: _paymentMethod,
        courseFee: cFee,
        totalFee: tFee,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        createdAt: widget.existingFeePlan?.createdAt ?? nowIso,
      );

      await _repository.saveAdmissionFee(feePlan: feePlan);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee structure updated successfully!'), backgroundColor: Colors.green),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save fee plan: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingFeePlan != null ? 'Edit Fee Structure' : 'Set Fee Structure'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nominal Catalogue Course Fee
              TextFormField(
                controller: _courseFeeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Nominal Course Fee (Optional)',
                  hintText: 'e.g. 15000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sell),
                ),
              ),

              const SizedBox(height: 14),

              // Agreed Final Payable Fee
              TextFormField(
                controller: _totalFeeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Final Agreed Payable Fee (₹) *',
                  hintText: 'e.g. 11000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Final agreed fee is required';
                  final amt = double.tryParse(val.trim());
                  if (amt == null || amt <= 0) return 'Enter a valid positive amount';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Payment Method
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Structure Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.style),
                ),
                items: const [
                  DropdownMenuItem(value: 'Installments', child: Text('Flexible Installments')),
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly Schedule')),
                  DropdownMenuItem(value: 'Full Payment', child: Text('One-time Full Payment')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),

              const SizedBox(height: 14),

              // Notes / Remarks
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Discount Remarks (Optional)',
                  hintText: 'e.g. ₹4000 Merit Scholarship Applied',
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
        ElevatedButton(
          onPressed: _isSaving ? null : _saveFeePlan,
          child: Text(_isSaving ? 'Saving...' : 'Save Fee Plan'),
        ),
      ],
    );
  }
}
