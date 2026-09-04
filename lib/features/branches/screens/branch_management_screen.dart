import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state_widget.dart';
import '../models/branch_model.dart';
import '../repository/branch_repository.dart';

/// Branch Management screen for creating and managing institute branches.
class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final BranchRepository _repo = BranchRepository();
  List<BranchModel> _branches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoading = true);
    try {
      _branches = await _repo.getBranches();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Management'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _branches.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.location_city_outlined,
                  title: 'No branches created',
                  subtitle: 'Add branches to manage multiple locations',
                )
              : RefreshIndicator(
                  onRefresh: _loadBranches,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _branches.length,
                    itemBuilder: (context, index) => _buildBranchCard(_branches[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBranchForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBranchCard(BranchModel branch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showBranchDetail(branch),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      branch.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton(
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (v) => _handleBranchAction(v, branch),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (branch.address != null && branch.address!.isNotEmpty)
                _infoRow(Icons.location_on, branch.address!),
              if (branch.phone != null && branch.phone!.isNotEmpty)
                _infoRow(Icons.phone, branch.phone!),
              if (branch.email != null && branch.email!.isNotEmpty)
                _infoRow(Icons.email, branch.email!),
              if (branch.managerName != null && branch.managerName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Manager: ${branch.managerName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    if (branch.managerPhone != null && branch.managerPhone!.isNotEmpty)
                      Text(' (${branch.managerPhone})', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        ],
      ),
    );
  }

  void _showBranchForm({BranchModel? branch}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BranchFormSheet(
        branch: branch,
        onSave: (b) async {
          Navigator.pop(context);
          if (branch == null) {
            await _repo.insertBranch(b);
          } else {
            await _repo.updateBranch(b);
          }
          _loadBranches();
        },
      ),
    );
  }

  void _showBranchDetail(BranchModel branch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(branch.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (branch.address != null && branch.address!.isNotEmpty)
              _detailTile(Icons.location_on, 'Address', branch.address!),
            if (branch.phone != null && branch.phone!.isNotEmpty)
              _detailTile(Icons.phone, 'Phone', branch.phone!),
            if (branch.email != null && branch.email!.isNotEmpty)
              _detailTile(Icons.email, 'Email', branch.email!),
            if (branch.managerName != null && branch.managerName!.isNotEmpty)
              _detailTile(Icons.person, 'Manager', branch.managerName!),
            if (branch.managerPhone != null && branch.managerPhone!.isNotEmpty)
              _detailTile(Icons.phone_android, 'Manager Phone', branch.managerPhone!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showBranchForm(branch: branch);
                },
                child: const Text('Edit Branch'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleBranchAction(String action, BranchModel branch) async {
    if (action == 'edit') {
      _showBranchForm(branch: branch);
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Branch?'),
          content: Text('Delete "${branch.name}"? Students and teachers will not be affected.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _repo.deleteBranch(branch.id!);
        _loadBranches();
      }
    }
  }
}

// ── Branch Form Sheet ─────────────────────────────────────────────

class _BranchFormSheet extends StatefulWidget {
  final BranchModel? branch;
  final Function(BranchModel) onSave;
  const _BranchFormSheet({this.branch, required this.onSave});

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.branch != null) {
      _nameController.text = widget.branch!.name;
      _addressController.text = widget.branch!.address ?? '';
      _phoneController.text = widget.branch!.phone ?? '';
      _emailController.text = widget.branch!.email ?? '';
      _managerNameController.text = widget.branch!.managerName ?? '';
      _managerPhoneController.text = widget.branch!.managerPhone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerNameController.dispose();
    _managerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.branch == null ? 'Add Branch' : 'Edit Branch',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Branch Name *', hintText: 'e.g. Downtown Branch', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text('Manager Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _managerNameController,
                      decoration: const InputDecoration(labelText: 'Manager Name', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _managerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Manager Phone', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    widget.onSave(BranchModel(
                      id: widget.branch?.id,
                      name: _nameController.text.trim(),
                      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
                      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
                      managerName: _managerNameController.text.trim().isEmpty ? null : _managerNameController.text.trim(),
                      managerPhone: _managerPhoneController.text.trim().isEmpty ? null : _managerPhoneController.text.trim(),
                      createdAt: widget.branch?.createdAt ?? DateTime.now().toIso8601String(),
                    ));
                  },
                  child: Text(widget.branch == null ? 'Add Branch' : 'Save Changes'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
