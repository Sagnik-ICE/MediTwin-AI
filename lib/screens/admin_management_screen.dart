import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/app_state.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalsController = TextEditingController();
  final _contactController = TextEditingController();
  final _divisionController = TextEditingController();
  final _districtController = TextEditingController();
  String _gender = '';
  String _bloodGroup = '';
  String _division = '';
  String _district = '';
  bool _saving = false;
  bool _loading = false;
  bool _requestedLoad = false;
  List<Map<String, dynamic>> _admins = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_requestedLoad) {
        _requestedLoad = true;
        _loadAdmins(context.read<AppState>());
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalsController.dispose();
    _contactController.dispose();
    _divisionController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmins(AppState appState) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      _admins = await appState.loadAdmins();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAdmin(AppState appState) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await appState.addAdmin(
      profile: UserProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 0,
        gender: _gender,
        bloodGroup: _bloodGroup,
        isBloodDonor: false,
        donorContactInfo: '',
        heightCm: double.tryParse(_heightController.text.trim()) ?? 0,
        weightKg: double.tryParse(_weightController.text.trim()) ?? 0,
        healthGoals: _goalsController.text.trim(),
        contactInfo: _contactController.text.trim(),
        division: _division,
        district: _district,
        accountType: 'admin',
      ),
      password: _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Admin added.')));
    if (error == null) {
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _ageController.clear();
      _heightController.clear();
      _weightController.clear();
      _goalsController.clear();
      _contactController.clear();
      _gender = '';
      _bloodGroup = '';
      _division = '';
      _district = '';
      await _loadAdmins(appState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add admin', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Create a Firebase Auth user, full profile, and register it as an admin.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 14),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Full name'),
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email'),
                            validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Age'),
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _gender.isEmpty ? null : _gender,
                            decoration: const InputDecoration(labelText: 'Gender'),
                            items: const ['Male', 'Female'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                            onChanged: (value) => setState(() => _gender = value ?? ''),
                            validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _bloodGroup.isEmpty ? null : _bloodGroup,
                            decoration: const InputDecoration(labelText: 'Blood group'),
                            items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                            onChanged: (value) => setState(() => _bloodGroup = value ?? ''),
                            validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _contactController,
                            decoration: const InputDecoration(labelText: 'Contact info'),
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Height (cm)'),
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Weight (kg)'),
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _goalsController,
                            decoration: const InputDecoration(labelText: 'Health goals'),
                            maxLines: 2,
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _divisionController,
                            decoration: const InputDecoration(labelText: 'Division'),
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _districtController,
                            decoration: const InputDecoration(labelText: 'District'),
                            validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Password'),
                            validator: (value) => (value == null || value.trim().length < 6) ? 'Password must be at least 6 characters' : null,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : () => _addAdmin(appState),
                              icon: _saving
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(_saving ? 'Creating...' : 'Create admin'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admins', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Current admin accounts registered in Firestore.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                    else if (_admins.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No additional admins found.'),
                      )
                    else
                      for (final admin in _admins)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.admin_panel_settings_rounded),
                          title: Text(admin['displayName']?.toString().isNotEmpty == true ? admin['displayName'].toString() : admin['email'].toString()),
                          subtitle: Text('${admin['email'] ?? ''}\nUID: ${admin['uid'] ?? admin['id'] ?? ''}'),
                          isThreeLine: true,
                          trailing: admin['email']?.toString().toLowerCase() == AppState.mainAdminEmail
                              ? const Chip(label: Text('Main admin'))
                              : IconButton(
                                  onPressed: () async {
                                    await appState.removeAdmin(admin['id'].toString());
                                    if (mounted) await _loadAdmins(appState);
                                  },
                                  icon: const Icon(Icons.delete_rounded),
                                ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}