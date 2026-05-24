import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bd_locations.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

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
      admins.sort((a, b) {
        final aMain = (a['email']?.toString().toLowerCase() ?? '') == AppState.mainAdminEmail.toLowerCase();
        final bMain = (b['email']?.toString().toLowerCase() ?? '') == AppState.mainAdminEmail.toLowerCase();
        if (aMain != bMain) return aMain ? -1 : 1;
        return (a['displayName']?.toString() ?? '').compareTo(b['displayName']?.toString() ?? '');
      });
      setState(() => _admins = admins);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load admin accounts.')),
      );
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
    if (age < 18 || age > 120) return 'Age must be between 18 and 120';
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
      SnackBar(content: Text(error ?? 'Admin account created.')),
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
        title: const Text('Remove admin access?'),
        content: Text(
          email.isEmpty
              ? 'This account will be removed from the admin registry.'
              : '$email will be removed from the admin registry.',
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1050;
            return Container(
              color: Theme.of(context).colorScheme.surface,
              child: ListView(
                padding: EdgeInsets.fromLTRB(wide ? 28 : 18, 18, wide ? 28 : 18, 32),
                children: [
                  _HeroPanel(
                    adminCount: _admins.length,
                    loading: _loading,
                    onRefresh: () => _loadAdmins(appState),
                  ),
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildCreatePanel(context, appState, wide: true)),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: _buildAdminsPanel(context, appState)),
                      ],
                    )
                  else ...[
                    _buildCreatePanel(context, appState, wide: false),
                    const SizedBox(height: 18),
                    _buildAdminsPanel(context, appState),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCreatePanel(BuildContext context, AppState appState, {required bool wide}) {
    final districts = _division.isEmpty ? const <String>[] : BdLocations.districtsFor(_division);

    return _SectionCard(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Create admin account',
              subtitle: 'Provision a secure admin login and profile in one controlled flow.',
            ),
            const SizedBox(height: 22),
            _FormSectionTitle('Identity'),
            const SizedBox(height: 12),
            _ResponsiveFields(
              wide: wide,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => _requiredText(value, label: 'Name is required'),
                ),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Temporary password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
                helperText: 'Minimum 6 characters. The admin can change it later.',
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 24),
            _FormSectionTitle('Profile details'),
            const SizedBox(height: 12),
            _ResponsiveFields(
              wide: wide,
              children: [
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _validateAge,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _gender.isEmpty ? null : _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.wc_rounded),
                  ),
                  items: const ['Male', 'Female', 'Other']
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: _saving ? null : (value) => setState(() => _gender = value ?? ''),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _bloodGroup.isEmpty ? null : _bloodGroup,
                  decoration: const InputDecoration(
                    labelText: 'Blood group',
                    prefixIcon: Icon(Icons.bloodtype_outlined),
                  ),
                  items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: _saving ? null : (value) => setState(() => _bloodGroup = value ?? ''),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                    prefixIcon: Icon(Icons.call_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _requiredText(value, label: 'Contact is required'),
                ),
                TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    prefixIcon: Icon(Icons.height_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _validateHeight,
                ),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _validateWeight,
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _goalsController,
              decoration: const InputDecoration(
                labelText: 'Health goals / notes',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              maxLines: 2,
              validator: (value) => _requiredText(value, label: 'Profile note is required'),
            ),
            const SizedBox(height: 24),
            _FormSectionTitle('Location'),
            const SizedBox(height: 12),
            _ResponsiveFields(
              wide: wide,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _division.isEmpty ? null : _division,
                  decoration: const InputDecoration(
                    labelText: 'Division',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: BdLocations.divisions
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _division = value ?? '';
                            _district = '';
                          });
                        },
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _district.isEmpty ? null : _district,
                  decoration: const InputDecoration(
                    labelText: 'District',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: districts
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: _saving || _division.isEmpty
                      ? null
                      : (value) => setState(() => _district = value ?? ''),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Admin access is restricted. New admins can manage doctors, emergency resources, and admin-only dashboards.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _clearForm,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear form'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: wide ? 2 : 1,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _addAdmin(appState),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(_saving ? 'Creating...' : 'Create admin'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminsPanel(BuildContext context, AppState appState) {
    final mainAdmin = _admins.where((admin) {
      return (admin['email']?.toString().toLowerCase() ?? '') == AppState.mainAdminEmail.toLowerCase();
    }).length;
    final additionalAdmins = (_admins.length - mainAdmin).clamp(0, _admins.length);

    return _SectionCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  icon: Icons.group_rounded,
                  title: 'Admin registry',
                  subtitle: 'Accounts with elevated workspace access.',
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Refresh',
                onPressed: _loading ? null : () => _loadAdmins(appState),
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Total', value: '${_admins.length}', icon: Icons.admin_panel_settings_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'Added', value: '$additionalAdmins', icon: Icons.person_add_alt_rounded)),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading && _admins.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_admins.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
              ),
              child: Column(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 34, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 10),
                  Text(
                    'No additional admins found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created admins will appear here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ..._admins.map((admin) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AdminAccountCard(
                    admin: admin,
                    onRemove: () => _removeAdmin(appState, admin),
                  ),
                )),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.adminCount,
    required this.loading,
    required this.onRefresh,
  });

  final int adminCount;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final refreshButton = OutlinedButton.icon(
      onPressed: loading ? null : onRefresh,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.38)),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        minimumSize: const Size(132, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.refresh_rounded),
      label: Text(loading ? 'Refreshing' : 'Refresh'),
    );

    final adminChip = Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            '${loading ? '—' : adminCount} registered admins',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.softShadow(opacity: 0.10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;

          final textBlock = Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create admin accounts, review elevated access, and keep the workspace controlled.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          );

          final titleRow = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              textBlock,
            ],
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleRow),
                const SizedBox(width: 16),
                adminChip,
                const SizedBox(width: 10),
                refreshButton,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow,
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [adminChip, refreshButton],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.25,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children, required this.wide});

  final List<Widget> children;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children.map((child) {
        return SizedBox(width: 310, child: child);
      }).toList(),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAccountCard extends StatelessWidget {
  const _AdminAccountCard({required this.admin, required this.onRemove});

  final Map<String, dynamic> admin;
  final VoidCallback onRemove;

  bool get _isMainAdmin => (admin['email']?.toString().toLowerCase() ?? '') == AppState.mainAdminEmail.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final name = admin['displayName']?.toString().trim().isNotEmpty == true
        ? admin['displayName'].toString().trim()
        : 'Admin account';
    final email = admin['email']?.toString() ?? '';
    final uid = admin['uid']?.toString().isNotEmpty == true ? admin['uid'].toString() : admin['id']?.toString() ?? '';
    final initial = name.trim().isEmpty ? 'A' : name.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isMainAdmin ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.32) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isMainAdmin ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18) : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.68),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _isMainAdmin ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: _isMainAdmin ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (_isMainAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Main',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                if (uid.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'UID: $uid',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!_isMainAdmin)
            IconButton.filledTonal(
              tooltip: 'Remove admin',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}
