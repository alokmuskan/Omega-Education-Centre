import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the database encryption key for SQLCipher.
///
/// On first launch, a 256-bit encryption key is generated and stored securely.
/// On subsequent launches, the existing key is retrieved from secure storage.
///
/// The key is used to encrypt/decrypt the SQLite database via SQLCipher.
/// On platforms where SQLCipher is not available (Windows, Linux, Web),
/// the key is still generated and stored but the database is not encrypted
/// at the SQLite level (OS-level encryption is relied upon instead).
class EncryptionKeyManager {
  EncryptionKeyManager._();

  static final EncryptionKeyManager instance = EncryptionKeyManager._();

  static const String _keyAlias = 'omega_erp_db_encryption_key';
  static const String _keyHashAlias = 'omega_erp_db_key_hash';

  /// When true, skips flutter_secure_storage (for unit tests).
  static bool testMode = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  String? _cachedKey;

  /// In test mode, returns a static dummy key instead of using secure storage.
  static const String _testKey = 'test_encryption_key_000000000000000000000000000000';

  /// Returns the database encryption key, generating one if it doesn't exist.
  ///
  /// The key is a 64-character hex string derived from a 256-bit random value.
  /// This key is suitable for use as the SQLCipher password parameter.
  Future<String> getEncryptionKey() async {
    // In test mode, return a static dummy key (no secure storage).
    if (testMode) return _testKey;

    if (_cachedKey != null) return _cachedKey!;

    try {
      // Try to read existing key
      final existingKey = await _secureStorage.read(key: _keyAlias);

      if (existingKey != null && existingKey.isNotEmpty) {
        _cachedKey = existingKey;
        return existingKey;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ENCRYPTION] Failed to read existing key, generating new one: $e');
      }
    }

    // Generate new key
    final newKey = _generateKey();

    try {
      await _secureStorage.write(key: _keyAlias, value: newKey);

      // Store a hash for verification (not the key itself)
      final hash = sha256.convert(utf8.encode(newKey)).toString();
      await _secureStorage.write(key: _keyHashAlias, value: hash);

      if (kDebugMode) {
        print('[ENCRYPTION] New database encryption key generated and stored');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ENCRYPTION] Failed to store key: $e');
      }
      // If secure storage fails, use an in-memory fallback
      // This is less secure but allows the app to function
    }

    _cachedKey = newKey;
    return newKey;
  }

  /// Verifies that the stored key hash matches the current key.
  /// Returns true if the key is valid, false if tampered.
  Future<bool> verifyKeyIntegrity() async {
    try {
      final key = await getEncryptionKey();
      final storedHash = await _secureStorage.read(key: _keyHashAlias);

      if (storedHash == null) return false;

      final currentHash = sha256.convert(utf8.encode(key)).toString();
      return currentHash == storedHash;
    } catch (_) {
      return false;
    }
  }

  /// Clears the stored encryption key. Use with extreme caution.
  /// This will make the existing encrypted database unreadable.
  Future<void> clearKey() async {
    await _secureStorage.delete(key: _keyAlias);
    await _secureStorage.delete(key: _keyHashAlias);
    _cachedKey = null;

    if (kDebugMode) {
      print('[ENCRYPTION] Database encryption key cleared');
    }
  }

  /// Generates a cryptographically secure 256-bit key.
  String _generateKey() {
    final random = Random.secure();
    final bytes = Uint8List(32); // 256 bits
    for (var i = 0; i < 32; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
