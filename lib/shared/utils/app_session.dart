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

  String _currentRole = AppConstants.roleAdmin;
  int? _currentTeacherId;
  int? _currentStudentId;
  TeacherModel? _currentTeacherModel;
  StudentModel? _currentStudentModel;
  String _currentUsername = 'Admin';

  String get currentRole => _currentRole;
  int? get currentTeacherId => _currentTeacherId;
  int? get currentStudentId => _currentStudentId;
  TeacherModel? get currentTeacherModel => _currentTeacherModel;
  StudentModel? get currentStudentModel => _currentStudentModel;
  String get currentUsername => _currentUsername;

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
    await _clearPersistedPayload();
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
    } catch (_) {
      // Ignore storage errors safely
    }
  }
}
