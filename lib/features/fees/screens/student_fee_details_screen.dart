import 'package:flutter/material.dart';

import '../../../shared/utils/app_session.dart';
import '../../students/models/student_model.dart';
import '../../students/repository/student_repository.dart';
import '../models/fee_installment_model.dart';
import '../models/fee_model.dart';
import '../models/fee_payment_model.dart';
import '../repository/fee_repository.dart';
import '../services/fee_receipt_service.dart';
import 'record_payment_dialog.dart';
import 'set_fee_plan_dialog.dart';

/// Screen displaying complete Fee Ledger, Payment History, and Receipt controls for a student.
class StudentFeeDetailsScreen extends StatefulWidget {
  final int studentId;
  final bool isStudentView;

  const StudentFeeDetailsScreen({
    super.key,
    required this.studentId,
    this.isStudentView = false,
  });

  @override
  State<StudentFeeDetailsScreen> createState() => _StudentFeeDetailsScreenState();
}

class _StudentFeeDetailsScreenState extends State<StudentFeeDetailsScreen> {
  final _repository = FeeRepository();
  final _studentRepository = StudentRepository();

  StudentModel? _student;
  FeeModel? _feePlan;
  List<FeePaymentModel> _payments = [];
  List<FeeInstallmentModel> _installments = [];

  double _totalPaid = 0.0;
  double _remainingDue = 0.0;
  String _feeStatus = 'Unpaid';

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeeDetails();
  }

  Future<void> _loadFeeDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final s = await _studentRepository.getStudentById(widget.studentId);
      final f = await _repository.getFeeForStudent(widget.studentId);
      final pList = await _repository.getPaymentsForStudent(widget.studentId);
      final iList = await _repository.getInstallmentsForStudent(widget.studentId);

      final paid = await _repository.getTotalPaid(widget.studentId);
      final due = await _repository.getOutstanding(widget.studentId);
      final status = await _repository.computeFeeStatus(widget.studentId);

      if (mounted) {
        setState(() {
          _student = s;
          _feePlan = f;
          _payments = pList;
          _installments = iList;
          _totalPaid = paid;
          _remainingDue = due;
          _feeStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load fee details: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openRecordPaymentDialog() async {
    if (_feePlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set the fee structure first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => RecordPaymentDialog(
        feeId: _feePlan!.id!,
        studentId: widget.studentId,
        remainingDue: _remainingDue,
      ),
    );

    if (updated == true) {
      _loadFeeDetails();
    }
  }

  Future<void> _openSetFeePlanDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => SetFeePlanDialog(
        studentId: widget.studentId,
        existingFeePlan: _feePlan,
      ),
    );

    if (updated == true) {
      _loadFeeDetails();
    }
  }

  Future<void> _printReceipt(FeePaymentModel payment) async {
    if (_student == null || _feePlan == null) return;
    try {
      await FeeReceiptService.printReceipt(
        student: _student!,
        feePlan: _feePlan!,
        payment: payment,
        totalPaidToDate: _totalPaid,
        remainingDue: _remainingDue,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate receipt: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    if (session.isTeacher) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: Teachers are not authorized to view student fee details.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (session.isStudent && widget.studentId != session.currentStudentId) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: You are not authorized to view another student\'s fee details.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final canEdit = AppSession.instance.isAdmin && !widget.isStudentView;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isStudentView ? 'My Fees' : 'Student Fee Details'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadFeeDetails, child: const Text('Retry')),
                    ],
                  ),
                )
              : _student == null
                  ? const Center(child: Text('Student record not found.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Student Header Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 28,
                                    child: Icon(Icons.person, size: 32),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _student!.name,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Class ${_student!.studentClass} (${_student!.board}) • Roll No: ${_student!.rollNo}',
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                        ),
                                        Text(
                                          'Father: ${_student!.fatherName}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Financial Summary Card
                          _buildFinancialSummaryCard(canEdit),

                          const SizedBox(height: 20),

                          // Admin Action Buttons
                          if (canEdit) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: _remainingDue > 0 ? _openRecordPaymentDialog : null,
                                    icon: const Icon(Icons.add_card),
                                    label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: _openSetFeePlanDialog,
                                    icon: const Icon(Icons.edit_note),
                                    label: Text(_feePlan != null ? 'Edit Fee Structure' : 'Set Fee Structure'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Payment History Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Payment History',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              Chip(
                                label: Text('${_payments.length} Payments'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          if (_payments.isEmpty)
                            Card(
                              color: Colors.grey.shade50,
                              child: const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text('No payment records found. Record a payment to generate receipts.'),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _payments.length,
                              itemBuilder: (context, index) {
                                final p = _payments[index];
                                return _buildPaymentCard(p);
                              },
                            ),

                          // Installments Schedule Section (if any)
                          if (_installments.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Planned Fee Schedule',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            ..._installments.map((inst) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.event, color: Colors.indigo),
                                  title: Text(inst.description ?? 'Installment'),
                                  subtitle: Text('Due: ${inst.dueDate}'),
                                  trailing: Text(
                                    '₹${inst.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildFinancialSummaryCard(bool canEdit) {
    Color statusBg = Colors.red.shade100;
    Color statusFg = Colors.red.shade900;

    if (_feeStatus == 'Paid') {
      statusBg = Colors.green.shade100;
      statusFg = Colors.green.shade900;
    } else if (_feeStatus == 'Partially Paid') {
      statusBg = Colors.orange.shade100;
      statusFg = Colors.orange.shade900;
    }

    final totalPayable = _feePlan?.totalFee ?? 0.0;
    final nominalFee = _feePlan?.courseFee;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FEE ACCOUNT SUMMARY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _feeStatus.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              if (nominalFee != null) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nominal Fee', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      Text(
                        '₹${nominalFee.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, color: Colors.white70, decoration: TextDecoration.lineThrough),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agreed Payable Fee', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    Text(
                      '₹${totalPayable.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Paid', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_totalPaid.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Remaining Due', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_remainingDue.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _remainingDue > 0 ? Colors.amberAccent : Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(FeePaymentModel payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.check, color: Colors.green.shade900),
        ),
        title: Text(
          '₹${payment.amount.toStringAsFixed(2)} (${payment.paymentMode})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${payment.paymentDate} • ${payment.effectiveReceiptNo}'),
            if (payment.remarks != null && payment.remarks!.isNotEmpty)
              Text('Note: ${payment.remarks}', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.receipt_long, color: Colors.indigo),
          tooltip: 'Generate Receipt PDF',
          onPressed: () => _printReceipt(payment),
        ),
      ),
    );
  }
}
