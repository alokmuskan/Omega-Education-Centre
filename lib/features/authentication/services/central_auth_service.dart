/// Central Identity Service mapping ERP User IDs to central authentication identifiers.
///
/// Preserves the existing User ID + Password login experience without exposing
/// internal email formats to end-users or changing the Flutter UI layout.
class CentralAuthService {
  CentralAuthService._();

  static final CentralAuthService instance = CentralAuthService._();

  /// Converts a standard ERP User ID (e.g., '9498', 'admin') to an email identifier.
  ///
  /// If the input already looks like an email (contains '@'), it is returned as-is.
  /// Otherwise, it maps to an internal domain: 'admin' → 'admin@omega.internal'.
  static String mapUserIdToEmail(String userId, {String domain = 'omega.internal'}) {
    final cleanUser = userId.trim();
    // If user already entered an email address, use it directly
    if (cleanUser.contains('@')) {
      return cleanUser.toLowerCase();
    }
    return '${cleanUser.toLowerCase()}@$domain';
  }

  /// Maps central user identity attributes for central authentication.
  Map<String, dynamic> createCentralIdentityMap({
    required String userId,
    required String role,
    required String orgId,
    String? referenceId,
  }) {
    return {
      'username': userId.trim(),
      'email': mapUserIdToEmail(userId),
      'role': role,
      'organisation_id': orgId,
      'reference_id': referenceId,
      'is_active': true,
    };
  }
}
