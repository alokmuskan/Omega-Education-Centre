import '../../../core/database/database_helper.dart';
import '../models/holiday_model.dart';
import '../models/event_model.dart';
import '../models/term_model.dart';

/// Repository for Academic Calendar CRUD operations.
class AcademicCalendarRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Holidays ──────────────────────────────────────────────────

  Future<List<HolidayModel>> getHolidays() async {
    final db = await _dbHelper.database;
    final maps = await db.query('holidays', orderBy: 'date ASC');
    return maps.map((m) => HolidayModel.fromMap(m)).toList();
  }

  Future<List<HolidayModel>> getHolidaysForMonth(int year, int month) async {
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'holidays',
      where: "date LIKE ? AND isActive = 1",
      whereArgs: ['$prefix%'],
      orderBy: 'date ASC',
    );
    return maps.map((m) => HolidayModel.fromMap(m)).toList();
  }

  Future<HolidayModel?> getHolidayById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('holidays', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return HolidayModel.fromMap(maps.first);
  }

  Future<int> insertHoliday(HolidayModel holiday) async {
    final db = await _dbHelper.database;
    return await db.insert('holidays', holiday.toMap());
  }

  Future<void> updateHoliday(HolidayModel holiday) async {
    final db = await _dbHelper.database;
    await db.update(
      'holidays',
      {...holiday.toMap(), 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [holiday.id],
    );
  }

  Future<void> deleteHoliday(int id) async {
    final db = await _dbHelper.database;
    await db.delete('holidays', where: 'id = ?', whereArgs: [id]);
  }

  // ── Events ────────────────────────────────────────────────────

  Future<List<EventModel>> getEvents() async {
    final db = await _dbHelper.database;
    final maps = await db.query('academic_events', orderBy: 'startDate ASC');
    return maps.map((m) => EventModel.fromMap(m)).toList();
  }

  Future<List<EventModel>> getEventsForMonth(int year, int month) async {
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'academic_events',
      where: "isActive = 1 AND (startDate LIKE ? OR (endDate IS NOT NULL AND endDate LIKE ?))",
      whereArgs: ['$prefix%', '$prefix%'],
      orderBy: 'startDate ASC',
    );
    return maps.map((m) => EventModel.fromMap(m)).toList();
  }

  Future<List<EventModel>> getUpcomingEvents({int limit = 5}) async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final maps = await db.query(
      'academic_events',
      where: "isActive = 1 AND startDate >= ?",
      whereArgs: [today],
      orderBy: 'startDate ASC',
      limit: limit,
    );
    return maps.map((m) => EventModel.fromMap(m)).toList();
  }

  Future<EventModel?> getEventById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('academic_events', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return EventModel.fromMap(maps.first);
  }

  Future<int> insertEvent(EventModel event) async {
    final db = await _dbHelper.database;
    return await db.insert('academic_events', event.toMap());
  }

  Future<void> updateEvent(EventModel event) async {
    final db = await _dbHelper.database;
    await db.update(
      'academic_events',
      {...event.toMap(), 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<void> deleteEvent(int id) async {
    final db = await _dbHelper.database;
    await db.delete('academic_events', where: 'id = ?', whereArgs: [id]);
  }

  // ── Terms ─────────────────────────────────────────────────────

  Future<List<TermModel>> getTerms({String? academicYear}) async {
    final db = await _dbHelper.database;
    final where = academicYear != null ? 'academicYear = ?' : null;
    final whereArgs = academicYear != null ? [academicYear] : null;
    final maps = await db.query('academic_terms', where: where, whereArgs: whereArgs, orderBy: 'startDate ASC');
    return maps.map((m) => TermModel.fromMap(m)).toList();
  }

  Future<TermModel?> getActiveTerm() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final maps = await db.query(
      'academic_terms',
      where: "isActive = 1 AND startDate <= ? AND endDate >= ?",
      whereArgs: [today, today],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TermModel.fromMap(maps.first);
  }

  Future<int> insertTerm(TermModel term) async {
    final db = await _dbHelper.database;
    return await db.insert('academic_terms', term.toMap());
  }

  Future<void> updateTerm(TermModel term) async {
    final db = await _dbHelper.database;
    await db.update(
      'academic_terms',
      {...term.toMap(), 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [term.id],
    );
  }

  Future<void> deleteTerm(int id) async {
    final db = await _dbHelper.database;
    await db.delete('academic_terms', where: 'id = ?', whereArgs: [id]);
  }

  // ── Helpers ───────────────────────────────────────────────────

  /// Checks if a given date is a holiday.
  Future<bool> isHoliday(String date) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'holidays',
      where: "date = ? AND isActive = 1",
      whereArgs: [date],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Returns the total number of holidays in a given month.
  Future<int> getHolidayCountForMonth(int year, int month) async {
    final holidays = await getHolidaysForMonth(year, month);
    return holidays.length;
  }
}
