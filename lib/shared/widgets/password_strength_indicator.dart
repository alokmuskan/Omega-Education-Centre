import 'package:flutter/material.dart';

import '../utils/password_strength_validator.dart';

/// A visual indicator showing password strength with a colored bar and label.
///
/// Usage:
/// ```dart
/// PasswordStrengthIndicator(
///   password: _newPasswordController.text,
///   onChanged: () => setState(() {}),
/// )
/// ```
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final VoidCallback? onChanged;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final result = PasswordStrengthValidator.evaluate(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength bar
        LinearProgressIndicator(
          value: result.score / 100.0,
          backgroundColor: Colors.grey.shade200,
          color: _strengthColor(result.strength),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 6),

        // Strength label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              result.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _strengthColor(result.strength),
              ),
            ),
            if (password.isNotEmpty)
              Text(
                '${result.score}%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),

        // Feedback tips (up to 3)
        if (result.feedback.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...result.feedback.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  static Color _strengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.fair:
        return Colors.orange;
      case PasswordStrength.medium:
        return Colors.amber.shade700;
      case PasswordStrength.strong:
        return Colors.lightGreen.shade700;
      case PasswordStrength.veryStrong:
        return Colors.green.shade800;
    }
  }
}
