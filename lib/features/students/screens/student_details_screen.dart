import 'dart:io';
import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/utils/app_session.dart';
import '../../../shared/utils/profile_photo_helper.dart';
import '../../../shared/widgets/profile_photo_widget.dart';
import '../../authentication/repository/auth_repository.dart';
import '../../tests/screens/student_result_history_screen.dart';
import '../models/student_model.dart';
import '../repository/student_repository.dart';
import 'id_card_preview_screen.dart';
import 'tc_preview_screen.dart';

class StudentDetailsScreen extends StatefulWidget {
  final StudentModel student;

  const StudentDetailsScreen({
    super.key,
    required this.student,
  });

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  late StudentModel _student;
  final StudentRepository _studentRepo = StudentRepository();

  @override
  void initState() {
    super.initState();
    _student = widget.student;
  }

  Widget buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.instance;
    if (session.isStudent && widget.student.id != session.currentStudentId) {
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

    final bool isPaid = _student.feeStatus == "Paid";
    final bool isAdmin = AppSession.instance.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Details"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            ProfilePhotoWidget(
              relativePath: _student.profilePhotoPath,
              fallbackLetter: _student.name.isNotEmpty ? _student.name[0] : 'S',
              radius: 50,
              isEditable: isAdmin,
              onPhotoSelected: (File file) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final String relativePath = await ProfilePhotoHelper.saveImage(
                    file,
                    'students',
                    'student_${_student.id}',
                  );
                  final String? oldPath = _student.profilePhotoPath;
                  final updatedStudent = _student.copyWith(profilePhotoPath: relativePath);
                  
                  await _studentRepo.updateStudent(updatedStudent);
                  
                  if (mounted) {
                    setState(() {
                      _student = updatedStudent;
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
                  final String? oldPath = _student.profilePhotoPath;
                  final updatedStudent = _student.copyWith(profilePhotoPath: null);
                  
                  await _studentRepo.updateStudent(updatedStudent);
                  
                  if (mounted) {
                    setState(() {
                      _student = updatedStudent;
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

            const SizedBox(height: 15),

            Text(
              _student.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            buildInfoTile(
              icon: Icons.menu_book,
              title: "Board",
              value: _student.board,
            ),

            buildInfoTile(
              icon: Icons.school,
              title: "Class",
              value: _student.studentClass,
            ),

            buildInfoTile(
              icon: Icons.confirmation_number,
              title: "Roll Number",
              value: _student.rollNo.toString(),
            ),

            buildInfoTile(
              icon: Icons.person,
              title: "Father Name",
              value: _student.fatherName,
            ),

            buildInfoTile(
              icon: Icons.phone,
              title: "Mobile",
              value: _student.mobile,
            ),

            buildInfoTile(
              icon: Icons.home,
              title: "Address",
              value: _student.address ?? 'N/A',
            ),

            buildInfoTile(
              icon: Icons.currency_rupee,
              title: "Fee Status",
              value: _student.feeStatus,
            ),

            if (_student.id != null)
              buildInfoTile(
                icon: Icons.badge,
                title: "Student ID Card",
                value: "Generate & share printable ID card",
                trailing: const Icon(Icons.chevron_right, color: Colors.blue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IdCardPreviewScreen(student: _student),
                    ),
                  );
                },
              ),

            if (_student.id != null)
              buildInfoTile(
                icon: Icons.description,
                title: "Transfer Certificate",
                value: "Generate & share TC",
                trailing: const Icon(Icons.chevron_right, color: Colors.teal),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TcPreviewScreen(student: _student),
                    ),
                  );
                },
              ),

            if (_student.id != null)
              buildInfoTile(
                icon: Icons.bar_chart,
                title: "Examination Results",
                value: "View overall report card & test history",
                trailing: const Icon(Icons.chevron_right, color: Colors.blue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentResultHistoryScreen(
                        studentId: _student.id!,
                      ),
                    ),
                  );
                },
              ),

            if (session.isAdmin)
              buildInfoTile(
                icon: Icons.key,
                title: "Reset Password",
                value: "Reset login credentials for ${_student.rollNo}",
                trailing: const Icon(Icons.chevron_right, color: Colors.indigo),
                onTap: _showResetPasswordDialog,
              ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isPaid
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                isPaid ? "Fees Paid" : "Fees Due",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPaid
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    final newPassCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password for ${_student.name}'),
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
          targetUsername: _student.rollNo.toString(),
          newPassword: result,
          role: AppConstants.roleStudent,
          referenceId: _student.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password for ${_student.name} reset successfully!'),
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
}