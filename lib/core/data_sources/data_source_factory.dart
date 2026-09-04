import 'package:flutter/foundation.dart';

import 'implementations/sqlite_data_source.dart';
import 'implementations/supabase_data_source.dart';
import 'interfaces/data_source.dart';

/// Factory that provides the correct [DataSource] implementation
/// based on the current platform.
///
/// **Usage:**
/// ```dart
/// final dataSource = DataSourceFactory.create();
/// final data = await dataSource.loadDashboardData();
/// ```
///
/// This eliminates the need for `kIsWeb` checks in feature code.
class DataSourceFactory {
  DataSourceFactory._();

  static DataSource? _instance;

  /// Get or create the platform-appropriate data source.
  ///
  /// Returns a singleton — the same instance for the lifetime of the app.
  static DataSource create() {
    if (_instance != null) return _instance!;

    if (kIsWeb) {
      _instance = SupabaseDataSource();
    } else {
      _instance = SqliteDataSource();
    }

    return _instance!;
  }

  /// Override the data source (useful for testing).
  static void override(DataSource source) {
    _instance = source;
  }

  /// Reset to platform default (useful in tests).
  static void reset() {
    _instance = null;
  }
}
