import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/app_session.dart';
import '../models/notice_model.dart';
import '../repository/notice_repository.dart';
import 'add_edit_notice_screen.dart';
import 'notice_details_screen.dart';

/// Role-based screen for Notice & Announcement Board with per-user read tracking.
class NoticeManagementScreen extends StatefulWidget {
  const NoticeManagementScreen({super.key});

  @override
  State<NoticeManagementScreen> createState() => _NoticeManagementScreenState();
}

class _NoticeManagementScreenState extends State<NoticeManagementScreen> {
  final _repository = NoticeRepository();
  final TextEditingController _searchController = TextEditingController();

  List<NoticeModel> _notices = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedStatus = 'All'; // 'All', 'Published', 'Draft', 'Expired', 'Archived'
  String _selectedType = 'All';
  String _selectedPriority = 'All';

  String get _currentUserId {
    if (AppSession.instance.isTeacher) {
      return 'teacher_${AppSession.instance.currentTeacherId ?? AppSession.instance.currentUsername}';
    } else if (AppSession.instance.isStudent) {
      return 'student_${AppSession.instance.currentStudentId ?? AppSession.instance.currentUsername}';
    }
    return 'admin_${AppSession.instance.currentUsername}';
  }

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotices({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      List<NoticeModel> list = [];
      final query = _searchController.text.trim();

      if (AppSession.instance.isAdmin) {
        list = await _repository.getAllNoticesAdmin(
          searchQuery: query,
          noticeType: _selectedType,
          priority: _selectedPriority,
          filterStatus: _selectedStatus,
        );
        final readIds = await _repository.getReadNoticeIdsForUser(_currentUserId);
        list = list.map((n) => n.copyWith(isRead: readIds.contains(n.id))).toList();
      } else if (AppSession.instance.isTeacher) {
        list = await _repository.getNoticesForRole(
          'Teacher',
          userId: _currentUserId,
        );
      } else {
        final sClass = AppSession.instance.currentStudentModel?.studentClass;
        final sBoard = AppSession.instance.currentStudentModel?.board;
        list = await _repository.getNoticesForRole(
          'Student',
          studentClass: sClass,
          board: sBoard,
          userId: _currentUserId,
        );
      }

      // In-memory search for non-admin search
      if (!AppSession.instance.isAdmin && query.isNotEmpty) {
        final q = query.toLowerCase();
        list = list.where((n) => n.title.toLowerCase().contains(q) || n.message.toLowerCase().contains(q) || n.category.toLowerCase().contains(q)).toList();
      }

      // Non-admin Category/Priority filtering
      if (!AppSession.instance.isAdmin) {
        if (_selectedType != 'All') {
          list = list.where((n) => n.category == _selectedType).toList();
        }
        if (_selectedPriority != 'All') {
          list = list.where((n) => n.priority == _selectedPriority).toList();
        }
      }

      if (mounted) {
        setState(() {
          _notices = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notices: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openNoticeDetails(NoticeModel notice) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoticeDetailsScreen(notice: notice)),
    );
    if (updated == true || !AppSession.instance.isAdmin) {
      _loadNotices(silent: true);
    }
  }

  Future<void> _openAddNoticeScreen() async {
    if (!AppSession.instance.isAdmin) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditNoticeScreen()),
    );

    if (updated == true) {
      _loadNotices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = AppSession.instance.isAdmin ? 'Notice Board Management' : 'Notice Board';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notices...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadNotices();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (_) => _loadNotices(),
            ),
          ),

          // Admin Status Chips Filter
          if (AppSession.instance.isAdmin)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: ['All', 'Published', 'Draft', 'Expired', 'Archived'].map((st) {
                  final selected = _selectedStatus == st;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      label: Text(st),
                      onSelected: (val) {
                        setState(() => _selectedStatus = st);
                        _loadNotices();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          // Category & Priority Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Categories')),
                      DropdownMenuItem(value: 'General', child: Text('General')),
                      DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                      DropdownMenuItem(value: 'Examination', child: Text('Examination')),
                      DropdownMenuItem(value: 'Fee', child: Text('Fee')),
                      DropdownMenuItem(value: 'Holiday', child: Text('Holiday')),
                      DropdownMenuItem(value: 'Class', child: Text('Class')),
                      DropdownMenuItem(value: 'Event', child: Text('Event')),
                      DropdownMenuItem(value: 'Emergency', child: Text('Emergency')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedType = val);
                        _loadNotices();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Priorities')),
                      DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'Important', child: Text('Important')),
                      DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedPriority = val);
                        _loadNotices();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Main Notices List
          Expanded(
            child: _isLoading
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
                            ElevatedButton(onPressed: _loadNotices, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _notices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_off, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  AppSession.instance.isAdmin ? 'No Notices Found' : 'No Notices Available For You',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppSession.instance.isAdmin ? 'Create your first announcement using the button below.' : 'You have no active announcements at this time.',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadNotices,
                            child: ListView.builder(
                              key: const PageStorageKey<String>('notice_list_scroll_key'),
                              padding: const EdgeInsets.all(16),
                              itemCount: _notices.length,
                              itemBuilder: (context, index) {
                                final notice = _notices[index];
                                return _buildNoticeCard(notice);
                              },
                            ),
                          ),
          ),
        ],
      ),

      floatingActionButton: AppSession.instance.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openAddNoticeScreen,
              icon: const Icon(Icons.add_alert),
              label: const Text('Create Notice'),
            )
          : null,
    );
  }

  Widget _buildNoticeCard(NoticeModel notice) {
    final isUrgent = notice.priority == 'Urgent';
    final isImportant = notice.priority == 'Important';

    Color bannerColor = Colors.blue.shade700;
    Color cardBg = Colors.white;

    if (isUrgent) {
      bannerColor = Colors.red.shade700;
      cardBg = Colors.red.shade50;
    } else if (isImportant) {
      bannerColor = Colors.orange.shade800;
      cardBg = Colors.orange.shade50;
    }

    String pDateFormatted = notice.publishDate;
    try {
      pDateFormatted = DateFormat('dd MMM yyyy').format(DateTime.parse(notice.publishDate));
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUrgent
            ? BorderSide(color: Colors.red.shade300, width: 1.5)
            : isImportant
                ? BorderSide(color: Colors.orange.shade300, width: 1)
                : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openNoticeDetails(notice),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bannerColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      notice.category.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isUrgent || isImportant)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isUrgent ? Colors.red.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        notice.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isUrgent ? Colors.red.shade900 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (!AppSession.instance.isAdmin && !notice.isRead)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'UNREAD',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    pDateFormatted,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                notice.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: notice.isRead ? FontWeight.w600 : FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                notice.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.grey.shade200,
                        label: Text('Target: ${notice.targetAudience}', style: const TextStyle(fontSize: 10)),
                      ),
                      if (notice.targetClass != null && notice.targetClass!.isNotEmpty)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.grey.shade200,
                          label: Text('Class ${notice.targetClass}', style: const TextStyle(fontSize: 10)),
                        ),
                      if (notice.targetBatch != null && notice.targetBatch!.isNotEmpty)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.amber.shade100,
                          label: Text('Batch: ${notice.targetBatch}', style: TextStyle(fontSize: 10, color: Colors.amber.shade900)),
                        ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      Icon(Icons.chevron_right, size: 18, color: Colors.indigo),
                    ],
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
