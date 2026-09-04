import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/backup/services/backup_service.dart';
import 'shared/config/backend_config.dart';
import 'shared/services/push_notification_service.dart';
import 'shared/services/biometric_service.dart';
import 'shared/services/license_service.dart';
import 'shared/services/localization_service.dart';
import 'shared/services/theme_service.dart';
import 'shared/services/crash_reporting_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Step 0: Initialize Crash Reporting (FIRST — catches all errors) ─
  await CrashReportingService.instance.init();

  // ── Step 1: Initialize Firebase (with graceful fallback) ────────────
  //
  // Firebase is required for FCM push notifications.
  // If firebase_options.dart is not configured (no Firebase project),
  // the app still works — push notifications are simply disabled.
  try {
    await Firebase.initializeApp();
    if (kDebugMode) {
      print('[MAIN] Firebase initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('[MAIN] Firebase initialization failed (push notifications disabled): $e');
    }
    // App continues without push notifications.
  }

  // ── Step 2: Register FCM background message handler ─────────────────
  //
  // This MUST be called before runApp() and outside of any widget context.
  // It enables the app to receive notifications when in background/terminated.
  try {
    registerFirebaseBackgroundHandler();
    if (kDebugMode) {
      print('[MAIN] FCM background handler registered');
    }
  } catch (e) {
    if (kDebugMode) {
      print('[MAIN] FCM background handler registration failed: $e');
    }
  }

  // ── Step 3: Load .env file if it exists ──────────────────────────────
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

  // ── Step 4: Load credentials from .env ───────────────────────────────
  BackendConfig.loadFromEnv();

  // ── Step 5: Override with SQLite settings if available ────────────────
  //
  // SQLite settings take priority over .env values. This allows the admin
  // to change credentials from the Settings screen without re-deploying.
  await BackendConfig.loadSettingsFromDb();

  // ── Step 6: Initialize Supabase SDK if configured ────────────────────
  if (BackendConfig.isBackendConfigured) {
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl!,
      publishableKey: BackendConfig.supabaseAnonKey!,
    );
  }

  // ── Step 7: Initialize Theme Service ─────────────────────────────────
  await ThemeService.instance.init();

  // ── Step 7b: Initialize Localization Service ─────────────────────────
  await LocalizationService.instance.init();

  // ── Step 7b: Initialize Biometric Service ────────────────────────────
  await BiometricService.instance.init();

  // ── Step 7c: Initialize License Service ──────────────────────────────
  await LicenseService.instance.init();

  // ── Step 8: Initialize Push Notifications ────────────────────────────
  //
  // After Firebase and Supabase are initialized, set up FCM.
  // This is non-blocking — if it fails, in-app notifications still work.
  try {
    await PushNotificationService.instance.initialize();
    if (kDebugMode) {
      print('[MAIN] Push notification service initialized');
    }
  } catch (e) {
    if (kDebugMode) {
      print('[MAIN] Push notification initialization failed: $e');
    }
  }

  // ── Step 9: Run automatic daily backup asynchronously on startup ──────
  BackupService().runAutomaticDailyBackup();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}