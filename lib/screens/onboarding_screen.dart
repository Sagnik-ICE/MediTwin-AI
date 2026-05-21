import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  late final TextEditingController _conditionsController;
  late final TextEditingController _donorContactController;
  String _gender = 'Male';
  String _bloodGroup = 'O+';
  bool _isBloodDonor = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _signupEmail = context.read<AppState>().currentUserEmail ?? p.email;
    _nameController = TextEditingController(text: p.name);
    _ageController = TextEditingController(text: p.age > 0 ? p.age.toString() : '');
    _gender = p.gender == 'Female' ? 'Female' : 'Male';
    _bloodGroup = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].contains(p.bloodGroup) ? p.bloodGroup : 'O+';
    _heightController = TextEditingController(text: p.heightCm > 0 ? p.heightCm.toStringAsFixed(0) : '');
    _weightController = TextEditingController(text: p.weightKg > 0 ? p.weightKg.toStringAsFixed(1) : '');
    _goalsController = TextEditingController(text: p.healthGoals);
    _conditionsController = TextEditingController(text: p.knownConditions);
    _donorContactController = TextEditingController(text: p.donorContactInfo);
    _isBloodDonor = p.isBloodDonor;
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
      donorContactInfo: _isBloodDonor ? _donorContactController.text.trim() : '',
      heightCm: double.parse(_heightController.text.trim()),
      weightKg: double.parse(_weightController.text.trim()),
      healthGoals: _goalsController.text.trim(),
      knownConditions: _conditionsController.text.trim(),
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
                    onChanged: (value) => setState(() => _gender = value ?? 'Male'),
                  ),
                  _selectField(
                    label: 'Blood group',
                    value: _bloodGroup,
                    items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                    onChanged: (value) => setState(() => _bloodGroup = value ?? 'O+'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isBloodDonor,
                    onChanged: (value) => setState(() => _isBloodDonor = value),
                    title: const Text('Willing to be a blood donor'),
                    subtitle: const Text('Your donor details will be stored for emergency contact.'),
                  ),
                  if (_isBloodDonor)
                    _field(
                      _donorContactController,
                      'Donor contact info',
                      validatorMessage: 'Enter phone number or contact info for donors',
                    ),
                  _field(_heightController, 'Height (cm)', number: true),
                  _field(_weightController, 'Weight (kg)', number: true),
                  _field(_goalsController, 'Health goals', maxLines: 2),
                  _field(_conditionsController, 'Known conditions', maxLines: 2),
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
        value: value,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
        validator: (selected) => (selected == null || selected.isEmpty) ? 'Required' : null,
      ),
    );
  }
}
