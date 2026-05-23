import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/health_log.dart';
import '../models/reminder_schedule.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/risk_badge.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key, required this.onAddData});

  final VoidCallback onAddData;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final today = appState.todayLog;
        final latest = appState.latestLog;
        final todayScore = appState.todayScore;

        return Container(
          decoration: const BoxDecoration(gradient: AppTheme.softBrandGradient),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final maxWidth = wide ? 1180.0 : 720.0;
                final horizontalPadding = wide ? 28.0 : 18.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        18,
                        horizontalPadding,
                        110,
                      ),
                      children: [
                        _HeroPanel(
                          appState: appState,
                          today: today,
                          latest: latest,
                          onAddData: onAddData,
                        ),
                        const SizedBox(height: 16),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _TodayOverview(
                                      today: today,
                                      latest: latest,
                                      todayScore: todayScore,
                                    ),
                                    if (latest != null && latest.riskFlags.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      _RiskFlagsPanel(latest: latest),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _InsightPanel(appState: appState, latest: latest, today: today),
                                    const SizedBox(height: 16),
                                    _ReminderCard(appState: appState),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _TodayOverview(today: today, latest: latest, todayScore: todayScore),
                          const SizedBox(height: 16),
                          _InsightPanel(appState: appState, latest: latest, today: today),
                          if (latest != null && latest.riskFlags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _RiskFlagsPanel(latest: latest),
                          ],
                          const SizedBox(height: 16),
                          _ReminderCard(appState: appState),
                        ],
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
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.appState,
    required this.today,
    required this.latest,
    required this.onAddData,
  });

  final AppState appState;
  final HealthLog? today;
  final HealthLog? latest;
  final VoidCallback onAddData;

  @override
  Widget build(BuildContext context) {
    final firstName = appState.profile.name.trim().isEmpty
        ? 'there'
        : appState.profile.name.trim().split(RegExp(r'\s+')).first;
    final hasToday = today != null;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.softShadow(opacity: 0.14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;

            final titleBlock = Column(
              crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.start,
              children: [
                Text(
                  'Good to see you, $firstName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasToday
                      ? 'Today\'s log is saved. Review your snapshot and keep your routine steady.'
                      : 'Add today\'s log to refresh your score, insight, and reminder plan.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.4,
                      ),
                ),
              ],
            );

            final status = _HeroStatusPill(
              hasToday: hasToday,
              latest: latest,
            );

            final action = FilledButton.icon(
              onPressed: onAddData,
              icon: const Icon(Icons.add_rounded),
              label: Text(hasToday ? 'Update today\'s log' : 'Add today\'s log'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 16),
                  status,
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: action),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 24),
                SizedBox(
                  width: 310,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      status,
                      const SizedBox(height: 12),
                      action,
                    ],
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

class _HeroStatusPill extends StatelessWidget {
  const _HeroStatusPill({required this.hasToday, required this.latest});

  final bool hasToday;
  final HealthLog? latest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasToday ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasToday ? 'Today logged' : 'Today not logged',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  latest == null
                      ? 'No previous entries yet'
                      : 'Latest entry: ${_formatLongDate(latest!.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
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

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({required this.today, required this.latest, required this.todayScore});

  final HealthLog? today;
  final HealthLog? latest;
  final int todayScore;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final scorePanel = _ScorePanel(
            score: todayScore,
            hasToday: today != null,
          );
          final metrics = _MetricsGrid(today: today);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                icon: Icons.monitor_heart_rounded,
                title: 'Today\'s health overview',
                subtitle: today == null
                    ? latest == null
                        ? 'No daily log has been added yet.'
                        : 'No log for today. Your latest saved entry is from ${_formatLongDate(latest!.date)}.'
                    : 'Updated from today\'s saved health log.',
              ),
              const SizedBox(height: 18),
              if (compact) ...[
                scorePanel,
                const SizedBox(height: 14),
                metrics,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 300, child: scorePanel),
                    const SizedBox(width: 16),
                    Expanded(child: metrics),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.score, required this.hasToday});

  final int score;
  final bool hasToday;

  @override
  Widget build(BuildContext context) {
    final statusTitle = hasToday ? _scoreLabel(score) : 'Waiting for today\'s log';
    final statusSubtitle = hasToday
        ? 'Your score is based on today\'s saved health log.'
        : 'Add today\'s log to calculate your current score.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasToday ? AppTheme.accentMint : AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: hasToday ? AppTheme.primaryTeal.withValues(alpha: 0.24) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          _ScoreBadge(score: score, hasToday: hasToday),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  statusSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.hasToday});

  final int score;
  final bool hasToday;

  @override
  Widget build(BuildContext context) {
    final color = hasToday ? AppTheme.primaryTeal : AppTheme.textMuted;

    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.22), width: 6),
        boxShadow: AppTheme.softShadow(opacity: 0.06),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Score',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.today});

  final HealthLog? today;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        icon: Icons.bedtime_rounded,
        label: 'Sleep',
        value: today == null ? '-' : '${today!.sleepHours.toStringAsFixed(1)} h',
      ),
      _MetricData(
        icon: Icons.water_drop_rounded,
        label: 'Hydration',
        value: today == null ? '-' : '${today!.waterGlasses} glasses',
      ),
      _MetricData(
        icon: Icons.self_improvement_rounded,
        label: 'Stress',
        value: today == null ? '-' : '${today!.stressLevel}/10',
      ),
      _MetricData(
        icon: Icons.directions_run_rounded,
        label: 'Exercise',
        value: today == null ? '-' : '${today!.exerciseMinutes} min',
      ),
      _MetricData(
        icon: Icons.sentiment_satisfied_alt_rounded,
        label: 'Mood',
        value: today?.mood ?? '-',
      ),
      _MetricData(
        icon: Icons.restaurant_rounded,
        label: 'Food',
        value: today?.foodQuality ?? '-',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;
        const gap = 10.0;
        final tileWidth = (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: tileWidth,
                  child: _MetricTile(data: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: AppTheme.primaryBlue, size: 21),
          const Spacer(),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 3),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({required this.appState, required this.latest, required this.today});

  final AppState appState;
  final HealthLog? latest;
  final HealthLog? today;

  @override
  Widget build(BuildContext context) {
    final insight = appState.personalizedInsight.trim();
    final cleanInsight = insight.isEmpty ? 'Add daily logs to generate a more useful personal insight.' : insight;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'Personal insight',
            subtitle: 'Based on your recent saved activity.',
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              cleanInsight,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.45,
                  ),
            ),
          ),
          if (latest != null && today == null) ...[
            const SizedBox(height: 12),
            _SmallNote(
              text: 'Using latest saved entry from ${_formatLongDate(latest!.date)}. Add today\'s log for a current view.',
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: _SectionHeader(
                  icon: Icons.alarm_rounded,
                  title: 'Health reminders',
                  subtitle: 'Manage routine nudges in one place.',
                ),
              ),
              TextButton.icon(
                onPressed: () => _editReminderTimes(context, appState),
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Times'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ReminderToggleRow(
            label: 'Hydration',
            time: appState.reminderSchedule.hydration.format(context),
            icon: Icons.water_drop_rounded,
            value: appState.reminderPreferences.hydration,
            onChanged: (value) {
              appState.setReminderPreferences(appState.reminderPreferences.copyWith(hydration: value));
            },
          ),
          _ReminderToggleRow(
            label: 'Sleep',
            time: appState.reminderSchedule.sleep.format(context),
            icon: Icons.bedtime_rounded,
            value: appState.reminderPreferences.sleep,
            onChanged: (value) {
              appState.setReminderPreferences(appState.reminderPreferences.copyWith(sleep: value));
            },
          ),
          _ReminderToggleRow(
            label: 'Daily log',
            time: appState.reminderSchedule.dailyLog.format(context),
            icon: Icons.edit_note_rounded,
            value: appState.reminderPreferences.dailyLog,
            onChanged: (value) {
              appState.setReminderPreferences(appState.reminderPreferences.copyWith(dailyLog: value));
            },
          ),
          _ReminderToggleRow(
            label: 'Stress break',
            time: appState.reminderSchedule.stressBreak.format(context),
            icon: Icons.spa_rounded,
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
              final picked = await showTimePicker(context: context, initialTime: initial);
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, draft), child: const Text('Save')),
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
}

class _ReminderToggleRow extends StatelessWidget {
  const _ReminderToggleRow({
    required this.label,
    required this.time,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String time;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 21),
          ),
          title: Text(label, style: Theme.of(context).textTheme.titleSmall),
          subtitle: Text(time),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RiskFlagsPanel extends StatelessWidget {
  const _RiskFlagsPanel({required this.latest});

  final HealthLog latest;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.warning_amber_rounded,
            title: 'Recent flags',
            subtitle: 'Items noticed in your latest saved log.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: latest.riskFlags.map((item) => RiskBadge(text: item)).toList(),
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.accentMint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppTheme.primaryTeal, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallNote extends StatelessWidget {
  const _SmallNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
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

String _scoreLabel(int score) {
  if (score >= 85) return 'Excellent';
  if (score >= 70) return 'Stable';
  if (score >= 50) return 'Needs attention';
  if (score > 0) return 'Low today';
  return 'Not logged';
}

String _formatLongDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  return '${date.day} $month ${date.year}';
}
