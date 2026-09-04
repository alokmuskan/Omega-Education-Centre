import 'package:flutter/material.dart';

import '../models/license_model.dart';
import '../services/license_service.dart';

/// License management screen for viewing and activating licenses.
class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final LicenseService _licenseService = LicenseService.instance;
  final _keyController = TextEditingController();
  bool _isActivating = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final license = _licenseService.currentLicense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('License & Subscription'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current License Card
            _buildLicenseCard(license),
            const SizedBox(height: 16),

            // Expiry Warning
            if (_licenseService.expiryWarning != null)
              _buildWarningBanner(_licenseService.expiryWarning!),

            // Features Status
            _buildFeaturesSection(),
            const SizedBox(height: 16),

            // Activation Section
            _buildActivationSection(),
            const SizedBox(height: 16),

            // Quick Actions
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseCard(LicenseModel? license) {
    final tier = license?.tier ?? 'free';
    final tierColor = _tierColor(tier);
    final tierIcon = _tierIcon(tier);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [tierColor.withAlpha(30), tierColor.withAlpha(10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(tierIcon, size: 32, color: tierColor),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _licenseService.tierName,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tierColor),
                    ),
                    if (license?.instituteName != null)
                      Text(license!.instituteName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: license?.isValid == true ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    license?.isValid == true ? 'Active' : 'Expired',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: license?.isValid == true ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (license != null) ...[
              _licenseInfoRow('License Key', license.key.length > 20 ? '${license.key.substring(0, 20)}...' : license.key),
              _licenseInfoRow('Issued', '${license.issuedAt.day}/${license.issuedAt.month}/${license.issuedAt.year}'),
              _licenseInfoRow('Expires', '${license.expiresAt.day}/${license.expiresAt.month}/${license.expiresAt.year}'),
              _licenseInfoRow('Days Remaining', '${license.daysRemaining} days'),
              _licenseInfoRow('Max Users', '${license.maxUsers}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _licenseInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13, color: Colors.orange.shade800)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final enabled = _licenseService.enabledFeatures;
    final disabled = _licenseService.disabledFeatures;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Features', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (enabled.isNotEmpty) ...[
              Text('Enabled (${enabled.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: enabled.map((f) => Chip(
                  label: Text(f.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.green.withAlpha(25),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
            if (disabled.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Disabled (${disabled.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: disabled.map((f) => Chip(
                  label: Text(f.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.red.withAlpha(15),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Activate License', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Enter your license key to activate premium features.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'License Key',
                hintText: 'e.g. STD-XXXX-XXXX-XXXX',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isActivating ? null : _activateLicense,
                child: _isActivating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Activate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time, color: Colors.blue),
              title: const Text('Start 14-Day Trial'),
              subtitle: const Text('Full access for 14 days, no credit card required'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _startTrial,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore, color: Colors.orange),
              title: const Text('Reset to Free'),
              subtitle: const Text('Switch back to free tier'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _resetToFree,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activateLicense() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a license key'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isActivating = true);
    try {
      final success = await _licenseService.activateLicense(key);
      if (mounted) {
        setState(() => _isActivating = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('License activated successfully!'), backgroundColor: Colors.green),
          );
          _keyController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid license key. Check the format and try again.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActivating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activation failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startTrial() async {
    await _licenseService.startTrial();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('14-day trial started! Full access enabled.'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _resetToFree() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset to Free?'),
        content: const Text('This will disable premium features. You can re-activate anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _licenseService.resetToFree();
      if (mounted) setState(() {});
    }
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'premium': return Colors.purple;
      case 'standard': return Colors.blue;
      case 'trial': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _tierIcon(String tier) {
    switch (tier) {
      case 'premium': return Icons.diamond;
      case 'standard': return Icons.star;
      case 'trial': return Icons.access_time;
      default: return Icons.free_cancellation;
    }
  }
}
