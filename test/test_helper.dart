import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:omega_education_centre/shared/utils/encryption_key_manager.dart';

/// Common test setup for all tests that use the database.
///
/// Call this at the top of each test file's main() function:
///
/// ```dart
/// void main() {
///   setUpTestDatabase();
///   // ... tests ...
/// }
/// ```
void setUpTestDatabase() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Skip SQLCipher encryption in tests (no native plugin available).
  EncryptionKeyManager.testMode = true;
}
