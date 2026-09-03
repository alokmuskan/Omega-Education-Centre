import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_class_record_model.dart';
import '../repository/daily_class_record_repository.dart';
import '../screens/add_edit_class_record_screen.dart';

/// Modal dialog displaying full details for a single Daily Class Record.
///
/// Provides Edit and Delete actions.
class ClassRecordDetailsDialog extends StatelessWidget {
  final DailyClassRecordModel record;

  const ClassRecordDetailsDialog({
    super.key,
    required this.record,
  });

  String _formatDate(String dateIso) {
    try {
      final dt = DateTime.parse(dateIso);
      return DateFormat('EEEE, dd MMMM yyyy').format(dt);
    } catch (_) {
      return dateIso;
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class Record?'),
        content: const Text(
          'This class record will be permanently deleted from the daily class register.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = DailyClassRecordRepository();
      await repo.deleteRecord(record.id!);

      if (!context.mounted) return;
      Navigator.pop(context, true); // Pop details dialog with true

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class record deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting class record: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleEdit(BuildContext context) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditClassRecordScreen(initialRecord: record),
      ),
    );

    if (updated == true && context.mounted) {
      Navigator.pop(context, true); // Pop details dialog with true to refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teacherDisplayName = record.teacherName ?? 'Teacher ID #${record.teacherId}';

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${record.subject} — Class ${record.studentClass}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(record.date),
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),

      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow(Icons.school, 'Class & Board', 'Class ${record.studentClass} (${record.board})'),
            if (record.batch != null && record.batch!.isNotEmpty)
              _detailRow(Icons.groups, 'Batch', record.batch!),
            _detailRow(Icons.person, 'Teacher', teacherDisplayName),
            _detailRow(Icons.book, 'Subject', record.subject),

            if (record.startTime != null || record.endTime != null)
              _detailRow(
                Icons.access_time,
                'Class Time',
                '${record.startTime ?? "N/A"} – ${record.endTime ?? "N/A"} (${record.formattedDuration})',
              )
            else
              _detailRow(Icons.timer, 'Duration', record.formattedDuration),

            const Divider(height: 20),

            _detailBlock('Topic Covered', record.topic, isRequired: true),

            if (record.homework != null && record.homework!.isNotEmpty)
              _detailBlock('Homework / Assignment', record.homework!),

            if (record.remarks != null && record.remarks!.isNotEmpty)
              _detailBlock('Remarks', record.remarks!),
          ],
        ),
      ),

      actions: [
        TextButton.icon(
          onPressed: () => _handleDelete(context),
          icon: const Icon(Icons.delete, color: Colors.red),
          label: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton.icon(
          onPressed: () => _handleEdit(context),
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBlock(String title, String content, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              content,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
