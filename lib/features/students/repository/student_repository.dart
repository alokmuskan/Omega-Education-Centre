import '../../../core/database/database_helper.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/services/audit_service.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/utils/password_util.dart';
import '../models/student_model.dart';

class StudentRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // ──────────────────────────────────────────────────────────────────────
  // Insert Student
  // Returns the new student's ID and seeds users account with role = Student.
  // ──────────────────────────────────────────────────────────────────────

  Future<int> insertStudent(StudentModel student) async {
    final db = await _databaseHelper.database;
    final id = await db.insert('students', student.toMap());

    // Automatically seed user account for student with role = Student
    final rollStr = student.rollNo.toString();
    if (rollStr.isNotEmpty && rollStr != '0') {
      final existing = await db.query(
        'users',
        where: 'LOWER(username) = LOWER(?)',
        whereArgs: [rollStr],
      );
      if (existing.isEmpty) {
        final salt = PasswordUtil.generateSalt();
        final hash = PasswordUtil.hashPassword(rollStr, salt);
        await db.insert('users', {
          'username': rollStr,
          'passwordHash': hash,
          'salt': salt,
          'role': AppConstants.roleStudent,
          'referenceId': id,
          'isActive': 1,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    }

    // Register with SyncEngine for central offline-first sync
    final createdStudent = student.copyWith(id: id);
    SyncEngine.instance.registerStudentChange(
      studentId: id,
      operation: 'CREATE',
      payload: createdStudent.toMap(),
    );

    // Audit log
    await AuditService.instance.logAction(
      action: AuditService.actionStudentCreate,
      entityType: 'students',
      entityId: id.toString(),
      newValue: student.toMap(),
    );

    return id;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get All Students (active only, ordered by name)
  // ──────────────────────────────────────────────────────────────────────

  Future<List<StudentModel>> getStudents() async {
    final db = await _databaseHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return maps.map(StudentModel.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Get Student By ID
  // ──────────────────────────────────────────────────────────────────────

  Future<StudentModel?> getStudentById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return StudentModel.fromMap(maps.first);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Update Student
  // ──────────────────────────────────────────────────────────────────────

  Future<int> updateStudent(StudentModel student) async {
    final db = await _databaseHelper.database;

    // Capture old state for audit
    Map<String, dynamic>? oldState;
    if (student.id != null) {
      final oldMaps = await db.query('students', where: 'id = ?', whereArgs: [student.id], limit: 1);
      if (oldMaps.isNotEmpty) oldState = Map<String, dynamic>.from(oldMaps.first);
    }

    final result = await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );

    if (student.id != null) {
      SyncEngine.instance.registerStudentChange(
        studentId: student.id!,
        operation: 'UPDATE',
        payload: student.toMap(),
      );

      // Audit log
      await AuditService.instance.logAction(
        action: AuditService.actionStudentUpdate,
        entityType: 'students',
        entityId: student.id.toString(),
        oldValue: oldState,
        newValue: student.toMap(),
      );
    }

    return result;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Update Fee Status cache label (called after each payment)
  // This is a display cache only — not used for financial math.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> updateFeeStatusCache(
    int studentId,
    String computedStatus,
  ) async {
    final db = await _databaseHelper.database;
    await db.update(
      'students',
      {'feeStatus': computedStatus},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Soft Delete (marks isActive = 0, never physically deletes)
  // ──────────────────────────────────────────────────────────────────────

  Future<int> deactivateStudent(int id) async {
    final db = await _databaseHelper.database;
    final result = await db.update(
      'students',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    SyncEngine.instance.registerStudentChange(
      studentId: id,
      operation: 'DELETE',
      payload: {'id': id, 'isActive': 0},
    );

    // Audit log
    await AuditService.instance.logAction(
      action: AuditService.actionStudentDelete,
      entityType: 'students',
      entityId: id.toString(),
      newValue: {'id': id, 'isActive': 0},
    );

    return result;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Search / Filter
  // ──────────────────────────────────────────────────────────────────────

  Future<List<StudentModel>> searchStudents({
    String? query,
    String? board,
    String? studentClass,
  }) async {
    final db = await _databaseHelper.database;

    final conditions = <String>['isActive = 1'];
    final args = <dynamic>[];

    if (query != null && query.isNotEmpty) {
      conditions.add('(name LIKE ? OR mobile LIKE ? OR fatherName LIKE ?)');
      final q = '%$query%';
      args.addAll([q, q, q]);
    }
    if (board != null && board != 'All') {
      conditions.add('board = ?');
      args.add(board);
    }
    if (studentClass != null && studentClass != 'All') {
      conditions.add('studentClass = ?');
      args.add(studentClass);
    }

    final maps = await db.query(
      'students',
      where: conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );

    return maps.map(StudentModel.fromMap).toList();
  }
}