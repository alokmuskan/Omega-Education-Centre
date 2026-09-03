import '../../../core/database/database_helper.dart';
import '../../../shared/utils/password_util.dart';
import '../../students/models/student_model.dart';

/// Result of parent authentication.
class ParentAuthResult {
  final bool success;
  final String message;
  final StudentModel? student;
  final String? parentName;

  const ParentAuthResult({
    required this.success,
    required this.message,
    this.student,
    this.parentName,
  });
}

/// Repository for Parent Portal authentication.
///
/// Parents log in using their mobile number (linked to a student record).
/// Password is the student's roll number (default) or a custom password.
class ParentAuthRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Authenticates a parent using mobile number and password.
  ///
  /// The parent account is auto-provisioned on first login using the student's
  /// roll number as the default password.
  Future<ParentAuthResult> login(String mobile, String password) async {
    final cleanMobile = mobile.trim();
    final cleanPass = password.trim();

    if (cleanMobile.isEmpty || cleanPass.isEmpty) {
      return const ParentAuthResult(
        success: false,
        message: 'Mobile number and password are required.',
      );
    }

    final db = await _dbHelper.database;

    // Find student by mobile (linked via fatherName or student mobile)
    final students = await db.query(
      'students',
      where: 'mobile = ? AND isActive = 1',
      whereArgs: [cleanMobile],
      limit: 1,
    );

    if (students.isEmpty) {
      return const ParentAuthResult(
        success: false,
        message: 'No active student found with this mobile number.',
      );
    }

    final student = StudentModel.fromMap(students.first);

    // Check if parent account exists
    final parentMaps = await db.query(
      'users',
      where: 'LOWER(username) = LOWER(?) AND role = ?',
      whereArgs: [cleanMobile, 'Parent'],
      limit: 1,
    );

    if (parentMaps.isNotEmpty) {
      // Existing parent account — verify password
      final storedHash = parentMaps.first['passwordHash'] as String?;
      final storedSalt = parentMaps.first['salt'] as String?;

      if (storedHash != null && storedSalt != null) {
        final valid = PasswordUtil.verifyPassword(cleanPass, storedHash, storedSalt);
        if (!valid) {
          return const ParentAuthResult(
            success: false,
            message: 'Invalid password.',
          );
        }
      }
    } else {
      // Auto-provision parent account with student roll number as password
      final defaultPassword = student.rollNo.toString();
      if (cleanPass != defaultPassword) {
        return ParentAuthResult(
          success: false,
          message: 'Default password is your child\'s roll number ($defaultPassword).',
        );
      }

      // Create parent user account
      final salt = PasswordUtil.generateSalt();
      final hash = PasswordUtil.hashPassword(cleanPass, salt);
      await db.insert('users', {
        'username': cleanMobile,
        'passwordHash': hash,
        'salt': salt,
        'role': 'Parent',
        'referenceId': student.id,
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    return ParentAuthResult(
      success: true,
      message: 'Login successful.',
      student: student,
      parentName: student.fatherName,
    );
  }
}
