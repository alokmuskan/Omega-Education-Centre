import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/profile_photo_helper.dart';
import '../../../shared/widgets/profile_photo_widget.dart';
import '../../fees/models/fee_installment_model.dart';
import '../../fees/models/fee_model.dart';
import '../../fees/models/fee_payment_model.dart';
import '../../fees/repository/fee_repository.dart';
import '../../settings/models/master_data_model.dart';
import '../../settings/services/institute_config_service.dart';
import '../models/student_model.dart';
import '../repository/student_repository.dart';

/// New Admission screen.
class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _studentRepo = StudentRepository();
  final _feeRepo = FeeRepository();
  final _configService = InstituteConfigService();

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  File? _tempPhotoFile;

  final _nameCtrl = TextEditingController();
  final _fatherCtrl = TextEditingController();
  final _motherCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _board = AppConstants.boards.first;
  String _studentClass = '10';
  List<String> _boardsList = AppConstants.boards;
  List<String> _classesList = AppConstants.classes;

  @override
  void initState() {
    super.initState();
    _loadConfigMasterData();
  }

  Future<void> _loadConfigMasterData() async {
    final bList = await _configService.getActiveMasterNamesWithHistorical(MasterCategory.board, _board);
    final cList = await _configService.getActiveMasterNamesWithHistorical(MasterCategory.studentClass, _studentClass);
    if (mounted) {
      setState(() {
        if (bList.isNotEmpty) _boardsList = bList;
        if (cList.isNotEmpty) _classesList = cList;
        if (!_boardsList.contains(_board)) _board = _boardsList.first;
        if (!_classesList.contains(_studentClass)) _studentClass = _classesList.first;
      });
    }
  }
  final _rollCtrl = TextEditingController();

  // ── Section 3: Fee Plan ──────────────────────────────────────────────

  /// 'Monthly' or 'Installments'
  String _paymentMethod = 'Installments';

  // Monthly fields
  final _monthlyAmtCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController();
  DateTime _startMonth = DateTime.now();
  final _durationCtrl = TextEditingController(text: '12');

  // Installment fields
  final _courseFeeCtrl = TextEditingController();
  final _agreedFeeCtrl = TextEditingController();

  /// Editable installment schedule (before saving, feeId is placeholder 0)
  final List<_InstallmentEntry> _installments = [
    _InstallmentEntry(
      amtCtrl: TextEditingController(),
      dueDate: DateTime.now(),
      descCtrl: TextEditingController(text: 'Admission'),
    ),
  ];

  // ── Section 4: Admission Payment ─────────────────────────────────────

  bool _recordAdmissionPayment = false;
  final _admissionPaymentCtrl = TextEditingController();
  String _admissionPaymentMode = 'Cash';
  final _admissionRemarksCtrl = TextEditingController();

  // ── Helpers ──────────────────────────────────────────────────────────

  final _currencyFormat = NumberFormat.currency(
    locale: 'hi_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  String _isoDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
  String _isoMonth(DateTime dt) => DateFormat('yyyy-MM').format(dt);
  String _displayMonth(DateTime dt) => DateFormat('MMM yyyy').format(dt);
  String _displayDate(DateTime dt) => DateFormat('d MMM yyyy').format(dt);

  double get _installmentTotal =>
      _installments.fold(0.0, (sum, e) {
        return sum + (double.tryParse(e.amtCtrl.text) ?? 0.0);
      });

  double get _agreedFee => double.tryParse(_agreedFeeCtrl.text) ?? 0.0;

  bool get _installmentTotalValid =>
      (_installmentTotal - _agreedFee).abs() < 0.01;

  // ── Add / Remove Installment ──────────────────────────────────────────

  void _addInstallment() {
    setState(() {
      _installments.add(_InstallmentEntry(
        amtCtrl: TextEditingController(),
        dueDate: DateTime.now().add(
          Duration(days: 30 * _installments.length),
        ),
        descCtrl: TextEditingController(
          text: 'Instalment ${_installments.length + 1}',
        ),
      ));
    });
  }

  void _removeInstallment(int index) {
    if (_installments.length <= 1) return;
    setState(() {
      _installments[index].dispose();
      _installments.removeAt(index);
    });
  }

  // ── Date Pickers ──────────────────────────────────────────────────────

  Future<void> _pickStartMonth() async {
    // Pick a date — we only use the year + month.
    final picked = await showDatePicker(
      context: context,
      initialDate: _startMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECT START MONTH',
    );
    if (picked != null) {
      setState(() => _startMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _pickInstallmentDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _installments[index].dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECT DUE DATE',
    );
    if (picked != null) {
      setState(() => _installments[index].dueDate = picked);
    }
  }

  // ── Auto-generate monthly schedule preview ───────────────────────────

  List<_MonthPreview> _generateMonthlyPreview() {
    final months = int.tryParse(_durationCtrl.text) ?? 0;
    final day = int.tryParse(_dueDayCtrl.text) ?? 1;
    final amount = double.tryParse(_monthlyAmtCtrl.text) ?? 0.0;
    if (months <= 0 || day < 1 || day > 28 || amount <= 0) return [];

    final list = <_MonthPreview>[];
    for (int i = 0; i < months; i++) {
      final month = _startMonth.month + i;
      final year = _startMonth.year + ((month - 1) ~/ 12);
      final adjustedMonth = ((month - 1) % 12) + 1;
      final dueDate = DateTime(year, adjustedMonth, day);
      list.add(_MonthPreview(dueDate: dueDate, amount: amount));
    }
    return list;
  }

  // ── Save ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;

    // 1. Validate form fields
    if (!_formKey.currentState!.validate()) return;

    // 2. Additional fee validations
    if (_paymentMethod == 'Installments') {
      if (_installments.isEmpty) {
        _showError('Add at least one instalment.');
        return;
      }
      if (!_installmentTotalValid) {
        _showError(
          'Instalment total (${_currencyFormat.format(_installmentTotal)}) '
          'does not match Final Agreed Fee (${_currencyFormat.format(_agreedFee)}).\n'
          'Please adjust instalment amounts.',
        );
        return;
      }
    }

    final admissionPaymentAmt =
        double.tryParse(_admissionPaymentCtrl.text) ?? 0.0;
    if (_recordAdmissionPayment && admissionPaymentAmt <= 0) {
      _showError('Admission payment amount must be greater than 0.');
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final today = _isoDate(DateTime.now());

      // 3. Build StudentModel
      // feeStatus starts as 'Due'; updated after any payment
      final student = StudentModel(
        name: _nameCtrl.text.trim(),
        fatherName: _fatherCtrl.text.trim(),
        motherName: _motherCtrl.text.trim().isEmpty
            ? null
            : _motherCtrl.text.trim(),
        board: _board,
        studentClass: _studentClass,
        rollNo: int.parse(_rollCtrl.text.trim()),
        mobile: _mobileCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        feeStatus: 'Due', // always starts as Due; recomputed after payment
        isActive: true,
        createdAt: now,
      );

      // 4. Insert student (outside transaction — get studentId first)
      final studentId = await _studentRepo.insertStudent(student);

      // Save student profile photo if selected
      String? savedPhotoPath;
      if (_tempPhotoFile != null) {
        try {
          savedPhotoPath = await ProfilePhotoHelper.saveImage(
            _tempPhotoFile!,
            'students',
            'student_$studentId',
          );
          await _studentRepo.updateStudent(
            student.copyWith(
              id: studentId,
              profilePhotoPath: savedPhotoPath,
            ),
          );
        } catch (photoErr) {
          // Photo save failed, but we show a warning and proceed so the admission is not corrupted
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Admission complete, but photo could not be saved: $photoErr'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      // 5. Build fee plan
      final double totalFee;
      final FeeModel feePlan;

      if (_paymentMethod == 'Monthly') {
        final monthlyAmt = double.parse(_monthlyAmtCtrl.text.trim());
        final months = int.parse(_durationCtrl.text.trim());
        totalFee = monthlyAmt * months;

        feePlan = FeeModel(
          studentId: studentId,
          paymentMethod: 'Monthly',
          totalFee: totalFee,
          monthlyAmount: monthlyAmt,
          paymentDueDay: int.parse(_dueDayCtrl.text.trim()),
          startMonth: _isoMonth(_startMonth),
          durationMonths: months,
          createdAt: now,
        );
      } else {
        totalFee = double.parse(_agreedFeeCtrl.text.trim());
        final courseFee = double.tryParse(_courseFeeCtrl.text.trim());

        feePlan = FeeModel(
          studentId: studentId,
          paymentMethod: 'Installments',
          courseFee: courseFee,
          totalFee: totalFee,
          createdAt: now,
        );
      }

      // 6. Build installment schedule
      final List<FeeInstallmentModel> schedule = [];

      if (_paymentMethod == 'Monthly') {
        final preview = _generateMonthlyPreview();
        for (int i = 0; i < preview.length; i++) {
          schedule.add(FeeInstallmentModel(
            feeId: 0, // set inside transaction
            studentId: studentId,
            amount: preview[i].amount,
            dueDate: _isoDate(preview[i].dueDate),
            description: 'Month ${i + 1}',
            createdAt: now,
          ));
        }
      } else {
        for (int i = 0; i < _installments.length; i++) {
          final e = _installments[i];
          schedule.add(FeeInstallmentModel(
            feeId: 0, // set inside transaction
            studentId: studentId,
            amount: double.parse(e.amtCtrl.text.trim()),
            dueDate: _isoDate(e.dueDate),
            description: e.descCtrl.text.trim().isEmpty
                ? 'Instalment ${i + 1}'
                : e.descCtrl.text.trim(),
            createdAt: now,
          ));
        }
      }

      // 7. Build optional admission payment
      FeePaymentModel? admissionPayment;
      if (_recordAdmissionPayment && admissionPaymentAmt > 0) {
        admissionPayment = FeePaymentModel(
          feeId: 0, // set inside transaction
          studentId: studentId,
          amount: admissionPaymentAmt,
          paymentDate: today,
          paymentMode: _admissionPaymentMode,
          remarks: _admissionRemarksCtrl.text.trim().isEmpty
              ? 'Admission payment'
              : _admissionRemarksCtrl.text.trim(),
        );
      }

      // 8. Save fee plan + schedule + optional payment (atomic)
      await _feeRepo.saveAdmissionFee(
        feePlan: feePlan,
        installments: schedule,
        admissionPayment: admissionPayment,
      );

      // 9. Update feeStatus cache if admission payment was made
      if (admissionPayment != null) {
        final status = await _feeRepo.computeFeeStatus(studentId);
        await _studentRepo.updateFeeStatusCache(studentId, status);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_nameCtrl.text.trim()} admitted successfully!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true); // true → student list refreshes
    } catch (e) {
      setState(() => _saving = false);
      _showError('Failed to save: $e');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Validation Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Dispose ──────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fatherCtrl.dispose();
    _motherCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _rollCtrl.dispose();
    _monthlyAmtCtrl.dispose();
    _dueDayCtrl.dispose();
    _durationCtrl.dispose();
    _courseFeeCtrl.dispose();
    _agreedFeeCtrl.dispose();
    _admissionPaymentCtrl.dispose();
    _admissionRemarksCtrl.dispose();
    for (final e in _installments) {
      e.dispose();
    }
    super.dispose();
  }

  // ╔══════════════════════════════════════════════════════════════════════╗
  // ║  BUILD                                                               ║
  // ╚══════════════════════════════════════════════════════════════════════╝

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Admission')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            children: [
              _buildPhotoSection(theme),
              const SizedBox(height: 16),
              _buildPersonalSection(theme),
              const SizedBox(height: 16),
              _buildAcademicSection(theme),
              const SizedBox(height: 16),
              _buildFeeSection(theme),
              const SizedBox(height: 16),
              _buildAdmissionPaymentSection(theme),
              const SizedBox(height: 24),
              _buildSaveButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Builders ─────────────────────────────────────────────────

  Widget _buildSectionHeader(
    ThemeData theme,
    IconData icon,
    String title,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  // ── 0. Photo Section ─────────────────────────────────────────────────

  Widget _buildPhotoSection(ThemeData theme) {
    return _buildCard(
      child: Column(
        children: [
          _buildSectionHeader(
            theme,
            Icons.add_a_photo,
            'Student Photo',
            Colors.indigo,
          ),
          const SizedBox(height: 20),
          ProfilePhotoWidget(
            previewFile: _tempPhotoFile,
            fallbackLetter: _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : 'S',
            radius: 50,
            isEditable: true,
            onPhotoSelected: (File file) {
              setState(() {
                _tempPhotoFile = file;
              });
            },
            onPhotoRemoved: () {
              setState(() {
                _tempPhotoFile = null;
              });
            },
          ),
          const SizedBox(height: 10),
          Text(
            _tempPhotoFile != null ? 'Photo selected' : 'No photo selected (Optional)',
            style: TextStyle(
              color: _tempPhotoFile != null ? Colors.green : Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Personal Information ──────────────────────────────────────────

  Widget _buildPersonalSection(ThemeData theme) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              theme, Icons.person, 'Personal Information', Colors.blue),
          const SizedBox(height: 20),

          _field(
            controller: _nameCtrl,
            label: 'Student Name *',
            icon: Icons.person_outline,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          _field(
            controller: _fatherCtrl,
            label: "Father's Name *",
            icon: Icons.man,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),

          _field(
            controller: _motherCtrl,
            label: "Mother's Name",
            icon: Icons.woman,
          ),
          const SizedBox(height: 14),

          _field(
            controller: _mobileCtrl,
            label: 'Mobile Number *',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.trim().length != 10) return 'Enter a valid 10-digit number';
              return null;
            },
          ),
          const SizedBox(height: 14),

          _field(
            controller: _addressCtrl,
            label: 'Address',
            icon: Icons.home_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ── 2. Academic Information ──────────────────────────────────────────

  Widget _buildAcademicSection(ThemeData theme) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              theme, Icons.school, 'Academic Information', Colors.indigo),
          const SizedBox(height: 20),

          // Board
          DropdownButtonFormField<String>(
            initialValue: _board,
            decoration: const InputDecoration(
              labelText: 'Board *',
              prefixIcon: Icon(Icons.account_balance),
            ),
            items: _boardsList
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _board = v!),
          ),
          const SizedBox(height: 14),

          // Class
          DropdownButtonFormField<String>(
            initialValue: _studentClass,
            decoration: const InputDecoration(
              labelText: 'Class *',
              prefixIcon: Icon(Icons.class_),
            ),
            items: _classesList
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c == 'Other' ? 'Other' : (c.startsWith('Class') ? c : 'Class $c')),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _studentClass = v!),
          ),
          const SizedBox(height: 14),

          // Roll No
          _field(
            controller: _rollCtrl,
            label: 'Roll Number *',
            icon: Icons.confirmation_number,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (int.tryParse(v.trim()) == null) return 'Must be a number';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ── 3. Fee & Payment Information ─────────────────────────────────────

  Widget _buildFeeSection(ThemeData theme) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              theme, Icons.payments, 'Fee & Payment Information', Colors.teal),
          const SizedBox(height: 20),

          // Payment method toggle
          Text(
            'Payment Method',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MethodButton(
                  label: 'Installments',
                  icon: Icons.account_balance_wallet,
                  selected: _paymentMethod == 'Installments',
                  onTap: () => setState(() => _paymentMethod = 'Installments'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodButton(
                  label: 'Monthly',
                  icon: Icons.calendar_month,
                  selected: _paymentMethod == 'Monthly',
                  onTap: () => setState(() => _paymentMethod = 'Monthly'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Dynamic fee fields
          if (_paymentMethod == 'Monthly')
            _buildMonthlyFields(theme)
          else
            _buildInstallmentFields(theme),
        ],
      ),
    );
  }

  // ── Monthly fields ───────────────────────────────────────────────────

  Widget _buildMonthlyFields(ThemeData theme) {
    final preview = _generateMonthlyPreview();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Monthly fee amount
        _field(
          controller: _monthlyAmtCtrl,
          label: 'Monthly Fee Amount (₹) *',
          icon: Icons.currency_rupee,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            final n = double.tryParse(v.trim());
            if (n == null || n <= 0) return 'Must be > 0';
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),

        // Payment due day
        _field(
          controller: _dueDayCtrl,
          label: 'Payment Due Day (1–28) *',
          icon: Icons.event,
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            final n = int.tryParse(v.trim());
            if (n == null || n < 1 || n > 28) return 'Enter 1–28';
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),

        // Start month picker
        GestureDetector(
          onTap: _pickStartMonth,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Start Month *',
              prefixIcon: Icon(Icons.date_range),
            ),
            child: Text(_displayMonth(_startMonth)),
          ),
        ),
        const SizedBox(height: 14),

        // Duration months
        _field(
          controller: _durationCtrl,
          label: 'Duration (Months) *',
          icon: Icons.timelapse,
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            final n = int.tryParse(v.trim());
            if (n == null || n < 1) return 'Must be ≥ 1';
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),

        // Total fee summary
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildMonthlyTotal(preview),
        ],

        // Preview schedule
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMonthlyPreviewTable(preview, theme),
        ],
      ],
    );
  }

  Widget _buildMonthlyTotal(List<_MonthPreview> preview) {
    final total = preview.fold(0.0, (s, e) => s + e.amount);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize, color: Colors.teal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${preview.length} months × '
              '₹${(double.tryParse(_monthlyAmtCtrl.text) ?? 0).toStringAsFixed(0)} = '
              '₹${total.toStringAsFixed(0)} total',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.teal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyPreviewTable(
      List<_MonthPreview> preview, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: Text(
                    'Month',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  'Due Date',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 14),
                SizedBox(
                  width: 70,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Show max 6 months in preview; user can scroll
          SizedBox(
            height: (preview.length > 6 ? 6 : preview.length) * 44.0,
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: preview.length > 6 ? 6 : preview.length,
              itemBuilder: (_, i) {
                final m = preview[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Month ${i + 1}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        _displayDate(m.dueDate),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 70,
                        child: Text(
                          '₹${m.amount.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (preview.length > 6)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                '+ ${preview.length - 6} more months…',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Installment fields ───────────────────────────────────────────────

  Widget _buildInstallmentFields(ThemeData theme) {
    final agreedFee = _agreedFee;
    final total = _installmentTotal;
    final valid = _installmentTotalValid && agreedFee > 0;
    final diff = (total - agreedFee).abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Course / catalogue fee
        _field(
          controller: _courseFeeCtrl,
          label: 'Standard / Course Fee (₹)',
          icon: Icons.school,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          helperText: 'Nominal fee before any discount (optional)',
          validator: (v) {
            if (v != null && v.trim().isNotEmpty) {
              final n = double.tryParse(v.trim());
              if (n == null || n <= 0) return 'Must be > 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        // Final agreed fee
        _field(
          controller: _agreedFeeCtrl,
          label: 'Final Agreed Fee (₹) *',
          icon: Icons.handshake,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          helperText: 'Actual amount the student will pay',
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            final n = double.tryParse(v.trim());
            if (n == null || n <= 0) return 'Must be > 0';
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),

        // Instalment schedule header
        Row(
          children: [
            const Text(
              'Instalment Schedule',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addInstallment,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Instalment rows
        ..._installments.asMap().entries.map(
              (entry) => _buildInstallmentRow(entry.key, entry.value, theme),
            ),

        const SizedBox(height: 16),

        // Total validation banner
        _buildInstallmentTotalBanner(
            valid, total, agreedFee, diff, theme),
      ],
    );
  }

  Widget _buildInstallmentRow(
    int index,
    _InstallmentEntry entry,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: entry.descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label (optional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_installments.length > 1)
                IconButton(
                  onPressed: () => _removeInstallment(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove instalment',
                ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: entry.amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹) *',
                    prefixIcon: Icon(Icons.currency_rupee, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be > 0';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickInstallmentDate(index),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due Date *',
                      prefixIcon: Icon(Icons.event, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _displayDate(entry.dueDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentTotalBanner(
    bool valid,
    double total,
    double agreedFee,
    double diff,
    ThemeData theme,
  ) {
    if (agreedFee <= 0) return const SizedBox.shrink();

    final color = valid ? Colors.green : Colors.red;
    final bgColor = valid ? Colors.green.shade50 : Colors.red.shade50;
    final icon = valid ? Icons.check_circle : Icons.error_outline;
    final label = valid
        ? 'Total matches Final Agreed Fee (₹${total.toStringAsFixed(0)})'
        : 'Total: ₹${total.toStringAsFixed(0)} | '
            'Needed: ₹${agreedFee.toStringAsFixed(0)} | '
            'Diff: ₹${diff.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Admission Payment ─────────────────────────────────────────────

  Widget _buildAdmissionPaymentSection(ThemeData theme) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            Icons.receipt_long,
            'Admission Payment',
            Colors.orange,
          ),
          const SizedBox(height: 6),
          Text(
            'Optionally record an actual payment made today.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),

          SwitchListTile.adaptive(
            value: _recordAdmissionPayment,
            onChanged: (v) =>
                setState(() => _recordAdmissionPayment = v),
            title: const Text('Record payment received now'),
            contentPadding: EdgeInsets.zero,
          ),

          if (_recordAdmissionPayment) ...[
            const SizedBox(height: 14),
            _field(
              controller: _admissionPaymentCtrl,
              label: 'Amount Received (₹) *',
              icon: Icons.currency_rupee,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _recordAdmissionPayment
                  ? (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = double.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Must be > 0';
                      return null;
                    }
                  : null,
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _admissionPaymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
                prefixIcon: Icon(Icons.payment),
              ),
              items: AppConstants.paymentModes
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _admissionPaymentMode = v!),
            ),
            const SizedBox(height: 14),

            _field(
              controller: _admissionRemarksCtrl,
              label: 'Remarks (optional)',
              icon: Icons.notes,
            ),
          ],
        ],
      ),
    );
  }

  // ── Save Button ──────────────────────────────────────────────────────

  Widget _buildSaveButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(Icons.how_to_reg),
        label: Text(
          _saving ? 'Saving…' : 'Complete Admission',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Shared field helper ──────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        helperText: helperText,
        helperMaxLines: 2,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Helper classes (private to this file)
// ════════════════════════════════════════════════════════════════════════

/// Editable state for one row in the installment schedule.
class _InstallmentEntry {
  TextEditingController amtCtrl;
  DateTime dueDate;
  TextEditingController descCtrl;

  _InstallmentEntry({
    required this.amtCtrl,
    required this.dueDate,
    required this.descCtrl,
  });

  void dispose() {
    amtCtrl.dispose();
    descCtrl.dispose();
  }
}

/// Preview data for one monthly schedule row.
class _MonthPreview {
  final DateTime dueDate;
  final double amount;

  _MonthPreview({required this.dueDate, required this.amount});
}

/// Extends List<_MonthPreview> — removed (not needed)

/// Payment method toggle button.
class _MethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.grey.shade600,
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}