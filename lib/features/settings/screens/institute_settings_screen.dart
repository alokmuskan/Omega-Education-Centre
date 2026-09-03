import 'package:flutter/material.dart';
import '../../authentication/repository/auth_repository.dart';
import '../../../shared/utils/app_session.dart';
import '../models/institute_profile_model.dart';
import '../models/master_data_model.dart';
import '../services/institute_config_service.dart';

/// Admin-only screen for managing Institute Profile, Academic Year, Master Data, and User Accounts.
class InstituteSettingsScreen extends StatefulWidget {
  const InstituteSettingsScreen({super.key});

  @override
  State<InstituteSettingsScreen> createState() => _InstituteSettingsScreenState();
}

class _InstituteSettingsScreenState extends State<InstituteSettingsScreen> with SingleTickerProviderStateMixin {
  final InstituteConfigService _configService = InstituteConfigService();
  final AuthRepository _authRepo = AuthRepository();

  late TabController _tabController;

  final _profileFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _principalController = TextEditingController();
  final _academicYearController = TextEditingController();
  final _logoPathController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  MasterCategory _selectedCategory = MasterCategory.studentClass;
  List<MasterDataItemModel> _masterItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _principalController.dispose();
    _academicYearController.dispose();
    _logoPathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _configService.getInstituteProfile();
      _nameController.text = profile.name;
      _addressController.text = profile.address;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
      _principalController.text = profile.principalName;
      _academicYearController.text = profile.academicYear;
      _logoPathController.text = profile.logoPath;

      await _loadMasterItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMasterItems() async {
    final items = await _configService.getMasterItems(_selectedCategory);
    if (mounted) {
      setState(() {
        _masterItems = items;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final updatedProfile = InstituteProfileModel(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        principalName: _principalController.text.trim(),
        academicYear: _academicYearController.text.trim(),
        logoPath: _logoPathController.text.trim(),
      );

      await _configService.saveInstituteProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Institute Profile saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveAcademicYear() async {
    final yr = _academicYearController.text.trim();
    if (yr.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _configService.saveAcademicYear(yr);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Academic Year updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update Academic Year: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showAddMasterItemDialog() async {
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add New ${_selectedCategory.displayName.singular()}'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '${_selectedCategory.displayName.singular()} Name',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _configService.addMasterItem(_selectedCategory, result);
      await _loadMasterItems();
    }
  }

  Future<void> _showEditMasterItemDialog(MasterDataItemModel item) async {
    final textController = TextEditingController(text: item.name);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${_selectedCategory.displayName.singular()} Name'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != item.name) {
      final updated = item.copyWith(name: result);
      await _configService.updateMasterItem(_selectedCategory, updated);
      await _loadMasterItems();
    }
  }

  Future<void> _toggleItemActive(MasterDataItemModel item, bool isActive) async {
    await _configService.toggleMasterItemActive(_selectedCategory, item.id, isActive);
    await _loadMasterItems();
  }

  @override
  Widget build(BuildContext context) {
    // Role protection: Admin only
    if (!AppSession.instance.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gpp_bad, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only logged-in administrators/directors are authorized to access Institute Configuration and Master Data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Institute Settings'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Profile'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Academic Year'),
            Tab(icon: Icon(Icons.category), text: 'Master Data'),
            Tab(icon: Icon(Icons.manage_accounts), text: 'Users'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildAcademicYearTab(),
                _buildMasterDataTab(),
                _buildUserAccountsTab(),
              ],
            ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('institute_settings_profile_scroll_key'),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'INSTITUTE PROFILE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 4),
            const Text(
              'General Institute Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Institute Name',
                prefixIcon: Icon(Icons.school),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Institute Name is required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _principalController,
              decoration: const InputDecoration(
                labelText: 'Director / Principal Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _logoPathController,
              decoration: const InputDecoration(
                labelText: 'Report / Certificate Logo File Path',
                prefixIcon: Icon(Icons.image),
                border: OutlineInputBorder(),
                hintText: 'e.g. assets/images/logo.png',
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : _saveProfile,
                icon: const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Profile Settings', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicYearTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACADEMIC SESSION',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
          const SizedBox(height: 4),
          const Text(
            'Active Academic Year',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'The active Academic Year is used across student examinations, report cards, and fee schedules.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _academicYearController,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      hintText: 'e.g. 2026-27',
                      prefixIcon: Icon(Icons.calendar_month),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildYearQuickChip('2025-26'),
                      const SizedBox(width: 8),
                      _buildYearQuickChip('2026-27'),
                      const SizedBox(width: 8),
                      _buildYearQuickChip('2027-28'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving ? null : _saveAcademicYear,
              icon: const Icon(Icons.check_circle),
              label: const Text('Update Academic Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearQuickChip(String year) {
    final isSelected = _academicYearController.text == year;
    return ChoiceChip(
      label: Text(year),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _academicYearController.text = year;
          });
        }
      },
    );
  }

  Widget _buildMasterDataTab() {
    return Column(
      children: [
        // Category Selector Chips
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: MasterCategory.values.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat.displayName),
                  selected: isSelected,
                  selectedColor: Colors.indigo.shade100,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.indigo.shade900 : Colors.black87,
                  ),
                  onSelected: (selected) {
                    if (selected && _selectedCategory != cat) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                      _loadMasterItems();
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const Divider(height: 1),

        // Action Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedCategory.displayName} (${_masterItems.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: _showAddMasterItemDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add ${_selectedCategory.displayName.singular()}'),
              ),
            ],
          ),
        ),

        // Master Items List
        Expanded(
          child: _masterItems.isEmpty
              ? Center(child: Text('No ${_selectedCategory.displayName} items found.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _masterItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (ctx, index) {
                    final item = _masterItems[index];
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: item.isActive ? null : TextDecoration.lineThrough,
                            color: item.isActive ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        subtitle: Text(
                          item.isActive ? 'Active' : 'Deactivated (Preserved for historical records)',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isActive ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.indigo),
                              onPressed: () => _showEditMasterItemDialog(item),
                            ),
                            Switch(
                              value: item.isActive,
                              activeThumbColor: Colors.green,
                              onChanged: (val) => _toggleItemActive(item, val),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserAccountsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _authRepo.getAllUserAccounts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!;
        if (users.isEmpty) {
          return const Center(child: Text('No user accounts registered.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            final u = users[index];
            final username = u['username'] as String;
            final role = u['role'] as String;
            final isActive = (u['isActive'] as int?) == 1;

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: role == 'Admin'
                      ? Colors.indigo.shade100
                      : role == 'Teacher'
                          ? Colors.teal.shade100
                          : Colors.amber.shade100,
                  child: Icon(
                    role == 'Admin'
                        ? Icons.admin_panel_settings
                        : role == 'Teacher'
                            ? Icons.school
                            : Icons.person,
                    color: role == 'Admin'
                        ? Colors.indigo.shade900
                        : role == 'Teacher'
                            ? Colors.teal.shade900
                            : Colors.amber.shade900,
                  ),
                ),
                title: Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Role: $role • ${isActive ? 'Enabled' : 'Disabled'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.key, color: Colors.indigo),
                      tooltip: 'Reset Password',
                      onPressed: () => _showAdminResetPasswordDialog(username),
                    ),
                    if (role != 'Admin')
                      Switch(
                        value: isActive,
                        activeThumbColor: Colors.green,
                        onChanged: (val) async {
                          await _authRepo.toggleUserAccountStatus(
                            targetUsername: username,
                            isEnabled: val,
                          );
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAdminResetPasswordDialog(String targetUsername) async {
    final newPassCtrl = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password: $targetUsername'),
        content: TextField(
          controller: newPassCtrl,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Password *',
            hintText: 'Minimum 4 characters',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, newPassCtrl.text.trim()),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _authRepo.adminResetPassword(
          targetUsername: targetUsername,
          newPassword: result,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password for "$targetUsername" reset successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reset password: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

extension StringSingular on String {
  String singular() {
    if (endsWith('es')) return substring(0, length - 2);
    if (endsWith('s')) return substring(0, length - 1);
    return this;
  }
}
