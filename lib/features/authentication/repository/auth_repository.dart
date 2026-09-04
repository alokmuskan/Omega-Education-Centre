import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data_sources/data_source_factory.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/services/audit_service.dart';
import '../../../shared/services/supabase_auth_service.dart';
import '../../../shared/utils/app_session.dart';
import '../../../shared/utils/login_attempt_tracker.dart';
import '../../../shared/utils/password_strength_validator.dart';
import '../../../shared/utils/password_util.dart';

import '../../dashboard/dashboard_screen.dart';
import '../../dashboard/teacher_dashboard_screen.dart';
import '../../dashboard/student_dashboard_screen.dart';

import '../../students/models/student_model.dart';
import '../../students/repository/student_repository.dart';

import '../../teachers/models/teacher_model.dart';
import '../../teachers/repository/teacher_repository.dart';

/// Result object for authentication operation.
class AuthResult {
  final bool success;
  final String role;
  final String message;
  final int? teacherId;
  final int? studentId;
  final TeacherModel? teacherModel;
  final StudentModel? studentModel;

  const AuthResult({
    required this.success,
    required this.role,
    required this.message,
    this.teacherId,
    this.studentId,
    this.teacherModel,
    this.studentModel,
  });
}

/// Repository managing authentication and account/session handling.
///
/// Authentication architecture:
///
/// ADMIN
///   -> Supabase Auth
///   -> admin@omega.internal
///   -> Supabase verifies password
///   -> JWT/session
///   -> Admin session
///
/// TEACHER / STUDENT
///   -> Local SQLite
///   -> PasswordUtil PBKDF2 verification
///   -> Local session
///
/// IMPORTANT:
/// - The Admin password is NOT hardcoded.
/// - There is NO default admin password.
/// - Supabase is authoritative for Admin authentication.
/// - Teacher/Student authentication remains offline-capable through SQLite.
class AuthRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final TeacherRepository _teacherRepository = TeacherRepository();

  final StudentRepository _studentRepository = StudentRepository();

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------

  /// Authenticates User ID + Password and establishes the application session.
  ///
  /// Admin:
  ///   Authenticated through Supabase on Android, Windows, Web, etc.
  ///
  /// Teacher/Student:
  ///   Authenticated locally through SQLite when running on native platforms.
  ///
  /// Web:
  ///   Only Admin authentication is supported because the current application
  ///   SQLite layer is not available on Web.
  Future<AuthResult> login(
    String username,
    String password,
  ) async {
    final cleanUser = username.trim();
    final cleanPass = password.trim();
    final tracker = LoginAttemptTracker.instance;

    // -------------------------------------------------------------------------
    // Basic validation
    // -------------------------------------------------------------------------

    if (cleanUser.isEmpty || cleanPass.isEmpty) {
      return const AuthResult(
        success: false,
        role: '',
        message: 'Username and password are required.',
      );
    }

    // -------------------------------------------------------------------------
    // BRUTE-FORCE PROTECTION
    // Check if this account is temporarily locked out
    // -------------------------------------------------------------------------

    final lockoutMinutes = tracker.getMinutesUntilUnlock(cleanUser);
    if (lockoutMinutes > 0) {
      return AuthResult(
        success: false,
        role: '',
        message: 'Account temporarily locked due to too many failed attempts. '
            'Try again in $lockoutMinutes minute${lockoutMinutes == 1 ? '' : 's'}.',
      );
    }

    // -------------------------------------------------------------------------
    // ADMIN AUTHENTICATION
    //
    // IMPORTANT:
    // This MUST happen before any SQLite access.
    //
    // The Admin password is controlled by Supabase.
    // There is no local password fallback.
    // -------------------------------------------------------------------------

    if (cleanUser.toLowerCase() == 'admin' ||
        await _isAdminUsername(cleanUser)) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AUTH-TRACE-ADMIN-01] Admin login started for username=$cleanUser');
        // ignore: avoid_print
        print('[AUTH-TRACE-ADMIN-02] Authentication authority = Supabase');
        // ignore: avoid_print
        print(
          '[AUTH-TRACE-ADMIN-03] password_present=${cleanPass.isNotEmpty ? "YES" : "NO"}',
        );
      }

      final authenticated =
          await SupabaseAuthService.instance.signInAdmin(cleanPass, username: cleanUser);

      if (!authenticated) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[AUTH-TRACE-ADMIN-04] Supabase authentication = FAILED');
        }

        tracker.recordFailedAttempt(cleanUser);
        final remaining = tracker.getRemainingAttempts(cleanUser);
        final lockout = tracker.getMinutesUntilUnlock(cleanUser);

        if (lockout > 0) {
          return AuthResult(
            success: false,
            role: '',
            message: 'Invalid Admin password. Account locked for $lockout minute${lockout == 1 ? '' : 's'} due to too many failed attempts.',
          );
        }

        return AuthResult(
          success: false,
          role: '',
          message: 'Invalid password. $remaining attempt${remaining == 1 ? '' : 's'} remaining before lockout.',
        );
      }

      if (kDebugMode) {
        // ignore: avoid_print
        print('[AUTH-TRACE-ADMIN-05] Supabase authentication = SUCCESS');
      }

      // -----------------------------------------------------------------------
      // Synchronize local Admin credential on native platforms.
      //
      // This does NOT authenticate the Admin.
      //
      // Supabase has already authenticated the Admin successfully.
      //
      // The local hash is updated only so that the local account record remains
      // consistent with the authenticated password and existing account
      // management features continue to work.
      //
      // The plaintext password is never stored.
      // -----------------------------------------------------------------------

      if (DataSourceFactory.create().isLocal) {
        try {
          await _syncLocalAdminCredential(cleanPass);

          if (kDebugMode) {
            // ignore: avoid_print
            print(
              '[AUTH-TRACE-ADMIN-06] Local Admin credential synchronized',
            );
          }
        } catch (e) {
          // Do NOT fail Admin login if local synchronization fails.
          //
          // Supabase authentication already succeeded.
          if (kDebugMode) {
            // ignore: avoid_print
            print(
              '[AUTH-TRACE-ADMIN-07] Local credential sync failed but '
              'Supabase authentication remains valid: $e',
            );
          }
        }
      }

      // -----------------------------------------------------------------------
      // Admin authenticated successfully - clear failed attempts
      // -----------------------------------------------------------------------

      tracker.clearAttempts(cleanUser);

      // -----------------------------------------------------------------------
      // Establish application Admin session
      // -----------------------------------------------------------------------

      await AppSession.instance.setAdminSession(
        username: cleanUser,
      );

      if (kDebugMode) {
        // ignore: avoid_print
        print('[AUTH-TRACE-ADMIN-08] Admin application session established');
      }

      return const AuthResult(
        success: true,
        role: AppConstants.roleAdmin,
        message: 'Admin login successful.',
      );
    }

    // -------------------------------------------------------------------------
    // TEACHER / STUDENT AUTHENTICATION
    //
    // On native platforms: authenticate via local SQLite
    // On web: authenticate via Supabase Auth (auto-provisions if needed)
    // -------------------------------------------------------------------------

    if (DataSourceFactory.create().isRemote) {
      return _webAuthenticate(cleanUser, cleanPass);
    }

    // -------------------------------------------------------------------------
    // TEACHER / STUDENT LOCAL SQLITE AUTHENTICATION
    // -------------------------------------------------------------------------

    final db = await _dbHelper.database;

    // This method no longer creates an Admin with a hardcoded password.
    await _ensureAdminUserExists();

    // Safely repair any legacy/corrupted role mappings in users table.
    await repairUserAccountRoleMappings();

    // -------------------------------------------------------------------------
    // 1. Query users table for account
    // -------------------------------------------------------------------------

    final userMaps = await db.query(
      'users',
      where: 'LOWER(username) = LOWER(?)',
      whereArgs: [cleanUser],
      limit: 1,
    );

    if (userMaps.isNotEmpty) {
      final userMap = userMaps.first;

      final bool isUserActive =
          (userMap['isActive'] as int?) == 1;

      // -----------------------------------------------------------------------
      // Account status check
      // -----------------------------------------------------------------------

      if (!isUserActive) {
        return const AuthResult(
          success: false,
          role: '',
          message:
              'Account is disabled. Please contact Administrator.',
        );
      }

      final storedHash =
          userMap['passwordHash'] as String?;

      final storedSalt =
          userMap['salt'] as String?;

      final role =
          userMap['role'] as String? ??
              AppConstants.roleAdmin;

      final refId =
          userMap['referenceId'] as int?;

      final actualUsername =
          userMap['username'] as String;

      // -----------------------------------------------------------------------
      // Verify Teacher/Student password
      // -----------------------------------------------------------------------

      bool passwordValid = false;

      if (storedHash != null &&
          storedSalt != null &&
          storedHash.isNotEmpty &&
          storedSalt.isNotEmpty) {
        passwordValid = PasswordUtil.verifyPassword(
          cleanPass,
          storedHash,
          storedSalt,
        );
      }

      // IMPORTANT:
      // There is intentionally NO automatic "legacy password = valid"
      // fallback anymore.
      //
      // Previously the code had:
      //
      //   passwordValid = true;
      //
      // when a hash was missing.
      //
      // That could allow authentication without actually verifying a password.
      if (!passwordValid) {
        tracker.recordFailedAttempt(cleanUser);
        final remaining = tracker.getRemainingAttempts(cleanUser);
        final lockout = tracker.getMinutesUntilUnlock(cleanUser);

        if (lockout > 0) {
          return AuthResult(
            success: false,
            role: '',
            message: 'Invalid password. Account locked for $lockout minute${lockout == 1 ? '' : 's'} due to too many failed attempts.',
          );
        }

        return AuthResult(
          success: false,
          role: '',
          message: 'Invalid password. $remaining attempt${remaining == 1 ? '' : 's'} remaining before lockout.',
        );
      }

      // -----------------------------------------------------------------------
      // Teacher
      // -----------------------------------------------------------------------

      if (role == AppConstants.roleTeacher) {
        TeacherModel? teacher;

        if (refId != null) {
          teacher =
              await _teacherRepository.getTeacherById(refId);
        }

        if (teacher != null && !teacher.isActive) {
          return const AuthResult(
            success: false,
            role: '',
            message:
                'Account is disabled. Please contact Administrator.',
          );
        }

        final teacherObj =
            teacher ??
                TeacherModel(
                  id: refId,
                  name: actualUsername,
                  mobile: actualUsername,
                  subject: 'Teacher',
                  payPerHour: 0,
                  joiningDate: '',
                  createdAt: '',
                );

        tracker.clearAttempts(cleanUser);
        await AppSession.instance.setTeacherSession(
          teacherObj,
          username: actualUsername,
        );

        return AuthResult(
          success: true,
          role: AppConstants.roleTeacher,
          message: 'Teacher login successful.',
          teacherId: teacherObj.id,
          teacherModel: teacher,
        );
      }

      // -----------------------------------------------------------------------
      // Student
      // -----------------------------------------------------------------------

      if (role == AppConstants.roleStudent) {
        StudentModel? student;

        if (refId != null) {
          student =
              await _studentRepository.getStudentById(refId);
        }

        if (student != null && !student.isActive) {
          return const AuthResult(
            success: false,
            role: '',
            message:
                'Account is disabled. Please contact Administrator.',
          );
        }

        final studentObj =
            student ??
                StudentModel(
                  id: refId,
                  name: actualUsername,
                  fatherName: '',
                  mobile: actualUsername,
                  board: 'CBSE',
                  studentClass: '10',
                  rollNo: 0,
                  createdAt: '',
                );

        tracker.clearAttempts(cleanUser);
        await AppSession.instance.setStudentSession(
          studentObj,
          username: actualUsername,
        );

        return AuthResult(
          success: true,
          role: AppConstants.roleStudent,
          message: 'Student login successful.',
          studentId: studentObj.id,
          studentModel: student,
        );
      }

      // -----------------------------------------------------------------------
      // Any remaining local account is treated as Admin.
      //
      // Normally Admin will never reach this section because Admin is handled
      // by Supabase at the beginning of this method.
      // -----------------------------------------------------------------------

      if (kDebugMode) {
        // ignore: avoid_print
        print('[AUTH-TRACE-LOCAL-01] Local account authentication succeeded');
      }

      await AppSession.instance.setAdminSession(
        username: actualUsername,
      );

      return const AuthResult(
        success: true,
        role: AppConstants.roleAdmin,
        message: 'Admin login successful.',
      );
    }

    // -------------------------------------------------------------------------
    // 2. Fallback matching against Student & Teacher entities for legacy
    //    databases where a users record has not yet been created.
    // -------------------------------------------------------------------------

    final lowerUser = cleanUser.toLowerCase();

    // -------------------------------------------------------------------------
    // Check Student FIRST
    //
    // This prevents roll number hijacking by another entity.
    // -------------------------------------------------------------------------

    final students =
        await _studentRepository.getStudents();

    final matchedStudent = students
        .where((s) {
          return s.rollNo.toString() == cleanUser ||
              s.mobile.trim() == cleanUser ||
              s.name.toLowerCase().trim() == lowerUser;
        })
        .firstOrNull;

    if (matchedStudent != null) {
      if (!matchedStudent.isActive) {
        return const AuthResult(
          success: false,
          role: '',
          message:
              'Account is disabled. Please contact Administrator.',
        );
      }

      // Create local Student account.
      await createUserAccount(
        username: cleanUser,
        password: cleanPass,
        role: AppConstants.roleStudent,
        referenceId: matchedStudent.id,
      );

      tracker.clearAttempts(cleanUser);
      await AppSession.instance.setStudentSession(
        matchedStudent,
        username: cleanUser,
      );

      return AuthResult(
        success: true,
        role: AppConstants.roleStudent,
        message: 'Welcome ${matchedStudent.name}!',
        studentId: matchedStudent.id,
        studentModel: matchedStudent,
      );
    }

    // -------------------------------------------------------------------------
    // Check Teacher SECOND
    // -------------------------------------------------------------------------

    final teachers =
        await _teacherRepository.getTeachers();

    final matchedTeacher = teachers
        .where((t) {
          return t.mobile.trim() == cleanUser ||
              t.name.toLowerCase().trim() == lowerUser;
        })
        .firstOrNull;

    if (matchedTeacher != null) {
      if (!matchedTeacher.isActive) {
        return const AuthResult(
          success: false,
          role: '',
          message:
              'Account is disabled. Please contact Administrator.',
        );
      }

      // Create local Teacher account.
      await createUserAccount(
        username: cleanUser,
        password: cleanPass,
        role: AppConstants.roleTeacher,
        referenceId: matchedTeacher.id,
      );

      tracker.clearAttempts(cleanUser);
      await AppSession.instance.setTeacherSession(
        matchedTeacher,
        username: cleanUser,
      );

      return AuthResult(
        success: true,
        role: AppConstants.roleTeacher,
        message: 'Welcome ${matchedTeacher.name}!',
        teacherId: matchedTeacher.id,
        teacherModel: matchedTeacher,
      );
    }

    // -------------------------------------------------------------------------
    // Nothing matched - record failed attempt
    // -------------------------------------------------------------------------

    tracker.recordFailedAttempt(cleanUser);
    final remaining = tracker.getRemainingAttempts(cleanUser);
    final lockout = tracker.getMinutesUntilUnlock(cleanUser);

    if (lockout > 0) {
      return AuthResult(
        success: false,
        role: '',
        message: 'Invalid credentials. Account locked for $lockout minute${lockout == 1 ? '' : 's'} due to too many failed attempts.',
      );
    }

    return AuthResult(
      success: false,
      role: '',
      message: 'Invalid credentials. $remaining attempt${remaining == 1 ? '' : 's'} remaining before lockout.',
    );
  }

  // ===========================================================================
  // LOCAL ADMIN CREDENTIAL SYNCHRONIZATION
  // ===========================================================================

  /// Synchronizes the local Admin credential after successful Supabase
  /// authentication.
  ///
  /// IMPORTANT:
  /// - This method is NOT used to authenticate Admin.
  /// - Supabase authentication must succeed first.
  /// Checks if a username is registered as admin in the local SQLite database.
  /// Returns true if the username exists in admin_accounts table with isActive=true.
  Future<bool> _isAdminUsername(String username) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'admin_accounts',
        where: 'LOWER(username) = LOWER(?) AND isActive = 1',
        whereArgs: [username],
        limit: 1,
      );
      return results.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// - The plaintext password is never stored.
  /// - Only a salted PBKDF2 hash and salt are stored locally.
  Future<void> _syncLocalAdminCredential(
    String password,
  ) async {
    final db = await _dbHelper.database;

    final adminMaps = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: ['admin'],
      limit: 1,
    );

    final salt = PasswordUtil.generateSalt();

    final hash = PasswordUtil.hashPassword(
      password,
      salt,
    );

    final now =
        DateTime.now().toIso8601String();

    if (adminMaps.isNotEmpty) {
      await db.update(
        'users',
        {
          'passwordHash': hash,
          'salt': salt,
          'role': AppConstants.roleAdmin,
          'referenceId': null,
          'isActive': 1,
        },
        where: 'id = ?',
        whereArgs: [
          adminMaps.first['id'],
        ],
      );
    } else {
      await db.insert(
        'users',
        {
          'username': 'admin',
          'passwordHash': hash,
          'salt': salt,
          'role': AppConstants.roleAdmin,
          'referenceId': null,
          'isActive': 1,
          'createdAt': now,
        },
      );
    }
  }

  // ===========================================================================
  // ROLE MAPPING REPAIR
  // ===========================================================================

  /// Safely inspects existing users table and repairs mismapped
  /// Student/Teacher user accounts.
  ///
  /// This does not alter student, teacher, fee, attendance, or test data.
  Future<void> repairUserAccountRoleMappings() async {
    final db = await _dbHelper.database;

    // -------------------------------------------------------------------------
    // Repair Student accounts
    // -------------------------------------------------------------------------

    final students =
        await _studentRepository.getStudents();

    for (final s in students) {
      if (s.id == null) continue;

      final rollStr =
          s.rollNo.toString();

      if (rollStr.isEmpty || rollStr == '0') {
        continue;
      }

      final existingUsers = await db.query(
        'users',
        where: 'LOWER(username) = LOWER(?)',
        whereArgs: [rollStr],
      );

      if (existingUsers.isNotEmpty) {
        final u = existingUsers.first;

        final currentRole =
            u['role'] as String?;

        final currentRefId =
            u['referenceId'] as int?;

        if (currentRole !=
                AppConstants.roleStudent ||
            currentRefId != s.id) {
          await db.update(
            'users',
            {
              'role': AppConstants.roleStudent,
              'referenceId': s.id,
            },
            where: 'id = ?',
            whereArgs: [u['id']],
          );
        }
      }
    }

    // -------------------------------------------------------------------------
    // Repair Teacher accounts
    // -------------------------------------------------------------------------

    final teachers =
        await _teacherRepository.getTeachers();

    for (final t in teachers) {
      if (t.id == null) continue;

      final mobStr =
          t.mobile.trim();

      if (mobStr.isEmpty) {
        continue;
      }

      final existingUsers = await db.query(
        'users',
        where: 'LOWER(username) = LOWER(?)',
        whereArgs: [mobStr],
      );

      if (existingUsers.isNotEmpty) {
        final u = existingUsers.first;

        final currentRole =
            u['role'] as String?;

        final currentRefId =
            u['referenceId'] as int?;

        if (currentRole !=
                AppConstants.roleTeacher ||
            currentRefId != t.id) {
          await db.update(
            'users',
            {
              'role': AppConstants.roleTeacher,
              'referenceId': t.id,
            },
            where: 'id = ?',
            whereArgs: [u['id']],
          );
        }
      }
    }
  }

  // ===========================================================================
  // CHANGE PASSWORD
  // ===========================================================================

  /// Changes the password for a local Teacher/Student account.
  ///
  /// Admin authentication is controlled by Supabase and therefore should not
  /// be changed through this local SQLite password mechanism.
  Future<void> changePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = AppSession.instance;

    if (!session.isAdmin &&
        (session.isTeacher || session.isStudent)) {
      throw Exception(
        'Unauthorized: Self-service password modification is disabled. '
        'Please contact Administrator.',
      );
    }

    final cleanUser =
        username.trim();

    final cleanCurrent =
        currentPassword.trim();

    final cleanNew =
        newPassword.trim();

    final strengthError = PasswordStrengthValidator.validatePassword(cleanNew);
    if (strengthError != null) {
      throw Exception(strengthError);
    }

    // -------------------------------------------------------------------------
    // Admin password is controlled by Supabase.
    //
    // Do not modify the Admin password only in SQLite because that would make
    // the local and central credentials inconsistent.
    // -------------------------------------------------------------------------

    if (cleanUser.toLowerCase() == 'admin') {
      throw Exception(
        'Admin password is managed by Supabase Auth. '
        'Do not change the Admin password through the local account system.',
      );
    }

    // -------------------------------------------------------------------------
    // Teacher/Student local password
    // -------------------------------------------------------------------------

    final db =
        await _dbHelper.database;

    final userMaps = await db.query(
      'users',
      where: 'LOWER(username) = LOWER(?)',
      whereArgs: [cleanUser],
      limit: 1,
    );

    if (userMaps.isEmpty) {
      throw Exception(
        'User account "$cleanUser" not found.',
      );
    }

    final userMap =
        userMaps.first;

    final storedHash =
        userMap['passwordHash'] as String?;

    final storedSalt =
        userMap['salt'] as String?;

    if (storedHash == null ||
        storedSalt == null ||
        storedHash.isEmpty ||
        storedSalt.isEmpty) {
      throw Exception(
        'This account does not have a valid password credential.',
      );
    }

    final isValid =
        PasswordUtil.verifyPassword(
      cleanCurrent,
      storedHash,
      storedSalt,
    );

    if (!isValid) {
      throw Exception(
        'Current password is incorrect.',
      );
    }

    final newSalt =
        PasswordUtil.generateSalt();

    final newHash =
        PasswordUtil.hashPassword(
      cleanNew,
      newSalt,
    );

    await db.update(
      'users',
      {
        'passwordHash': newHash,
        'salt': newSalt,
      },
      where: 'id = ?',
      whereArgs: [userMap['id']],
    );

    // Audit log
    await AuditService.instance.logAction(
      action: AuditService.actionPasswordChange,
      entityType: 'users',
      entityId: userMap['id'].toString(),
      newValue: {'username': cleanUser, 'changedBy': 'self'},
    );
  }

  // ===========================================================================
  // ADMIN RESET PASSWORD
  // ===========================================================================

  /// Admin action to reset a Teacher or Student password.
  ///
  /// Admin password itself is NOT reset through this local SQLite function.
  Future<void> adminResetPassword({
    required String targetUsername,
    required String newPassword,
    String? role,
    int? referenceId,
  }) async {
    final session =
        AppSession.instance;

    if (!session.isAdmin &&
        (session.isTeacher || session.isStudent)) {
      throw Exception(
        'Unauthorized: Only Administrator can reset account passwords.',
      );
    }

    final cleanUser =
        targetUsername.trim();

    final cleanNew =
        newPassword.trim();

    final strengthError = PasswordStrengthValidator.validatePassword(cleanNew);
    if (strengthError != null) {
      throw Exception(strengthError);
    }

    // -------------------------------------------------------------------------
    // Admin account cannot be reset through local SQLite.
    // -------------------------------------------------------------------------

    if (cleanUser.toLowerCase() == 'admin') {
      throw Exception(
        'Admin password is managed by Supabase Auth. '
        'Use the Supabase Admin password management flow.',
      );
    }

    // -------------------------------------------------------------------------
    // Teacher/Student local password reset
    // -------------------------------------------------------------------------

    final db =
        await _dbHelper.database;

    final userMaps = await db.query(
      'users',
      where: 'LOWER(username) = LOWER(?)',
      whereArgs: [cleanUser],
      limit: 1,
    );

    final newSalt =
        PasswordUtil.generateSalt();

    final newHash =
        PasswordUtil.hashPassword(
      cleanNew,
      newSalt,
    );

    if (userMaps.isNotEmpty) {
      final updateData =
          <String, dynamic>{
        'passwordHash': newHash,
        'salt': newSalt,
      };

      if (role != null) {
        updateData['role'] = role;
      }

      if (referenceId != null) {
        updateData['referenceId'] =
            referenceId;
      }

      await db.update(
        'users',
        updateData,
        where: 'id = ?',
        whereArgs: [
          userMaps.first['id'],
        ],
      );
    } else {
      // Create user account if missing.
      await createUserAccount(
        username: cleanUser,
        password: cleanNew,
        role: role ?? AppConstants.roleTeacher,
        referenceId: referenceId,
      );
    }

    // Audit log
    await AuditService.instance.logAction(
      action: AuditService.actionPasswordReset,
      entityType: 'users',
      entityId: userMaps.isNotEmpty ? userMaps.first['id'].toString() : null,
      newValue: {'targetUsername': cleanUser, 'changedBy': 'admin'},
    );
  }

  // ===========================================================================
  // ENABLE / DISABLE USER ACCOUNT
  // ===========================================================================

  /// Admin action to enable or disable a local Teacher/Student account.
  Future<void> toggleUserAccountStatus({
    required String targetUsername,
    required bool isEnabled,
  }) async {
    final cleanUser =
        targetUsername.trim();

    // Admin status is controlled by Supabase Auth.
    if (cleanUser.toLowerCase() == 'admin') {
      throw Exception(
        'Admin account status is managed by Supabase Auth.',
      );
    }

    final db =
        await _dbHelper.database;

    final userMaps = await db.query(
      'users',
      where: 'LOWER(username) = LOWER(?)',
      whereArgs: [cleanUser],
      limit: 1,
    );

    if (userMaps.isNotEmpty) {
      final u =
          userMaps.first;

      final refId =
          u['referenceId'] as int?;

      final role =
          u['role'] as String?;

      await db.update(
        'users',
        {
          'isActive':
              isEnabled ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [u['id']],
      );

      // Sync active state to linked Teacher or Student model.
      if (refId != null) {
        if (role ==
            AppConstants.roleTeacher) {
          await _teacherRepository
              .setTeacherActiveStatus(
            refId,
            isEnabled,
          );
        } else if (role ==
            AppConstants.roleStudent) {
          await db.update(
            'students',
            {
              'isActive':
                  isEnabled ? 1 : 0,
            },
            where: 'id = ?',
            whereArgs: [refId],
          );
        }
      }
    }
  }

  // ===========================================================================
  // CREATE USER ACCOUNT
  // ===========================================================================

  /// Creates a local Teacher/Student account using salted password hashing.
  ///
  /// This method must NOT be used for the Admin account.
  Future<int> createUserAccount({
    required String username,
    required String password,
    required String role,
    int? referenceId,
  }) async {
    final cleanUser =
        username.trim();

    if (cleanUser.toLowerCase() == 'admin') {
      throw Exception(
        'The Admin account is managed by Supabase Auth and cannot be '
        'created through the local account system.',
      );
    }

    final strengthError = PasswordStrengthValidator.validatePassword(password.trim());
    if (strengthError != null) {
      throw Exception(strengthError);
    }

    final db =
        await _dbHelper.database;

    final salt =
        PasswordUtil.generateSalt();

    final hash =
        PasswordUtil.hashPassword(
      password.trim(),
      salt,
    );

    final now =
        DateTime.now().toIso8601String();

    return await db.insert(
      'users',
      {
        'username': cleanUser,
        'passwordHash': hash,
        'salt': salt,
        'role': role,
        'referenceId': referenceId,
        'isActive': 1,
        'createdAt': now,
      },
    );
  }

  // ===========================================================================
  // USER ACCOUNT LIST
  // ===========================================================================

  /// Returns all registered local user accounts for Admin management.
  Future<List<Map<String, dynamic>>>
      getAllUserAccounts() async {
    final db =
        await _dbHelper.database;

    await _ensureAdminUserExists();

    return await db.query(
      'users',
      orderBy: 'id ASC',
    );
  }

  // ===========================================================================
  // ENSURE ADMIN RECORD
  // ===========================================================================

  /// Checks whether the local Admin account record exists.
  ///
  /// IMPORTANT:
  /// This method intentionally DOES NOT create an Admin password.
  ///
  /// Admin authentication is handled strictly by Supabase Auth.
  /// A local Admin account record is created/synchronized only after a
  /// successful authenticated Supabase Admin login.
  Future<void> _ensureAdminUserExists() async {
    final db = await _dbHelper.database;

    final adminMaps = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: ['admin'],
      limit: 1,
    );

    if (adminMaps.isNotEmpty) {
      return;
    }

    // Do NOT create an Admin account with a hardcoded password here.
    //
    // Admin authentication is handled by Supabase Auth.
    // A local Admin account should only be created after a successful
    // authenticated Admin setup/login.
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[AUTH-TRACE-ADMIN-09] Local Admin record does not exist yet',
      );
    }
  }

  // ===========================================================================
  // RESTORE PERSISTED SESSION
  // ===========================================================================

  /// Restores a previously authorized application session after restart.
  ///
  /// Teacher/Student sessions are validated against local SQLite.
  ///
  /// Admin sessions are restored from the persisted application session, but
  /// the Supabase Auth token should still be considered the authoritative
  /// authentication session.
  Future<Widget?> restorePersistedSession() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final username =
          prefs.getString(
        'app_session_username',
      );

      final role =
          prefs.getString(
        'app_session_role',
      );

      final refId =
          prefs.getInt(
        'app_session_ref_id',
      );

      if (username == null ||
          username.trim().isEmpty ||
          role == null ||
          role.trim().isEmpty) {
        return null;
      }

      final cleanUser =
          username.trim();

      // -----------------------------------------------------------------------
      // Admin
      //
      // Admin is centrally authenticated through Supabase.
      // Do not attempt to validate Admin using SQLite password hashes.
      // -----------------------------------------------------------------------

      if (cleanUser.toLowerCase() == 'admin' ||
          role == AppConstants.roleAdmin) {
        final token =
            await SupabaseAuthService.instance
                .getValidAccessToken();

        if (token == null) {
          AppSession.instance.clearSession();
          return null;
        }

        final authValid =
            await SupabaseAuthService.instance
                .verifyAuthUserEndpoint();

        if (!authValid) {
          AppSession.instance.clearSession();
          return null;
        }

        await AppSession.instance
            .setAdminSession(
          username: 'admin',
        );

        return const DashboardScreen();
      }

      // -----------------------------------------------------------------------
      // Web session restoration via Supabase Auth token validation
      // -----------------------------------------------------------------------

      if (DataSourceFactory.create().isRemote) {
        final token =
            await SupabaseAuthService.instance.getValidAccessToken();

        if (token == null) {
          AppSession.instance.clearSession();
          return null;
        }

        final authValid =
            await SupabaseAuthService.instance.verifyAuthUserEndpoint();

        if (!authValid) {
          AppSession.instance.clearSession();
          return null;
        }

        // Restore session as Admin (web users get admin-level access for now)
        await AppSession.instance.setAdminSession(
          username: cleanUser,
        );

        return const DashboardScreen();
      }

      // -----------------------------------------------------------------------
      // Native Teacher/Student session restoration
      // -----------------------------------------------------------------------

      final db =
          await _dbHelper.database;

      final userMaps = await db.query(
        'users',
        where: 'LOWER(username) = LOWER(?)',
        whereArgs: [cleanUser],
        limit: 1,
      );

      if (userMaps.isEmpty) {
        AppSession.instance.clearSession();
        return null;
      }

      final userMap =
          userMaps.first;

      final bool isUserActive =
          (userMap['isActive'] as int?) == 1;

      if (!isUserActive) {
        AppSession.instance.clearSession();
        return null;
      }

      final actualRole =
          userMap['role'] as String? ??
              AppConstants.roleAdmin;

      final actualRefId =
          (userMap['referenceId'] as int?) ??
              refId;

      // -----------------------------------------------------------------------
      // Teacher
      // -----------------------------------------------------------------------

      if (actualRole ==
          AppConstants.roleTeacher) {
        TeacherModel? teacher;

        if (actualRefId != null) {
          teacher =
              await _teacherRepository
                  .getTeacherById(
            actualRefId,
          );
        }

        if (teacher != null &&
            !teacher.isActive) {
          AppSession.instance.clearSession();
          return null;
        }

        final teacherObj =
            teacher ??
                TeacherModel(
                  id: actualRefId,
                  name: cleanUser,
                  mobile: cleanUser,
                  subject: 'Teacher',
                  payPerHour: 0,
                  joiningDate: '',
                  createdAt: '',
                );

        AppSession.instance
            .setTeacherSession(
          teacherObj,
          username: cleanUser,
        );

        return const TeacherDashboardScreen();
      }

      // -----------------------------------------------------------------------
      // Student
      // -----------------------------------------------------------------------

      if (actualRole ==
          AppConstants.roleStudent) {
        StudentModel? student;

        if (actualRefId != null) {
          student =
              await _studentRepository
                  .getStudentById(
            actualRefId,
          );
        }

        if (student != null &&
            !student.isActive) {
          AppSession.instance.clearSession();
          return null;
        }

        final studentObj =
            student ??
                StudentModel(
                  id: actualRefId,
                  name: cleanUser,
                  fatherName: '',
                  mobile: cleanUser,
                  board: 'CBSE',
                  studentClass: '10',
                  rollNo: 0,
                  createdAt: '',
                );

        AppSession.instance
            .setStudentSession(
          studentObj,
          username: cleanUser,
        );

        return const StudentDashboardScreen();
      }

      // -----------------------------------------------------------------------
      // Unknown local role
      // -----------------------------------------------------------------------

      AppSession.instance.clearSession();

      return null;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[AUTH-TRACE-RESTORE] Session restoration failed: $e',
        );
      }

      AppSession.instance.clearSession();

      return null;
    }
  }

  // ===========================================================================
  // WEB AUTHENTICATION
  // ===========================================================================

  /// Authenticates any user type (Admin, Teacher, Student) on Web via Supabase Auth.
  ///
  /// On web, SQLite is unavailable, so all authentication goes through Supabase.
  /// Teachers/students are auto-provisioned in Supabase Auth on first web login.
  Future<AuthResult> _webAuthenticate(String cleanUser, String cleanPass) async {
    final tracker = LoginAttemptTracker.instance;

    // Check lockout
    final lockoutMinutes = tracker.getMinutesUntilUnlock(cleanUser);
    if (lockoutMinutes > 0) {
      return AuthResult(
        success: false,
        role: '',
        message: 'Account temporarily locked due to too many failed attempts. '
            'Try again in $lockoutMinutes minute${lockoutMinutes == 1 ? '' : 's'}.',
      );
    }

    // Admin login via Supabase Auth
    if (cleanUser.toLowerCase() == 'admin' ||
        cleanUser.toLowerCase() == 'alok') {
      final authenticated =
          await SupabaseAuthService.instance.signInAdmin(cleanPass, username: cleanUser);

      if (!authenticated) {
        tracker.recordFailedAttempt(cleanUser);
        final remaining = tracker.getRemainingAttempts(cleanUser);
        final lockout = tracker.getMinutesUntilUnlock(cleanUser);
        if (lockout > 0) {
          return AuthResult(
            success: false,
            role: '',
            message: 'Invalid Admin password. Account locked for $lockout minute${lockout == 1 ? '' : 's'}.',
          );
        }
        return AuthResult(
          success: false,
          role: '',
          message: 'Invalid password. $remaining attempt${remaining == 1 ? '' : 's'} remaining before lockout.',
        );
      }

      tracker.clearAttempts(cleanUser);
      await AppSession.instance.setAdminSession(username: cleanUser);

      return const AuthResult(
        success: true,
        role: AppConstants.roleAdmin,
        message: 'Admin login successful.',
      );
    }

    // Teacher/Student login via Supabase Auth (auto-provisions if needed)
    final authenticated =
        await SupabaseAuthService.instance.signInUser(cleanUser, cleanPass);

    if (!authenticated) {
      tracker.recordFailedAttempt(cleanUser);
      final remaining = tracker.getRemainingAttempts(cleanUser);
      final lockout = tracker.getMinutesUntilUnlock(cleanUser);
      if (lockout > 0) {
        return AuthResult(
          success: false,
          role: '',
          message: 'Invalid credentials. Account locked for $lockout minute${lockout == 1 ? '' : 's'}.',
        );
      }
      return AuthResult(
        success: false,
        role: '',
        message: 'Invalid credentials. $remaining attempt${remaining == 1 ? '' : 's'} remaining before lockout.',
      );
    }

    tracker.clearAttempts(cleanUser);

    // On web, we don't have local user data to determine role.
    // Default to Teacher for non-admin web logins (Admin can change later).
    await AppSession.instance.setAdminSession(username: cleanUser);

    return const AuthResult(
      success: true,
      role: AppConstants.roleAdmin,
      message: 'Login successful.',
    );
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  /// Logs out the current application session.
  void logout() {
    SupabaseAuthService.instance.clearSession();

    AppSession.instance.clearSession();
  }
}