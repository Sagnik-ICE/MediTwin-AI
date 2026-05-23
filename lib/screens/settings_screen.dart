import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _deletePasswordController = TextEditingController();

  bool _showDeletePanel = false;
  bool _deletingAccount = false;
  String? _deletePasswordError;
  String? _deleteAccountError;

  @override
  void dispose() {
    _deletePasswordController.dispose();
    super.dispose();
  }

  bool get _actionsDisabled => _deletingAccount;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_deletingAccount) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                const Text(
                  'Deleting account...',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
              ],
              _SectionCard(
                title: 'Account',
                subtitle: 'Profile, password, and sign-out controls.',
                children: [
                  _ActionTile(
                    icon: Icons.person_rounded,
                    title: 'Profile',
                    subtitle: 'View and update your profile details',
                    enabled: !_actionsDisabled,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.file_download_rounded,
                    title: 'Export data',
                    subtitle: 'Copy your profile and logs as JSON',
                    enabled: !_actionsDisabled,
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Copy health data?'),
                          content: const Text(
                            'This copies your profile and health logs to the system clipboard. Other apps may be able to read clipboard content on some devices.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              child: const Text('Copy'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;

                      final payload = await appState.exportUserData();
                      await Clipboard.setData(ClipboardData(text: payload));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Export copied to clipboard.')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Session',
                subtitle: 'Logout or delete the current account.',
                children: [
                  _ActionTile(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    subtitle: 'Return to the sign-in screen',
                    destructive: true,
                    enabled: !_actionsDisabled,
                    onTap: () async {
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

                      if (confirm != true) return;
                      await appState.logout();
                    },
                  ),
                  _ActionTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete account',
                    subtitle: 'Permanently remove your account and cloud data',
                    destructive: true,
                    enabled: !_actionsDisabled,
                    onTap: () {
                      setState(() {
                        _showDeletePanel = true;
                        _deletePasswordError = null;
                        _deleteAccountError = null;
                      });
                    },
                  ),
                ],
              ),
              if (_showDeletePanel) ...[
                const SizedBox(height: 16),
                _DeleteAccountPanel(
                  passwordController: _deletePasswordController,
                  passwordError: _deletePasswordError,
                  accountError: _deleteAccountError,
                  deleting: _deletingAccount,
                  onPasswordChanged: (_) {
                    if (_deletePasswordError != null || _deleteAccountError != null) {
                      setState(() {
                        _deletePasswordError = null;
                        _deleteAccountError = null;
                      });
                    }
                  },
                  onCancel: _deletingAccount
                      ? null
                      : () {
                          setState(() {
                            _showDeletePanel = false;
                            _deletePasswordError = null;
                            _deleteAccountError = null;
                            _deletePasswordController.clear();
                          });
                        },
                  onDelete: _deletingAccount ? null : () => _deleteAccount(appState),
                ),
              ],
              if (appState.isAdmin) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Admin',
                  subtitle: 'Admin tools are available in the separate admin shell.',
                  children: const [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.admin_panel_settings_rounded),
                      title: Text('Use the admin app entry'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteAccount(AppState appState) async {
    if (_deletingAccount) return;

    final password = _deletePasswordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _deletePasswordError = 'Password is required';
        _deleteAccountError = null;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _deletingAccount = true;
      _deletePasswordError = null;
      _deleteAccountError = null;
    });

    final result = await appState.deleteAccount(password: password);

    // Successful deletion changes AppState.loggedIn and the app root removes this
    // screen. Do not push, pop, show a dialog, or show a snackbar here.
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _deletingAccount = false;
        _deleteAccountError = result;
      });
    }
  }
}

class _DeleteAccountPanel extends StatelessWidget {
  const _DeleteAccountPanel({
    required this.passwordController,
    required this.passwordError,
    required this.accountError,
    required this.deleting,
    required this.onPasswordChanged,
    required this.onCancel,
    required this.onDelete,
  });

  final TextEditingController passwordController;
  final String? passwordError;
  final String? accountError;
  final bool deleting;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm account deletion',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This permanently deletes the account, profile, appointments, ratings, and related cloud data. Re-enter your password to continue.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              enabled: !deleting,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: passwordError,
              ),
              onChanged: onPasswordChanged,
              onSubmitted: (_) {
                if (!deleting) onDelete?.call();
              },
            ),
            if (accountError != null) ...[
              const SizedBox(height: 12),
              Text(
                accountError!,
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDelete,
                    icon: deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_forever_rounded),
                    label: Text(deleting ? 'Deleting...' : 'Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final baseColor = destructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface;
    final color = enabled ? baseColor : Theme.of(context).disabledColor;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: enabled ? onTap : null,
    );
  }
}
