import 'package:flutter/material.dart';

import '../../notices/screens/notice_management_screen.dart';

/// Dashboard Notices Section
///
/// Displays recent notices with priority indicators.
class DashboardNoticesSection extends StatelessWidget {
  final List<dynamic> notices;
  final VoidCallback? onViewAll;

  const DashboardNoticesSection({
    super.key,
    required this.notices,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Notices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: onViewAll ?? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NoticeManagementScreen()),
                );
              },
              child: const Text("View All"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        notices.isEmpty
            ? _buildEmptyState()
            : Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final notice = notices[idx];
                    final isUrgent = notice.priority == 'Urgent' || notice.priority == 'Important';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isUrgent ? const Color(0xFFFFEBEE) : const Color(0xFFFFFDE7),
                        child: Icon(
                          Icons.campaign,
                          color: isUrgent ? Colors.red : Colors.orange,
                        ),
                      ),
                      title: Text(
                        notice.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Target: ${notice.targetRole}\nPublished: ${notice.publishDate}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No active notices published.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }
}
