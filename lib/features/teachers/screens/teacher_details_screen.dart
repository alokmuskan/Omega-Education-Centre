import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../../../shared/utils/profile_photo_helper.dart';
import '../../../shared/widgets/profile_photo_widget.dart';
import '../models/teacher_model.dart';
import '../repository/teacher_repository.dart';
import '../../authentication/repository/auth_repository.dart';
import 'edit_teacher_screen.dart';
import '../../attendance/screens/teacher_attendance_history_screen.dart';
import '../../salary/screens/teacher_payment_history_screen.dart';
import '../../class_register/screens/daily_class_register_main_screen.dart';

/// Screen displaying complete details for a single teacher.
class TeacherDetailsScreen extends StatefulWidget {
  final TeacherModel teacher;

  const TeacherDetailsScreen({
    super.key,
    required this.teacher,
  });

  @override
  State<TeacherDetailsScreen> createState() => _TeacherDetailsScreenState();
}

class _TeacherDetailsScreenState extends State<TeacherDetailsScreen> {
  final _repository = TeacherRepository();
  late TeacherModel _currentTeacher;

  @override
  void initState() {
    super.initState();
    _currentTeacher = widget.teacher;
  }

  Future<void> _refreshTeacher() async {
    if (_currentTeacher.id == null) return;
    final updated = await _repository.getTeacherById(_currentTeacher.id!);
    if (updated != null && mounted) {
      setState(() => _currentTeacher = updated);
    }
  }

  Future<void> _toggleStatus() async {
    if (_currentTeacher.id == null) return;

    final newStatus = !_currentTeacher.isActive;
    final actionText = newStatus ? 'Activate' : 'Deactivate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionText Teacher?'),
        content: Text(
          'Are you sure you want to $actionText ${_currentTeacher.name}?\n\n'
          'Note: Soft deactivation preserves all historical attendance and payment records linked to this teacher.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? Colors.green : Colors.orange.shade800,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _repository.setTeacherActiveStatus(_currentTeacher.id!, newStatus);
    await _refreshTeacher();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_currentTeacher.name} is now ${newStatus ? "Active" : "Inactive"}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openEditScreen() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTeacherScreen(teacher: _currentTeacher),
      ),
    );

    if (updated == true) {
      await _refreshTeacher();
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final newPassCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password for ${_currentTeacher.name}'),
        content: TextField(
          controller: newPassCtrl,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Password *',
            hintText: 'Minimum 4 characters',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, newPassCtrl.text.trim()),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await AuthRepository().adminResetPassword(
          targetUsername: _currentTeacher.mobile,
          newPassword: result,
          role: AppConstants.roleTeacher,
          referenceId: _currentTeacher.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password for ${_currentTeacher.name} reset successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reset password: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }



  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue.shade700),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ),
    );
  }

  String _formatJoiningDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('d MMMM yyyy').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    if (session.isStudent) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: Students are not authorized to view teacher details.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (session.isTeacher && widget.teacher.id != session.currentTeacherId) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access Denied: You can only view your own details.',
            style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final teacher = _currentTeacher;
    final isActive = teacher.isActive;
    final bool isAdmin = AppSession.instance.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Details'),
        centerTitle: true,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Teacher',
              onPressed: _openEditScreen,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar & Header
            ProfilePhotoWidget(
              relativePath: _currentTeacher.profilePhotoPath,
              fallbackLetter: _currentTeacher.name.isNotEmpty ? _currentTeacher.name[0] : 'T',
              radius: 50,
              isEditable: isAdmin,
              onPhotoSelected: (File file) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final String relativePath = await ProfilePhotoHelper.saveImage(
                    file,
                    'teachers',
                    'teacher_${_currentTeacher.id}',
                  );
                  final String? oldPath = _currentTeacher.profilePhotoPath;
                  final updatedTeacher = _currentTeacher.copyWith(profilePhotoPath: relativePath);
                  
                  await _repository.updateTeacher(updatedTeacher);
                  
                  if (mounted) {
                    setState(() {
                      _currentTeacher = updatedTeacher;
                    });
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Profile photo updated successfully.')),
                    );
                  }

                  if (oldPath != null && oldPath.isNotEmpty) {
                    await ProfilePhotoHelper.deleteImage(oldPath);
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to update photo: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              onPhotoRemoved: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final String? oldPath = _currentTeacher.profilePhotoPath;
                  final updatedTeacher = _currentTeacher.copyWith(profilePhotoPath: null);
                  
                  await _repository.updateTeacher(updatedTeacher);
                  
                  if (mounted) {
                    setState(() {
                      _currentTeacher = updatedTeacher;
                    });
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Profile photo removed.')),
                    );
                  }

                  if (oldPath != null && oldPath.isNotEmpty) {
                    await ProfilePhotoHelper.deleteImage(oldPath);
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to remove photo: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),

            const SizedBox(height: 12),

            Text(
              teacher.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                ...teacher.subjects.map((sub) => Chip(
                      avatar: const Icon(Icons.subject, size: 16),
                      label: Text(sub),
                      backgroundColor: theme.colorScheme.secondary.withAlpha(25),
                      side: BorderSide.none,
                    )),
                Chip(
                  avatar: Icon(
                    isActive ? Icons.check_circle : Icons.pause_circle_filled,
                    size: 16,
                    color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                  label: Text(
                    teacher.status,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green.shade900 : Colors.grey.shade800,
                    ),
                  ),
                  backgroundColor:
                      isActive ? Colors.green.shade100 : Colors.grey.shade200,
                  side: BorderSide.none,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Pay Per Hour (Highlighted)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.currency_rupee, color: Colors.green),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configured Pay Per Hour',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${teacher.payPerHour.toStringAsFixed(0)} / hour',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Info Tiles
            _buildInfoTile(
              icon: Icons.phone,
              title: 'Mobile Number',
              value: teacher.mobile,
            ),

            _buildInfoTile(
              icon: Icons.subject,
              title: 'Teaching Subject',
              value: teacher.subject,
            ),

            _buildInfoTile(
              icon: Icons.school,
              title: 'Qualification',
              value: (teacher.qualification != null &&
                      teacher.qualification!.isNotEmpty)
                  ? teacher.qualification!
                  : 'Not specified',
            ),

            _buildInfoTile(
              icon: Icons.calendar_today,
              title: 'Joining Date',
              value: _formatJoiningDate(teacher.joiningDate),
            ),

            _buildInfoTile(
              icon: Icons.info_outline,
              title: 'Status',
              value: teacher.status,
              valueColor: isActive ? Colors.green.shade800 : Colors.grey.shade700,
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openEditScreen,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Teacher'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isActive ? Colors.orange.shade800 : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _toggleStatus,
                    icon: Icon(isActive ? Icons.pause : Icons.play_arrow),
                    label: Text(isActive ? 'Deactivate' : 'Activate'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Upcoming Modules Section (Phase 4 / Phase 5 placeholders)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Upcoming Teacher Modules',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Card(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.co_present, color: Colors.blue),
                    title: const Text('Teacher Attendance History'),
                    subtitle: const Text('View daily hours taught & monthly total'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeacherAttendanceHistoryScreen(
                            initialTeacherId: _currentTeacher.id,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.payments, color: Colors.green),
                    title: const Text('Salary & Earnings'),
                    subtitle: Text(
                      'View monthly earned salary & payment history (₹${_currentTeacher.payPerHour.toStringAsFixed(0)}/hr)',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeacherPaymentHistoryScreen(
                            initialTeacherId: _currentTeacher.id,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined, color: Colors.teal),
                    title: const Text('Teaching Logs'),
                    subtitle: const Text('View class register records for this teacher'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyClassRegisterMainScreen(
                            initialTeacherId: _currentTeacher.id,
                          ),
                        ),
                      );
                    },
                  ),
                  if (session.isAdmin) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.key, color: Colors.indigo),
                      title: const Text('Reset Password'),
                      subtitle: Text('Reset credentials for ${_currentTeacher.mobile}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showResetPasswordDialog,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
