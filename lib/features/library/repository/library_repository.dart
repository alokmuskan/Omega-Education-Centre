import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/book_model.dart';
import '../models/book_issue_model.dart';

/// Library Repository
///
/// Handles all database operations for library book management and issue tracking.
class LibraryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ══════════════════════════════════════════════════════════════════════
  // BOOKS CRUD
  // ══════════════════════════════════════════════════════════════════════

  /// Insert a new book
  Future<int> insertBook(BookModel book) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final data = book.toMap()
      ..remove('id')
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    return await db.insert('books', data);
  }

  /// Get all active books
  Future<List<BookModel>> getBooks({String? category, String? search}) async {
    final db = await _dbHelper.database;
    String where = 'isActive = 1';
    List<dynamic> whereArgs = [];

    if (category != null && category.isNotEmpty) {
      where += ' AND category = ?';
      whereArgs.add(category);
    }

    if (search != null && search.isNotEmpty) {
      where += ' AND (title LIKE ? OR author LIKE ? OR isbn LIKE ?)';
      final s = '%$search%';
      whereArgs.addAll([s, s, s]);
    }

    final maps = await db.query('books', where: where, whereArgs: whereArgs, orderBy: 'title ASC');
    return maps.map((m) => BookModel.fromMap(m)).toList();
  }

  /// Get a book by ID
  Future<BookModel?> getBook(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('books', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return BookModel.fromMap(maps.first);
  }

  /// Update a book
  Future<int> updateBook(BookModel book) async {
    final db = await _dbHelper.database;
    final data = book.toMap()
      ..['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('books', data, where: 'id = ?', whereArgs: [book.id]);
  }

  /// Soft delete a book
  Future<int> deleteBook(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'books',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get book categories (distinct)
  Future<List<String>> getCategories() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT DISTINCT category FROM books WHERE category IS NOT NULL AND category != '' AND isActive = 1 ORDER BY category",
    );
    return result.map((r) => r['category'] as String).toList();
  }

  /// Get book count
  Future<int> getBookCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM books WHERE isActive = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total copies across all books
  Future<Map<String, int>> getCopiesStats() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(totalCopies) as total, SUM(availableCopies) as available FROM books WHERE isActive = 1',
    );
    return {
      'total': (result.first['total'] as int?) ?? 0,
      'available': (result.first['available'] as int?) ?? 0,
    };
  }

  // ══════════════════════════════════════════════════════════════════════
  // BOOK ISSUES CRUD
  // ══════════════════════════════════════════════════════════════════════

  /// Issue a book to a student
  Future<int> issueBook(BookIssueModel issue) async {
    final db = await _dbHelper.database;

    // Decrease available copies
    await db.rawUpdate(
      'UPDATE books SET availableCopies = availableCopies - 1, updatedAt = ? WHERE id = ? AND availableCopies > 0',
      [DateTime.now().toIso8601String(), issue.bookId],
    );

    final now = DateTime.now().toIso8601String();
    final data = issue.toMap()
      ..remove('id')
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    return await db.insert('book_issues', data);
  }

  /// Return a book
  Future<void> returnBook(int issueId, {double fine = 0, String? remarks}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    // Get the issue to find the bookId
    final issue = await getIssue(issueId);
    if (issue == null) return;

    // Update issue record
    await db.update(
      'book_issues',
      {
        'returnDate': now,
        'fineAmount': fine,
        'status': 'Returned',
        'remarks': remarks,
        'updatedAt': now,
      },
      where: 'id = ?',
      whereArgs: [issueId],
    );

    // Increase available copies
    await db.rawUpdate(
      'UPDATE books SET availableCopies = availableCopies + 1, updatedAt = ? WHERE id = ?',
      [now, issue.bookId],
    );
  }

  /// Get all issues (with joined book and student info)
  Future<List<BookIssueModel>> getIssues({
    String? status,
    int? studentId,
    int? bookId,
  }) async {
    final db = await _dbHelper.database;

    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null && status.isNotEmpty) {
      where += ' AND bi.status = ?';
      whereArgs.add(status);
    }
    if (studentId != null) {
      where += ' AND bi.studentId = ?';
      whereArgs.add(studentId);
    }
    if (bookId != null) {
      where += ' AND bi.bookId = ?';
      whereArgs.add(bookId);
    }

    final maps = await db.rawQuery('''
      SELECT 
        bi.*,
        b.title as bookTitle,
        b.author as bookAuthor,
        s.name as studentName,
        s.rollNo as studentRollNo,
        s.studentClass as studentClass
      FROM book_issues bi
      LEFT JOIN books b ON bi.bookId = b.id
      LEFT JOIN students s ON bi.studentId = s.id
      WHERE $where
      ORDER BY bi.issueDate DESC
    ''', whereArgs);

    return maps.map((m) => BookIssueModel.fromMap(m)).toList();
  }

  /// Get a single issue by ID
  Future<BookIssueModel?> getIssue(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('book_issues', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return BookIssueModel.fromMap(maps.first);
  }

  /// Delete an issue record (only if status is 'Issued')
  Future<int> deleteIssue(int id) async {
    final db = await _dbHelper.database;

    // Get the issue to restore available copies
    final issue = await getIssue(id);
    if (issue == null) return 0;

    if (issue.status == 'Issued') {
      // Restore available copies
      await db.rawUpdate(
        'UPDATE books SET availableCopies = availableCopies + 1, updatedAt = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), issue.bookId],
      );
    }

    return await db.delete('book_issues', where: 'id = ?', whereArgs: [id]);
  }

  /// Get issues for a specific student
  Future<List<BookIssueModel>> getStudentIssues(int studentId) async {
    return getIssues(studentId: studentId);
  }

  /// Get overdue issues
  Future<List<BookIssueModel>> getOverdueIssues() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final maps = await db.rawQuery('''
      SELECT 
        bi.*,
        b.title as bookTitle,
        b.author as bookAuthor,
        s.name as studentName,
        s.rollNo as studentRollNo,
        s.studentClass as studentClass
      FROM book_issues bi
      LEFT JOIN books b ON bi.bookId = b.id
      LEFT JOIN students s ON bi.studentId = s.id
      WHERE bi.status = 'Issued' AND bi.dueDate < ?
      ORDER BY bi.dueDate ASC
    ''', [now]);

    return maps.map((m) => BookIssueModel.fromMap(m)).toList();
  }

  /// Get issue count by status
  Future<Map<String, int>> getIssueStats() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT status, COUNT(*) as count FROM book_issues GROUP BY status
    ''');
    final stats = {'Issued': 0, 'Returned': 0, 'Overdue': 0};
    for (final row in result) {
      stats[row['status'] as String] = (row['count'] as int?) ?? 0;
    }
    return stats;
  }
}
