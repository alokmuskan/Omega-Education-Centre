import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/backup/services/backup_service.dart';
import 'shared/config/backend_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load Supabase credentials from local SQLite settings (or defaults)
  await BackendConfig.loadSettingsFromDb();

  // Initialize Supabase Flutter SDK if credentials are configured
  if (BackendConfig.isBackendConfigured) {
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl!,
      publishableKey: BackendConfig.supabaseAnonKey!, 
    );
  }

  // Run automatic daily backup asynchronously on startup
  BackupService().runAutomaticDailyBackup();

  runApp(const App());
}