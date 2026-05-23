import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bd_locations.dart';
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
    super.dispose();
  }

  Future<void> _loadAdmins(AppState appState) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final admins = await appState.loadAdmins();
      if (!mounted) return;
      setState(() => _admins = admins);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _parseAge() => int.parse(_ageController.text.trim());

  double _parseHeight() => double.parse(_heightController.text.trim());

  double _parseWeight() => double.parse(_weightController.text.trim());

  String? _requiredText(String? value, {String label = 'Required'}) {
    if (value == null || value.trim().isEmpty) return label;
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) return 'Enter a valid email';
    return null;
  }

  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Age is required';
    final age = int.tryParse(text);
    if (age == null) return 'Enter a valid age';
    if (age < 0 || age > 120) return 'Age must be between 0 and 120';
    return null;
  }

  String? _validateHeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Height is required';
    final height = double.tryParse(text);
    if (height == null) return 'Enter a valid height';
    if (height <= 0 || height > 300) return 'Height must be between 1 and 300 cm';
    return null;
  }

  String? _validateWeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Weight is required';
    final weight = double.tryParse(text);
    if (weight == null) return 'Enter a valid weight';
    if (weight <= 0 || weight > 500) return 'Weight must be between 1 and 500 kg';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value?.trim() ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _ageController.clear();
    _heightController.clear();
    _weightController.clear();
    _goalsController.clear();
    _contactController.clear();

    setState(() {
      _gender = '';
      _bloodGroup = '';
      _division = '';
      _district = '';
    });
  }

  Future<void> _addAdmin(AppState appState) async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _saving = true);

    final profile = UserProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      age: _parseAge(),
      gender: _gender,
      bloodGroup: _bloodGroup,
      isBloodDonor: false,
      donorContactInfo: '',
      heightCm: _parseHeight(),
      weightKg: _parseWeight(),
      healthGoals: _goalsController.text.trim(),
      contactInfo: _contactController.text.trim(),
      division: _division,
      district: _district,
      accountType: 'admin',
    );

    final error = await appState.addAdmin(
      profile: profile,
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Admin added.')),
    );

    if (error == null) {
      _clearForm();
      await _loadAdmins(appState);
    }
  }

  Future<void> _removeAdmin(AppState appState, Map<String, dynamic> admin) async {
    final adminId = admin['id']?.toString() ?? '';
    final email = admin['email']?.toString() ?? '';

    if (adminId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove admin?'),
        content: Text(
          email.isEmpty
              ? 'This admin will be removed from the admin list.'
              : '$email will be removed from the admin list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await appState.removeAdmin(adminId);
    if (mounted) await _loadAdmins(appState);
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
                    Text(
                      'Add admin',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create a Firebase Auth user, full profile, and register it as an admin.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Full name'),
                            textInputAction: TextInputAction.next,
                            validator: (value) => _requiredText(value),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email'),
                            textInputAction: TextInputAction.next,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Age'),
                            textInputAction: TextInputAction.next,
                            validator: _validateAge,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _gender.isEmpty ? null : _gender,
                            decoration: const InputDecoration(labelText: 'Gender'),
                            items: const ['Male', 'Female']
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() => _gender = value ?? ''),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _bloodGroup.isEmpty ? null : _bloodGroup,
                            decoration: const InputDecoration(labelText: 'Blood group'),
                            items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() => _bloodGroup = value ?? ''),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _contactController,
                            decoration: const InputDecoration(labelText: 'Contact info'),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            validator: (value) => _requiredText(value),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Height (cm)'),
                            textInputAction: TextInputAction.next,
                            validator: _validateHeight,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Weight (kg)'),
                            textInputAction: TextInputAction.next,
                            validator: _validateWeight,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _goalsController,
                            decoration: const InputDecoration(labelText: 'Health goals'),
                            maxLines: 2,
                            validator: (value) => _requiredText(value),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _division.isEmpty ? null : _division,
                            decoration: const InputDecoration(labelText: 'Division'),
                            items: BdLocations.divisions
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _division = value ?? '';
                                _district = '';
                              });
                            },
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _district.isEmpty ? null : _district,
                            decoration: const InputDecoration(labelText: 'District'),
                            items: BdLocations.districts
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() => _district = value ?? ''),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Password'),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : () => _addAdmin(appState),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
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
                    Text(
                      'Admins',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Current admin accounts registered in Firestore.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      )
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
                          title: Text(
                            admin['displayName']?.toString().isNotEmpty == true
                                ? admin['displayName'].toString()
                                : admin['email']?.toString() ?? 'Admin',
                          ),
                          subtitle: Text(
                            '${admin['email'] ?? ''}\nUID: ${admin['uid'] ?? admin['id'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: admin['email']?.toString().toLowerCase() == AppState.mainAdminEmail
                              ? const Chip(label: Text('Main admin'))
                              : IconButton(
                                  tooltip: 'Remove admin',
                                  onPressed: () => _removeAdmin(appState, admin),
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
