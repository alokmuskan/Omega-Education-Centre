import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notification preferences for the current user.
///
/// Controls which notification types are enabled and how they're delivered.
class NotificationPreferences {
  bool feeReminders;
  bool examAlerts;
  bool attendanceAlerts;
  bool generalNotices;
  bool smsEnabled;
  bool pushEnabled;
  int reminderDaysBefore; // Days before due date to send fee reminder

  NotificationPreferences({
    this.feeReminders = true,
    this.examAlerts = true,
    this.attendanceAlerts = true,
    this.generalNotices = true,
    this.smsEnabled = true,
    this.pushEnabled = true,
    this.reminderDaysBefore = 7,
  });

  static const String _prefix = 'notif_pref_';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix}fee_reminders', feeReminders);
    await prefs.setBool('${_prefix}exam_alerts', examAlerts);
    await prefs.setBool('${_prefix}attendance_alerts', attendanceAlerts);
    await prefs.setBool('${_prefix}general_notices', generalNotices);
    await prefs.setBool('${_prefix}sms_enabled', smsEnabled);
    await prefs.setBool('${_prefix}push_enabled', pushEnabled);
    await prefs.setInt('${_prefix}reminder_days', reminderDaysBefore);
  }

  static Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      feeReminders: prefs.getBool('${_prefix}fee_reminders') ?? true,
      examAlerts: prefs.getBool('${_prefix}exam_alerts') ?? true,
      attendanceAlerts: prefs.getBool('${_prefix}attendance_alerts') ?? true,
      generalNotices: prefs.getBool('${_prefix}general_notices') ?? true,
      smsEnabled: prefs.getBool('${_prefix}sms_enabled') ?? true,
      pushEnabled: prefs.getBool('${_prefix}push_enabled') ?? true,
      reminderDaysBefore: prefs.getInt('${_prefix}reminder_days') ?? 7,
    );
  }
}

/// Screen for managing notification preferences.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  NotificationPreferences _prefs = NotificationPreferences();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await NotificationPreferences.load();
    setState(() => _isLoading = false);
  }

  Future<void> _savePrefs() async {
    await _prefs.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _savePrefs,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Delivery channels
                const Text('Delivery Channels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive in-app notifications'),
                  value: _prefs.pushEnabled,
                  onChanged: (v) => setState(() => _prefs.pushEnabled = v),
                ),
                SwitchListTile(
                  title: const Text('SMS Notifications'),
                  subtitle: const Text('Receive SMS on registered mobile'),
                  value: _prefs.smsEnabled,
                  onChanged: (v) => setState(() => _prefs.smsEnabled = v),
                ),
                const Divider(height: 32),

                // Notification types
                const Text('Notification Types', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Fee Reminders'),
                  subtitle: const Text('Get reminded before fee due dates'),
                  value: _prefs.feeReminders,
                  onChanged: (v) => setState(() => _prefs.feeReminders = v),
                ),
                SwitchListTile(
                  title: const Text('Exam Alerts'),
                  subtitle: const Text('Get notified about upcoming exams'),
                  value: _prefs.examAlerts,
                  onChanged: (v) => setState(() => _prefs.examAlerts = v),
                ),
                SwitchListTile(
                  title: const Text('Attendance Alerts'),
                  subtitle: const Text('Get notified about attendance status'),
                  value: _prefs.attendanceAlerts,
                  onChanged: (v) => setState(() => _prefs.attendanceAlerts = v),
                ),
                SwitchListTile(
                  title: const Text('General Notices'),
                  subtitle: const Text('Institute announcements and updates'),
                  value: _prefs.generalNotices,
                  onChanged: (v) => setState(() => _prefs.generalNotices = v),
                ),
                const Divider(height: 32),

                // Fee reminder timing
                const Text('Fee Reminder Timing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Send reminder before'),
                  trailing: DropdownButton<int>(
                    value: _prefs.reminderDaysBefore,
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 days')),
                      DropdownMenuItem(value: 5, child: Text('5 days')),
                      DropdownMenuItem(value: 7, child: Text('7 days')),
                      DropdownMenuItem(value: 14, child: Text('14 days')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _prefs.reminderDaysBefore = v);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
