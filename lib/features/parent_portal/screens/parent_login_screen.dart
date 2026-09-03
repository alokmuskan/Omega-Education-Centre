import 'package:flutter/material.dart';

import '../repository/parent_auth_repository.dart';
import 'parent_dashboard_screen.dart';

/// Login screen for Parents to access the Parent Portal.
///
/// Parents log in with their mobile number (linked to student record).
/// Default password is the child's roll number.
class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepo = ParentAuthRepository();
  bool _isLoading = false;
  bool _isPasswordHidden = true;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authRepo.login(
        _mobileController.text,
        _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: Colors.red),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentDashboardScreen(
            student: result.student!,
            parentName: result.parentName ?? 'Parent',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
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
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
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
                    const Icon(Icons.family_restroom, color: Colors.white, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Parent Portal',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'View your child\'s attendance, fees & results',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
                        filled: true,
                        fillColor: Colors.white.withAlpha(25),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter mobile number';
                        if (v.trim().length < 10) return 'Enter valid 10-digit mobile';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isPasswordHidden,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password (Child\'s Roll Number)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                          onPressed: () => setState(() => _isPasswordHidden = !_isPasswordHidden),
                        ),
                        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
                        filled: true,
                        fillColor: Colors.white.withAlpha(25),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter password';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1B5E20),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Color(0xFF1B5E20))
                            : const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Default password is your child\'s roll number.\nContact institute to reset.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
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
