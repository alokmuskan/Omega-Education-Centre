import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';

/// Lightweight, non-breaking health check service for central Supabase backend connectivity.
///
/// Verifies whether the Flutter application can reach the Supabase backend
/// when internet is available, falling back gracefully to local offline mode.
class SupabaseHealthService {
  SupabaseHealthService._();

  static final SupabaseHealthService instance = SupabaseHealthService._();

  /// Performs a safe, read-only HTTP connectivity check against Supabase REST endpoint.
  ///
  /// Returns `true` if Supabase responds with HTTP 200/204/401/403 (indicating endpoint is reachable),
  /// or `false` if connection times out or device is offline.
  Future<bool> checkConnectivity({Duration timeout = const Duration(seconds: 3)}) async {
    if (!BackendConfig.isBackendConfigured) {
      return false;
    }

    try {
      final String baseUrl = BackendConfig.supabaseUrl!;
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        return false;
      }

      final String fullUrl = baseUrl.endsWith('/') ? '${baseUrl}rest/v1/' : '$baseUrl/rest/v1/';
      final Uri uri = Uri.parse(fullUrl);

      final response = await http
          .get(
            uri,
            headers: {
              'apikey': BackendConfig.supabaseAnonKey ?? '',
            },
          )
          .timeout(
            timeout,
            onTimeout: () => http.Response('Timeout', 504),
          );

      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      // Offline fallback for any network, DNS, socket, or parsing errors
      return false;
    }
  }
}
