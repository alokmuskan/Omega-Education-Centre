import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;

/// Password hashing utility using PBKDF2-HMAC-SHA256.
///
/// Provides secure password hashing and verification for the offline ERP.
/// Uses PBKDF2 with 10,000 iterations, 128-bit salt, and 256-bit derived key.
class PasswordUtil {
  PasswordUtil._();

  static const int _iterations = 10000;
  static const int _saltLength = 16; // 128 bits
  static const int _keyLength = 32; // 256 bits

  /// Generates a cryptographically secure random salt as hex string.
  static String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return _bytesToHex(saltBytes);
  }

  /// Hashes a password with the given salt using PBKDF2-HMAC-SHA256.
  /// Returns a 64-character hex string.
  static String hashPassword(String password, String salt) {
    final saltBytes = _hexToBytes(salt);
    final passwordBytes = utf8.encode(password);

    // PBKDF2 using HMAC-SHA256
    final key = _pbkdf2HmacSha256(passwordBytes, saltBytes, _iterations, _keyLength);
    return _bytesToHex(key);
  }

  /// Verifies a password against stored hash and salt.
  /// Returns true if the password matches.
  static bool verifyPassword(String password, String storedHash, String salt) {
    final computedHash = hashPassword(password, salt);
    // Constant-time comparison to prevent timing attacks
    if (computedHash.length != storedHash.length) return false;
    int result = 0;
    for (int i = 0; i < computedHash.length; i++) {
      result |= computedHash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return result == 0;
  }

  /// PBKDF2 key derivation using HMAC-SHA256.
  static List<int> _pbkdf2HmacSha256(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = crypto.Hmac(crypto.sha256, password);
    final blocks = <int>[];
    final blockSize = 32; // SHA-256 output size

    for (int i = 1; blocks.length < keyLength; i++) {
      // U1 = HMAC(password, salt || INT(i))
      var u = hmac.convert([...salt, ..._intToBytes(i)]).bytes;
      final t = List<int>.from(u);

      // U2 through Uc
      for (int j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (int k = 0; k < blockSize; k++) {
          t[k] ^= u[k];
        }
      }

      blocks.addAll(t);
    }

    return blocks.sublist(0, keyLength);
  }

  static List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}
