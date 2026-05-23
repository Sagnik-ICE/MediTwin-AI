import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reminder_schedule.dart';
import '../providers/app_state.dart';
import '../widgets/app_logo.dart';
import '../widgets/glass_card.dart';
import '../widgets/health_score_ring.dart';
import '../widgets/risk_badge.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key, required this.onAddData});

  final VoidCallback onAddData;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final latest = appState.latestLog;
        final today = appState.todayLog;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5F9F8), Color(0xFFEAF2FF), Color(0xFFF9FBFD)],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _heroHeader(context, appState, onAddData),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _summaryTile(context, 'Health Score', '${appState.todayScore}')),
                    const SizedBox(width: 10),
                    Expanded(child: _summaryTile(context, 'Sleep', today == null ? '-' : '${today.sleepHours.toStringAsFixed(1)} h')),
                    const SizedBox(width: 10),
                    Expanded(child: _summaryTile(context, 'Stress', today == null ? '-' : '${today.stressLevel}/10')),
                  ],
                ),
                if (latest != null && today == null) ...[
                  const SizedBox(height: 14),
                  GlassCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No health log has been added today. The recent summary below is based on your latest saved log from ${_formatShortDate(latest.date)}.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _currentSummary(context, appState),
                const SizedBox(height: 14),
                _todayMetrics(context, today),
                const SizedBox(height: 14),
                _reminderCard(context, appState),
                const SizedBox(height: 14),
                if (latest != null && latest.riskFlags.isNotEmpty)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent flags',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(children: latest.riskFlags.map((item) => RiskBadge(text: item)).toList()),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                if (appState.logs.isEmpty)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No logs yet',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start with a quick health log to see trends and reminders here.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _currentSummary(BuildContext context, AppState appState) {
    Widget textBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            appState.personalizedInsight,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        return GlassCard(
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HealthScoreRing(score: appState.todayScore, size: 88),
                    const SizedBox(height: 14),
                    textBlock(),
                  ],
                )
              : Row(
                  children: [
                    HealthScoreRing(score: appState.todayScore, size: 88),
                    const SizedBox(width: 16),
                    Expanded(child: textBlock()),
                  ],
                ),
        );
      },
    );
  }

  Widget _todayMetrics(BuildContext context, dynamic today) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricCard(context, 'Mood', today?.mood ?? '-'),
              _metricCard(context, 'Hydration', today == null ? '-' : '${today.waterGlasses} glasses'),
              _metricCard(context, 'Exercise', today == null ? '-' : '${today.exerciseMinutes} mins'),
              _metricCard(context, 'Weight', today == null ? '-' : '${today.weight.toStringAsFixed(1)} kg'),
            ],
          ),
          if (today == null) ...[
            const SizedBox(height: 10),
            Text(
              'Add today\'s daily log to update these values.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _reminderCard(BuildContext context, AppState appState) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Health reminders',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _editReminderTimes(context, appState),
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Times'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onAddData,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Daily log'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ReminderToggleRow(
            label: 'Hydration',
            time: appState.reminderSchedule.hydration.format(context),
            value: appState.reminderPreferences.hydration,
            onChanged: (value) {
              appState.setReminderPreferences(appState.reminderPreferences.copyWith(hydration: value));
            },
          ),
          _ReminderToggleRow(
            label: 'Sleep',
            time: appState.reminderSchedule.sleep.format(context),
            value: appState.reminderPreferences.sleep,
            onChanged: (value) {
              appState.setReminderPreferences(appState.reminderPreferences.copyWith(sleep: value));
            },
          ),
          _ReminderToggleRow(
            label: 'Daily log',
            time: appState.reminderSchedule.dailyLog.format(context),
            value: appState.reminderPreferences.dailyLog,
            onChanged: (value) {
              appState.setReminderPreferences(appState.reminderPreferences.copyWith(dailyLog: value));
            },
          ),
          _ReminderToggleRow(
            label: 'Stress break',
            time: appState.reminderSchedule.stressBreak.format(context),
            value: appState.reminderPreferences.stressBreak,
            onChanged: (value) {
              appState.setReminderPreferences(appState.reminderPreferences.copyWith(stressBreak: value));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editReminderTimes(BuildContext context, AppState appState) async {
    final current = appState.reminderSchedule;
    var draft = current;

    final result = await showDialog<ReminderSchedule>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickTime({
              required TimeOfDay initial,
              required ValueChanged<TimeOfDay> onPicked,
            }) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: initial,
              );
              if (picked != null) {
                setDialogState(() => onPicked(picked));
              }
            }

            return AlertDialog(
              title: const Text('Reminder times'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TimeTile(
                    title: 'Hydration',
                    time: draft.hydration.format(context),
                    onTap: () => pickTime(
                      initial: draft.hydration,
                      onPicked: (value) => draft = draft.copyWith(hydration: value),
                    ),
                  ),
                  _TimeTile(
                    title: 'Sleep',
                    time: draft.sleep.format(context),
                    onTap: () => pickTime(
                      initial: draft.sleep,
                      onPicked: (value) => draft = draft.copyWith(sleep: value),
                    ),
                  ),
                  _TimeTile(
                    title: 'Daily log',
                    time: draft.dailyLog.format(context),
                    onTap: () => pickTime(
                      initial: draft.dailyLog,
                      onPicked: (value) => draft = draft.copyWith(dailyLog: value),
                    ),
                  ),
                  _TimeTile(
                    title: 'Stress break',
                    time: draft.stressBreak.format(context),
                    onTap: () => pickTime(
                      initial: draft.stressBreak,
                      onPicked: (value) => draft = draft.copyWith(stressBreak: value),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, draft),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await appState.setReminderSchedule(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder times saved.')),
        );
      }
    }
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Widget _metricCard(BuildContext context, String title, String value) {
    return SizedBox(
      width: 150,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(BuildContext context, String title, String value) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _heroHeader(BuildContext context, AppState appState, VoidCallback onAddData) {
    final firstName = appState.profile.name.trim().isEmpty ? 'there' : appState.profile.name.trim().split(RegExp(r'\s+')).first;
    return GlassCard(
      child: Row(
        children: [
          const AppLogo(size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good to see you, $firstName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'A clean snapshot of your health, reminders, and next steps.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onAddData,
            child: const Text('Add data'),
          ),
        ],
      ),
    );
  }
}

class _ReminderToggleRow extends StatelessWidget {
  const _ReminderToggleRow({
    required this.label,
    required this.time,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String time;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(time),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.title, required this.time, required this.onTap});

  final String title;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(time),
      trailing: const Icon(Icons.edit_calendar_rounded),
      onTap: onTap,
    );
  }
}
