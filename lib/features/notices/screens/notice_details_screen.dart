import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/app_session.dart';
import '../models/notice_model.dart';
import '../repository/notice_repository.dart';
import 'add_edit_notice_screen.dart';
import 'notice_read_status_screen.dart';

/// Screen displaying complete details of a selected notice.
/// Automatically marks notice as read when opened by a Student or Teacher.
class NoticeDetailsScreen extends StatefulWidget {
  final NoticeModel notice;

  const NoticeDetailsScreen({super.key, required this.notice});

  @override
  State<NoticeDetailsScreen> createState() => _NoticeDetailsScreenState();
}

class _NoticeDetailsScreenState extends State<NoticeDetailsScreen> {
  final NoticeRepository _repository = NoticeRepository();
  late NoticeModel _notice;

  @override
  void initState() {
    super.initState();
    _notice = widget.notice;
    _autoMarkReadIfNeeded();
  }

  Future<void> _autoMarkReadIfNeeded() async {
    final session = AppSession.instance;
    if (session.isAdmin || _notice.id == null) return;

    final String userId = session.isStudent
        ? 'student_${session.currentStudentModel?.id ?? 0}'
        : session.isTeacher
            ? 'teacher_${session.currentTeacherModel?.id ?? 0}'
            : session.currentUsername;

    if (userId.isEmpty) return;

    await _repository.markNoticeAsRead(_notice.id!, userId);
    if (!mounted) return;
    setState(() {
      _notice = _notice.copyWith(isRead: true);
    });
  }

  Future<void> _toggleArchive() async {
    if (_notice.id == null) return;
    final newArchivedState = !_notice.isArchived;
    await _repository.toggleArchiveStatus(_notice.id!, newArchivedState);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newArchivedState ? 'Notice archived.' : 'Notice unarchived.'),
        backgroundColor: Colors.indigo,
      ),
    );
    setState(() {
      _notice = _notice.copyWith(isActive: !newArchivedState);
    });
  }

  Future<void> _deleteNotice() async {
    if (_notice.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text('Are you sure you want to permanently delete this notice? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteNotice(_notice.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notice deleted successfully.'), backgroundColor: Colors.red),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AppSession.instance.isAdmin;

    String pubDateFormatted = _notice.publishDate;
    try {
      final dt = DateTime.parse(_notice.publishDate);
      pubDateFormatted = DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {}

    String expDateFormatted = _notice.expiryDate ?? 'No expiry';
    if (_notice.expiryDate != null && _notice.expiryDate!.isNotEmpty) {
      try {
        final dt = DateTime.parse(_notice.expiryDate!);
        expDateFormatted = DateFormat('dd MMM yyyy').format(dt);
      } catch (_) {}
    }

    Color priorityColor = Colors.blue;
    if (_notice.priority == 'Urgent') {
      priorityColor = Colors.red;
    } else if (_notice.priority == 'Important') {
      priorityColor = Colors.orange;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Details'),
        centerTitle: true,
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'Read Status Analytics',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoticeReadStatusScreen(notice: _notice),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Notice',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditNoticeScreen(initialNotice: _notice),
                  ),
                );
                if (updated == true && mounted) {
                  final refreshed = await _repository.getNoticeById(_notice.id!);
                  if (refreshed != null && mounted) {
                    setState(() => _notice = refreshed);
                  }
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'archive') {
                  _toggleArchive();
                } else if (val == 'delete') {
                  _deleteNotice();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Text(_notice.isArchived ? 'Unarchive Notice' : 'Archive Notice'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Notice', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Priority Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: priorityColor),
                  ),
                  child: Text(
                    _notice.priority.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: priorityColor, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(_notice.category),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                if (!isAdmin)
                  Row(
                    children: [
                      Icon(
                        _notice.isRead ? Icons.check_circle : Icons.circle_notifications,
                        color: _notice.isRead ? Colors.green : Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _notice.isRead ? 'Read' : 'Unread',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _notice.isRead ? Colors.green.shade800 : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              _notice.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // Notice Information Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_outline, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Target Audience: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Expanded(
                          child: Text(
                            '${_notice.targetAudience}${_notice.targetClass != null && _notice.targetClass!.isNotEmpty ? ' (${_notice.targetClass})' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Publish Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(pubDateFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.event_busy, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Expiry Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(expDateFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Notice Message Body
            const Text(
              'ANNOUNCEMENT DETAILS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _notice.message,
                style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
            ),

            const SizedBox(height: 24),

            if (isAdmin)
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NoticeReadStatusScreen(notice: _notice),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('View Read Status Analytics'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
