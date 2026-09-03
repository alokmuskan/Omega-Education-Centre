import 'package:flutter/material.dart';

import '../../features/authentication/repository/auth_repository.dart';
import '../utils/app_session.dart';
import '../utils/password_strength_validator.dart';
import 'password_strength_indicator.dart';

/// Reusable self-service dialog for logged-in Teachers and Students to change their password.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  static Future<void> show(BuildContext context) async {
    if (!AppSession.instance.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password resets can only be performed by an Administrator.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _authRepo = AuthRepository();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final username = AppSession.instance.currentUsername;
      await _authRepo.changePassword(
        username: username,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully! Please use your new password next time.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = AppSession.instance.currentUsername;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_reset, color: Colors.indigo),
          SizedBox(width: 10),
          Text('Change Password'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User ID (Read-only)
              TextFormField(
                initialValue: username,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'User ID (Read-Only)',
                  prefixIcon: Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Color(0xFFF0F4F8),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Current Password
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _hideCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password *',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_hideCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter current password' : null,
              ),
              const SizedBox(height: 14),

              // New Password
              TextFormField(
                controller: _newPasswordController,
                obscureText: _hideNew,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'New Password *',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_hideNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _hideNew = !_hideNew),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter new password';
                  final error = PasswordStrengthValidator.validatePassword(v.trim());
                  if (error != null) return error;
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Password Strength Indicator
              PasswordStrengthIndicator(
                password: _newPasswordController.text,
              ),
              const SizedBox(height: 14),

              // Confirm New Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _hideConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password *',
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_hideConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Confirm new password';
                  if (v.trim() != _newPasswordController.text.trim()) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade800,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _submitChangePassword,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Update Password'),
        ),
      ],
    );
  }
}
