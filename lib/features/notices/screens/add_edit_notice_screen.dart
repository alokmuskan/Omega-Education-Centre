import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../models/notice_model.dart';
import '../repository/notice_repository.dart';
import '../../../shared/utils/app_session.dart';

/// Screen for creating or editing institute notices and announcements.
class AddEditNoticeScreen extends StatefulWidget {
  final NoticeModel? initialNotice;

  const AddEditNoticeScreen({
    super.key,
    this.initialNotice,
  });

  @override
  State<AddEditNoticeScreen> createState() => _AddEditNoticeScreenState();
}

class _AddEditNoticeScreenState extends State<AddEditNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = NoticeRepository();

  late TextEditingController _titleController;
  late TextEditingController _messageController;
  late String _noticeType;
  late String _targetRole;
  late String _targetClass;
  late String _targetBoard;
  late TextEditingController _batchController;
  late String _priority;
  bool _isPublished = true;
  DateTime _publishDate = DateTime.now();
  DateTime? _expiryDate;

  bool _isSaving = false;
  bool get _isEditMode => widget.initialNotice != null;

  static const List<String> noticeTypes = [
    'General',
    'Academic',
    'Examination',
    'Fee',
    'Holiday',
    'Class',
    'Event',
    'Emergency',
    'Other',
  ];

  static const List<String> targetRoles = [
    'Everyone',
    'Students',
    'Teachers',
    'Specific Class',
    'Specific Batch',
  ];

  static const List<String> priorities = [
    'Normal',
    'Important',
    'Urgent',
  ];

  @override
  void initState() {
    super.initState();
    final n = widget.initialNotice;
    if (n != null) {
      _titleController = TextEditingController(text: n.title);
      _messageController = TextEditingController(text: n.message);
      _noticeType = noticeTypes.contains(n.noticeType) ? n.noticeType : 'General';
      _targetRole = targetRoles.contains(n.targetRole) ? n.targetRole : 'Everyone';
      _targetClass = n.targetClass ?? 'All';
      _targetBoard = n.targetBoard ?? 'All';
      _batchController = TextEditingController(text: n.targetBatch ?? '');
      _priority = n.priority;
      _isPublished = n.isPublished;
      _publishDate = DateTime.tryParse(n.publishDate) ?? DateTime.now();
      _expiryDate = n.expiryDate != null ? DateTime.tryParse(n.expiryDate!) : null;
    } else {
      _titleController = TextEditingController();
      _messageController = TextEditingController();
      _noticeType = 'General';
      _targetRole = 'Everyone';
      _targetClass = 'All';
      _targetBoard = 'All';
      _batchController = TextEditingController();
      _priority = 'Normal';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _batchController.dispose();
    super.dispose();
  }

  Future<void> _pickPublishDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _publishDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _publishDate = picked);
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? _publishDate.add(const Duration(days: 7)),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _saveNotice() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_targetRole == 'Specific Class' && (_targetClass == 'All' || _targetClass.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a specific class for "Specific Class" target audience.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_targetRole == 'Specific Batch' && _batchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a target batch name.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Expiry date >= publish date validation
    if (_expiryDate != null) {
      final pubNorm = DateTime(_publishDate.year, _publishDate.month, _publishDate.day);
      final expNorm = DateTime(_expiryDate!.year, _expiryDate!.month, _expiryDate!.day);
      if (expNorm.isBefore(pubNorm)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expiry date cannot be before publish date.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final pDateStr = DateFormat('yyyy-MM-dd').format(_publishDate);
      final eDateStr = _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null;

      final notice = NoticeModel(
        id: widget.initialNotice?.id,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        noticeType: _noticeType,
        targetRole: _targetRole,
        targetClass: _targetClass == 'All' ? null : _targetClass,
        targetBoard: _targetBoard,
        targetBatch: _batchController.text.trim().isNotEmpty ? _batchController.text.trim() : null,
        publishDate: pDateStr,
        expiryDate: eDateStr,
        priority: _priority,
        isPublished: _isPublished,
        isActive: widget.initialNotice?.isActive ?? true,
        createdAt: widget.initialNotice?.createdAt,
      );

      if (_isEditMode) {
        await _repository.updateNotice(notice);
      } else {
        await _repository.insertNotice(notice);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Notice updated successfully.' : 'Notice saved successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save notice: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.instance.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: Administrator privileges required.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Notice' : 'Add Notice'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Notice Title *',
                  hintText: 'e.g. Mathematics Unit Test Date Sheet',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.campaign),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
              ),

              const SizedBox(height: 16),

              // Notice Message
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notice Message / Description *',
                  hintText: 'Enter complete announcement content...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.article),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Message is required' : null,
              ),

              const SizedBox(height: 16),

              // Notice Category & Priority Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _noticeType,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: noticeTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _noticeType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.priority_high),
                      ),
                      items: priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _priority = val);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Target Audience Selection
              DropdownButtonFormField<String>(
                initialValue: _targetRole,
                decoration: const InputDecoration(
                  labelText: 'Target Audience *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                items: targetRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _targetRole = val);
                },
              ),

              const SizedBox(height: 16),

              // Target Class / Target Batch conditional fields
              if (_targetRole == 'Students' || _targetRole == 'Specific Class' || _targetRole == 'Everyone')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _targetClass,
                    decoration: InputDecoration(
                      labelText: _targetRole == 'Specific Class' ? 'Specific Class *' : 'Target Class',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.school),
                    ),
                    items: AppConstants.classesWithAll.map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Classes' : 'Class $c'))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _targetClass = val);
                    },
                  ),
                ),

              if (_targetRole == 'Specific Batch' || _targetRole == 'Students' || _targetRole == 'Everyone')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _batchController,
                    decoration: InputDecoration(
                      labelText: _targetRole == 'Specific Batch' ? 'Specific Batch Name *' : 'Target Batch (Optional)',
                      hintText: 'e.g. Udaan Batch',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.groups),
                    ),
                  ),
                ),

              // Target Board
              DropdownButtonFormField<String>(
                initialValue: _targetBoard,
                decoration: const InputDecoration(
                  labelText: 'Target Board',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
                items: AppConstants.boardsWithAll.map((b) => DropdownMenuItem(value: b, child: Text(b == 'All' ? 'All Boards' : b))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _targetBoard = val);
                },
              ),

              const SizedBox(height: 16),

              // Publish Date & Expiry Date Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickPublishDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Publish Date *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event),
                        ),
                        child: Text(DateFormat('dd MMM yyyy').format(_publishDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickExpiryDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Expiry Date',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.event_busy),
                          suffixIcon: _expiryDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _expiryDate = null),
                                )
                              : null,
                        ),
                        child: Text(
                          _expiryDate != null ? DateFormat('dd MMM yyyy').format(_expiryDate!) : 'No Expiry',
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Published Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish Immediately', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Unchecking saves notice as draft (unpublished).'),
                value: _isPublished,
                onChanged: (val) => setState(() => _isPublished = val),
              ),

              const SizedBox(height: 24),

              // Save Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isSaving ? null : _saveNotice,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSaving
                            ? 'Saving...'
                            : _isEditMode
                                ? 'Update Notice'
                                : _isPublished
                                    ? 'Publish Notice'
                                    : 'Save Draft',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
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
}
