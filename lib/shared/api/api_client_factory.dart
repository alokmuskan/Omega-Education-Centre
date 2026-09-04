import '../../shared/config/backend_config.dart';
import 'api_client.dart';
import 'supabase_api_client.dart';

/// Factory that provides the correct [ApiClient] implementation
/// based on the configured backend.
///
/// **Usage:**
/// ```dart
/// final api = ApiClientFactory.create();
/// final result = await api.fetch('students', select: 'id,name');
/// ```
///
/// Currently supports:
/// - **Supabase** — when `BackendConfig.isBackendConfigured` is true
/// - **No-op** — returns a dummy client that always fails gracefully
class ApiClientFactory {
  ApiClientFactory._();

  static ApiClient? _instance;

  /// Get or create the platform-appropriate API client.
  static ApiClient create() {
    if (_instance != null) return _instance!;

    if (BackendConfig.isBackendConfigured) {
      _instance = SupabaseApiClient();
    } else {
      _instance = _NoOpApiClient();
    }

    return _instance!;
  }

  /// Override the API client (useful for testing).
  static void override(ApiClient client) {
    _instance = client;
  }

  /// Reset to default (useful in tests).
  static void reset() {
    _instance = null;
  }
}

/// No-op API client used when no backend is configured.
/// All operations return graceful failures.
class _NoOpApiClient extends ApiClient {
  @override
  String get backendName => 'none';

  @override
  bool get isConfigured => false;

  @override
  Future<ApiResult<List<Map<String, dynamic>>>> fetch(
    String table, {
    String select = '*',
    String? filter,
    int? limit,
  }) async {
    return ApiResult.failure('No backend configured');
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    return ApiResult.failure('No backend configured');
  }

  @override
  Future<ApiResult<int>> update(
    String table,
    Map<String, dynamic> data, {
    required String filter,
  }) async {
    return ApiResult.failure('No backend configured');
  }

  @override
  Future<ApiResult<int>> delete(String table, {required String filter}) async {
    return ApiResult.failure('No backend configured');
  }

  @override
  Future<ApiResult<int>> upsert(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    return ApiResult.failure('No backend configured');
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> rpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    return ApiResult.failure('No backend configured');
  }
}
