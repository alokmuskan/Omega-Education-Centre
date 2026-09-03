import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/backup/services/backup_service.dart';
import 'shared/config/backend_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Step 1: Load .env file if it exists ──────────────────────────────
  //
  // This sets SUPABASE_URL, SUPABASE_ANON_KEY, and ORG_CODE from
  // environment variables. The .env file is gitignored and must be
  // created from .env.example before first run.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env file not found — app will run in offline-only mode.
    // This is expected on first run or in CI environments.
  }

  // ── Step 2: Load credentials from .env ───────────────────────────────
  BackendConfig.loadFromEnv();

  // ── Step 3: Override with SQLite settings if available ────────────────
  //
  // SQLite settings take priority over .env values. This allows the admin
  // to change credentials from the Settings screen without re-deploying.
  await BackendConfig.loadSettingsFromDb();

  // ── Step 4: Initialize Supabase SDK if configured ────────────────────
  if (BackendConfig.isBackendConfigured) {
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl!,
      publishableKey: BackendConfig.supabaseAnonKey!,
    );
  }

  // ── Step 5: Run automatic daily backup asynchronously on startup ──────
  BackupService().runAutomaticDailyBackup();

  runApp(const App());
}