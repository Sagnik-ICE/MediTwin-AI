import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalsController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _donorContactController = TextEditingController();
  bool _isEditing = false;
  bool _saving = false;
  bool _changingPassword = false;
  String _gender = 'Male';
  String _bloodGroup = 'O+';
  bool _isBloodDonor = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _syncFromProfile(context.read<AppState>().profile);
    _loaded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalsController.dispose();
    _conditionsController.dispose();
    _donorContactController.dispose();
    super.dispose();
  }

  void _syncFromProfile(UserProfile p) {
    _nameController.text = p.name;
    _ageController.text = p.age > 0 ? p.age.toString() : '';
    _gender = p.gender == 'Female' ? 'Female' : 'Male';
    _bloodGroup = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(p.bloodGroup) ? p.bloodGroup : 'O+';
    _heightController.text = p.heightCm > 0 ? p.heightCm.toStringAsFixed(0) : '';
    _weightController.text = p.weightKg > 0 ? p.weightKg.toStringAsFixed(1) : '';
    _goalsController.text = p.healthGoals;
    _conditionsController.text = p.knownConditions;
    _donorContactController.text = p.donorContactInfo;
    _isBloodDonor = p.isBloodDonor;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final appState = context.read<AppState>();
    final profile = UserProfile(
      name: _nameController.text.trim(),
      email: appState.currentUserEmail ?? appState.profile.email,
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      gender: _gender,
      bloodGroup: _bloodGroup,
      isBloodDonor: _isBloodDonor,
      donorContactInfo: _isBloodDonor ? _donorContactController.text.trim() : '',
      heightCm: double.tryParse(_heightController.text.trim()) ?? 0,
      weightKg: double.tryParse(_weightController.text.trim()) ?? 0,
      healthGoals: _goalsController.text.trim(),
      knownConditions: _conditionsController.text.trim(),
    );

    await appState.updateProfile(profile);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter your current password and choose a new one.'),
            const SizedBox(height: 16),
            TextField(controller: currentController, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
            const SizedBox(height: 10),
            TextField(controller: newController, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Update')),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;

    setState(() => _changingPassword = true);
    final error = await context.read<AppState>().changePassword(
          currentPassword: currentController.text.trim(),
          newPassword: newController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _changingPassword = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Password updated.')));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final p = appState.profile;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        if (_isEditing) {
                          _saveProfile();
                        } else {
                          _syncFromProfile(p);
                          setState(() => _isEditing = true);
                        }
                      },
                icon: Icon(_isEditing ? Icons.save_rounded : Icons.edit_rounded),
                label: Text(_isEditing ? 'Save' : 'Update profile'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    _row('Name', p.name.isEmpty ? '-' : p.name),
                    _row('Email', p.email.isEmpty ? '-' : p.email),
                    _row('Age', p.age > 0 ? p.age.toString() : '-'),
                    _row('Gender', p.gender.isEmpty ? '-' : p.gender),
                    _row('Blood group', p.bloodGroup.isEmpty ? '-' : p.bloodGroup),
                    _row('Donor', p.isBloodDonor ? 'Yes' : 'No'),
                    if (p.isBloodDonor) _row('Donor contact', p.donorContactInfo.isEmpty ? '-' : p.donorContactInfo),
                    _row('Height', p.heightCm > 0 ? '${p.heightCm.toStringAsFixed(0)} cm' : '-'),
                    _row('Weight', p.weightKg > 0 ? '${p.weightKg.toStringAsFixed(1)} kg' : '-'),
                    _row('Goals', p.healthGoals.isEmpty ? '-' : p.healthGoals),
                    _row('Conditions', p.knownConditions.isEmpty ? '-' : p.knownConditions),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_isEditing)
                GlassCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Edit profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        _field(_nameController, 'Name'),
                        _readonlyField(appState.currentUserEmail ?? p.email, 'Email'),
                        Row(
                          children: [
                            Expanded(child: _field(_ageController, 'Age', number: true)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _dropdownField(
                                label: 'Gender',
                                value: _gender,
                                items: const ['Male', 'Female'],
                                onChanged: (value) => setState(() => _gender = value ?? 'Male'),
                              ),
                            ),
                          ],
                        ),
                        _dropdownField(
                          label: 'Blood group',
                          value: _bloodGroup,
                          items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                          onChanged: (value) => setState(() => _bloodGroup = value ?? 'O+'),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Willing to be a blood donor'),
                          subtitle: const Text('Store donor contact info for emergencies.'),
                          value: _isBloodDonor,
                          onChanged: (value) => setState(() => _isBloodDonor = value),
                        ),
                        if (_isBloodDonor) _field(_donorContactController, 'Donor contact info', validatorMessage: 'Enter contact info for donors'),
                        Row(
                          children: [
                            Expanded(child: _field(_heightController, 'Height (cm)', number: true)),
                            const SizedBox(width: 10),
                            Expanded(child: _field(_weightController, 'Weight (kg)', number: true)),
                          ],
                        ),
                        _field(_goalsController, 'Health goals', maxLines: 2),
                        _field(_conditionsController, 'Known conditions', maxLines: 2),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveProfile,
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded),
                            label: Text(_saving ? 'Saving...' : 'Save profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Profile actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          _syncFromProfile(p);
                          setState(() => _isEditing = true);
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Update profile'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _changingPassword ? null : _changePassword,
                        icon: const Icon(Icons.password_rounded),
                        label: Text(_changingPassword ? 'Opening...' : 'Change password'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _readonlyField(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        readOnly: true,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    int maxLines = 1,
    String? validatorMessage,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return validatorMessage ?? 'Required';
          if (number && double.tryParse(value.trim()) == null) return 'Enter a valid number';
          return null;
        },
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
        validator: (selected) => (selected == null || selected.isEmpty) ? 'Required' : null,
      ),
    );
  }
}
