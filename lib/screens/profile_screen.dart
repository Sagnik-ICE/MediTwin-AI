// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bd_locations.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import 'auth_screen.dart';
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
  final _contactController = TextEditingController();
  bool _isEditing = false;
  bool _saving = false;
  bool _changingPassword = false;
  String _gender = '';
  String _bloodGroup = '';
  String _division = '';
  String _district = '';
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
    _contactController.dispose();
    super.dispose();
  }

  void _syncFromProfile(UserProfile p) {
    _nameController.text = p.name;
    _ageController.text = p.age > 0 ? p.age.toString() : '';
    _gender = ['Male', 'Female'].contains(p.gender) ? p.gender : '';
    _bloodGroup = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(p.bloodGroup) ? p.bloodGroup : '';
    _heightController.text = p.heightCm > 0 ? p.heightCm.toStringAsFixed(0) : '';
    _weightController.text = p.weightKg > 0 ? p.weightKg.toStringAsFixed(1) : '';
    _goalsController.text = p.healthGoals;
    _contactController.text = p.contactInfo;
    _division = BdLocations.divisions.contains(p.division) ? p.division : '';
    _district = BdLocations.districts.contains(p.district) ? p.district : '';
    _isBloodDonor = p.isBloodDonor;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final currentProfile = appState.profile;
    final preservedAccountType = currentProfile.accountType.trim().isEmpty ? 'patient' : currentProfile.accountType.trim();

    final profile = UserProfile(
      name: _nameController.text.trim(),
      email: appState.currentUserEmail ?? currentProfile.email,
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      gender: _gender,
      bloodGroup: _bloodGroup,
      isBloodDonor: _isBloodDonor,
      donorContactInfo: _isBloodDonor ? _contactController.text.trim() : '',
      heightCm: double.tryParse(_heightController.text.trim()) ?? 0,
      weightKg: double.tryParse(_weightController.text.trim()) ?? 0,
      healthGoals: _goalsController.text.trim(),
      contactInfo: _contactController.text.trim(),
      division: _division,
      district: _district,
      accountType: preservedAccountType,
    );

    final error = await appState.updateProfile(profile);
    if (!mounted) return;

    setState(() {
      _saving = false;
      if (error == null) {
        _isEditing = false;
      }
    });

    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
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
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Password updated.')));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final p = appState.profile;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
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
                    _row('Account type', p.accountType.trim().isEmpty ? 'patient' : p.accountType),
                    _row('Age', p.age > 0 ? p.age.toString() : '-'),
                    _row('Gender', p.gender.isEmpty ? '-' : p.gender),
                    _row('Blood group', p.bloodGroup.isEmpty ? '-' : p.bloodGroup),
                    _row('Donor', p.isBloodDonor ? 'Yes' : 'No'),
                    _row('Contact', p.contactInfo.isEmpty ? '-' : p.contactInfo),
                    _row('Division', p.division.isEmpty ? '-' : p.division),
                    _row('District', p.district.isEmpty ? '-' : p.district),
                    _row('Height', p.heightCm > 0 ? '${p.heightCm.toStringAsFixed(0)} cm' : '-'),
                    _row('Weight', p.weightKg > 0 ? '${p.weightKg.toStringAsFixed(1)} kg' : '-'),
                    _row('Goals', p.healthGoals.isEmpty ? '-' : p.healthGoals),
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
                                onChanged: (value) => setState(() => _gender = value ?? ''),
                              ),
                            ),
                          ],
                        ),
                        _dropdownField(
                          label: 'Blood group',
                          value: _bloodGroup,
                          items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                          onChanged: (value) => setState(() => _bloodGroup = value ?? ''),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Willing to be a blood donor'),
                          subtitle: const Text('Your contact will be reused if you opt in as a donor.'),
                          value: _isBloodDonor,
                          onChanged: (value) => setState(() => _isBloodDonor = value),
                        ),
                        _field(_contactController, 'Contact', validatorMessage: 'Enter a contact number or email'),
                        Row(
                          children: [
                            Expanded(child: _field(_heightController, 'Height (cm)', number: true)),
                            const SizedBox(width: 10),
                            Expanded(child: _field(_weightController, 'Weight (kg)', number: true)),
                          ],
                        ),
                        _field(_goalsController, 'Health goals', maxLines: 2),
                        _dropdownField(
                          label: 'Division',
                          value: _division,
                          items: BdLocations.divisions,
                          onChanged: (value) => setState(() => _division = value ?? ''),
                        ),
                        _dropdownField(
                          label: 'District',
                          value: _district,
                          items: BdLocations.districts,
                          onChanged: (value) => setState(() => _district = value ?? ''),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
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
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Logout?'),
                              content: const Text('You will be returned to the sign-in screen.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Logout')),
                              ],
                            ),
                          );
                          if (!(confirm ?? false)) return;
                          final navigator = Navigator.of(context);
                          await context.read<AppState>().logout();
                          if (!mounted) return;
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const AuthScreen()),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Logout'),
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
        initialValue: items.contains(value) ? value : null,
        hint: Text(label),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
        validator: (selected) => (selected == null || selected.isEmpty) ? 'Required' : null,
      ),
    );
  }
}
