import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/services/biometric_service.dart';
import '../../../shared/utils/login_attempt_tracker.dart';
import '../../backup/screens/recovery_screen.dart';
import '../../parent_portal/screens/parent_login_screen.dart';
import '../../dashboard/dashboard_screen.dart';
import '../../dashboard/student_dashboard_screen.dart';
import '../../dashboard/teacher_dashboard_screen.dart';
import '../repository/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final AuthRepository _authRepository = AuthRepository();
  bool isPasswordHidden = true;
  bool _isLoggingIn = false;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  bool _canUseBiometric = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricCapability();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBiometricCapability() async {
    final biometric = BiometricService.instance;
    await biometric.init();
    final canUse = await biometric.canAuthenticate();
    if (mounted) {
      setState(() {
        _canUseBiometric = canUse;
        _biometricEnabled = biometric.isEnabled;
      });
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final tracker = LoginAttemptTracker.instance;
      final seconds = tracker.getSecondsUntilUnlock(usernameController.text);
      if (seconds <= 0) {
        timer.cancel();
        setState(() => _lockoutSeconds = 0);
      } else {
        setState(() => _lockoutSeconds = seconds);
      }
    });
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoggingIn = true);

    try {
      final result = await _authRepository.login(
        usernameController.text,
        passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoggingIn = false);

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        // Start lockout timer if account is locked
        final tracker = LoginAttemptTracker.instance;
        if (tracker.getMinutesUntilUnlock(usernameController.text) > 0) {
          _startLockoutTimer();
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Offer biometric enrollment after successful password login
      _offerBiometricEnrollment(usernameController.text);

      Widget destinationScreen;
      if (result.role == AppConstants.roleTeacher) {
        destinationScreen = const TeacherDashboardScreen();
      } else if (result.role == AppConstants.roleStudent) {
        destinationScreen = const StudentDashboardScreen();
      } else {
        destinationScreen = DashboardScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destinationScreen),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );    }
  }

  // ── Biometric Login ──────────────────────────────────────────────

  Future<void> _biometricLogin() async {
    final biometric = BiometricService.instance;
    final username = biometric.enrolledUsername;

    if (username == null || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No biometric account enrolled. Please login with password first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      final didAuth = await biometric.authenticate(
        reason: 'Login to Omega Education Centre',
      );

      if (!mounted) return;

      if (!didAuth) {
        setState(() => _isLoggingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed. Please login with password.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Biometric succeeded — authenticate via stored session or password
      // For security, we still need to verify credentials via the auth repository.
      // The biometric just confirms it's the right person on this device.
      final result = await _authRepository.restorePersistedSession();

      if (!mounted) return;
      setState(() => _isLoggingIn = false);

      if (result != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => result),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login with password.'),
            backgroundColor: Colors.orange,
          ),
        );
        // Clear biometric enrollment if session is expired
        await biometric.disableBiometric();
        setState(() => _biometricEnabled = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _offerBiometricEnrollment(String username) async {
    final biometric = BiometricService.instance;
    if (biometric.isEnabled) return; // Already enrolled

    final canUse = await biometric.canAuthenticate();
    if (!canUse || !mounted) return;

    // Show enrollment prompt after a brief delay
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final typeLabel = await biometric.getBiometricTypeLabel();
    if (!mounted) return;

    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.fingerprint, size: 48, color: Color(0xFF0D47A1)),
        title: const Text('Enable Biometric Login?'),
        content: Text(
          'Your device supports $typeLabel. '
          'Enable it for faster login next time?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (shouldEnable == true && mounted) {
      await biometric.enableBiometric(username);
      setState(() => _biometricEnabled = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login enabled!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF9C4),
              Color(0xFFFFFDE7),
              Color(0xFFE3F2FD),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logo/logo.png',
                      height: 130,
                    ),

                    const SizedBox(height: 25),

                    const Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "Omega Education Centre ERP",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Lockout warning banner
                    if (_lockoutSeconds > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_clock, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Account locked. Try again in ${_lockoutSeconds ~/ 60}:${(_lockoutSeconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    TextFormField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: "Username / Mobile / Account ID",
                        hintText: "admin, teacher, or student",
                        prefixIcon: const Icon(Icons.person),
                        filled: true,
                        fillColor: Colors.white.withAlpha(230),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blueGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Please enter username or mobile";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: passwordController,
                      obscureText: isPasswordHidden,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordHidden = !isPasswordHidden;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white.withAlpha(230),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blueGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Please enter password";
                        }
                        if (value.length < 8) {
                          return "Password must be at least 8 characters";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoggingIn ? null : login,
                        child: _isLoggingIn
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "LOGIN",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    // ── Biometric Login Button ──────────────────────────────
                    if (_canUseBiometric && _biometricEnabled) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D47A1),
                            side: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoggingIn ? null : _biometricLogin,
                          icon: const Icon(Icons.fingerprint, size: 24),
                          label: const Text(
                            "Login with Biometrics",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],

                     const SizedBox(height: 20),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RecoveryScreen()),
                        );
                      },
                      child: const Text(
                        "Already have an Omega ERP backup?\nRecover Existing ERP",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF0D47A1),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ParentLoginScreen()),
                        );
                      },
                      child: const Text(
                        "Parent? Login to View Your Child's Progress",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "Omega Education Centre ERP v1.0",
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}