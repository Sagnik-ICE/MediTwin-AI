import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/health_score_ring.dart';
import '../widgets/risk_badge.dart';
import '../widgets/app_logo.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key, required this.onAddData});

  final VoidCallback onAddData;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final latest = appState.logs.isNotEmpty ? appState.logs.first : null;

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
                    Expanded(child: _summaryTile(context, 'Sleep', latest == null ? '-' : '${latest.sleepHours.toStringAsFixed(1)} h')),
                    const SizedBox(width: 10),
                    Expanded(child: _summaryTile(context, 'Stress', latest == null ? '-' : '${latest.stressLevel}/10')),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 520;
                    return GlassCard(
                      child: stacked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HealthScoreRing(score: appState.todayScore, size: 96),
                                const SizedBox(height: 14),
                                Text('Current summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(appState.personalizedInsight, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            )
                          : Row(
                              children: [
                                HealthScoreRing(score: appState.todayScore, size: 96),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Current summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(appState.personalizedInsight, style: Theme.of(context).textTheme.bodyMedium),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _metricCard(context, 'Mood', latest?.mood ?? '-'),
                          _metricCard(context, 'Hydration', latest == null ? '-' : '${latest.waterGlasses} glasses'),
                          _metricCard(context, 'Exercise', latest == null ? '-' : '${latest.exerciseMinutes} mins'),
                          _metricCard(context, 'Weight', latest == null ? '-' : '${latest.weight.toStringAsFixed(1)} kg'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Health reminders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
                        value: appState.reminderPreferences.hydration,
                        onChanged: (value) {
                          appState.setReminderPreferences(appState.reminderPreferences.copyWith(hydration: value));
                        },
                      ),
                      _ReminderToggleRow(
                        label: 'Sleep',
                        value: appState.reminderPreferences.sleep,
                        onChanged: (value) {
                          appState.setReminderPreferences(appState.reminderPreferences.copyWith(sleep: value));
                        },
                      ),
                      _ReminderToggleRow(
                        label: 'Daily log',
                        value: appState.reminderPreferences.dailyLog,
                        onChanged: (value) {
                          appState.setReminderPreferences(appState.reminderPreferences.copyWith(dailyLog: value));
                        },
                      ),
                      _ReminderToggleRow(
                        label: 'Stress break',
                        value: appState.reminderPreferences.stressBreak,
                        onChanged: (value) {
                          appState.setReminderPreferences(appState.reminderPreferences.copyWith(stressBreak: value));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (latest != null && latest.riskFlags.isNotEmpty)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent flags', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Wrap(children: latest.riskFlags.map((r) => RiskBadge(text: r)).toList()),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                if (appState.logs.isEmpty)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No logs yet', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Start with a quick health log to see trends and reminders here.', style: Theme.of(context).textTheme.bodyMedium),
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

  Widget _metricCard(BuildContext context, String title, String value) {
    return SizedBox(
      width: 150,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _heroHeader(BuildContext context, AppState appState, VoidCallback onAddData) {
    final name = appState.profile.name.trim().isEmpty ? 'there' : appState.profile.name.split(' ').first;
    return GlassCard(
      child: Row(
        children: [
          const AppLogo(size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good to see you, $name', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('A clean snapshot of your health, reminders, and next steps.', style: Theme.of(context).textTheme.bodyMedium),
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
  const _ReminderToggleRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
