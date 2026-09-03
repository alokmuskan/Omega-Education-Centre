import 'package:flutter/material.dart';
import '../features/authentication/login/login_screen.dart';
import '../features/authentication/repository/auth_repository.dart';
import '../shared/config/backend_config.dart';
import '../shared/services/sync_engine.dart';
import '../shared/themes/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Omega Education Centre',
      theme: AppTheme.lightTheme,
      home: const AppStartupWrapper(),
    );
  }
}

class AppStartupWrapper extends StatefulWidget {
  const AppStartupWrapper({super.key});

  @override
  State<AppStartupWrapper> createState() => _AppStartupWrapperState();
}

class _AppStartupWrapperState extends State<AppStartupWrapper> with WidgetsBindingObserver {
  late Future<Widget> _initialScreenFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialScreenFuture = _restoreSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SyncEngine.instance.syncAll();
    }
  }

  Future<Widget> _restoreSession() async {
    try {
      await BackendConfig.loadSettingsFromDb();
      final authRepository = AuthRepository();
      final targetScreen = await authRepository.restorePersistedSession();
      // Trigger non-blocking background sync on app launch
      SyncEngine.instance.syncAll();

      if (targetScreen != null) {
        return targetScreen;
      }
    } catch (_) {
      // Fallback cleanly to login on error
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return snapshot.data!;
        }
        return Scaffold(
          backgroundColor: const Color(0xFF0D47A1),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Omega Education Centre',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}