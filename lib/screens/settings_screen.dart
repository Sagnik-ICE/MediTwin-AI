import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
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
          body: SafeArea(
            child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              return ListView(
                padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SettingsHero(),
                          if (_deletingAccount) ...[
                            const SizedBox(height: 16),
                            const LinearProgressIndicator(),
                            const SizedBox(height: 10),
                            Text(
                              'Deleting account...',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Account',
                            subtitle: 'Profile, password, and data export controls.',
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
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Session',
                            subtitle: 'Logout or permanently delete the current account.',
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
                            const SizedBox(height: 14),
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
                            const SizedBox(height: 14),
                            _SectionCard(
                              title: 'Admin',
                              subtitle: 'Admin tools are available in the separate admin shell.',
                              children: const [
                                _StaticInfoTile(
                                  icon: Icons.admin_panel_settings_rounded,
                                  title: 'Use the admin app entry',
                                  subtitle: 'Open the admin workspace from the admin shell.',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            ),
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

class _SettingsHero extends StatelessWidget {
  const _SettingsHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.softShadow(opacity: 0.10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your profile, data export, sign-in session, and account safety.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.18)),
        boxShadow: AppTheme.softShadow(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.warning_amber_rounded, color: colorScheme.error),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Confirm account deletion',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.error,
                        height: 1.15,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This permanently deletes the account, profile, appointments, ratings, and related cloud data. Re-enter your password to continue.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            enabled: !deleting,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final buttons = [
                OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
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
              ];

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buttons[0],
                    const SizedBox(height: 10),
                    buttons[1],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 12),
                  Expanded(child: buttons[1]),
                ],
              );
            },
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final accent = destructive ? colorScheme.error : AppTheme.primaryBlue;
    final textColor = enabled ? AppTheme.textPrimary : Theme.of(context).disabledColor;
    final subtitleColor = enabled ? AppTheme.textSecondary : Theme.of(context).disabledColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: enabled ? AppTheme.surfaceTint.withValues(alpha: 0.42) : AppTheme.surfaceTint.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: enabled ? 0.10 : 0.05),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: enabled ? accent : Theme.of(context).disabledColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: enabled ? AppTheme.textMuted : Theme.of(context).disabledColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticInfoTile extends StatelessWidget {
  const _StaticInfoTile({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
