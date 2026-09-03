import 'package:flutter_test/flutter_test.dart';
import 'package:omega_education_centre/shared/config/backend_config.dart';
import 'package:omega_education_centre/shared/services/supabase_health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 27 — Supabase Secure Backend Connection Tests', () {
    test('1. Unconfigured BackendConfig returns offline fallback gracefully', () async {
      BackendConfig.initialize(url: '', anonKey: '');
      expect(BackendConfig.isBackendConfigured, isFalse);

      final isConnected = await SupabaseHealthService.instance.checkConnectivity();
      expect(isConnected, isFalse);
    });

    test('2. BackendConfig stores public non-secret client credentials safely', () {
      BackendConfig.initialize(
        url: 'https://test-project.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test',
      );

      expect(BackendConfig.isBackendConfigured, isTrue);
      expect(BackendConfig.supabaseUrl, equals('https://test-project.supabase.co'));
      expect(
        BackendConfig.supabaseAnonKey,
        equals('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test'),
      );

      // Reset to unconfigured state
      BackendConfig.initialize(url: '', anonKey: '');
    });

    test('3. SupabaseHealthService fails gracefully without throwing exceptions when unreachable or invalid scheme', () async {
      BackendConfig.initialize(
        url: 'unsupported-scheme://offline-test-host',
        anonKey: 'invalid-key',
      );

      final isConnectedInvalidScheme = await SupabaseHealthService.instance.checkConnectivity(
        timeout: const Duration(milliseconds: 100),
      );

      expect(isConnectedInvalidScheme, isFalse);

      // Clean up
      BackendConfig.initialize(url: '', anonKey: '');
    });
  });
}
