import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric authentication service for Omega Education Centre ERP.
///
/// Provides:
/// - Device capability detection (fingerprint, face)
/// - Enable/disable biometric login per user preference
/// - Authenticate via biometrics with fallback to password
/// - Persistent preference storage
///
/// Usage:
///   final canUse = await BiometricService.instance.canAuthenticate();
///   if (canUse) await BiometricService.instance.authenticate();
class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricUsernameKey = 'biometric_username';

  bool _isEnabled = false;
  String? _enrolledUsername;

  bool get isEnabled => _isEnabled;
  String? get enrolledUsername => _enrolledUsername;

  // ── Initialization ──────────────────────────────────────────────

  /// Loads biometric preference from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
      _enrolledUsername = prefs.getString(_biometricUsernameKey);
    } catch (_) {
      _isEnabled = false;
      _enrolledUsername = null;
    }
  }

  // ── Device Capability ───────────────────────────────────────────

  /// Returns true if the device supports biometric authentication.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      if (kDebugMode) {
        print('[BIOMETRIC] canCheckBiometrics failed: $e');
      }
      return false;
    }
  }

  /// Returns true if the device has any enrolled biometrics (fingerprint/face).
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('[BIOMETRIC] getAvailableBiometrics failed: $e');
      }
      return false;
    }
  }

  /// Returns true if biometric auth is both supported and has enrolled biometrics.
  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;
      return await hasEnrolledBiometrics();
    } catch (_) {
      return false;
    }
  }

  /// Returns a list of available biometric types on this device.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Returns a human-readable description of available biometrics.
  Future<String> getBiometricTypeLabel() async {
    final types = await getAvailableBiometrics();
    if (types.isEmpty) return 'None';

    final labels = <String>[];
    if (types.contains(BiometricType.fingerprint)) labels.add('Fingerprint');
    if (types.contains(BiometricType.face)) labels.add('Face');
    if (types.contains(BiometricType.iris)) labels.add('Iris');

    return labels.isEmpty ? 'Biometric' : labels.join(' / ');
  }

  // ── Authentication ──────────────────────────────────────────────

  /// Authenticates the user via biometrics.
  ///
  /// [reason] — The message shown in the biometric dialog.
  /// Returns true if authentication succeeded, false otherwise.
  Future<bool> authenticate({String? reason}) async {
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: reason ?? 'Verify your identity to continue',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow fallback to device PIN/pattern
          useErrorDialogs: true,
        ),
      );

      if (kDebugMode) {
        print('[BIOMETRIC] Auth result: $didAuth');
      }

      return didAuth;
    } catch (e) {
      if (kDebugMode) {
        print('[BIOMETRIC] Authentication failed: $e');
      }
      return false;
    }
  }

  /// Authenticates with biometrics only (no device PIN fallback).
  Future<bool> authenticateBiometricOnly({String? reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason ?? 'Verify your identity to continue',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('[BIOMETRIC] Biometric-only auth failed: $e');
      }
      return false;
    }
  }

  // ── Preference Management ───────────────────────────────────────

  /// Enables biometric login for the given username.
  ///
  /// Call this after a successful password login when the user opts in.
  Future<void> enableBiometric(String username) async {
    _isEnabled = true;
    _enrolledUsername = username;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, true);
      await prefs.setString(_biometricUsernameKey, username);
    } catch (_) {}
  }

  /// Disables biometric login.
  Future<void> disableBiometric() async {
    _isEnabled = false;
    _enrolledUsername = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, false);
      await prefs.remove(_biometricUsernameKey);
    } catch (_) {}
  }

  /// Returns true if biometric is enabled AND the given username matches.
  bool isBiometricEnabledFor(String username) {
    return _isEnabled && _enrolledUsername == username;
  }
}
