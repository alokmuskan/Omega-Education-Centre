import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/vehicle_model.dart';
import '../models/route_model.dart';
import '../models/student_transport_model.dart';

/// Transport Repository
///
/// Handles all database operations for transport management.
class TransportRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ══════════════════════════════════════════════════════════════════════
  // VEHICLES CRUD
  // ══════════════════════════════════════════════════════════════════════

  /// Insert a new vehicle
  Future<int> insertVehicle(VehicleModel vehicle) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final data = vehicle.toMap()
      ..remove('id')
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    return await db.insert('vehicles', data);
  }

  /// Get all active vehicles
  Future<List<VehicleModel>> getVehicles({String? search}) async {
    final db = await _dbHelper.database;
    String where = 'isActive = 1';
    List<dynamic> whereArgs = [];

    if (search != null && search.isNotEmpty) {
      where += ' AND (vehicleNumber LIKE ? OR driverName LIKE ?)';
      final s = '%$search%';
      whereArgs.addAll([s, s]);
    }

    final maps = await db.query('vehicles', where: where, whereArgs: whereArgs, orderBy: 'vehicleNumber ASC');
    return maps.map((m) => VehicleModel.fromMap(m)).toList();
  }

  /// Get a vehicle by ID
  Future<VehicleModel?> getVehicle(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('vehicles', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return VehicleModel.fromMap(maps.first);
  }

  /// Update a vehicle
  Future<int> updateVehicle(VehicleModel vehicle) async {
    final db = await _dbHelper.database;
    final data = vehicle.toMap()
      ..['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('vehicles', data, where: 'id = ?', whereArgs: [vehicle.id]);
  }

  /// Soft delete a vehicle
  Future<int> deleteVehicle(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'vehicles',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get vehicle count
  Future<int> getVehicleCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM vehicles WHERE isActive = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ══════════════════════════════════════════════════════════════════════
  // ROUTES CRUD
  // ══════════════════════════════════════════════════════════════════════

  /// Insert a new route
  Future<int> insertRoute(RouteModel route) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final data = route.toMap()
      ..remove('id')
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    return await db.insert('transport_routes', data);
  }

  /// Get all active routes (with vehicle info)
  Future<List<RouteModel>> getRoutes({int? vehicleId, String? search}) async {
    final db = await _dbHelper.database;
    String where = 'r.isActive = 1';
    List<dynamic> whereArgs = [];

    if (vehicleId != null) {
      where += ' AND r.vehicleId = ?';
      whereArgs.add(vehicleId);
    }
    if (search != null && search.isNotEmpty) {
      where += ' AND (r.routeName LIKE ? OR r.startPoint LIKE ? OR r.endPoint LIKE ?)';
      final s = '%$search%';
      whereArgs.addAll([s, s, s]);
    }

    final maps = await db.rawQuery('''
      SELECT 
        r.*,
        v.vehicleNumber,
        v.capacity as vehicleCapacity
      FROM transport_routes r
      LEFT JOIN vehicles v ON r.vehicleId = v.id
      WHERE $where
      ORDER BY r.routeName ASC
    ''', whereArgs);

    return maps.map((m) => RouteModel.fromMap(m)).toList();
  }

  /// Get a route by ID
  Future<RouteModel?> getRoute(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT 
        r.*,
        v.vehicleNumber,
        v.capacity as vehicleCapacity
      FROM transport_routes r
      LEFT JOIN vehicles v ON r.vehicleId = v.id
      WHERE r.id = ?
      LIMIT 1
    ''', [id]);
    if (maps.isEmpty) return null;
    return RouteModel.fromMap(maps.first);
  }

  /// Update a route
  Future<int> updateRoute(RouteModel route) async {
    final db = await _dbHelper.database;
    final data = route.toMap()
      ..['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('transport_routes', data, where: 'id = ?', whereArgs: [route.id]);
  }

  /// Soft delete a route
  Future<int> deleteRoute(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'transport_routes',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get route count
  Future<int> getRouteCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM transport_routes WHERE isActive = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ══════════════════════════════════════════════════════════════════════
  // STUDENT TRANSPORT CRUD
  // ══════════════════════════════════════════════════════════════════════

  /// Assign a student to a route
  Future<int> assignStudent(StudentTransportModel assignment) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final data = assignment.toMap()
      ..remove('id')
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    return await db.insert('student_transport', data);
  }

  /// Get all student transport assignments (with joined info)
  Future<List<StudentTransportModel>> getStudentAssignments({int? routeId, int? studentId}) async {
    final db = await _dbHelper.database;
    String where = 'st.isActive = 1';
    List<dynamic> whereArgs = [];

    if (routeId != null) {
      where += ' AND st.routeId = ?';
      whereArgs.add(routeId);
    }
    if (studentId != null) {
      where += ' AND st.studentId = ?';
      whereArgs.add(studentId);
    }

    final maps = await db.rawQuery('''
      SELECT 
        st.*,
        s.name as studentName,
        s.rollNo as studentRollNo,
        s.studentClass,
        r.routeName,
        v.vehicleNumber
      FROM student_transport st
      LEFT JOIN students s ON st.studentId = s.id
      LEFT JOIN transport_routes r ON st.routeId = r.id
      LEFT JOIN vehicles v ON r.vehicleId = v.id
      WHERE $where
      ORDER BY s.name ASC
    ''', whereArgs);

    return maps.map((m) => StudentTransportModel.fromMap(m)).toList();
  }

  /// Remove a student from a route
  Future<int> removeStudent(int assignmentId) async {
    final db = await _dbHelper.database;
    return await db.update(
      'student_transport',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [assignmentId],
    );
  }

  /// Get student count for a route
  Future<int> getStudentCount(int routeId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM student_transport WHERE routeId = ? AND isActive = 1',
      [routeId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total transport students
  Future<int> getTotalTransportStudents() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM student_transport WHERE isActive = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
