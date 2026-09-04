import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/database/database_helper.dart';

/// Configuration wrapper for optional central Supabase backend integration.
///
/// Keeps local SQLite (`omega_education.db`) functionality 100% offline-first
/// and non-breaking while preparing the application for multi-device sync.
///
/// Credential loading priority:
///   1. Runtime overrides via `initialize()` (e.g., from Settings screen)
///   2. `.env` file values loaded by `flutter_dotenv`
///   3. SQLite `app_settings` table via `loadSettingsFromDb()`
///
/// IMPORTANT:
///   - No credentials are hardcoded in source code.
///   - The app runs fully offline if no credentials are configured.
///   - `.env` must be created from `.env.example` before first run.
class BackendConfig {
  BackendConfig._();

  static const String defaultOrgCode = 'ORG_OMEGA_DEFAULT';

  /// Central Supabase Project URL
  static String? supabaseUrl;

  /// Central Supabase Public Anon Key
  static String? supabaseAnonKey;

  /// Organisation code for multi-tenant scenarios
  static String orgCode = defaultOrgCode;

  /// Returns true if central backend integration credentials are provided.
  static bool get isBackendConfigured =>
      supabaseUrl != null &&
      supabaseUrl!.trim().isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey!.trim().isNotEmpty;

  /// Safely configures backend credentials without throwing errors if omitted.
  static void initialize({String? url, String? anonKey, String? code}) {
    if (url != null) supabaseUrl = url;
    if (anonKey != null) supabaseAnonKey = anonKey;
    if (code != null) orgCode = code;
  }

  /// Loads credentials from `.env` file (flutter_dotenv).
  ///
  /// This should be called early in `main()` after `dotenv.load()`.
  static void loadFromEnv() {
    final url = dotenv.env['SUPABASE_URL'];
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    final code = dotenv.env['ORG_CODE'];

    if (url != null && url.trim().isNotEmpty) {
      supabaseUrl = url.trim();
    }
    if (key != null && key.trim().isNotEmpty) {
      supabaseAnonKey = key.trim();
    }
    if (code != null && code.trim().isNotEmpty) {
      orgCode = code.trim();
    }
  }

  /// Loads backend settings from local SQLite `app_settings` table.
  ///
  /// This provides a secondary fallback for runtime-configured credentials
  /// (e.g., changed from the Settings screen after first launch).
  static Future<void> loadSettingsFromDb() async {
    try {
      final db = DatabaseHelper.instance;
      final storedUrl = await db.getSetting('supabase_url');
      final storedKey = await db.getSetting('supabase_anon_key');
      final storedOrgCode = await db.getSetting('org_code');

      if (storedUrl != null && storedUrl.trim().isNotEmpty) {
        supabaseUrl = storedUrl.trim();
      }
      if (storedKey != null && storedKey.trim().isNotEmpty) {
        supabaseAnonKey = storedKey.trim();
      }
      if (storedOrgCode != null && storedOrgCode.trim().isNotEmpty) {
        orgCode = storedOrgCode.trim();
      }
    } catch (_) {
      // SQLite not available — rely on env vars or runtime overrides.
    }
  }
}
