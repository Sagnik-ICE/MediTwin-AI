import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../constants/bd_locations.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../widgets/app_logo.dart';
import '../widgets/disclaimer_banner.dart';
import 'admin_shell.dart';
import 'doctor_shell.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalsController = TextEditingController();
  final _contactController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _register = false;
  bool _loading = false;
  bool _showPassword = false;
  bool _isBloodDonor = false;
  String _gender = '';
  String _bloodGroup = '';
  String _division = '';
  String _district = '';
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalsController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final appState = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final error = _register ? await appState.register(email, password) : await appState.login(email, password);

    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = error;
    });

    if (error != null) return;

    if (_register) {
      final profile = UserProfile(
        name: _nameController.text.trim(),
        email: email,
        age: int.tryParse(_ageController.text.trim()) ?? 0,
        gender: _gender,
        bloodGroup: _bloodGroup,
        isBloodDonor: _isBloodDonor,
        donorContactInfo: _isBloodDonor ? _contactController.text.trim() : '',
        heightCm: double.tryParse(_heightController.text.trim()) ?? 0,
        weightKg: double.tryParse(_weightController.text.trim()) ?? 0,
        healthGoals: _goalsController.text.trim(),
        contactInfo: _contactController.text.trim(),
        division: _isBloodDonor ? _division : '',
        district: _isBloodDonor ? _district : '',
        accountType: 'patient',
      );
      await appState.completeOnboarding(profile);
    }

    await appState.refreshAuthState();
    if (!mounted) return;

    final isAdminUser = appState.isAdmin || appState.profile.accountType.toLowerCase() == 'admin';
    final next = appState.isDoctor
      ? const DoctorShell()
      : isAdminUser
        ? const AdminShell()
        : const MainShell();

    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        if (_register) {
          setState(() => _register = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF4F8FB), Color(0xFFEAF4FF), Color(0xFFF8FCFD)],
              stops: [0.0, 0.52, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final formCard = _buildFormCard(theme);
                      final heroPanel = _buildHeroPanel(theme);

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: heroPanel),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: formCard),
                          ],
                        );
                      }

                      return Column(
                        children: [heroPanel, const SizedBox(height: 20), formCard],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPanel(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppLogo(size: 72),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppConstants.tagline,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            const DisclaimerBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_register)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _loading ? null : () => setState(() => _register = false),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to login'),
                  ),
                ),
              Text(
                _register ? 'Create your account' : 'Sign in to continue',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _register
                    ? 'Create a secure account to sync health logs, profile data, and AI conversations.'
                    : 'Access your cloud health workspace and continue from any device.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_rounded)),
                validator: (value) {
                  if (value == null || value.trim().isEmpty || !value.contains('@')) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                autofillHints: const [AutofillHints.password],
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!_loading) _submit();
                },
              ),
              if (_register) ...[
                const SizedBox(height: 14),
                _textField(controller: _nameController, label: 'Full name'),
                const SizedBox(height: 14),
                _textField(controller: _ageController, label: 'Age', keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                _dropdownField(
                  label: 'Gender',
                  value: _gender,
                  items: const ['Male', 'Female'],
                  onChanged: (value) => setState(() => _gender = value ?? ''),
                ),
                const SizedBox(height: 14),
                _dropdownField(
                  label: 'Blood group',
                  value: _bloodGroup,
                  items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                  onChanged: (value) => setState(() => _bloodGroup = value ?? ''),
                ),
                const SizedBox(height: 12),
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
                  subtitle: const Text('Your donor record can be shown in the emergency donor list.'),
                ),
                const SizedBox(height: 10),
                _textField(controller: _contactController, label: 'Contact info', keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                _textField(controller: _heightController, label: 'Height (cm)', keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                _textField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                _textField(controller: _goalsController, label: 'Health goals', maxLines: 2),
                if (_isBloodDonor) ...[
                  const SizedBox(height: 14),
                  _dropdownField(
                    label: 'Division',
                    value: _division,
                    items: BdLocations.divisions,
                    onChanged: (value) => setState(() => _division = value ?? ''),
                  ),
                  const SizedBox(height: 14),
                  _dropdownField(
                    label: 'District',
                    value: _district,
                    items: BdLocations.districts,
                    onChanged: (value) => setState(() => _district = value ?? ''),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_register ? 'Create account' : 'Sign in'),
                ),
              ),
              const SizedBox(height: 10),
              if (_register)
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _register = false),
                  child: const Text('Back to login'),
                )
              else
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _register = true),
                  child: const Text('Need an account? Create one'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (!_register) return null;
        if (value == null || value.trim().isEmpty) return '$label is required';
        return null;
      },
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      decoration: InputDecoration(labelText: label),
      items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      validator: (selected) {
        if (!_register) return null;
        return (selected == null || selected.isEmpty) ? '$label is required' : null;
      },
    );
  }
}