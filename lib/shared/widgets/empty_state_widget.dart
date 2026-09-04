import 'package:flutter/material.dart';

/// Reusable empty state widget with icon, title, subtitle, and optional CTA.
///
/// Usage:
///   if (items.isEmpty) EmptyStateWidget(
///     icon: Icons.school_outlined,
///     title: 'No students enrolled yet',
///     subtitle: 'Tap + to add the first student',
///     actionLabel: 'Add Student',
///     onAction: () => Navigator.push(...),
///   )
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 72,
    this.iconColor,
  });

  // ── Preset Constructors ────────────────────────────────────────

  /// No students enrolled yet.
  const EmptyStateWidget.noStudents({VoidCallback? onAdd, Key? key})
      : this(
          key: key,
          icon: Icons.school_outlined,
          title: 'No students enrolled yet',
          subtitle: 'Tap the button below to add your first student',
          actionLabel: 'Add Student',
          onAction: onAdd,
        );

  /// No teachers added yet.
  const EmptyStateWidget.noTeachers({VoidCallback? onAdd, Key? key})
      : this(
          key: key,
          icon: Icons.person_add_outlined,
          title: 'No teachers added yet',
          subtitle: 'Tap the button below to add your first faculty member',
          actionLabel: 'Add Teacher',
          onAction: onAdd,
        );

  /// No notices available.
  const EmptyStateWidget.noNotices({Key? key})
      : this(
          key: key,
          icon: Icons.campaign_outlined,
          title: 'No notices yet',
          subtitle: 'Announcements and notices will appear here',
        );

  /// No tests created.
  const EmptyStateWidget.noTests({VoidCallback? onCreate, Key? key})
      : this(
          key: key,
          icon: Icons.quiz_outlined,
          title: 'No tests found',
          subtitle: 'Create a test to start recording student results',
          actionLabel: 'Create Test',
          onAction: onCreate,
        );

  /// No timetable entries.
  const EmptyStateWidget.noTimetable({Key? key})
      : this(
          key: key,
          icon: Icons.table_chart_outlined,
          title: 'No timetable entries',
          subtitle: 'Add timetable entries to schedule classes',
        );

  /// No fee records.
  const EmptyStateWidget.noFeeRecords({Key? key})
      : this(
          key: key,
          icon: Icons.receipt_long_outlined,
          title: 'No fee records',
          subtitle: 'Fee records will appear here once students are enrolled',
        );

  /// No attendance records.
  const EmptyStateWidget.noAttendance({String? detail, Key? key})
      : this(
          key: key,
          icon: Icons.event_available_outlined,
          title: 'No attendance records',
          subtitle: detail ?? 'Attendance data will appear here',
        );

  /// No salary records.
  const EmptyStateWidget.noSalaryRecords({Key? key})
      : this(
          key: key,
          icon: Icons.payments_outlined,
          title: 'No salary records',
          subtitle: 'Teacher salary summaries will appear here',
        );

  /// No audit logs.
  const EmptyStateWidget.noAuditLogs({Key? key})
      : this(
          key: key,
          icon: Icons.history,
          title: 'No audit logs',
          subtitle: 'Financial transaction history will appear here',
        );

  /// No search results.
  const EmptyStateWidget.noSearchResults({Key? key})
      : this(
          key: key,
          icon: Icons.search_off,
          title: 'No results found',
          subtitle: 'Try adjusting your search or filters',
        );

  /// Generic no data.
  const EmptyStateWidget.noData({String? message, Key? key})
      : this(
          key: key,
          icon: Icons.inbox_outlined,
          title: 'No data available',
          subtitle: message,
        );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = iconColor ??
        (isDark ? Colors.grey.shade500 : Colors.grey.shade400);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with subtle background circle
            Container(
              width: iconSize + 32,
              height: iconSize + 32,
              decoration: BoxDecoration(
                color: effectiveIconColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: effectiveIconColor,
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),

            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],

            // CTA Button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
