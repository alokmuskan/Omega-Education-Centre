import 'dart:math';
import '../../../core/database/database_helper.dart';
import '../../../shared/utils/password_util.dart';

/// Data container for Organisation Identity and Recovery status.
/// Plaintext recovery code is ONLY populated when a new code is freshly generated
/// so the UI can display it once to the Admin. It is NEVER stored in database or metadata.
class OrgIdentityData {
  final String organisationId;
  final String organisationName;
  final String recoveryCodeHash;
  final String recoveryCodeSalt;
  final String? newlyGeneratedCode; // Non-null ONLY on initial generation/reset

  const OrgIdentityData({
    required this.organisationId,
    required this.organisationName,
    required this.recoveryCodeHash,
    required this.recoveryCodeSalt,
    this.newlyGeneratedCode,
  });
}

/// Service managing immutable Organisation Identity and cryptographically secure
/// one-way hashed disaster recovery credentials.
class OrgIdentityService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static const String keyOrgId = 'org_id';
  static const String keyOrgName = 'org_name';
  static const String keyRecoveryHash = 'recovery_code_hash';
  static const String keyRecoverySalt = 'recovery_code_salt';

  /// Fetches existing Organisation Identity from DB settings or initializes default
  /// settings on fresh installation / v16 migration.
  Future<OrgIdentityData> getOrCreateOrgIdentity() async {
    String? orgId = await _dbHelper.getSetting(keyOrgId);
    String? orgName = await _dbHelper.getSetting(keyOrgName);
    String? hash = await _dbHelper.getSetting(keyRecoveryHash);
    String? salt = await _dbHelper.getSetting(keyRecoverySalt);

    bool isNew = false;
    String? newPlaintextCode;

    if (orgId == null || orgId.trim().isEmpty) {
      orgId = _generateUniqueOrgId();
      await _dbHelper.setSetting(keyOrgId, orgId);
    }

    if (orgName == null || orgName.trim().isEmpty) {
      orgName = 'Omega Education Centre';
      await _dbHelper.setSetting(keyOrgName, orgName);
    }

    if (hash == null || salt == null || hash.isEmpty || salt.isEmpty) {
      isNew = true;
      newPlaintextCode = _generateRandomRecoveryCode();
      salt = PasswordUtil.generateSalt();
      hash = PasswordUtil.hashPassword(newPlaintextCode, salt);

      await _dbHelper.setSetting(keyRecoverySalt, salt);
      await _dbHelper.setSetting(keyRecoveryHash, hash);
    }

    return OrgIdentityData(
      organisationId: orgId,
      organisationName: orgName,
      recoveryCodeHash: hash,
      recoveryCodeSalt: salt,
      newlyGeneratedCode: isNew ? newPlaintextCode : null,
    );
  }

  /// Verifies input Organisation ID and input Recovery Code against expected Org ID, salt, and hash.
  bool verifyCredentials({
    required String inputOrgId,
    required String inputRecoveryCode,
    required String expectedOrgId,
    required String storedHash,
    required String storedSalt,
  }) {
    final cleanInputOrg = inputOrgId.trim();
    final cleanExpectedOrg = expectedOrgId.trim();
    final cleanCode = inputRecoveryCode.trim().toUpperCase();

    if (cleanInputOrg.isEmpty || cleanCode.isEmpty || cleanExpectedOrg.isEmpty) {
      return false;
    }

    if (cleanInputOrg != cleanExpectedOrg) {
      return false;
    }

    return PasswordUtil.verifyPassword(cleanCode, storedHash, storedSalt);
  }

  /// Generates a fresh Recovery Code for the existing organisation.
  /// Computes and stores new salt and hash in DB settings, and returns plaintext code to display once.
  Future<String> regenerateRecoveryCode() async {
    final newPlaintextCode = _generateRandomRecoveryCode();
    final salt = PasswordUtil.generateSalt();
    final hash = PasswordUtil.hashPassword(newPlaintextCode, salt);

    await _dbHelper.setSetting(keyRecoverySalt, salt);
    await _dbHelper.setSetting(keyRecoveryHash, hash);

    return newPlaintextCode;
  }

  /// Stores restored organisation identity settings into local database.
  Future<void> saveRestoredOrgIdentity({
    required String orgId,
    required String orgName,
    required String recoveryCodeHash,
    required String recoveryCodeSalt,
  }) async {
    await _dbHelper.setSetting(keyOrgId, orgId);
    await _dbHelper.setSetting(keyOrgName, orgName);
    await _dbHelper.setSetting(keyRecoveryHash, recoveryCodeHash);
    await _dbHelper.setSetting(keyRecoverySalt, recoveryCodeSalt);
  }

  /// Helper to generate high-entropy random recovery code using Random.secure().
  /// Format: OEC-XXXX-XXXX-XXXX (e.g. OEC-7K9P-42MX-81QA)
  String _generateRandomRecoveryCode() {
    final random = Random.secure();
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // Excludes confusing chars (0,1,I,O)
    
    String block() => List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'OEC-${block()}-${block()}-${block()}';
  }

  /// Helper to generate a unique Organisation ID.
  /// Format: OEC-SAMASTIPUR-XXXX (e.g. OEC-SAMASTIPUR-8F2A)
  String _generateUniqueOrgId() {
    final random = Random.secure();
    const chars = '0123456789ABCDEF';
    final suffix = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'OEC-SAMASTIPUR-$suffix';
  }
}
