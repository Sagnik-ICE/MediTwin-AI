import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              _SectionCard(
                title: 'Account',
                subtitle: 'Profile, password, and sign-out controls.',
                children: [
                  _ActionTile(
                    icon: Icons.person_rounded,
                    title: 'Profile',
                    subtitle: 'View and update your profile details',
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    },
                  ),
                  _ActionTile(
                    icon: Icons.file_download_rounded,
                    title: 'Export data',
                    subtitle: 'Copy your profile and logs as JSON',
                    onTap: () async {
                      final payload = await appState.exportUserData();
                      await Clipboard.setData(ClipboardData(text: payload));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export copied to clipboard.')));
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
                    onTap: () async {
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
                      await appState.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                        (route) => false,
                      );
                    },
                  ),
                  _ActionTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete account',
                    subtitle: 'Permanently remove your account and cloud data',
                    destructive: true,
                    onTap: () async {
                      final passwordController = TextEditingController();
                      final dialogFormKey = GlobalKey<FormState>();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete account?'),
                          content: Form(
                            key: dialogFormKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('This permanently deletes your cloud data and account. Re-enter your password to continue.'),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(labelText: 'Password'),
                                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Password is required' : null,
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () {
                                if (dialogFormKey.currentState?.validate() ?? false) {
                                  Navigator.of(dialogContext).pop(true);
                                }
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (!(confirmed ?? false)) return;
                      final result = await appState.deleteAccount(password: passwordController.text.trim());
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result ?? 'Account deleted.')));
                      if (result == null) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
              if (appState.isAdmin) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Admin',
                  subtitle: 'Admin tools are available in the separate admin shell.',
                  children: const [
                    ListTile(
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
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.destructive = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}