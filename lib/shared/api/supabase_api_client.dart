import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/config/backend_config.dart';
import '../../shared/services/supabase_auth_service.dart';
import 'api_client.dart';

/// Supabase REST API client implementation.
///
/// Wraps all HTTP calls with:
/// - Automatic JWT header injection
/// - Retry logic for transient failures (429, 5xx, network errors)
/// - Consistent error handling via [ApiResult]
/// - Timeout on every request
class SupabaseApiClient extends ApiClient {
  final http.Client _httpClient;
  final int maxRetries;
  final Duration timeout;
  final Duration retryDelay;

  SupabaseApiClient({
    http.Client? httpClient,
    this.maxRetries = 2,
    this.timeout = const Duration(seconds: 15),
    this.retryDelay = const Duration(seconds: 1),
  }) : _httpClient = httpClient ?? http.Client();

  // ══════════════════════════════════════════════════════════════════════
  // IDENTITY
  // ══════════════════════════════════════════════════════════════════════

  @override
  String get backendName => 'supabase';

  @override
  bool get isConfigured => BackendConfig.isBackendConfigured;

  String get _baseUrl => BackendConfig.supabaseUrl ?? '';

  // ══════════════════════════════════════════════════════════════════════
  // HEADERS
  // ══════════════════════════════════════════════════════════════════════

  Future<Map<String, String>> _headers() async {
    final anonKey = BackendConfig.supabaseAnonKey ?? '';
    final jwtToken = await SupabaseAuthService.instance.getValidAccessToken();
    return {
      'apikey': anonKey,
      if (jwtToken != null) 'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
  }

  // ══════════════════════════════════════════════════════════════════════
  // CRUD
  // ══════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<List<Map<String, dynamic>>>> fetch(
    String table, {
    String select = '*',
    String? filter,
    int? limit,
  }) async {
    if (!isConfigured) {
      return ApiResult.failure('Backend not configured');
    }

    final params = <String>['select=$select'];
    if (filter != null) params.add(filter);
    if (limit != null) params.add('limit=$limit');
    final url = '$_baseUrl/rest/v1/$table?${params.join('&')}';

    final response = await _requestWithRetry(() async {
      final hdrs = await _headers();
      return _httpClient.get(Uri.parse(url), headers: hdrs).timeout(timeout);
    });

    if (response == null) {
      return ApiResult.failure('Request timed out', retryable: true);
    }

    if (response.statusCode != 200) {
      return ApiResult.failure(
        'Fetch failed: ${response.statusCode}',
        statusCode: response.statusCode,
        retryable: _isRetryable(response.statusCode),
      );
    }

    try {
      final data = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.failure('Failed to parse response: $e');
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    if (!isConfigured) {
      return ApiResult.failure('Backend not configured');
    }

    final url = '$_baseUrl/rest/v1/$table';

    final response = await _requestWithRetry(() async {
      final hdrs = await _headers();
      return _httpClient
          .post(Uri.parse(url), headers: hdrs, body: jsonEncode(data))
          .timeout(timeout);
    });

    if (response == null) {
      return ApiResult.failure('Request timed out', retryable: true);
    }

    if (response.statusCode != 201 && response.statusCode != 200) {
      return ApiResult.failure(
        'Insert failed: ${response.statusCode}',
        statusCode: response.statusCode,
        retryable: _isRetryable(response.statusCode),
      );
    }

    try {
      final result = jsonDecode(response.body);
      if (result is List && result.isNotEmpty) {
        return ApiResult.success(result.first as Map<String, dynamic>);
      }
      return ApiResult.success(data);
    } catch (e) {
      return ApiResult.success(data);
    }
  }

  @override
  Future<ApiResult<int>> update(
    String table,
    Map<String, dynamic> data, {
    required String filter,
  }) async {
    if (!isConfigured) {
      return ApiResult.failure('Backend not configured');
    }

    final url = '$_baseUrl/rest/v1/$table?$filter';

    final response = await _requestWithRetry(() async {
      final hdrs = await _headers();
      return _httpClient
          .patch(Uri.parse(url), headers: hdrs, body: jsonEncode(data))
          .timeout(timeout);
    });

    if (response == null) {
      return ApiResult.failure('Request timed out', retryable: true);
    }

    if (response.statusCode != 200 && response.statusCode != 204) {
      return ApiResult.failure(
        'Update failed: ${response.statusCode}',
        statusCode: response.statusCode,
        retryable: _isRetryable(response.statusCode),
      );
    }

    // Supabase returns affected row count in response header or body
    try {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (body is List) return ApiResult.success(body.length);
      return ApiResult.success(1);
    } catch (_) {
      return ApiResult.success(1);
    }
  }

  @override
  Future<ApiResult<int>> delete(
    String table, {
    required String filter,
  }) async {
    if (!isConfigured) {
      return ApiResult.failure('Backend not configured');
    }

    final url = '$_baseUrl/rest/v1/$table?$filter';

    final response = await _requestWithRetry(() async {
      final hdrs = await _headers();
      return _httpClient.delete(Uri.parse(url), headers: hdrs).timeout(timeout);
    });

    if (response == null) {
      return ApiResult.failure('Request timed out', retryable: true);
    }

    if (response.statusCode != 200 && response.statusCode != 204) {
      return ApiResult.failure(
        'Delete failed: ${response.statusCode}',
        statusCode: response.statusCode,
        retryable: _isRetryable(response.statusCode),
      );
    }

    return ApiResult.success(1);
  }

  @override
  Future<ApiResult<int>> upsert(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    if (!isConfigured) {
      return ApiResult.failure('Backend not configured');
    }

    final url = '$_baseUrl/rest/v1/$table';

    final response = await _requestWithRetry(() async {
      final hdrs = await _headers();
      // Supabase upsert uses POST with Prefer: resolution=merge-duplicates
      final upsertHeaders = Map<String, String>.from(hdrs)
        ..['Prefer'] = 'resolution=merge-duplicates,return=representation';
      return _httpClient
          .post(Uri.parse(url), headers: upsertHeaders, body: jsonEncode(data))
          .timeout(timeout);
    });

    if (response == null) {
      return ApiResult.failure('Request timed out', retryable: true);
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      return ApiResult.failure(
        'Upsert failed: ${response.statusCode}',
        statusCode: response.statusCode,
        retryable: _isRetryable(response.statusCode),
      );
    }

    try {
      final result = jsonDecode(response.body);
      if (result is List) return ApiResult.success(result.length);
      return ApiResult.success(data.length);
    } catch (_) {
      return ApiResult.success(data.length);
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> rpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    if (!isConfigured) {
      return ApiResult.failure('Backend not configured');
    }

    final url = '$_baseUrl/rest/v1/rpc/$functionName';

    final response = await _requestWithRetry(() async {
      final hdrs = await _headers();
      return _httpClient
          .post(Uri.parse(url), headers: hdrs, body: jsonEncode(params ?? {}))
          .timeout(timeout);
    });

    if (response == null) {
      return ApiResult.failure('Request timed out', retryable: true);
    }

    if (response.statusCode != 200) {
      return ApiResult.failure(
        'RPC failed: ${response.statusCode}',
        statusCode: response.statusCode,
        retryable: _isRetryable(response.statusCode),
      );
    }

    try {
      final result = jsonDecode(response.body);
      if (result is Map<String, dynamic>) return ApiResult.success(result);
      return ApiResult.success({'result': result});
    } catch (e) {
      return ApiResult.failure('Failed to parse RPC response: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // RETRY LOGIC
  // ══════════════════════════════════════════════════════════════════════

  /// Execute [request] with automatic retry on transient failures.
  Future<http.Response?> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await request();

        // Retry on rate limit (429) or server errors (5xx)
        if (_isRetryable(response.statusCode) && attempt < maxRetries) {
          final delay = retryDelay * (attempt + 1); // linear backoff
          await Future.delayed(delay);
          continue;
        }

        return response;
      } on TimeoutException {
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * (attempt + 1));
          continue;
        }
        return null;
      } catch (e) {
        // Network errors — retry if attempts remain
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * (attempt + 1));
          continue;
        }
        return null;
      }
    }
    return null;
  }

  /// Whether a status code indicates a transient failure worth retrying.
  bool _isRetryable(int statusCode) {
    return statusCode == 429 || // Too Many Requests
        (statusCode >= 500 && statusCode < 600); // Server errors
  }
}
