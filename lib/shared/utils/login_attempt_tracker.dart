import 'package:shared_preferences/shared_preferences.dart';

/// Tracks failed login attempts per user and enforces progressive lockout.
///
/// Lockout rules (per user):
///   5 failed attempts  → 5 minute lockout
///  10 failed attempts  → 30 minute lockout
///  15+ failed attempts → 60 minute lockout
///
/// The counter resets on successful login or after lockout expires.
class LoginAttemptTracker {
  LoginAttemptTracker._();

  static final LoginAttemptTracker instance = LoginAttemptTracker._();

  /// Per-user in-memory caches keyed by lowercase username.
  final Map<String, int> _attemptCounts = {};
  final Map<String, DateTime?> _lockoutUntils = {};

  /// Whether test mode is active (skips SharedPreferences).
  static bool testMode = false;

  // ── Lockout Thresholds ──────────────────────────────────────────────

  static const int _threshold1 = 5;
  static const int _threshold2 = 10;
  static const int _threshold3 = 15;

  static const int _lockoutMinutes1 = 5;
  static const int _lockoutMinutes2 = 30;
  static const int _lockoutMinutes3 = 60;

  // ── Public API (synchronous for auth flow integration) ──────────────

  /// Returns true if the given username is currently locked out.
  bool isLockedOut(String username) {
    final key = username.trim().toLowerCase();
    final lockoutUntil = _lockoutUntils[key];
    if (lockoutUntil == null) return false;
    if (DateTime.now().isBefore(lockoutUntil)) return true;
    // Lockout expired — reset.
    _resetUser(key);
    return false;
  }

  /// Returns minutes remaining until unlock, or 0 if not locked out.
  int getMinutesUntilUnlock(String username) {
    final key = username.trim().toLowerCase();
    final lockoutUntil = _lockoutUntils[key];
    if (lockoutUntil == null) return 0;
    final remaining = lockoutUntil.difference(DateTime.now());
    if (remaining.isNegative) {
      _resetUser(key);
      return 0;
    }
    return remaining.inMinutes + 1; // Round up to nearest minute
  }

  /// Returns seconds remaining until unlock, or 0 if not locked out.
  int getSecondsUntilUnlock(String username) {
    final key = username.trim().toLowerCase();
    final lockoutUntil = _lockoutUntils[key];
    if (lockoutUntil == null) return 0;
    final remaining = lockoutUntil.difference(DateTime.now());
    if (remaining.isNegative) {
      _resetUser(key);
      return 0;
    }
    return remaining.inSeconds;
  }

  /// Returns remaining attempts before lockout, or 0 if locked out.
  int getRemainingAttempts(String username) {
    final key = username.trim().toLowerCase();
    if (isLockedOut(key)) return 0;
    final count = _attemptCounts[key] ?? 0;
    if (count < _threshold1) return _threshold1 - count;
    if (count < _threshold2) return _threshold2 - count;
    if (count < _threshold3) return _threshold3 - count;
    return 0;
  }

  /// Records a failed login attempt. Triggers lockout if threshold reached.
  void recordFailedAttempt(String username) {
    final key = username.trim().toLowerCase();
    final count = (_attemptCounts[key] ?? 0) + 1;
    _attemptCounts[key] = count;

    if (count >= _threshold3) {
      _lockoutUntils[key] =
          DateTime.now().add(Duration(minutes: _lockoutMinutes3));
    } else if (count >= _threshold2) {
      _lockoutUntils[key] =
          DateTime.now().add(Duration(minutes: _lockoutMinutes2));
    } else if (count >= _threshold1) {
      _lockoutUntils[key] =
          DateTime.now().add(Duration(minutes: _lockoutMinutes1));
    }

    if (!testMode) {
      _persistUser(key, count, _lockoutUntils[key]);
    }
  }

  /// Resets the attempt counter on successful login.
  void clearAttempts(String username) {
    final key = username.trim().toLowerCase();
    _resetUser(key);
    if (!testMode) {
      _clearPersisted(key);
    }
  }

  /// Returns a user-friendly message about the current lockout state.
  String? getLockoutMessage(String username) {
    final key = username.trim().toLowerCase();
    if (isLockedOut(key)) {
      final seconds = getSecondsUntilUnlock(key);
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return 'Account locked. Try again in ${minutes}m ${secs}s.';
    }
    final remaining = getRemainingAttempts(key);
    if (remaining > 0 && remaining <= 2) {
      return '$remaining attempt${remaining == 1 ? '' : 's'} remaining before lockout.';
    }
    return null;
  }

  // ── Internal Helpers ────────────────────────────────────────────────

  void _resetUser(String key) {
    _attemptCounts[key] = 0;
    _lockoutUntils[key] = null;
  }

  Future<void> _persistUser(
    String key,
    int count,
    DateTime? lockoutUntil,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('login_attempts_$key', count);
      if (lockoutUntil != null) {
        await prefs.setString(
          'login_lockout_$key',
          lockoutUntil.toIso8601String(),
        );
      }
    } catch (_) {}
  }

  Future<void> _clearPersisted(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('login_attempts_$key');
      await prefs.remove('login_lockout_$key');
    } catch (_) {}
  }
}
