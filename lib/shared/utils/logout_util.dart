import 'package:flutter/material.dart';

import '../utils/app_session.dart';
import '../../features/authentication/login/login_screen.dart';

/// Shared Logout Utility
///
/// Provides a consistent logout flow with confirmation dialog.
/// Use this instead of duplicating logout logic in each dashboard.
class LogoutUtil {
  LogoutUtil._();

  /// Show logout confirmation dialog and perform logout if confirmed.
  ///
  /// Returns true if logout was performed, false if cancelled.
  static Future<bool> logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppSession.instance.clearSession();
      if (!context.mounted) return false;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return true;
    }

    return false;
  }

  /// Simple logout without confirmation dialog.
  ///
  /// Use this for programmatic logout (e.g., session timeout).
  static void forceLogout(BuildContext context) {
    AppSession.instance.clearSession();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
