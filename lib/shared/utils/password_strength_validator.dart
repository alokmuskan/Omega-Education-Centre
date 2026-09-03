/// Evaluates password strength based on multiple criteria.
///
/// Strength levels:
///   Weak     — less than 8 chars or missing multiple categories
///   Fair     — 8+ chars with 2 categories
///   Medium   — 8+ chars with 3 categories
///   Strong   — 12+ chars with 3+ categories
///   VeryStrong — 14+ chars with all 4 categories
///
/// Categories:
///   1. Lowercase letters (a-z)
///   2. Uppercase letters (A-Z)
///   3. Digits (0-9)
///   4. Special characters (!@#\$%^&*()-_+=...)
class PasswordStrengthValidator {
  PasswordStrengthValidator._();

  /// Minimum acceptable strength for account creation/reset.
  static const PasswordStrength minimumStrength = PasswordStrength.medium;

  // ── Rules ──────────────────────────────────────────────────────────

  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _special = RegExp(r'[!@#$%^&*()\-_=+\[\]{}|;:,.<>?/~` ]');

  /// Common passwords/words that should be rejected.
  static const List<String> _commonPasswords = [
    'password',
    '12345678',
    '123456789',
    '1234567890',
    'qwerty123',
    'abc12345',
    'password1',
    'admin123',
    'letmein123',
    'welcome1',
    'monkey123',
    'dragon123',
    'master123',
  ];

  // ── Public API ─────────────────────────────────────────────────────

  /// Evaluates the strength of a password.
  static PasswordStrengthResult evaluate(String password) {
    final clean = password.trim();

    if (clean.isEmpty) {
      return const PasswordStrengthResult(
        strength: PasswordStrength.weak,
        score: 0,
        label: 'Enter a password',
        feedback: [],
      );
    }

    final feedback = <String>[];
    int score = 0;

    // Length scoring
    if (clean.length >= 14) {
      score += 30;
    } else if (clean.length >= 12) {
      score += 25;
    } else if (clean.length >= 8) {
      score += 15;
    } else if (clean.length >= 6) {
      score += 8;
    } else {
      score += 2;
      feedback.add('At least 8 characters recommended');
    }

    // Category scoring
    if (_lowercase.hasMatch(clean)) {
      score += 15;
    } else {
      feedback.add('Add lowercase letters');
    }

    if (_uppercase.hasMatch(clean)) {
      score += 15;
    } else {
      feedback.add('Add uppercase letters');
    }

    if (_digit.hasMatch(clean)) {
      score += 15;
    } else {
      feedback.add('Add numbers');
    }

    if (_special.hasMatch(clean)) {
      score += 15;
    } else {
      feedback.add('Add special characters (!@#\$%...)');
    }

    // Check for common passwords
    final lowerClean = clean.toLowerCase();
    for (final common in _commonPasswords) {
      if (lowerClean == common || lowerClean.startsWith(common)) {
        score = score.clamp(0, 15);
        feedback.insert(0, 'This is a commonly used password');
        break;
      }
    }

    // Check for repetitive patterns
    if (RegExp(r'(.)\1{2,}').hasMatch(clean)) {
      score -= 10;
      feedback.add('Avoid repeated characters (e.g., aaa)');
    }

    // Check for sequential patterns
    if (RegExp(r'(012|123|234|345|456|567|678|789|890|abc|bcd|cde|def|efg)')
        .hasMatch(lowerClean)) {
      score -= 10;
      feedback.add('Avoid sequential characters (e.g., 123, abc)');
    }

    // Determine strength level
    score = score.clamp(0, 100);
    final strength = _scoreToStrength(score);

    // Ensure the feedback is at most 3 items
    final trimmedFeedback = feedback.length > 3
        ? feedback.sublist(0, 3)
        : feedback;

    return PasswordStrengthResult(
      strength: strength,
      score: score,
      label: _strengthLabel(strength),
      feedback: trimmedFeedback,
    );
  }

  /// Returns true if the password meets the minimum strength requirement.
  static bool meetsMinimumStrength(String password) {
    final result = evaluate(password);
    return result.strength.index >= minimumStrength.index;
  }

  /// Returns an error message if the password doesn't meet requirements,
  /// or null if it's acceptable.
  static String? validatePassword(String password) {
    final result = evaluate(password);
    if (result.strength.index < minimumStrength.index) {
      return 'Password is ${result.label}. Minimum required: ${_strengthLabel(minimumStrength)}. '
          '${result.feedback.isNotEmpty ? result.feedback.first : ''}';
    }
    return null;
  }

  // ── Private Helpers ────────────────────────────────────────────────

  static PasswordStrength _scoreToStrength(int score) {
    if (score >= 70) return PasswordStrength.veryStrong;
    if (score >= 50) return PasswordStrength.strong;
    if (score >= 30) return PasswordStrength.medium;
    if (score >= 15) return PasswordStrength.fair;
    return PasswordStrength.weak;
  }

  static String _strengthLabel(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }
}

/// Password strength levels from weakest to strongest.
enum PasswordStrength {
  weak,
  fair,
  medium,
  strong,
  veryStrong,
}

/// Result of a password strength evaluation.
class PasswordStrengthResult {
  final PasswordStrength strength;
  final int score;
  final String label;
  final List<String> feedback;

  const PasswordStrengthResult({
    required this.strength,
    required this.score,
    required this.label,
    required this.feedback,
  });
}
