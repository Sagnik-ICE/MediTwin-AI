import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bd_locations.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../widgets/disclaimer_banner.dart';
import 'admin_shell.dart';
import 'main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _signupEmail;
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _goalsController;
  late final TextEditingController _contactController;
  String _gender = '';
  String _bloodGroup = '';
  String _division = '';
  String _district = '';
  bool _isBloodDonor = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _signupEmail = context.read<AppState>().currentUserEmail ?? p.email;
    _nameController = TextEditingController(text: p.name);
    _ageController = TextEditingController(text: p.age > 0 ? p.age.toString() : '');
    _gender = ['Male', 'Female'].contains(p.gender) ? p.gender : '';
    _bloodGroup = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(p.bloodGroup) ? p.bloodGroup : '';
    _heightController = TextEditingController(text: p.heightCm > 0 ? p.heightCm.toStringAsFixed(0) : '');
    _weightController = TextEditingController(text: p.weightKg > 0 ? p.weightKg.toStringAsFixed(1) : '');
    _goalsController = TextEditingController(text: p.healthGoals);
    _contactController = TextEditingController(text: p.contactInfo);
    _division = BdLocations.divisions.contains(p.division) ? p.division : '';
    _district = BdLocations.districts.contains(p.district) ? p.district : '';
    _isBloodDonor = p.isBloodDonor;
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

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final profile = UserProfile(
      name: _nameController.text.trim(),
      email: _signupEmail,
      age: int.parse(_ageController.text.trim()),
      gender: _gender,
      bloodGroup: _bloodGroup,
      isBloodDonor: _isBloodDonor,
      donorContactInfo: _isBloodDonor ? _contactController.text.trim() : '',
      heightCm: double.parse(_heightController.text.trim()),
      weightKg: double.parse(_weightController.text.trim()),
      healthGoals: _goalsController.text.trim(),
      contactInfo: _contactController.text.trim(),
      division: _division,
      district: _district,
    );

    await context.read<AppState>().completeOnboarding(profile);

    if (!mounted) {
      return;
    }

    // Refresh auth/cloud state to ensure admin flag is current before routing.
    await context.read<AppState>().refreshAuthState();
    if (!mounted) return;
    final isAdmin = context.read<AppState>().isAdmin;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => isAdmin ? const AdminShell() : const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Build Your Health Twin',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const DisclaimerBanner(),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _field(_nameController, 'Name'),
                  _field(_ageController, 'Age', number: true),
                  _selectField(
                    label: 'Gender',
                    value: _gender,
                    items: const ['Male', 'Female'],
                    onChanged: (value) => setState(() => _gender = value ?? ''),
                  ),
                  _selectField(
                    label: 'Blood group',
                    value: _bloodGroup,
                    items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                    onChanged: (value) => setState(() => _bloodGroup = value ?? ''),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isBloodDonor,
                    onChanged: (value) => setState(() {
                      _isBloodDonor = value;
                      if (!value) {
                        _division = '';
                        _district = '';
                      }
                    }),
                    title: const Text('Willing to be a blood donor'),
                    subtitle: const Text('Your contact will be reused for donor records if you opt in.'),
                  ),
                  _field(_contactController, 'Contact', validatorMessage: 'Enter a contact number or email'),
                  _field(_heightController, 'Height (cm)', number: true),
                  _field(_weightController, 'Weight (kg)', number: true),
                  _field(_goalsController, 'Health goals', maxLines: 2),
                  if (_isBloodDonor) ...[
                    _selectField(
                      label: 'Division',
                      value: _division,
                      items: BdLocations.divisions,
                      onChanged: (value) => setState(() => _division = value ?? ''),
                    ),
                    _selectField(
                      label: 'District',
                      value: _district,
                      items: BdLocations.districts,
                      onChanged: (value) => setState(() => _district = value ?? ''),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Signed in as $_signupEmail',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _finish,
                      child: const Text('Complete Onboarding'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return validatorMessage ?? 'Required';
          }
          if (number && double.tryParse(value.trim()) == null) {
            return 'Enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  Widget _selectField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? null : value,
        hint: Text(label),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
        validator: (selected) => (selected == null || selected.isEmpty) ? 'Required' : null,
      ),
    );
  }
}
