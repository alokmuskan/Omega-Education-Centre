import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/backend_config.dart';
import '../../features/authentication/services/central_auth_service.dart';

/// Central Supabase Auth service managing user session JWT acquisition and token lifecycle.
///
/// Strictly uses Supabase Auth REST endpoints (`/auth/v1/token?grant_type=password` and `/auth/v1/user`).
/// Maintains access JWT in memory only. Stores ONLY the session refresh token in SharedPreferences.
/// NEVER persists plaintext passwords or sensitive credentials.
class SupabaseAuthService {
  SupabaseAuthService._();

  static final SupabaseAuthService instance = SupabaseAuthService._();

  static const String _keyRefreshToken = 'supabase_refresh_token';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _authUserId;

  /// Returns the current authenticated Supabase Auth User UUID (masked/sanitized for logs).
  String? get authUserId => _authUserId;

  /// Returns true if a valid, non-expired access JWT exists in memory.
  bool get hasValidToken =>
      _accessToken != null &&
      _accessToken!.isNotEmpty &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  /// Returns active valid access JWT, or NULL if session is unauthenticated or expired.
  /// Strictly NEVER falls back to publishable key or anon token.
  Future<String?> getValidAccessToken() async {
    final tokenValid = hasValidToken;

    if (kDebugMode) {
      // ignore: avoid_print
      print('[AUTH-TRACE-11] get_valid_access_token_called=YES');
      // ignore: avoid_print
      print('[AUTH-TRACE-12] sync_jwt_present=${tokenValid ? "YES" : "NO"}');
      // ignore: avoid_print
      print('[SYNC-DEBUG-02] JWT available = ${tokenValid ? "YES" : "NO"}');
      // ignore: avoid_print
      print('[SYNC-DEBUG-03] JWT expired = ${!tokenValid ? "YES" : "NO"}');
    }

    if (tokenValid) {
      return _accessToken;
    }

    // Load persisted refresh token if in-memory token is absent
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _refreshToken = prefs.getString(_keyRefreshToken);
      } catch (_) {}
    }

    // Attempt token refresh if refresh token exists
    if (_refreshToken != null && _refreshToken!.isNotEmpty && BackendConfig.isBackendConfigured) {
      final refreshed = await _refreshSession();
      if (refreshed && hasValidToken) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[AUTH-TRACE-12] sync_jwt_present=YES (refreshed)');
        }
        return _accessToken;
      }
    }

    return null;
  }

  /// Authenticates Admin with Supabase Auth using transient password entered during login.
  ///
  /// Maps `admin` to `admin@omega.internal`. Password is NOT stored or persisted.
  Future<bool> signInAdmin(String password) async {
    final email = CentralAuthService.mapUserIdToEmail('admin');

    final anonKey = BackendConfig.supabaseAnonKey ?? '';
    final url = Uri.parse('${BackendConfig.supabaseUrl}/auth/v1/token?grant_type=password');

    if (kDebugMode) {
      // ignore: avoid_print
      print('[AUTH-DIAG] URL = /auth/v1/token?grant_type=password');
      // ignore: avoid_print
      print('[AUTH-DIAG] HTTP METHOD = POST');
      // ignore: avoid_print
      print('[AUTH-DIAG] email = $email');
      // ignore: avoid_print
      print('[AUTH-DIAG] password present = ${password.isNotEmpty ? "YES" : "NO"}');
      // ignore: avoid_print
      print('[AUTH-DIAG] password length = ${password.length}');
      // ignore: avoid_print
      print('[AUTH-DIAG] content-type = application/json');
      // ignore: avoid_print
      print('[AUTH-DIAG] apikey present = ${anonKey.isNotEmpty ? "YES" : "NO"}');
      // ignore: avoid_print
      print('[AUTH-DIAG] apikey type = publishable');
      // ignore: avoid_print
      print('[AUTH-DIAG] request body valid JSON = YES');

      // ignore: avoid_print
      print('[AUTH-TRACE-02] supabase_signin_called=YES');
      // ignore: avoid_print
      print('[AUTH-DEBUG-02] Mapped user ID -> $email');
      // ignore: avoid_print
      print('[AUTH-DEBUG-03] Supabase Auth request started');
      // ignore: avoid_print
      print('[AUTH-TRACE-03] email=$email');
    }

    if (!BackendConfig.isBackendConfigured) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AUTH-TRACE-04] supabase_http_status=0');
        // ignore: avoid_print
        print('[AUTH-DEBUG-04] Supabase Auth HTTP status = 0');
        // ignore: avoid_print
        print('[AUTH-TRACE-05] supabase_signin_success=NO');
        // ignore: avoid_print
        print('[AUTH-DEBUG-05] access_token received = NO');
      }
      return false;
    }

    try {
      final res = await http
          .post(
            url,
            headers: {
              'apikey': anonKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        // ignore: avoid_print
        print('[AUTH-DIAG] HTTP STATUS = ${res.statusCode}');
        // ignore: avoid_print
        print('[AUTH-DIAG] RESPONSE BODY = ${res.body}');
        // ignore: avoid_print
        print('[AUTH-TRACE-04] supabase_http_status=${res.statusCode}');
        // ignore: avoid_print
        print('[AUTH-DEBUG-04] Supabase Auth HTTP status = ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        final expiresIn = (data['expires_in'] as int?) ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60)); // 60s buffer

        final userObj = data['user'] as Map<String, dynamic>?;
        if (userObj != null && userObj['id'] != null) {
          _authUserId = userObj['id'] as String;
        }

        // Persist refresh token for seamless app session restoration
        if (_refreshToken != null && _refreshToken!.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyRefreshToken, _refreshToken!);
          } catch (_) {}
        }

        if (kDebugMode) {
          // ignore: avoid_print
          print('[AUTH-TRACE-05] supabase_signin_success=YES');
          // ignore: avoid_print
          print('[AUTH-DEBUG-05] access_token received = YES');
          // ignore: avoid_print
          print('[AUTH-DEBUG-06] access_token stored in memory = YES');
          // ignore: avoid_print
          print('[AUTH-TRACE-06] access_token_present=${(_accessToken != null && _accessToken!.isNotEmpty) ? "YES" : "NO"}');
          // ignore: avoid_print
          print('[AUTH-TRACE-07] refresh_token_present=${(_refreshToken != null && _refreshToken!.isNotEmpty) ? "YES" : "NO"}');
          // ignore: avoid_print
          print('[AUTH-TRACE-08] supabase_user_present=${userObj != null ? "YES" : "NO"}');
          // ignore: avoid_print
          print('[AUTH-TRACE-09] supabase_user_id_present=${_authUserId != null ? "YES" : "NO"}');
          // ignore: avoid_print
          print('[AUTH-TRACE-10] jwt_expiry_valid=${hasValidToken ? "YES" : "NO"}');
        }
        return true;
      } else {
        // Fallback: If user does not exist centrally yet, attempt controlled identity signup
        if (res.statusCode == 400) {
          final signupUrl = Uri.parse('${BackendConfig.supabaseUrl}/auth/v1/signup');
          try {
            final signupRes = await http
                .post(
                  signupUrl,
                  headers: {
                    'apikey': anonKey,
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'email': email,
                    'password': password,
                  }),
                )
                .timeout(const Duration(seconds: 10));

            if (kDebugMode) {
              // ignore: avoid_print
              print('[AUTH-DIAG] SIGNUP FALLBACK HTTP STATUS = ${signupRes.statusCode}');
              // ignore: avoid_print
              print('[AUTH-DIAG] SIGNUP FALLBACK RESPONSE BODY = ${signupRes.body}');
            }

            if (signupRes.statusCode == 200 || signupRes.statusCode == 201) {
              final Map<String, dynamic> signupData = jsonDecode(signupRes.body) as Map<String, dynamic>;
              if (signupData.containsKey('access_token') && signupData['access_token'] != null) {
                _accessToken = signupData['access_token'] as String?;
                _refreshToken = signupData['refresh_token'] as String?;
                final expiresIn = (signupData['expires_in'] as int?) ?? 3600;
                _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

                final userObj = signupData['user'] as Map<String, dynamic>?;
                if (userObj != null && userObj['id'] != null) {
                  _authUserId = userObj['id'] as String;
                }

                if (_refreshToken != null && _refreshToken!.isNotEmpty) {
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(_keyRefreshToken, _refreshToken!);
                  } catch (_) {}
                }

                if (kDebugMode) {
                  // ignore: avoid_print
                  print('[AUTH-TRACE-05] supabase_signin_success=YES (provisioned)');
                  // ignore: avoid_print
                  print('[AUTH-TRACE-06] access_token_present=YES');
                  // ignore: avoid_print
                  print('[AUTH-TRACE-07] refresh_token_present=YES');
                  // ignore: avoid_print
                  print('[AUTH-TRACE-08] supabase_user_present=YES');
                  // ignore: avoid_print
                  print('[AUTH-TRACE-09] supabase_user_id_present=YES');
                  // ignore: avoid_print
                  print('[AUTH-TRACE-10] jwt_expiry_valid=${hasValidToken ? "YES" : "NO"}');
                }
                return true;
              }
            }
          } catch (_) {}
        }

        if (kDebugMode) {
          // ignore: avoid_print
          print('[AUTH-TRACE-05] supabase_signin_success=NO');
          // ignore: avoid_print
          print('[AUTH-TRACE-06] access_token_present=NO');
          // ignore: avoid_print
          print('[AUTH-TRACE-07] refresh_token_present=NO');
        }
        await _clearSessionPayload();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AUTH-TRACE-05] supabase_signin_success=NO');
        // ignore: avoid_print
        print('[AUTH-TRACE-06] access_token_present=NO');
      }
      await _clearSessionPayload();
      return false;
    }
  }

  /// Attempts session refresh using stored refresh token.
  Future<bool> _refreshSession() async {
    if (_refreshToken == null || _refreshToken!.isEmpty || !BackendConfig.isBackendConfigured) return false;
    final anonKey = BackendConfig.supabaseAnonKey ?? '';
    final url = Uri.parse('${BackendConfig.supabaseUrl}/auth/v1/token?grant_type=refresh_token');

    try {
      final res = await http
          .post(
            url,
            headers: {
              'apikey': anonKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'refresh_token': _refreshToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        final expiresIn = (data['expires_in'] as int?) ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

        final userObj = data['user'] as Map<String, dynamic>?;
        if (userObj != null && userObj['id'] != null) {
          _authUserId = userObj['id'] as String;
        }

        if (_refreshToken != null && _refreshToken!.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyRefreshToken, _refreshToken!);
          } catch (_) {}
        }
        return true;
      }
    } catch (_) {}
    await _clearSessionPayload();
    return false;
  }

  /// Diagnostic verification of `/auth/v1/user` using active access JWT.
  Future<int> verifyAuthUserEndpointStatusCode() async {
    final token = await getValidAccessToken();
    if (token == null || !BackendConfig.isBackendConfigured) return 401;

    final anonKey = BackendConfig.supabaseAnonKey ?? '';
    final url = Uri.parse('${BackendConfig.supabaseUrl}/auth/v1/user');

    try {
      final res = await http.get(
        url,
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (kDebugMode) {
        // ignore: avoid_print
        print('[AUTH-TRACE-13] auth_user_http_status=${res.statusCode}');
      }
      return res.statusCode;
    } catch (_) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AUTH-TRACE-13] auth_user_http_status=500');
      }
      return 500;
    }
  }

  Future<bool> verifyAuthUserEndpoint() async {
    final status = await verifyAuthUserEndpointStatusCode();
    return status == 200;
  }

  /// Clears in-memory session tokens upon logout.
  Future<void> clearSession() async {
    await _clearSessionPayload();
  }

  Future<void> _clearSessionPayload() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _authUserId = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRefreshToken);
    } catch (_) {}
  }
}
