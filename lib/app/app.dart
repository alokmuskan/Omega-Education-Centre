import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/authentication/login/login_screen.dart';
import '../features/authentication/repository/auth_repository.dart';
import '../features/onboarding/screens/onboarding_wizard_screen.dart';
import '../shared/config/backend_config.dart';
import '../shared/services/sync_engine.dart';
import '../l10n/app_translations.dart';
import '../shared/services/localization_service.dart';
import '../shared/services/theme_service.dart';
import '../shared/themes/app_theme.dart';
import '../shared/utils/app_session.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: LocalizationService.instance,
          builder: (context, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'Omega Education Centre',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeService.instance.themeMode,
              locale: LocalizationService.instance.locale,
              supportedLocales: const [Locale('en'), Locale('hi')],
              localizationsDelegates: const [
                AppTranslationsDelegate(),
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
              ],
              home: const AppStartupWrapper(),
            );
          },
        );
      },
    );
  }
}

/// Global navigator key for showing dialogs from non-widget contexts.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppStartupWrapper extends StatefulWidget {
  const AppStartupWrapper({super.key});

  @override
  State<AppStartupWrapper> createState() => _AppStartupWrapperState();
}

class _AppStartupWrapperState extends State<AppStartupWrapper> with WidgetsBindingObserver {
  late Future<Widget> _initialScreenFuture;
  Timer? _timeoutWarningTimer;
  bool _warningDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialScreenFuture = _restoreSession();
    _startTimeoutWarningTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutWarningTimer?.cancel();
    super.dispose();
  }

  /// Starts a periodic timer that checks for session timeout warning.
  void _startTimeoutWarningTimer() {
    _timeoutWarningTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkTimeoutWarning();
    });
  }

  /// Checks if a timeout warning should be shown or if session has expired.
  Future<void> _checkTimeoutWarning() async {
    final session = AppSession.instance;
    if (session.currentUsername.isEmpty) return; // Not logged in

    if (await session.isSessionTimedOut()) {
      // Session expired — logout immediately.
      _performAutoLogout('Session expired due to inactivity.');
    } else if (await session.shouldShowTimeoutWarning() && !_warningDialogShown) {
      // approaching timeout — show warning dialog.
      _warningDialogShown = true;
      _showTimeoutWarningDialog();
    }
  }

  void _performAutoLogout(String message) {
    _warningDialogShown = false;
    AppSession.instance.clearSession();
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.orange),
      );
      Navigator.of(ctx).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showTimeoutWarningDialog() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        // Auto-dismiss and logout after 60 seconds if user doesn't interact.
        Timer(const Duration(seconds: 60), () {
          if (dialogCtx.mounted) {
            Navigator.of(dialogCtx).pop();
            _performAutoLogout('Session expired due to inactivity.');
          }
        });

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.timer, color: Colors.orange),
              SizedBox(width: 8),
              Text('Session Expiring'),
            ],
          ),
          content: const Text(
            'Your session will expire in less than 2 minutes due to inactivity.\n\nTap anywhere to stay logged in.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                AppSession.instance.touchActivity();
                _warningDialogShown = false;
              },
              child: const Text('STAY LOGGED IN'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _performAutoLogout('Logged out.');
              },
              child: const Text('LOGOUT NOW'),
            ),
          ],
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Record activity on resume.
      AppSession.instance.touchActivity();
      _warningDialogShown = false;
      // Check for timeout.
      _checkTimeoutWarning();
      // Trigger sync.
      SyncEngine.instance.syncAll();
    }
  }

  Future<Widget> _restoreSession() async {
    try {
      // Check if onboarding is complete (first-run wizard)
      final onboardingComplete = await OnboardingWizardScreen.isOnboardingComplete();
      if (!onboardingComplete) {
        return const OnboardingWizardScreen();
      }

      // Skip SQLite settings on web — SQLite is not available in browsers
      if (!kIsWeb) {
        try {
          await BackendConfig.loadSettingsFromDb();
        } catch (_) {}
      }

      final authRepository = AuthRepository();
      final targetScreen = await authRepository.restorePersistedSession();

      // Trigger non-blocking background sync on app launch (skip on web)
      if (!kIsWeb) {
        try {
          SyncEngine.instance.syncAll();
        } catch (_) {}
      }

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
    return GestureDetector(
      onTap: () {
        // Record user activity on any tap.
        AppSession.instance.touchActivity();
        _warningDialogShown = false;
      },
      child: FutureBuilder<Widget>(
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
      ),
    );
  }
}