import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/database/database_helper.dart';

/// SMS delivery status.
enum SmsDeliveryStatus {
  pending,
  sent,
  delivered,
  failed,
  cancelled,
}

/// A single SMS message record.
class SmsMessage {
  final String id;
  final String recipientMobile;
  final String recipientName;
  final String templateName;
  final String message;
  final SmsDeliveryStatus status;
  final String? gatewayMessageId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;

  const SmsMessage({
    required this.id,
    required this.recipientMobile,
    required this.recipientName,
    required this.templateName,
    required this.message,
    required this.status,
    this.gatewayMessageId,
    this.errorMessage,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'recipientMobile': recipientMobile,
        'recipientName': recipientName,
        'templateName': templateName,
        'message': message,
        'status': status.name,
        'gatewayMessageId': gatewayMessageId,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
        'sentAt': sentAt?.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
      };

  factory SmsMessage.fromMap(Map<String, dynamic> map) => SmsMessage(
        id: map['id'] ?? '',
        recipientMobile: map['recipientMobile'] ?? '',
        recipientName: map['recipientName'] ?? '',
        templateName: map['templateName'] ?? '',
        message: map['message'] ?? '',
        status: SmsDeliveryStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => SmsDeliveryStatus.pending,
        ),
        gatewayMessageId: map['gatewayMessageId'],
        errorMessage: map['errorMessage'],
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        sentAt: map['sentAt'] != null ? DateTime.tryParse(map['sentAt']) : null,
        deliveredAt: map['deliveredAt'] != null ? DateTime.tryParse(map['deliveredAt']) : null,
      );
}

/// SMS template for fee reminders and notifications.
class SmsTemplate {
  final String name;
  final String subject;
  final String body;
  final bool isActive;

  const SmsTemplate({
    required this.name,
    required this.subject,
    required this.body,
    this.isActive = true,
  });

  /// Renders the template with variables replaced.
  /// Variables: {student_name}, {amount}, {due_date}, {institute_name}, {class}
  String render(Map<String, String> variables) {
    var result = body;
    for (final entry in variables.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}

/// SMS Gateway Service for sending fee reminders and notifications.
///
/// Supports MSG91 API for Indian mobile numbers.
/// Also provides local template management and delivery tracking.
class SmsService {
  SmsService._();

  static final SmsService instance = SmsService._();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String? _msg91ApiKey;
  String? _msg91SenderId;
  bool _isConfigured = false;

  /// Default SMS templates for fee reminders.
  static const List<SmsTemplate> defaultTemplates = [
    SmsTemplate(
      name: 'fee_reminder_7days',
      subject: 'Fee Due Reminder (7 days)',
      body: 'Dear {student_name} ({class}), your fee of ₹{amount} is due on {due_date}. Please pay before the due date. — {institute_name}',
    ),
    SmsTemplate(
      name: 'fee_reminder_ondue',
      subject: 'Fee Due Today',
      body: 'Dear {student_name} ({class}), your fee of ₹{amount} is due TODAY. Please pay at the earliest. — {institute_name}',
    ),
    SmsTemplate(
      name: 'fee_reminder_overdue',
      subject: 'Fee Overdue',
      body: 'Dear {student_name} ({class}), your fee of ₹{amount} is OVERDUE. Please pay immediately to avoid any inconvenience. — {institute_name}',
    ),
    SmsTemplate(
      name: 'payment_received',
      subject: 'Payment Received',
      body: 'Dear {student_name}, your payment of ₹{amount} has been received. Receipt No: {receipt_no}. Thank you! — {institute_name}',
    ),
    SmsTemplate(
      name: 'exam_alert',
      subject: 'Exam Alert',
      body: 'Dear {student_name} ({class}), {exam_name} is scheduled on {exam_date}. Please prepare well. — {institute_name}',
    ),
  ];

  /// Configures the SMS gateway with MSG91 credentials.
  void configure({String? msg91ApiKey, String? senderId}) {
    _msg91ApiKey = msg91ApiKey;
    _msg91SenderId = senderId;
    _isConfigured = msg91ApiKey != null && msg91ApiKey.isNotEmpty;
  }

  bool get isConfigured => _isConfigured;

  /// Sends an SMS via MSG91 API.
  Future<bool> sendSms({
    required String mobile,
    required String message,
    String templateName = 'general',
    String recipientName = '',
  }) async {
    if (!_isConfigured) {
      if (kDebugMode) {
        print('[SMS] Gateway not configured. Message not sent.');
      }
      return false;
    }

    try {
      final res = await http.post(
        Uri.parse('https://api.msg91.com/api/v5/flow'),
        headers: {
          'Content-Type': 'application/json',
          'authkey': _msg91ApiKey!,
        },
        body: jsonEncode({
          'flow_id': _msg91SenderId,
          'mobiles': '91$mobile',
          'message': message,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['type'] == 'success';
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[SMS] Send failed: $e');
      }
      return false;
    }
  }

  /// Sends a fee reminder to a student's parent.
  Future<SmsMessage> sendFeeReminder({
    required String studentName,
    required String mobile,
    required double amount,
    required String dueDate,
    required String className,
    required String instituteName,
    String templateName = 'fee_reminder_7days',
  }) async {
    final template = defaultTemplates.firstWhere(
      (t) => t.name == templateName,
      orElse: () => defaultTemplates.first,
    );

    final message = template.render({
      'student_name': studentName,
      'amount': amount.toStringAsFixed(0),
      'due_date': dueDate,
      'institute_name': instituteName,
      'class': className,
    });

    final sent = await sendSms(
      mobile: mobile,
      message: message,
      templateName: templateName,
      recipientName: studentName,
    );

    final sms = SmsMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      recipientMobile: mobile,
      recipientName: studentName,
      templateName: templateName,
      message: message,
      status: sent ? SmsDeliveryStatus.sent : SmsDeliveryStatus.failed,
      createdAt: DateTime.now(),
      sentAt: sent ? DateTime.now() : null,
    );

    // Log to local database
    await _logSms(sms);

    return sms;
  }

  /// Sends a payment receipt SMS.
  Future<SmsMessage> sendPaymentReceipt({
    required String studentName,
    required String mobile,
    required double amount,
    required String receiptNo,
    required String instituteName,
  }) async {
    final template = defaultTemplates.firstWhere(
      (t) => t.name == 'payment_received',
      orElse: () => defaultTemplates.last,
    );

    final message = template.render({
      'student_name': studentName,
      'amount': amount.toStringAsFixed(0),
      'receipt_no': receiptNo,
      'institute_name': instituteName,
    });

    final sent = await sendSms(
      mobile: mobile,
      message: message,
      templateName: 'payment_received',
      recipientName: studentName,
    );

    final sms = SmsMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      recipientMobile: mobile,
      recipientName: studentName,
      templateName: 'payment_received',
      message: message,
      status: sent ? SmsDeliveryStatus.sent : SmsDeliveryStatus.failed,
      createdAt: DateTime.now(),
      sentAt: sent ? DateTime.now() : null,
    );

    await _logSms(sms);

    return sms;
  }

  /// Returns all SMS messages from local log.
  Future<List<SmsMessage>> getSmsLog({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final db = await _dbHelper.database;
      final where = status != null ? 'status = ?' : null;
      final whereArgs = status != null ? [status] : null;

      final maps = await db.query(
        'sms_log',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'createdAt DESC',
        limit: limit,
        offset: offset,
      );

      return maps.map((m) => SmsMessage.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Logs an SMS message to local database.
  Future<void> _logSms(SmsMessage sms) async {
    try {
      final db = await _dbHelper.database;
      // sms_log table may not exist yet — create if needed
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sms_log (
          id TEXT PRIMARY KEY,
          recipientMobile TEXT NOT NULL,
          recipientName TEXT,
          templateName TEXT,
          message TEXT,
          status TEXT,
          gatewayMessageId TEXT,
          errorMessage TEXT,
          createdAt TEXT,
          sentAt TEXT,
          deliveredAt TEXT
        )
      ''');

      await db.insert('sms_log', sms.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('[SMS] Log failed: $e');
      }
    }
  }
}
