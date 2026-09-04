import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../shared/config/backend_config.dart';
import '../../../shared/services/supabase_auth_service.dart';
import '../interfaces/data_source.dart';

/// Supabase REST-backed data source for the web platform.
///
/// Uses the Supabase REST API via `http` package.
/// This is the data source used when running in a browser.
class SupabaseDataSource extends DataSource {
  @override
  bool get isLocal => false;

  @override
  bool get isRemote => true;

  @override
  bool get supportsSync => false;

  // ══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════

  Future<Map<String, String>> _headers() async {
    final anonKey = BackendConfig.supabaseAnonKey ?? '';
    final jwtToken = await SupabaseAuthService.instance.getValidAccessToken();
    return {
      'apikey': anonKey,
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    };
  }

  String get _baseUrl => BackendConfig.supabaseUrl ?? '';

  Future<List<Map<String, dynamic>>> _restGet(String table, {String? select, String? filter}) async {
    if (_baseUrl.isEmpty || !BackendConfig.isBackendConfigured) return [];
    try {
      final hdrs = await _headers();
      var url = '$baseUrl/rest/v1/$table';
      final params = <String>[];
      if (select != null) params.add('select=$select');
      if (filter != null) params.add(filter);
      if (params.isNotEmpty) url += '?${params.join('&')}';
      final res = await http.get(Uri.parse(url), headers: hdrs).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  // ══════════════════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ══════════════════════════════════════════════════════════════════════

  @override
  Future<Map<String, dynamic>> authenticate(String username, String password) async {
    // On web, authentication goes through Supabase Auth.
    // This is handled by SupabaseAuthService directly — the data source
    // just validates the session exists.
    final token = await SupabaseAuthService.instance.getValidAccessToken();
    if (token == null) {
      throw Exception('Not authenticated via Supabase');
    }

    // Fetch user profile from Supabase
    final rows = await _restGet(
      'admin_accounts',
      select: 'id, username, displayName',
      filter: 'username=eq.${username.trim().toLowerCase()}',
    );

    if (rows.isNotEmpty) {
      return {
        'id': rows.first['id'],
        'username': rows.first['username'],
        'role': 'admin',
        'displayName': rows.first['displayName'] ?? rows.first['username'],
      };
    }

    // Check teachers
    final teacherRows = await _restGet(
      'teachers',
      select: 'id, username, name',
      filter: 'username=eq.${username.trim().toLowerCase()}&isActive=eq.true',
    );

    if (teacherRows.isNotEmpty) {
      return {
        'id': teacherRows.first['id'],
        'username': teacherRows.first['username'],
        'role': 'teacher',
        'displayName': teacherRows.first['name'],
      };
    }

    // Check students
    final studentRows = await _restGet(
      'students',
      select: 'id, username, name',
      filter: 'username=eq.${username.trim().toLowerCase()}&isActive=eq.true',
    );

    if (studentRows.isNotEmpty) {
      return {
        'id': studentRows.first['id'],
        'username': studentRows.first['username'],
        'role': 'student',
        'displayName': studentRows.first['name'],
      };
    }

    throw Exception('Invalid username or password');
  }

  @override
  Future<Map<String, dynamic>?> restoreSession() async {
    final token = await SupabaseAuthService.instance.getValidAccessToken();
    if (token == null) return null;

    // Token exists — we consider the session valid on web.
    // The actual user profile is loaded lazily.
    return {'authenticated': true, 'platform': 'web'};
  }

  // ══════════════════════════════════════════════════════════════════════
  // DASHBOARD DATA
  // ══════════════════════════════════════════════════════════════════════

  @override
  Future<DashboardData> loadDashboardData() async {
    if (!BackendConfig.isBackendConfigured) {
      return const DashboardData();
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Active Students
    final students = await _restGet('students', select: 'id', filter: 'isActive=eq.true');

    // Active Teachers
    final teachers = await _restGet('teachers', select: 'id', filter: 'isActive=eq.true');

    // Classes Today
    final classes = await _restGet('daily_class_records', select: 'id', filter: 'date=eq.$todayStr');

    // Student Attendance Today
    int present = 0, absent = 0, lateCount = 0, leave = 0;
    final attendance = await _restGet('student_attendance', select: 'status', filter: 'date=eq.$todayStr');
    for (final row in attendance) {
      final s = (row['status'] as String?) ?? '';
      if (s == 'Present') {
        present++;
      } else if (s == 'Absent') {
        absent++;
      } else if (s == 'Late') {
        lateCount++;
      } else if (s == 'Leave') {
        leave++;
      }
    }

    // Fee Due
    double feeDue = 0.0;
    final fees = await _restGet('fees', select: 'courseFee');
    for (final row in fees) {
      feeDue += (row['courseFee'] as num?)?.toDouble() ?? 0.0;
    }
    final paid = await _restGet('fee_payments', select: 'amountPaid');
    double totalPaid = 0.0;
    for (final row in paid) {
      totalPaid += (row['amountPaid'] as num?)?.toDouble() ?? 0.0;
    }
    feeDue = (feeDue - totalPaid).clamp(0.0, double.infinity);

    // Recent notices
    final notices = await _restGet('notices', select: '*', filter: 'order=createdAt.desc&limit=3');

    return DashboardData(
      activeStudentCount: students.length,
      activeTeacherCount: teachers.length,
      totalFeesCollected: totalPaid,
      pendingFees: feeDue,
      todayAttendance: present,
      recentNotices: notices,
    );
  }
}
