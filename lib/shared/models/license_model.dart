/// License model for subscription management.
///
/// License tiers:
/// - Trial: 14-day full access
/// - Free: Basic features only
/// - Standard: All features
/// - Premium: All features + priority support
class LicenseModel {
  final String key;
  final String tier; // 'trial', 'free', 'standard', 'premium'
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String? instituteName;
  final int maxUsers;
  final List<String> enabledModules;

  const LicenseModel({
    required this.key,
    required this.tier,
    required this.issuedAt,
    required this.expiresAt,
    this.instituteName,
    this.maxUsers = 1,
    this.enabledModules = const [],
  });

  /// Whether the license is currently valid (not expired).
  bool get isValid => DateTime.now().isBefore(expiresAt);

  /// Whether the license is expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Days remaining until expiry.
  int get daysRemaining => expiresAt.difference(DateTime.now()).inDays;

  /// Whether the license is in trial period.
  bool get isTrial => tier == 'trial';

  /// Whether this is a free tier license.
  bool get isFree => tier == 'free';

  /// Whether premium features are enabled.
  bool get hasPremiumFeatures => tier == 'standard' || tier == 'premium' || tier == 'trial';

  /// Whether a specific module is enabled.
  bool isModuleEnabled(String module) {
    if (hasPremiumFeatures) return true;
    return enabledModules.contains(module);
  }

  Map<String, dynamic> toMap() => {
        'key': key,
        'tier': tier,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'instituteName': instituteName,
        'maxUsers': maxUsers,
        'enabledModules': enabledModules,
      };

  factory LicenseModel.fromMap(Map<String, dynamic> map) => LicenseModel(
        key: map['key'] as String? ?? '',
        tier: map['tier'] as String? ?? 'free',
        issuedAt: DateTime.tryParse(map['issuedAt'] ?? '') ?? DateTime.now(),
        expiresAt: DateTime.tryParse(map['expiresAt'] ?? '') ?? DateTime.now().add(const Duration(days: 14)),
        instituteName: map['instituteName'] as String?,
        maxUsers: map['maxUsers'] as int? ?? 1,
        enabledModules: List<String>.from(map['enabledModules'] ?? []),
      );

  /// Creates a free tier license.
  factory LicenseModel.free() => LicenseModel(
        key: 'FREE-${DateTime.now().millisecondsSinceEpoch}',
        tier: 'free',
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 365 * 10)), // 10 years
      );

  /// Creates a trial license (14 days).
  factory LicenseModel.trial({String? instituteName}) => LicenseModel(
        key: 'TRIAL-${DateTime.now().millisecondsSinceEpoch}',
        tier: 'trial',
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 14)),
        instituteName: instituteName,
        maxUsers: 3,
      );

  /// Creates a standard license.
  factory LicenseModel.standard({required String key, String? instituteName, int maxUsers = 5}) => LicenseModel(
        key: key,
        tier: 'standard',
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 365)),
        instituteName: instituteName,
        maxUsers: maxUsers,
      );
}
