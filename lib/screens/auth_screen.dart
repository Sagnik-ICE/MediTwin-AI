import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../constants/bd_locations.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../widgets/app_logo.dart';
import '../widgets/disclaimer_banner.dart';

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
    if (_loading) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final appState = context.read<AppState>();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_register) {
        final authError = await appState.register(
          email,
          password,
          activateSession: false,
        );

        if (!mounted) return;

        if (authError != null) {
          setState(() {
            _loading = false;
            _error = authError;
          });
          return;
        }

        final profile = UserProfile(
          name: _nameController.text.trim(),
          email: email,
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
          accountType: 'patient',
        );

        final profileError = await appState.completeOnboarding(profile);
        if (!mounted) return;

        if (profileError != null) {
          setState(() {
            _loading = false;
            _error = profileError;
          });
          return;
        }

        // Root app switches to the correct shell from AppState.loggedIn.
        setState(() => _loading = false);
        return;
      }

      final authError = await appState.login(email, password);
      if (!mounted) return;

      if (authError != null) {
        setState(() {
          _loading = false;
          _error = authError;
        });
        return;
      }

      // Root app switches to the correct shell from AppState.loggedIn.
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _register
            ? 'Account was created, but signup could not be completed. Check Firestore rules and try again.'
            : 'Sign in failed. Please try again.';
      });
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_loading) return;

    final email = _emailController.text.trim().toLowerCase();
    if (!_isValidEmail(email)) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await context.read<AppState>().sendPasswordReset(email);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset email sent.')),
    );
  }

  void _switchMode(bool register) {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _register = register;
      _error = null;
    });
  }

  List<String> get _districtItems {
    if (_division.trim().isEmpty) return BdLocations.districts;
    return BdLocations.districtsFor(_division);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_register,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _register) {
          _switchMode(false);
        }
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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                ),
              ),
              child: const AppLogo(size: 78),
            ),
            const SizedBox(height: 22),
            Text(
              AppConstants.appName,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Text(
                AppConstants.tagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
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
                    onPressed: _loading ? null : () => _switchMode(false),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to sign in'),
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
                enabled: !_loading,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
                validator: (value) {
                  if (!_isValidEmail(value?.trim() ?? '')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                obscureText: !_showPassword,
                textInputAction: _register ? TextInputAction.next : TextInputAction.done,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    onPressed: _loading ? null : () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!_register && !_loading) _submit();
                },
              ),
              if (!_register) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _sendPasswordReset,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ],
              if (_register) ...[
                const SizedBox(height: 14),
                _textField(controller: _nameController, label: 'Full name'),
                const SizedBox(height: 14),
                _textField(
                  controller: _ageController,
                  label: 'Age',
                  keyboardType: TextInputType.number,
                  validator: _validateAge,
                ),
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
                  onChanged: _loading ? null : (value) => setState(() => _isBloodDonor = value),
                  title: const Text('Willing to be a blood donor'),
                  subtitle: const Text('This is a normal-user profile option, not a separate account type.'),
                ),
                const SizedBox(height: 10),
                _textField(
                  controller: _contactController,
                  label: 'Contact info',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _textField(
                  controller: _heightController,
                  label: 'Height (cm)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validateHeight,
                ),
                const SizedBox(height: 14),
                _textField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validateWeight,
                ),
                const SizedBox(height: 14),
                _textField(controller: _goalsController, label: 'Health goals', maxLines: 2),
                const SizedBox(height: 14),
                _dropdownField(
                  label: 'Division',
                  value: _division,
                  items: BdLocations.divisions,
                  onChanged: (value) {
                    setState(() {
                      _division = value ?? '';
                      if (_division.isEmpty || !BdLocations.districtsFor(_division).contains(_district)) {
                        _district = '';
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
                _dropdownField(
                  label: 'District',
                  value: _district,
                  items: _districtItems,
                  onChanged: (value) => setState(() => _district = value ?? ''),
                ),
              ],
              const SizedBox(height: 14),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
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
              TextButton(
                onPressed: _loading ? null : () => _switchMode(!_register),
                child: Text(_register ? 'Already have an account? Sign in' : 'Need an account? Create one'),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: TextInputAction.next,
      enabled: !_loading,
      decoration: InputDecoration(labelText: label),
      validator: validator ??
          (value) {
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
    final uniqueItems = items.toSet().toList();
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty || !uniqueItems.contains(value) ? null : value,
      decoration: InputDecoration(labelText: label),
      items: uniqueItems.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
      onChanged: _loading ? null : onChanged,
      validator: (selected) {
        if (!_register) return null;
        return (selected == null || selected.isEmpty) ? '$label is required' : null;
      },
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }

  String? _validateAge(String? value) {
    if (!_register) return null;
    final age = int.tryParse((value ?? '').trim());
    if (age == null) return 'Enter a valid age';
    if (age < 1 || age > 120) return 'Age must be between 1 and 120';
    return null;
  }

  String? _validateHeight(String? value) {
    if (!_register) return null;
    final height = double.tryParse((value ?? '').trim());
    if (height == null) return 'Enter a valid height';
    if (height <= 0 || height > 300) return 'Height must be between 1 and 300 cm';
    return null;
  }

  String? _validateWeight(String? value) {
    if (!_register) return null;
    final weight = double.tryParse((value ?? '').trim());
    if (weight == null) return 'Enter a valid weight';
    if (weight <= 0 || weight > 500) return 'Weight must be between 1 and 500 kg';
    return null;
  }
}
