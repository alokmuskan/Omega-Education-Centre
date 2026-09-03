import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard/dashboard_screen.dart';
import '../../../core/database/database_helper.dart';

/// First-run setup wizard for new installations.
///
/// Steps:
/// 1. Institute name, address, phone, email
/// 2. Select boards (CBSE, BSEB, ICSE, etc.)
/// 3. Select classes (1-12, Foundation, etc.)
/// 4. Create admin account
/// 5. (Optional) Connect Supabase for cloud sync
class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  static const String _onboardingCompleteKey = 'onboarding_complete';

  /// Returns true if onboarding has been completed.
  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Marks onboarding as complete.
  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;

  // Step 1: Institute info
  final _instituteNameController = TextEditingController();
  final _instituteAddressController = TextEditingController();
  final _institutePhoneController = TextEditingController();
  final _instituteEmailController = TextEditingController();

  // Step 2: Boards
  final List<String> _availableBoards = ['CBSE', 'BSEB', 'ICSE', 'State Board', 'IGCSE', 'IB', 'Other'];
  final Set<String> _selectedBoards = {'CBSE', 'BSEB'};

  // Step 3: Classes
  final List<String> _availableClasses = [
    'Nursery', 'LKG', 'UKG',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
    '11', '12', 'Foundation', 'Dropper',
  ];
  final Set<String> _selectedClasses = {'9', '10', '11', '12'};

  // Step 4: Admin account
  final _adminPasswordController = TextEditingController();
  final _adminConfirmPasswordController = TextEditingController();
  bool _adminPasswordVisible = false;
  bool _isCreatingAccount = false;

  // Step 5: Supabase
  final _supabaseUrlController = TextEditingController();
  final _supabaseKeyController = TextEditingController();
  bool _supabaseConnecting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _instituteNameController.dispose();
    _instituteAddressController.dispose();
    _institutePhoneController.dispose();
    _instituteEmailController.dispose();
    _adminPasswordController.dispose();
    _adminConfirmPasswordController.dispose();
    _supabaseUrlController.dispose();
    _supabaseKeyController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    // Save institute settings to database
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('app_settings', {'key': 'institute_name', 'value': _instituteNameController.text.trim()});
      await db.insert('app_settings', {'key': 'institute_address', 'value': _instituteAddressController.text.trim()});
      await db.insert('app_settings', {'key': 'institute_phone', 'value': _institutePhoneController.text.trim()});
      await db.insert('app_settings', {'key': 'institute_email', 'value': _instituteEmailController.text.trim()});
      await db.insert('app_settings', {'key': 'selected_boards', 'value': _selectedBoards.join(',')});
      await db.insert('app_settings', {'key': 'selected_classes', 'value': _selectedClasses.join(',')});

      // Save Supabase credentials if provided
      if (_supabaseUrlController.text.trim().isNotEmpty) {
        await db.insert('app_settings', {'key': 'supabase_url', 'value': _supabaseUrlController.text.trim()});
        await db.insert('app_settings', {'key': 'supabase_anon_key', 'value': _supabaseKeyController.text.trim()});
      }
    } catch (_) {}

    // Mark onboarding complete
    await OnboardingWizardScreen.markOnboardingComplete();

    // Navigate to dashboard
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen()),
      );
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
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Step ${_currentStep + 1} of $_totalSteps',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _totalSteps,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // Page view
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _currentStep = index),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                    _buildStep4(),
                    _buildStep5(),
                  ],
                ),
              ),

              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _prevStep,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _currentStep == _totalSteps - 1
                            ? _completeOnboarding
                            : (_currentStep == 3 ? null : _nextStep),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D47A1),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _currentStep == _totalSteps - 1 ? 'Get Started' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1: Institute Info ──────────────────────────────────────

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.school, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Welcome to Omega ERP',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Let\'s set up your coaching centre.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          _buildTextField(_instituteNameController, 'Institute Name', Icons.business),
          const SizedBox(height: 12),
          _buildTextField(_instituteAddressController, 'Address', Icons.location_on),
          const SizedBox(height: 12),
          _buildTextField(_institutePhoneController, 'Phone', Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _buildTextField(_instituteEmailController, 'Email (optional)', Icons.email, keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
  }

  // ── Step 2: Select Boards ──────────────────────────────────────

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.menu_book, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Select Boards',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Which boards does your institute follow?',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableBoards.map((board) {
              final isSelected = _selectedBoards.contains(board);
              return FilterChip(
                label: Text(board),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedBoards.add(board);
                    } else {
                      _selectedBoards.remove(board);
                    }
                  });
                },
                selectedColor: Colors.white,
                checkmarkColor: const Color(0xFF0D47A1),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF0D47A1) : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: Colors.white24,
                side: BorderSide(color: isSelected ? Colors.white : Colors.white38),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Select Classes ─────────────────────────────────────

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.class_, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Select Classes',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Which classes does your institute teach?',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableClasses.map((cls) {
                final isSelected = _selectedClasses.contains(cls);
                return FilterChip(
                  label: Text(cls),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedClasses.add(cls);
                      } else {
                        _selectedClasses.remove(cls);
                      }
                    });
                  },
                  selectedColor: Colors.white,
                  checkmarkColor: const Color(0xFF0D47A1),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF0D47A1) : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  backgroundColor: Colors.white24,
                  side: BorderSide(color: isSelected ? Colors.white : Colors.white38),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4: Create Admin Account ───────────────────────────────

  Widget _buildStep4() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Create Admin Account',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set a strong password for the admin account.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            _adminPasswordController,
            'Admin Password',
            Icons.lock,
            obscure: !_adminPasswordVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _adminPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.white70,
              ),
              onPressed: () => setState(() => _adminPasswordVisible = !_adminPasswordVisible),
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _adminConfirmPasswordController,
            'Confirm Password',
            Icons.lock_outline,
            obscure: true,
          ),
          const SizedBox(height: 16),
          if (_isCreatingAccount)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          const SizedBox(height: 8),
          const Text(
            'Note: Admin login uses "admin" as username. The password will be synced to Supabase if configured.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Step 5: Connect Supabase (Optional) ────────────────────────

  Widget _buildStep5() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_sync, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Cloud Sync (Optional)',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect to Supabase for multi-device sync and web access. You can skip this and configure later.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          _buildTextField(_supabaseUrlController, 'Supabase Project URL', Icons.link),
          const SizedBox(height: 12),
          _buildTextField(_supabaseKeyController, 'Supabase Anon Key', Icons.vpn_key),
          const SizedBox(height: 16),
          if (_supabaseConnecting)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          const SizedBox(height: 8),
          const Text(
            'Leave blank to run fully offline. You can configure this later in Settings.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Shared Widget ──────────────────────────────────────────────

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withAlpha(25),
      ),
    );
  }
}
