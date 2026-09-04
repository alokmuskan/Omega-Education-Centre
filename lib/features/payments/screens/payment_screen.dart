import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

import '../services/payment_gateway_service.dart';

/// Screen for processing fee payments with multiple payment methods.
///
/// Flow:
/// 1. Student selects fee amount
/// 2. Chooses payment method (Cash / UPI / Card / Net-Banking)
/// 3. Processes payment
/// 4. Shows receipt
class PaymentScreen extends StatefulWidget {
  final String studentName;
  final int studentId;
  final String className;
  final double outstandingAmount;

  const PaymentScreen({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.className,
    required this.outstandingAmount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _amountController = TextEditingController();
  final _paymentGateway = PaymentGatewayService.instance;

  String _selectedMethod = 'cash';
  bool _isProcessing = false;
  PaymentTransaction? _completedTransaction;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.outstandingAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text) ?? 0;

  Future<void> _processPayment() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_amount > widget.outstandingAmount + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount exceeds outstanding (₹${widget.outstandingAmount.toStringAsFixed(0)})'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final receiptId = 'REC-${DateTime.now().millisecondsSinceEpoch}';

      PaymentTransaction transaction;

      if (_selectedMethod == 'cash') {
        // Cash payment — record directly
        transaction = _paymentGateway.recordCashPayment(
          amount: _amount,
          receiptId: receiptId,
        );
      } else {
        // Online payment — create order and process
        final orderResult = await _paymentGateway.createOrder(
          amount: _amount,
          receiptId: receiptId,
        );

        if (!orderResult.success) {
          if (mounted) {
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(orderResult.message), backgroundColor: Colors.red),
            );
          }
          return;
        }

        // In a real app, this would open Razorpay checkout.
        // For now, simulate successful payment.
        transaction = PaymentTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          orderId: orderResult.transaction!.orderId,
          amount: _amount,
          method: _selectedMethod,
          status: PaymentStatus.successful,
          razorpayPaymentId: 'pay_simulated_${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
          completedAt: DateTime.now(),
        );
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _completedTransaction = transaction;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareReceipt() async {
    if (_completedTransaction == null) return;

    final receipt = _paymentGateway.generateReceipt(
      _completedTransaction!,
      studentName: widget.studentName,
      className: widget.className,
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/receipt_${_completedTransaction!.orderId}.txt');
    await file.writeAsString(receipt);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Fee Payment Receipt — ${widget.studentName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_completedTransaction != null) {
      return _buildReceiptScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : 'S',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Class ${widget.className}', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Outstanding
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Outstanding Amount', style: TextStyle(fontSize: 14)),
                    Text(
                      '₹${widget.outstandingAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Amount input
            const Text('Payment Amount', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
                hintText: 'Enter amount',
              ),
            ),
            const SizedBox(height: 8),

            // Quick amount buttons
            Row(
              children: [
                _buildAmountChip('Full'),
                const SizedBox(width: 8),
                _buildAmountChip('Half'),
              ],
            ),
            const SizedBox(height: 20),

            // Payment method
            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.money)),
                ButtonSegment(value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code)),
                ButtonSegment(value: 'card', label: Text('Card'), icon: Icon(Icons.credit_card)),
              ],
              selected: {_selectedMethod},
              onSelectionChanged: (sel) => setState(() => _selectedMethod = sel.first),
            ),
            const SizedBox(height: 24),

            // Pay button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _selectedMethod == 'cash' ? 'Record Cash Payment' : 'Pay ₹${_amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptScreen() {
    final t = _completedTransaction!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text('Payment Successful!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('₹${t.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildReceiptRow('Receipt No', t.orderId),
                      _buildReceiptRow('Student', widget.studentName),
                      _buildReceiptRow('Class', widget.className),
                      _buildReceiptRow('Method', t.method.toUpperCase()),
                      if (t.razorpayPaymentId != null)
                        _buildReceiptRow('Transaction ID', t.razorpayPaymentId!),
                      _buildReceiptRow('Date', '${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _shareReceipt,
                      child: const Text('Share Receipt'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAmountChip(String label) {
    double amount = 0;
    if (label == 'Full') amount = widget.outstandingAmount;
    if (label == 'Half') amount = widget.outstandingAmount / 2;

    return ActionChip(
      label: Text('$label (₹${amount.toStringAsFixed(0)})'),
      onPressed: () => setState(() => _amountController.text = amount.toStringAsFixed(0)),
    );
  }
}
