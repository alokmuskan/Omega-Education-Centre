import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';

/// In-app notification center showing all notifications with read/unread status.
/// Also displays FCM push notification status.
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  bool _showPushStatus = false;

  @override
  void initState() {
    super.initState();
    _notificationService.loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notificationService.notifications;
    final pushEnabled = _notificationService.isPushEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          // Push notification status chip
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _showPushStatus = !_showPushStatus),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pushEnabled ? Colors.green.withAlpha(30) : Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pushEnabled ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pushEnabled ? Icons.notifications_active : Icons.notifications_off,
                      size: 14,
                      color: pushEnabled ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pushEnabled ? 'Push ON' : 'Push OFF',
                      style: TextStyle(
                        fontSize: 11,
                        color: pushEnabled ? Colors.green.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (notifications.isNotEmpty) ...[
            TextButton(
              onPressed: () async {
                await _notificationService.markAllAsRead();
                setState(() {});
              },
              child: const Text('Read All', style: TextStyle(color: Colors.white70)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear All',
              onPressed: () async {
                await _notificationService.clearAll();
                setState(() {});
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Push notification status panel
          if (_showPushStatus) _buildPushStatusPanel(pushEnabled),

          // Notification list
          Expanded(
            child: notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No notifications', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        const SizedBox(height: 8),
                        if (!pushEnabled)
                          Text(
                            'Push notifications are disabled',
                            style: TextStyle(color: Colors.orange.shade400, fontSize: 12),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return _buildNotificationTile(n);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds the push notification status panel.
  Widget _buildPushStatusPanel(bool pushEnabled) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: pushEnabled ? Colors.green.withAlpha(15) : Colors.orange.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: pushEnabled ? Colors.green.withAlpha(50) : Colors.orange.withAlpha(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pushEnabled ? Icons.check_circle : Icons.warning,
                size: 18,
                color: pushEnabled ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                pushEnabled ? 'Push Notifications Active' : 'Push Notifications Disabled',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pushEnabled ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ],
          ),
          if (pushEnabled) ...[
            const SizedBox(height: 8),
            FutureBuilder<String?>(
              future: _notificationService.fcmToken,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final token = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FCM Token: ${token.substring(0, 20)}...',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You will receive push notifications for fee reminders, exam alerts, and notices.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  );
                }
                return Text(
                  'Loading FCM token...',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Enable push notifications in device settings to receive alerts when the app is closed.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification notification) {
    final icon = _typeIcon(notification.type);
    final color = _typeColor(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _notificationService.removeNotification(notification.id);
        setState(() {});
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          notification.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('dd MMM').format(notification.createdAt),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              ),
          ],
        ),
        onTap: () async {
          await _notificationService.markAsRead(notification.id);
          setState(() {});
        },
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'fee_due':
        return Icons.payment;
      case 'exam_alert':
        return Icons.quiz;
      case 'notice':
        return Icons.campaign;
      case 'attendance':
        return Icons.calendar_month;
      default:
        return Icons.info;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'fee_due':
        return Colors.orange;
      case 'exam_alert':
        return Colors.purple;
      case 'notice':
        return Colors.blue;
      case 'attendance':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
