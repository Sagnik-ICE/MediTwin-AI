// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bd_locations.dart';
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
  final _contactController = TextEditingController();

  bool _isEditing = false;
  bool _saving = false;
  bool _changingPassword = false;
  bool _loggingOut = false;
  bool _loaded = false;

  String _gender = '';
  String _bloodGroup = '';
  String _division = '';
  String _district = '';
  bool _isBloodDonor = false;

  static const _genders = ['Male', 'Female'];
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

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

  List<String> get _districtOptions {
    if (_division.trim().isEmpty) return BdLocations.districts;
    final filtered = BdLocations.districtsFor(_division);
    return filtered.isEmpty ? BdLocations.districts : filtered;
  }

  void _syncFromProfile(UserProfile p) {
    _nameController.text = p.name;
    _ageController.text = p.age > 0 ? p.age.toString() : '';
    _heightController.text = p.heightCm > 0 ? _cleanNumber(p.heightCm) : '';
    _weightController.text = p.weightKg > 0 ? _cleanNumber(p.weightKg) : '';
    _goalsController.text = p.healthGoals;
    _contactController.text = p.contactInfo;

    _gender = _genders.contains(p.gender) ? p.gender : '';
    _bloodGroup = _bloodGroups.contains(p.bloodGroup) ? p.bloodGroup : '';
    _division = BdLocations.divisions.contains(p.division) ? p.division : '';

    final allowedDistricts = _division.isEmpty ? BdLocations.districts : BdLocations.districtsFor(_division);
    _district = allowedDistricts.contains(p.district) ? p.district : '';
    _isBloodDonor = p.isBloodDonor;
  }

  String _cleanNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  UserProfile _profileFromForm(AppState appState, UserProfile currentProfile) {
    final preservedAccountType = currentProfile.accountType.trim().isEmpty ? 'patient' : currentProfile.accountType.trim();
    final contact = _contactController.text.trim();

    return UserProfile(
      name: _nameController.text.trim(),
      email: appState.currentUserEmail ?? currentProfile.email,
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      gender: _gender,
      bloodGroup: _bloodGroup,
      isBloodDonor: _isBloodDonor,
      donorContactInfo: _isBloodDonor ? contact : '',
      heightCm: double.tryParse(_heightController.text.trim()) ?? 0,
      weightKg: double.tryParse(_weightController.text.trim()) ?? 0,
      healthGoals: _goalsController.text.trim(),
      contactInfo: contact,
      division: _division,
      district: _district,
      accountType: preservedAccountType,
    );
  }

  bool _sameProfile(UserProfile a, UserProfile b) {
    return a.name == b.name &&
        a.email == b.email &&
        a.age == b.age &&
        a.gender == b.gender &&
        a.bloodGroup == b.bloodGroup &&
        a.isBloodDonor == b.isBloodDonor &&
        a.donorContactInfo == b.donorContactInfo &&
        a.heightCm == b.heightCm &&
        a.weightKg == b.weightKg &&
        a.healthGoals == b.healthGoals &&
        a.contactInfo == b.contactInfo &&
        a.division == b.division &&
        a.district == b.district &&
        a.accountType == b.accountType;
  }

  Future<void> _saveProfile() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _saving) return;

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final currentProfile = appState.profile;
    final nextProfile = _profileFromForm(appState, currentProfile);

    if (_sameProfile(nextProfile, currentProfile)) {
      messenger.showSnackBar(const SnackBar(content: Text('No profile changes to save.')));
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _saving = true);
    final error = await appState.updateProfile(nextProfile);
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
    if (_changingPassword || _loggingOut || _saving) return;

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? currentError;
    String? newError;
    String? confirmError;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              void clearErrors() {
                if (currentError != null || newError != null || confirmError != null) {
                  setDialogState(() {
                    currentError = null;
                    newError = null;
                    confirmError = null;
                  });
                }
              }

              void submit() {
                final current = currentController.text.trim();
                final next = newController.text.trim();
                final confirm = confirmController.text.trim();

                setDialogState(() {
                  currentError = current.isEmpty ? 'Current password is required' : null;
                  newError = next.length < 6 ? 'New password must be at least 6 characters' : null;
                  confirmError = confirm != next ? 'Passwords do not match' : null;
                });

                if (currentError == null && newError == null && confirmError == null) {
                  Navigator.of(dialogContext).pop(true);
                }
              }

              return AlertDialog(
                title: const Text('Change password'),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Enter your current password and choose a new one.'),
                      const SizedBox(height: 16),
                      _dialogPasswordField(
                        controller: currentController,
                        label: 'Current password',
                        errorText: currentError,
                        onChanged: clearErrors,
                        onSubmitted: submit,
                      ),
                      const SizedBox(height: 10),
                      _dialogPasswordField(
                        controller: newController,
                        label: 'New password',
                        errorText: newError,
                        onChanged: clearErrors,
                        onSubmitted: submit,
                      ),
                      const SizedBox(height: 10),
                      _dialogPasswordField(
                        controller: confirmController,
                        label: 'Confirm new password',
                        errorText: confirmError,
                        onChanged: clearErrors,
                        onSubmitted: submit,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: submit,
                    child: const Text('Update'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true) return;

      setState(() => _changingPassword = true);
      final error = await context.read<AppState>().changePassword(
            currentPassword: currentController.text.trim(),
            newPassword: newController.text.trim(),
          );

      if (!mounted) return;
      setState(() => _changingPassword = false);

      messenger.showSnackBar(
        SnackBar(
          content: Text(error ?? 'Password updated.'),
          backgroundColor: error == null ? null : Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
      if (mounted && _changingPassword) {
        setState(() => _changingPassword = false);
      }
    }
  }

  Future<void> _logout(AppState appState) async {
    if (_loggingOut || _saving || _changingPassword) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will be returned to the sign-in screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loggingOut = true);
    await appState.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final profile = appState.profile;
        final actionsDisabled = _saving || _changingPassword || _loggingOut;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth >= 1100 ? 1040.0 : constraints.maxWidth;
                final isWide = constraints.maxWidth >= 860;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 24 : 16,
                        16,
                        isWide ? 24 : 16,
                        32,
                      ),
                      children: [
                        if (_loggingOut) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 12),
                        ],
                        _ProfileHero(
                          profile: profile,
                          completion: _profileCompletion(profile),
                          onEdit: actionsDisabled
                              ? null
                              : () {
                                  _syncFromProfile(profile);
                                  setState(() => _isEditing = true);
                                },
                        ),
                        const SizedBox(height: 16),
                        if (_isEditing)
                          _buildEditForm(context, appState, profile, isWide, actionsDisabled)
                        else
                          _buildProfileBody(context, appState, profile, isWide, actionsDisabled),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileBody(
    BuildContext context,
    AppState appState,
    UserProfile profile,
    bool isWide,
    bool actionsDisabled,
  ) {
    final summary = _summaryItems(profile);

    final summaryCard = _SectionCard(
      title: 'Personal details',
      subtitle: 'Your basic health and contact information.',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          for (var i = 0; i < summary.length; i++) ...[
            _InfoRow(label: summary[i].label, value: summary[i].value, icon: summary[i].icon),
            if (i != summary.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );

    final actionsCard = _SectionCard(
      title: 'Account actions',
      subtitle: 'Manage your profile access and session.',
      icon: Icons.manage_accounts_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: actionsDisabled ? null : _changePassword,
            icon: const Icon(Icons.password_rounded),
            label: Text(_changingPassword ? 'Updating password...' : 'Change password'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: actionsDisabled ? null : () => _logout(appState),
            icon: _loggingOut
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout_rounded),
            label: Text(_loggingOut ? 'Logging out...' : 'Logout'),
          ),
          const SizedBox(height: 14),
          _PrivacyNote(
            text: profile.isBloodDonor
                ? 'Your donor contact can appear in the donor list because you opted in.'
                : 'Your profile data is used for your account, health logs, and personalized guidance.',
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: summaryCard),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: actionsCard),
        ],
      );
    }

    return Column(
      children: [
        summaryCard,
        const SizedBox(height: 16),
        actionsCard,
      ],
    );
  }

  Widget _buildEditForm(
    BuildContext context,
    AppState appState,
    UserProfile profile,
    bool isWide,
    bool actionsDisabled,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _SectionCard(
            title: 'Update profile',
            subtitle: 'Keep your health profile accurate for better insights.',
            icon: Icons.edit_note_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FormGroupTitle(title: 'Identity'),
                _responsiveRow(
                  isWide: isWide,
                  children: [
                    _field(_nameController, 'Full name', enabled: !actionsDisabled),
                    _readonlyField(appState.currentUserEmail ?? profile.email, 'Email address'),
                  ],
                ),
                _responsiveRow(
                  isWide: isWide,
                  children: [
                    _field(
                      _ageController,
                      'Age',
                      number: true,
                      enabled: !actionsDisabled,
                      validator: _validateAge,
                    ),
                    _dropdownField(
                      label: 'Gender',
                      value: _gender,
                      items: _genders,
                      enabled: !actionsDisabled,
                      onChanged: (value) => setState(() => _gender = value ?? ''),
                    ),
                    _dropdownField(
                      label: 'Blood group',
                      value: _bloodGroup,
                      items: _bloodGroups,
                      enabled: !actionsDisabled,
                      onChanged: (value) => setState(() => _bloodGroup = value ?? ''),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _FormGroupTitle(title: 'Health profile'),
                _responsiveRow(
                  isWide: isWide,
                  children: [
                    _field(
                      _heightController,
                      'Height (cm)',
                      number: true,
                      enabled: !actionsDisabled,
                      validator: _validateHeight,
                    ),
                    _field(
                      _weightController,
                      'Weight (kg)',
                      number: true,
                      enabled: !actionsDisabled,
                      validator: _validateWeight,
                    ),
                  ],
                ),
                _field(
                  _goalsController,
                  'Health goals or important notes',
                  maxLines: 3,
                  enabled: !actionsDisabled,
                  validatorMessage: 'Enter a health goal or note',
                ),
                const SizedBox(height: 10),
                _FormGroupTitle(title: 'Location and contact'),
                _responsiveRow(
                  isWide: isWide,
                  children: [
                    _dropdownField(
                      label: 'Division',
                      value: _division,
                      items: BdLocations.divisions,
                      enabled: !actionsDisabled,
                      onChanged: (value) {
                        setState(() {
                          _division = value ?? '';
                          final options = _districtOptions;
                          if (!options.contains(_district)) _district = '';
                        });
                      },
                    ),
                    _dropdownField(
                      label: 'District',
                      value: _district,
                      items: _districtOptions,
                      enabled: !actionsDisabled,
                      onChanged: (value) => setState(() => _district = value ?? ''),
                    ),
                  ],
                ),
                _field(
                  _contactController,
                  'Contact number or email',
                  enabled: !actionsDisabled,
                  validatorMessage: 'Enter a contact number or email',
                ),
                _DonorToggle(
                  value: _isBloodDonor,
                  enabled: !actionsDisabled,
                  onChanged: (value) => setState(() => _isBloodDonor = value),
                ),
                const SizedBox(height: 16),
                _FormActions(
                  saving: _saving,
                  disabled: actionsDisabled,
                  onCancel: () {
                    _syncFromProfile(profile);
                    setState(() => _isEditing = false);
                  },
                  onSave: _saveProfile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _profileCompletion(UserProfile p) {
    final values = [
      p.name,
      p.email,
      p.age > 0 ? 'age' : '',
      p.gender,
      p.bloodGroup,
      p.contactInfo,
      p.division,
      p.district,
      p.heightCm > 0 ? 'height' : '',
      p.weightKg > 0 ? 'weight' : '',
      p.healthGoals,
    ];
    final filled = values.where((value) => value.toString().trim().isNotEmpty).length;
    return ((filled / values.length) * 100).round().clamp(0, 100);
  }

  List<_SummaryItem> _summaryItems(UserProfile p) {
    return [
      _SummaryItem(Icons.person_outline_rounded, 'Name', p.name.isEmpty ? '-' : p.name),
      _SummaryItem(Icons.email_outlined, 'Email', p.email.isEmpty ? '-' : p.email),
      _SummaryItem(Icons.verified_user_outlined, 'Account type', _titleCase(p.accountType.trim().isEmpty ? 'patient' : p.accountType)),
      _SummaryItem(Icons.cake_outlined, 'Age', p.age > 0 ? p.age.toString() : '-'),
      _SummaryItem(Icons.wc_rounded, 'Gender', p.gender.isEmpty ? '-' : p.gender),
      _SummaryItem(Icons.bloodtype_outlined, 'Blood group', p.bloodGroup.isEmpty ? '-' : p.bloodGroup),
      _SummaryItem(Icons.phone_outlined, 'Contact', p.contactInfo.isEmpty ? '-' : p.contactInfo),
      _SummaryItem(Icons.location_on_outlined, 'Location', _formatLocation(p)),
      _SummaryItem(Icons.height_rounded, 'Height', p.heightCm > 0 ? '${_cleanNumber(p.heightCm)} cm' : '-'),
      _SummaryItem(Icons.monitor_weight_outlined, 'Weight', p.weightKg > 0 ? '${_cleanNumber(p.weightKg)} kg' : '-'),
      _SummaryItem(Icons.volunteer_activism_outlined, 'Blood donor', p.isBloodDonor ? 'Opted in' : 'Not opted in'),
      _SummaryItem(Icons.flag_outlined, 'Goals', p.healthGoals.isEmpty ? '-' : p.healthGoals),
    ];
  }

  String _formatLocation(UserProfile p) {
    final parts = [p.district, p.division].where((value) => value.trim().isNotEmpty).toList();
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    final age = int.tryParse(text);
    if (age == null) return 'Enter a valid age';
    if (age < 0 || age > 120) return 'Age must be between 0 and 120';
    return null;
  }

  String? _validateHeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    final height = double.tryParse(text);
    if (height == null) return 'Enter a valid number';
    if (height <= 0 || height > 300) return 'Height must be between 1 and 300 cm';
    return null;
  }

  String? _validateWeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    final weight = double.tryParse(text);
    if (weight == null) return 'Enter a valid number';
    if (weight <= 0 || weight > 500) return 'Weight must be between 1 and 500 kg';
    return null;
  }

  Widget _responsiveRow({
    required bool isWide,
    required List<Widget> children,
  }) {
    if (!isWide || children.length == 1) {
      return Column(
        children: [
          for (final child in children) child,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _readonlyField(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
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
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: validator ??
            (value) {
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
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        hint: Text(label),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: enabled ? onChanged : null,
        decoration: InputDecoration(labelText: label),
        validator: (selected) => (selected == null || selected.isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _dialogPasswordField({
    required TextEditingController controller,
    required String label,
    required String? errorText,
    required VoidCallback onChanged,
    required VoidCallback onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
      ),
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.completion,
    required this.onEdit,
  });

  final UserProfile profile;
  final int completion;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = profile.name.trim().isEmpty ? 'Complete your profile' : profile.name.trim();
    final email = profile.email.trim().isEmpty ? 'Email not added' : profile.email.trim();
    final role = profile.accountType.trim().isEmpty ? 'patient' : profile.accountType.trim();
    final roleLabel = role[0].toUpperCase() + role.substring(1).toLowerCase();

    final editButton = FilledButton.icon(
      onPressed: onEdit,
      icon: const Icon(Icons.edit_rounded, size: 18),
      label: const Text('Edit profile'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    );

    Widget identityBlock({required bool centered}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    Widget pills({required bool centered}) {
      return Wrap(
        alignment: centered ? WrapAlignment.center : WrapAlignment.start,
        spacing: 10,
        runSpacing: 10,
        children: [
          _HeroPill(
            icon: Icons.verified_user_outlined,
            label: roleLabel,
          ),
          _HeroPill(
            icon: completion >= 80 ? Icons.task_alt_rounded : Icons.pending_actions_rounded,
            label: '$completion% complete',
          ),
          if (profile.isBloodDonor)
            const _HeroPill(
              icon: Icons.bloodtype_outlined,
              label: 'Donor opt-in',
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.70)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;

          if (wide) {
            final textWidth = (constraints.maxWidth - 78 - 18 - 18 - 160)
                .clamp(260.0, constraints.maxWidth);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Avatar(name: name),
                const SizedBox(width: 18),
                SizedBox(
                  width: textWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identityBlock(centered: false),
                      const SizedBox(height: 14),
                      pills(centered: false),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                editButton,
              ],
            );
          }

          final detailsWidth = (constraints.maxWidth - 78 - 16).clamp(160.0, constraints.maxWidth);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Avatar(name: name),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: detailsWidth,
                    child: identityBlock(centered: false),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              pills(centered: false),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: editButton),
            ],
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = name.trim().isEmpty
        ? 'U'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.95),
            colorScheme.tertiaryContainer.withValues(alpha: 0.80),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 25,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: colorScheme.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormGroupTitle extends StatelessWidget {
  const _FormGroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _DonorToggle extends StatelessWidget {
  const _DonorToggle({required this.value, required this.enabled, required this.onChanged});

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFFFE6E6) : colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.bloodtype_outlined,
              color: value ? const Color(0xFFB42318) : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blood donor opt-in', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  'Use your contact information in the donor list only when enabled.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.saving,
    required this.disabled,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final bool disabled;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: disabled ? null : onCancel,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: disabled ? null : onSave,
          icon: saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded),
          label: Text(saving ? 'Saving...' : 'Save changes'),
        ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}
