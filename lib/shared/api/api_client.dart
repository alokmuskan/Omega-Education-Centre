/// Abstract API client interface.
///
/// All feature code should depend on this interface rather than using
/// raw `http` calls. The [ApiClientFactory] selects the correct
/// implementation (Supabase, Firebase, custom backend) at runtime.
///
/// This makes it possible to swap backends without changing feature code.
abstract class ApiClient {
  // ══════════════════════════════════════════════════════════════════════
  // IDENTITY
  // ══════════════════════════════════════════════════════════════════════

  /// Name of the backend (e.g. 'supabase', 'firebase', 'custom').
  String get backendName;

  /// Whether the client is configured and ready to make requests.
  bool get isConfigured;

  // ══════════════════════════════════════════════════════════════════════
  // CRUD OPERATIONS
  // ══════════════════════════════════════════════════════════════════════

  /// Fetch rows from a table with optional select/filter/order params.
  ///
  /// [table] — table or view name (e.g. 'students', 'fee_payments').
  /// [select] — column spec (e.g. 'id,name,classId' or '*').
  /// [filter] — Supabase-style query params (e.g. 'isActive=eq.true&order=name.asc').
  /// [limit] — max rows to return (null = no limit).
  Future<ApiResult<List<Map<String, dynamic>>>> fetch(
    String table, {
    String select,
    String filter,
    int? limit,
  });

  /// Insert a single row into [table].
  Future<ApiResult<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  );

  /// Update rows in [table] matching [filter].
  Future<ApiResult<int>> update(
    String table,
    Map<String, dynamic> data, {
    required String filter,
  });

  /// Delete rows from [table] matching [filter].
  Future<ApiResult<int>> delete(
    String table, {
    required String filter,
  });

  /// Upsert (insert or update) rows in [table].
  Future<ApiResult<int>> upsert(
    String table,
    List<Map<String, dynamic>> data,
  );

  /// Execute a raw RPC call (Supabase Edge Function or PostgREST function).
  Future<ApiResult<Map<String, dynamic>>> rpc(
    String functionName, {
    Map<String, dynamic>? params,
  });
}

/// Unified result wrapper for API calls.
///
/// Encapsulates success data or error information with retry guidance.
class ApiResult<T> {
  final T? data;
  final ApiError? error;
  final bool isRetryable;

  const ApiResult({this.data, this.error, this.isRetryable = false});

  bool get isSuccess => data != null && error == null;
  bool get isFailure => error != null;

  factory ApiResult.success(T data) => ApiResult(data: data);

  factory ApiResult.failure(String message, {bool retryable = false, int? statusCode}) {
    return ApiResult(
      error: ApiError(message: message, statusCode: statusCode),
      isRetryable: retryable,
    );
  }
}

/// Error details from an API call.
class ApiError {
  final String message;
  final int? statusCode;
  final String? details;

  const ApiError({required this.message, this.statusCode, this.details});

  @override
  String toString() => 'ApiError($statusCode: $message)';
}
