import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../features/students/models/student_model.dart';
import '../../features/teachers/models/teacher_model.dart';

/// Offline session state manager for Omega Education Centre ERP.
///
/// Stores authenticated user session info: role (Admin/Teacher/Student),
/// reference IDs, and user display info.
///
/// STRICT RBAC RULE:
/// Login determines role. Role determines access.
/// User CANNOT change role from inside the app.
class AppSession {
  AppSession._privateConstructor();
  static final AppSession instance = AppSession._privateConstructor();

  static const String _keyUsername = 'app_session_username';
  static const String _keyRole = 'app_session_role';
  static const String _keyRefId = 'app_session_ref_id';
  static const String _keyCreatedAt = 'app_session_created_at';
  static const String _keyLastActivity = 'app_session_last_activity';
  static const String _keyTimeoutMinutes = 'app_session_timeout_minutes';

  /// Default session timeout in minutes.
  static const int defaultTimeoutMinutes = 15;

  /// Warning time before timeout (in minutes). Dialog shown this many minutes before logout.
  static const int warningMinutesBeforeTimeout = 2;

  String _currentRole = AppConstants.roleAdmin;
  int? _currentTeacherId;
  int? _currentStudentId;
  TeacherModel? _currentTeacherModel;
  StudentModel? _currentStudentModel;
  String _currentUsername = 'Admin';
  DateTime? _lastActivityTimestamp;

  String get currentRole => _currentRole;
  int? get currentTeacherId => _currentTeacherId;
  int? get currentStudentId => _currentStudentId;
  TeacherModel? get currentTeacherModel => _currentTeacherModel;
  StudentModel? get currentStudentModel => _currentStudentModel;
  String get currentUsername => _currentUsername;
  DateTime? get lastActivityTimestamp => _lastActivityTimestamp;

  bool get isAdmin => _currentRole == AppConstants.roleAdmin;
  bool get isTeacher => _currentRole == AppConstants.roleTeacher;
  bool get isStudent => _currentRole == AppConstants.roleStudent;

  Future<void> setAdminSession({String username = 'Admin'}) async {
    _currentRole = AppConstants.roleAdmin;
    _currentTeacherId = null;
    _currentStudentId = null;
    _currentTeacherModel = null;
    _currentStudentModel = null;
    _currentUsername = username;
    await _persistSessionPayload(username: username, role: AppConstants.roleAdmin, refId: null);
  }

  Future<void> setTeacherSession(TeacherModel teacher, {String? username}) async {
    _currentRole = AppConstants.roleTeacher;
    _currentTeacherId = teacher.id;
    _currentStudentId = null;
    _currentTeacherModel = teacher;
    _currentStudentModel = null;
    _currentUsername = username ?? teacher.name;
    await _persistSessionPayload(
      username: _currentUsername,
      role: AppConstants.roleTeacher,
      refId: teacher.id,
    );
  }

  Future<void> setStudentSession(StudentModel student, {String? username}) async {
    _currentRole = AppConstants.roleStudent;
    _currentTeacherId = null;
    _currentStudentId = student.id;
    _currentTeacherModel = null;
    _currentStudentModel = student;
    _currentUsername = username ?? student.name;
    await _persistSessionPayload(
      username: _currentUsername,
      role: AppConstants.roleStudent,
      refId: student.id,
    );
  }

  Future<void> clearSession() async {
    _currentRole = AppConstants.roleAdmin;
    _currentTeacherId = null;
    _currentStudentId = null;
    _currentTeacherModel = null;
    _currentStudentModel = null;
    _currentUsername = '';
    _lastActivityTimestamp = null;
    await _clearPersistedPayload();
  }

  // ── Activity Tracking ──────────────────────────────────────────────

  /// Records a user activity event. Called on taps, navigation, input, etc.
  void touchActivity() {
    _lastActivityTimestamp = DateTime.now();
    _persistActivityTimestamp();
  }

  /// Returns the configured session timeout in minutes.
  Future<int> getTimeoutMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyTimeoutMinutes) ?? defaultTimeoutMinutes;
    } catch (_) {
      return defaultTimeoutMinutes;
    }
  }

  /// Sets the session timeout in minutes.
  Future<void> setTimeoutMinutes(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyTimeoutMinutes, minutes);
    } catch (_) {}
  }

  /// Checks if the session has timed out based on last activity.
  /// Returns true if the session should be expired.
  Future<bool> isSessionTimedOut() async {
    if (_lastActivityTimestamp == null) {
      // No activity recorded yet — load from prefs.
      await _loadActivityTimestamp();
    }
    if (_lastActivityTimestamp == null) return false;

    final timeoutMinutes = await getTimeoutMinutes();
    final elapsed = DateTime.now().difference(_lastActivityTimestamp!);
    return elapsed.inMinutes >= timeoutMinutes;
  }

  /// Returns minutes until session timeout. Negative if already timed out.
  Future<int> minutesUntilTimeout() async {
    if (_lastActivityTimestamp == null) {
      await _loadActivityTimestamp();
    }
    if (_lastActivityTimestamp == null) return defaultTimeoutMinutes;

    final timeoutMinutes = await getTimeoutMinutes();
    final elapsed = DateTime.now().difference(_lastActivityTimestamp!);
    final remaining = timeoutMinutes - elapsed.inMinutes;
    return remaining;
  }

  /// Returns true if the warning threshold has been reached
  /// (within warningMinutesBeforeTimeout of expiry).
  Future<bool> shouldShowTimeoutWarning() async {
    final remaining = await minutesUntilTimeout();
    return remaining <= warningMinutesBeforeTimeout && remaining > 0;
  }

  Future<void> _persistActivityTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastActivity, _lastActivityTimestamp!.toIso8601String());
    } catch (_) {}
  }

  Future<void> _loadActivityTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getString(_keyLastActivity);
      if (ts != null) {
        _lastActivityTimestamp = DateTime.parse(ts);
      }
    } catch (_) {}
  }

  void resetInMemoryStateForTestOnly() {
    _currentRole = AppConstants.roleAdmin;
    _currentTeacherId = null;
    _currentStudentId = null;
    _currentTeacherModel = null;
    _currentStudentModel = null;
    _currentUsername = '';
  }

  Future<void> _persistSessionPayload({
    required String username,
    required String role,
    int? refId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyRole, role);
      if (refId != null) {
        await prefs.setInt(_keyRefId, refId);
      } else {
        await prefs.remove(_keyRefId);
      }
      await prefs.setString(_keyCreatedAt, DateTime.now().toIso8601String());
      // Record activity timestamp on login.
      touchActivity();
    } catch (_) {
      // Ignore storage errors safely
    }
  }

  Future<void> _clearPersistedPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyRefId);
      await prefs.remove(_keyCreatedAt);
      await prefs.remove(_keyLastActivity);
    } catch (_) {
      // Ignore storage errors safely
    }
  }
}
