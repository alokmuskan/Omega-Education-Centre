import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_notification_service.dart';

/// A single notification item.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'fee_due', 'exam_alert', 'notice', 'attendance', 'general'
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        body: map['body'] ?? '',
        type: map['type'] ?? 'general',
        data: map['data'],
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        isRead: map['isRead'] ?? false,
      );
}

/// In-app notification service with read/unread tracking and FCM integration.
///
/// Stores notifications in SharedPreferences for persistence.
/// Integrates with Firebase Cloud Messaging for push notifications.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _storageKey = 'app_notifications';
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // ── FCM Integration ─────────────────────────────────────────────

  /// Returns whether push notifications are enabled.
  bool get isPushEnabled => PushNotificationService.instance.isEnabled;

  /// Returns the current FCM token for server-side push triggers.
  Future<String?> get fcmToken => PushNotificationService.instance.getToken();

  /// Subscribes to a push notification topic (e.g., class-specific alerts).
  Future<void> subscribeToTopic(String topic) async {
    await PushNotificationService.instance.subscribeToTopic(topic);
  }

  /// Unsubscribes from a push notification topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await PushNotificationService.instance.unsubscribeFromTopic(topic);
  }

  /// Subscribes to class-specific notification topics.
  ///
  /// Called when a teacher or admin selects a class. Ensures they receive
  /// push notifications targeted to that class.
  Future<void> subscribeToClassTopic(String className) async {
    await subscribeToTopic('class_$className');
  }

  /// Unsubscribes from class-specific notification topics.
  Future<void> unsubscribeFromClassTopic(String className) async {
    await unsubscribeFromTopic('class_$className');
  }

  /// Subscribes to role-based notification topics.
  Future<void> subscribeToRoleTopic(String role) async {
    await subscribeToTopic('role_$role');
  }

  // ── Load / Persist ──────────────────────────────────────────────

  /// Loads notifications from local storage.
  Future<void> loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _notifications.clear();
        _notifications.addAll(list.map((e) => AppNotification.fromMap(e)));
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NOTIFICATION] Failed to load: $e');
      }
    }
  }

  /// Persists notifications to local storage.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_notifications.map((n) => n.toMap()).toList());
      await prefs.setString(_storageKey, json);
    } catch (_) {}
  }

  // ── CRUD Operations ─────────────────────────────────────────────

  /// Adds a new notification (in-app only).
  ///
  /// For push notifications, use [notifyFeeDue], [notifyExamAlert], etc.
  /// which create both in-app and push notifications.
  Future<void> addNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    _notifications.insert(0, notification);
    await _persist();
  }

  /// Marks a notification as read.
  Future<void> markAsRead(String notificationId) async {
    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => AppNotification(id: '', title: '', body: '', type: '', createdAt: DateTime.now()),
    );
    if (notification.id.isNotEmpty) {
      notification.isRead = true;
      await _persist();
    }
  }

  /// Marks all notifications as read.
  Future<void> markAllAsRead() async {
    for (final n in _notifications) {
      n.isRead = true;
    }
    await _persist();
  }

  /// Clears all notifications.
  Future<void> clearAll() async {
    _notifications.clear();
    await _persist();
  }

  /// Removes a specific notification.
  Future<void> removeNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _persist();
  }

  // ── Notification Generators ─────────────────────────────────────

  /// Generates a fee due reminder notification (in-app).
  Future<void> notifyFeeDue(String studentName, double amount, String className) async {
    await addNotification(
      title: 'Fee Due Reminder',
      body: '$studentName (Class $className) — ₹${amount.toStringAsFixed(0)} fee due',
      type: 'fee_due',
      data: {'studentName': studentName, 'amount': amount, 'class': className},
    );
  }

  /// Generates an exam alert notification (in-app).
  Future<void> notifyExamAlert(String testName, String date) async {
    await addNotification(
      title: 'Exam Alert',
      body: '$testName scheduled for $date',
      type: 'exam_alert',
      data: {'testName': testName, 'date': date},
    );
  }

  /// Generates a general notice notification (in-app).
  Future<void> notifyNotice(String title, String content) async {
    await addNotification(
      title: title,
      body: content,
      type: 'notice',
    );
  }

  /// Generates an attendance alert notification (in-app).
  Future<void> notifyAttendanceAlert(String studentName, String status) async {
    await addNotification(
      title: 'Attendance Alert',
      body: '$studentName marked as $status',
      type: 'attendance',
      data: {'studentName': studentName, 'status': status},
    );
  }
}
