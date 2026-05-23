import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/debug_logger.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _fs = FirestoreService();

  bool _loading = true;
  AdminDashboardStats? _stats;
  List<AdminAuditEntry> _auditLogs = const [];

  static const AdminDashboardStats _emptyStats = AdminDashboardStats(
    users: 0,
    admins: 0,
    normalDoctors: 0,
    dedicatedDoctors: 0,
    ambulances: 0,
    hospitals: 0,
    bloodBanks: 0,
    donors: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _fs.loadAdminDashboardStats(),
        _fs.loadRecentAdminAuditLogs(limit: 10),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminDashboardStats;
        _auditLogs = (results[1] as List<AdminAuditEntry>);
      });
    } catch (e, st) {
      DebugLogger.error('Admin dashboard failed to load', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load dashboard metrics.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats ?? _emptyStats;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1024;
            final horizontalPadding = wide ? 28.0 : 16.0;

            return ListView(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 110),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AdminHero(
                          stats: stats,
                          loading: _loading,
                          onRefresh: _loading ? null : _loadStats,
                        ),
                        const SizedBox(height: 18),
                        if (_loading && _stats == null)
                          const _DashboardLoading()
                        else ...[
                          _OverviewStrip(stats: stats),
                          const SizedBox(height: 16),
                          _SectionHeader(
                            icon: Icons.analytics_rounded,
                            title: 'Workspace metrics',
                            subtitle: 'Private counts for the admin workspace only.',
                          ),
                          const SizedBox(height: 12),
                          _MetricsGrid(stats: stats),
                          const SizedBox(height: 18),
                          _OperationalSummary(stats: stats),
                          const SizedBox(height: 18),
                          _RecentActivityCard(entries: _auditLogs),
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
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.stats, required this.loading, required this.onRefresh});

  final AdminDashboardStats stats;
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final totalPublicDirectory = stats.doctors + stats.emergencyResources + stats.donors;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.softShadow(opacity: 0.10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;

          final titleBlock = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin overview',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monitor users, doctors, emergency records, and donor visibility from one controlled workspace.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w600,
                            height: 1.38,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final refreshButton = OutlinedButton.icon(
            onPressed: onRefresh,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(loading ? 'Refreshing' : 'Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          );

          final summary = _HeroSummary(
            users: stats.users,
            doctors: stats.doctors,
            directoryRecords: totalPublicDirectory,
          );

          if (!wide) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 18),
                summary,
                const SizedBox(height: 18),
                Align(alignment: Alignment.centerLeft, child: refreshButton),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 18),
                    refreshButton,
                  ],
                ),
              ),
              const SizedBox(width: 22),
              SizedBox(width: 430, child: summary),
            ],
          );
        },
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.users, required this.doctors, required this.directoryRecords});

  final int users;
  final int doctors;
  final int directoryRecords;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final items = [
            _HeroMetric(label: 'Users', value: users, icon: Icons.groups_rounded),
            _HeroMetric(label: 'Doctors', value: doctors, icon: Icons.medical_services_rounded),
            _HeroMetric(label: 'Directory', value: directoryRecords, icon: Icons.folder_shared_rounded),
          ];

          if (compact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i != items.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }

          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i != items.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 14),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StripData('Dedicated ratio', stats.doctors == 0 ? '0%' : '${((stats.dedicatedDoctors / stats.doctors) * 100).round()}%', Icons.verified_rounded),
      _StripData('Emergency records', stats.emergencyResources.toString(), Icons.emergency_rounded),
      _StripData('Visible donors', stats.donors.toString(), Icons.volunteer_activism_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 3 : 1;
        final spacing = 12.0;
        final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items) SizedBox(width: itemWidth, child: _StripCard(data: item)),
          ],
        );
      },
    );
  }
}

class _StripData {
  const _StripData(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _StripCard extends StatelessWidget {
  const _StripCard({required this.data});

  final _StripData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.045),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceTint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(data.icon, color: AppTheme.primaryTeal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryNavy,
                        fontWeight: FontWeight.w900,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.accentMint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppTheme.primaryTeal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricData('Users', stats.users, Icons.groups_rounded, 'Saved user profiles', AppTheme.primaryBlue),
      _MetricData('Admins', stats.admins, Icons.admin_panel_settings_rounded, 'Management access', AppTheme.primaryNavy),
      _MetricData('Normal doctors', stats.normalDoctors, Icons.badge_rounded, 'Directory only', AppTheme.info),
      _MetricData('Dedicated doctors', stats.dedicatedDoctors, Icons.verified_user_rounded, 'Login and appointments', AppTheme.success),
      _MetricData('Ambulances', stats.ambulances, Icons.local_taxi_rounded, 'Transport support', AppTheme.warning),
      _MetricData('Hospitals', stats.hospitals, Icons.local_hospital_rounded, 'Emergency facilities', AppTheme.danger),
      _MetricData('Blood banks', stats.bloodBanks, Icons.bloodtype_rounded, 'Blood support centers', AppTheme.primaryTeal),
      _MetricData('Donors', stats.donors, Icons.volunteer_activism_rounded, 'Visible donor entries', AppTheme.accentCyan),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1040 ? 4 : width >= 720 ? 2 : 1;
        final spacing = 14.0;
        final itemWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: itemWidth, child: _MetricCard(data: card)),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.description, this.color);

  final String label;
  final int value;
  final IconData icon;
  final String description;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.045),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryNavy,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  data.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalSummary extends StatelessWidget {
  const _OperationalSummary({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final totalDoctors = stats.doctors;
    final totalEmergency = stats.emergencyResources;
    final dedicatedText = totalDoctors == 0
        ? 'No doctors have been added yet.'
        : '${stats.dedicatedDoctors} of $totalDoctors doctors have dedicated login profiles.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.insights_rounded, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operational summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  '$dedicatedText Emergency directory contains $totalEmergency records. Donor count shows only visible donor entries.',
                  style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.entries});

  final List<AdminAuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.04),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.history_rounded, color: AppTheme.primaryTeal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent admin activity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Latest management actions recorded for accountability.',
                      style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'No recent admin activity has been recorded yet.',
                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  _ActivityRow(entry: entries[i]),
                  if (i != entries.length - 1) const Divider(height: 18),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final AdminAuditEntry entry;

  String get _title {
    final label = entry.label.trim().isEmpty ? entry.targetType : entry.label.trim();
    switch (entry.action) {
      case 'doctor_created':
        return 'Doctor added: $label';
      case 'doctor_updated':
        return 'Doctor updated: $label';
      case 'doctor_deleted':
        return 'Doctor deleted: $label';
      case 'emergency_resource_created':
        return 'Emergency resource added: $label';
      case 'emergency_resource_updated':
        return 'Emergency resource updated: $label';
      case 'emergency_resource_deleted':
        return 'Emergency resource deleted: $label';
      case 'admin_saved':
        return 'Admin saved: $label';
      case 'admin_deleted':
        return 'Admin removed: $label';
      case 'appointment_status_updated':
        return 'Appointment marked ${entry.label}';
      default:
        return label;
    }
  }

  IconData get _icon {
    if (entry.action.contains('doctor')) return Icons.medical_services_rounded;
    if (entry.action.contains('emergency')) return Icons.emergency_rounded;
    if (entry.action.contains('admin')) return Icons.admin_panel_settings_rounded;
    if (entry.action.contains('appointment')) return Icons.event_note_rounded;
    return Icons.history_rounded;
  }

  Color get _color {
    if (entry.action.contains('deleted')) return AppTheme.danger;
    if (entry.action.contains('created')) return AppTheme.success;
    if (entry.action.contains('updated')) return AppTheme.primaryBlue;
    return AppTheme.primaryTeal;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(entry.createdAt);
    final actor = entry.actorEmail.trim().isEmpty ? 'Admin' : entry.actorEmail.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_icon, color: _color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '$actor${timeText.isEmpty ? '' : ' • $timeText'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}


class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
