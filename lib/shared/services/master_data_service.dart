import '../../core/database/database_helper.dart';

/// Master Data Service
///
/// Loads configurable lists (boards, classes, subjects) from the database.
/// Falls back to AppConstants defaults if no database entries exist.
class MasterDataService {
  static MasterDataService? _instance;
  static MasterDataService get instance => _instance ??= MasterDataService._();
  MasterDataService._();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ══════════════════════════════════════════════════════════════════════
  // BOARDS
  // ══════════════════════════════════════════════════════════════════════

  /// Default boards (used if database is empty)
  static const List<String> defaultBoards = ['CBSE', 'BSEB', 'ICSE', 'Others'];

  /// Get all active boards from database
  Future<List<String>> getBoards() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        "SELECT DISTINCT board FROM students WHERE board IS NOT NULL AND board != '' ORDER BY board",
      );
      final boards = result.map((r) => r['board'] as String).toList();

      // Merge with defaults to ensure we always have the standard boards
      final allBoards = <String>{...defaultBoards, ...boards}.toList();
      return allBoards;
    } catch (e) {
      return defaultBoards;
    }
  }

  /// Get boards with "All" option
  Future<List<String>> getBoardsWithAll() async {
    final boards = await getBoards();
    return ['All', ...boards];
  }

  /// Add a new board (adds a student with this board, or you can use master_data table)
  Future<void> addBoard(String board) async {
    // Boards are derived from student data, so this is a no-op
    // unless we create a master_data table
  }

  // ══════════════════════════════════════════════════════════════════════
  // CLASSES
  // ══════════════════════════════════════════════════════════════════════

  /// Default classes
  static const List<String> defaultClasses = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', 'Other'
  ];

  /// Get all active classes from database
  Future<List<String>> getClasses() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        "SELECT DISTINCT studentClass FROM students WHERE studentClass IS NOT NULL AND studentClass != '' ORDER BY studentClass",
      );
      final classes = result.map((r) => r['studentClass'] as String).toList();

      // Merge with defaults
      final allClasses = <String>{...defaultClasses, ...classes}.toList();
      return allClasses;
    } catch (e) {
      return defaultClasses;
    }
  }

  /// Get classes with "All" option
  Future<List<String>> getClassesWithAll() async {
    final classes = await getClasses();
    return ['All', ...classes];
  }

  // ══════════════════════════════════════════════════════════════════════
  // SUBJECTS
  // ══════════════════════════════════════════════════════════════════════

  /// Default subjects
  static const List<String> defaultSubjects = [
    'Mathematics',
    'Science',
    'English',
    'Hindi',
    'Social Science',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'Other',
  ];

  /// Get all subjects from test_subjects table
  Future<List<String>> getSubjects() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        "SELECT DISTINCT subjectName FROM test_subjects WHERE subjectName IS NOT NULL AND subjectName != '' ORDER BY subjectName",
      );
      final subjects = result.map((r) => r['subjectName'] as String).toList();

      // Merge with defaults
      final allSubjects = <String>{...defaultSubjects, ...subjects}.toList();
      return allSubjects;
    } catch (e) {
      return defaultSubjects;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // STUDENT CLASSES (for forms)
  // ══════════════════════════════════════════════════════════════════════

  /// Get student classes for dropdown (includes 'All' option)
  static List<String> get studentClasses => [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', 'Other'
  ];

  /// Get student classes without 'All'
  static List<String> get studentClassesOnly => [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', 'Other'
  ];
}
