import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/license_model.dart';

/// Service for managing software license and subscription.
///
/// Features:
/// - License validation and persistence
/// - Feature gating based on tier
/// - Trial period management
/// - Expiry warnings
class LicenseService {
  LicenseService._();

  static final LicenseService instance = LicenseService._();

  static const String _licenseKey = 'app_license_key';
  static const String _licenseTier = 'app_license_tier';
  static const String _licenseExpiry = 'app_license_expiry';
  static const String _licenseIssued = 'app_license_issued';
  static const String _licenseInstitute = 'app_license_institute';
  static const String _licenseMaxUsers = 'app_license_max_users';

  LicenseModel? _currentLicense;
  bool _initialized = false;

  LicenseModel? get currentLicense => _currentLicense;
  bool get isInitialized => _initialized;

  // ── Initialization ────────────────────────────────────────────

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_licenseKey);
      final tier = prefs.getString(_licenseTier);

      if (key != null && tier != null) {
        _currentLicense = LicenseModel(
          key: key,
          tier: tier,
          issuedAt: DateTime.tryParse(prefs.getString(_licenseIssued) ?? '') ?? DateTime.now(),
          expiresAt: DateTime.tryParse(prefs.getString(_licenseExpiry) ?? '') ?? DateTime.now().add(const Duration(days: 14)),
          instituteName: prefs.getString(_licenseInstitute),
          maxUsers: prefs.getInt(_licenseMaxUsers) ?? 1,
        );
      } else {
        // No license — default to free
        _currentLicense = LicenseModel.free();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LICENSE] Init failed: $e');
      }
      _currentLicense = LicenseModel.free();
    }
    _initialized = true;
  }

  // ── License Management ────────────────────────────────────────

  /// Activates a license key.
  Future<bool> activateLicense(String key, {String? instituteName}) async {
    // In production, this would validate against a server.
    // For now, we accept known key patterns.
    final tier = _validateKey(key);
    if (tier == null) return false;

    final now = DateTime.now();
    _currentLicense = LicenseModel(
      key: key,
      tier: tier,
      issuedAt: now,
      expiresAt: tier == 'trial' ? now.add(const Duration(days: 14)) : now.add(const Duration(days: 365)),
      instituteName: instituteName,
      maxUsers: tier == 'premium' ? 50 : tier == 'standard' ? 10 : 3,
    );

    await _persistLicense();
    return true;
  }

  /// Starts a trial period.
  Future<void> startTrial({String? instituteName}) async {
    _currentLicense = LicenseModel.trial(instituteName: instituteName);
    await _persistLicense();
  }

  /// Resets to free tier.
  Future<void> resetToFree() async {
    _currentLicense = LicenseModel.free();
    await _persistLicense();
  }

  // ── Feature Gating ────────────────────────────────────────────

  /// Returns true if the given module/feature is enabled for current license.
  bool isFeatureEnabled(String feature) {
    if (_currentLicense == null) return false;
    return _currentLicense!.isModuleEnabled(feature);
  }

  /// Returns true if premium features are available.
  bool get hasPremiumFeatures => _currentLicense?.hasPremiumFeatures ?? false;

  /// Returns true if license is valid (not expired).
  bool get isValid => _currentLicense?.isValid ?? false;

  /// Returns true if license is expired.
  bool get isExpired => _currentLicense?.isExpired ?? true;

  /// Returns true if in trial period.
  bool get isTrial => _currentLicense?.isTrial ?? false;

  /// Days remaining until expiry.
  int get daysRemaining => _currentLicense?.daysRemaining ?? 0;

  /// Current license tier name.
  String get tierName {
    switch (_currentLicense?.tier) {
      case 'premium': return 'Premium';
      case 'standard': return 'Standard';
      case 'trial': return 'Trial';
      case 'free': return 'Free';
      default: return 'Free';
    }
  }

  /// Returns a warning message if license is about to expire.
  String? get expiryWarning {
    if (_currentLicense == null) return null;
    if (isExpired) return 'License expired. Please renew.';
    if (daysRemaining <= 3) return 'License expires in $daysRemaining day${daysRemaining == 1 ? '' : 's'}.';
    if (daysRemaining <= 7) return 'License expires in $daysRemaining days.';
    return null;
  }

  // ── Feature List ──────────────────────────────────────────────

  /// Returns list of features enabled for current tier.
  List<String> get enabledFeatures {
    if (_currentLicense == null) return [];
    if (hasPremiumFeatures) {
      return [
        'students', 'teachers', 'attendance', 'fees', 'tests',
        'notices', 'timetable', 'class_register', 'salary',
        'homework', 'academic_calendar', 'batches', 'branches',
        'id_card', 'analytics', 'audit_log', 'backup',
      ];
    }
    return ['students', 'teachers', 'attendance', 'notices'];
  }

  /// Returns list of features disabled for current tier.
  List<String> get disabledFeatures {
    final all = ['students', 'teachers', 'attendance', 'fees', 'tests',
      'notices', 'timetable', 'class_register', 'salary',
      'homework', 'academic_calendar', 'batches', 'branches',
      'id_card', 'analytics', 'audit_log', 'backup'];
    return all.where((f) => !enabledFeatures.contains(f)).toList();
  }

  // ── Internal ──────────────────────────────────────────────────

  String? _validateKey(String key) {
    // Simple pattern matching for demo purposes.
    // In production, validate against Supabase or license server.
    final upper = key.toUpperCase();
    if (upper.startsWith('PREMIUM-')) return 'premium';
    if (upper.startsWith('STD-') || upper.startsWith('STANDARD-')) return 'standard';
    if (upper.startsWith('TRIAL-')) return 'trial';
    if (upper.startsWith('FREE-')) return 'free';
    return null;
  }

  Future<void> _persistLicense() async {
    if (_currentLicense == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKey, _currentLicense!.key);
      await prefs.setString(_licenseTier, _currentLicense!.tier);
      await prefs.setString(_licenseExpiry, _currentLicense!.expiresAt.toIso8601String());
      await prefs.setString(_licenseIssued, _currentLicense!.issuedAt.toIso8601String());
      if (_currentLicense!.instituteName != null) {
        await prefs.setString(_licenseInstitute, _currentLicense!.instituteName!);
      }
      await prefs.setInt(_licenseMaxUsers, _currentLicense!.maxUsers);
    } catch (e) {
      if (kDebugMode) {
        print('[LICENSE] Persist failed: $e');
      }
    }
  }
}
