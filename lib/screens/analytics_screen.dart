import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/health_log.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, _) {
            final logs = appState.logs;
            if (logs.isEmpty) {
              return const _EmptyAnalyticsState();
            }

            final recent = logs.take(7).toList().reversed.toList();
            final current = logs.first;
            final averages = _Averages.fromLogs(recent);
            final trend = _trendCopy(recent);
            final focusItems = _focusItems(averages, current);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
              children: [
                _HeroPanel(
                  current: current,
                  logCount: logs.length,
                  recentCount: recent.length,
                  trend: trend,
                ),
                const SizedBox(height: 18),
                _MetricGrid(averages: averages),
                const SizedBox(height: 18),
                _ScoreTrendCard(logs: recent),
                const SizedBox(height: 18),
                _HabitBalanceCard(averages: averages),
                const SizedBox(height: 18),
                _FocusCard(items: focusItems),
                const SizedBox(height: 18),
                _RecentLogsCard(logs: recent.reversed.toList()),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _trendCopy(List<HealthLog> logs) {
    if (logs.length < 2) return 'Add more logs to build a reliable trend.';
    final first = logs.first.healthScore;
    final last = logs.last.healthScore;
    final diff = last - first;
    if (diff >= 8) return 'Your score is improving across recent logs.';
    if (diff <= -8) return 'Your recent score is trending downward.';
    return 'Your recent score is fairly stable.';
  }

  static List<String> _focusItems(_Averages averages, HealthLog current) {
    final items = <String>[];
    if (averages.sleep < 7) {
      items.add('Sleep is below target. Aim for a consistent 7-8 hour schedule.');
    }
    if (averages.water < 7) {
      items.add('Hydration is slightly low. Add 1-2 glasses earlier in the day.');
    }
    if (averages.stress > 6) {
      items.add('Stress is elevated. Add short breaks or breathing sessions.');
    }
    if (averages.exercise < 20) {
      items.add('Activity is low. A 15-20 minute walk can improve the trend.');
    }
    if (current.riskFlags.isNotEmpty) {
      items.add('Review recent risk flags and avoid ignoring persistent symptoms.');
    }
    if (items.isEmpty) {
      items.add('Your recent pattern looks balanced. Keep logging daily to maintain accuracy.');
    }
    return items.take(3).toList();
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.current,
    required this.logCount,
    required this.recentCount,
    required this.trend,
  });

  final HealthLog current;
  final int logCount;
  final int recentCount;
  final String trend;

  @override
  Widget build(BuildContext context) {
    final score = current.healthScore.clamp(0, 100);
    final scoreLabel = score >= 80
        ? 'Strong'
        : score >= 60
            ? 'Moderate'
            : 'Needs attention';

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.softShadow(opacity: 0.14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final scorePanel = _HeroScore(score: score, label: scoreLabel);
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                ),
                child: Text(
                  'Last ${recentCount == 1 ? 'entry' : '$recentCount entries'} reviewed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Health Statistics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                trend,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroChip(icon: Icons.event_available_rounded, label: 'Latest: ${_formatDate(current.date)}'),
                  _HeroChip(icon: Icons.article_rounded, label: '$logCount total logs'),
                  if (current.riskFlags.isNotEmpty)
                    _HeroChip(icon: Icons.warning_amber_rounded, label: '${current.riskFlags.length} flag${current.riskFlags.length == 1 ? '' : 's'}'),
                ],
              ),
            ],
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 28),
                scorePanel,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: 20),
              scorePanel,
            ],
          );
        },
      ),
    );
  }
}

class _HeroScore extends StatelessWidget {
  const _HeroScore({required this.score, required this.label});

  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current score',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 5),
                child: Text(
                  '/100',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.averages});

  final _Averages averages;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        title: 'Avg score',
        value: averages.score.toStringAsFixed(0),
        suffix: '/100',
        icon: Icons.monitor_heart_rounded,
        tone: AppTheme.primaryBlue,
      ),
      _MetricData(
        title: 'Sleep',
        value: averages.sleep.toStringAsFixed(1),
        suffix: 'h',
        icon: Icons.bedtime_rounded,
        tone: const Color(0xFF4F46E5),
      ),
      _MetricData(
        title: 'Hydration',
        value: averages.water.toStringAsFixed(1),
        suffix: 'glasses',
        icon: Icons.water_drop_rounded,
        tone: const Color(0xFF0284C7),
      ),
      _MetricData(
        title: 'Stress',
        value: averages.stress.toStringAsFixed(1),
        suffix: '/10',
        icon: Icons.self_improvement_rounded,
        tone: AppTheme.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics.map((metric) => SizedBox(width: width, child: _MetricCard(data: metric))).toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: data.tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(data.icon, color: data.tone, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text: data.value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                    children: [
                      TextSpan(
                        text: ' ${data.suffix}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
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

class _ScoreTrendCard extends StatelessWidget {
  const _ScoreTrendCard({required this.logs});

  final List<HealthLog> logs;

  @override
  Widget build(BuildContext context) {
    final spots = logs.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.healthScore.toDouble());
    }).toList();

    return _SectionCard(
      icon: Icons.trending_up_rounded,
      title: 'Score trend',
      subtitle: 'Your health score across recent daily logs.',
      child: SizedBox(
        height: 230,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.border.withValues(alpha: 0.7),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 20,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= logs.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _shortDay(logs[index].date),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppTheme.primaryNavy,
                getTooltipItems: (items) => items.map((item) {
                  return LineTooltipItem(
                    '${item.y.toStringAsFixed(0)} / 100',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppTheme.primaryTeal,
                barWidth: 4,
                isStrokeCapRound: true,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryTeal.withValues(alpha: 0.22),
                      AppTheme.primaryTeal.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: AppTheme.surface,
                    strokeWidth: 3,
                    strokeColor: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitBalanceCard extends StatelessWidget {
  const _HabitBalanceCard({required this.averages});

  final _Averages averages;

  @override
  Widget build(BuildContext context) {
    final items = [
      _BalanceItem('Sleep quality', averages.sleep, 8, '${averages.sleep.toStringAsFixed(1)} h', Icons.bedtime_rounded),
      _BalanceItem('Hydration', averages.water, 8, '${averages.water.toStringAsFixed(1)} glasses', Icons.water_drop_rounded),
      _BalanceItem('Exercise', averages.exercise, 30, '${averages.exercise.toStringAsFixed(0)} min', Icons.directions_walk_rounded),
      _BalanceItem('Stress control', 10 - averages.stress, 10, '${averages.stress.toStringAsFixed(1)}/10 stress', Icons.spa_rounded),
    ];

    return _SectionCard(
      icon: Icons.dashboard_customize_rounded,
      title: 'Wellness balance',
      subtitle: 'A clean view of the habits influencing your score.',
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _BalanceRow(item: items[i]),
            if (i != items.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.item});

  final _BalanceItem item;

  @override
  Widget build(BuildContext context) {
    final ratio = _ratio(item.value, item.target);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.accentMint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(item.icon, color: AppTheme.primaryTeal, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: AppTheme.surfaceSoft,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.lightbulb_rounded,
      title: 'Recommended focus',
      subtitle: 'Based on your recent logged pattern.',
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.primaryTeal,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
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

class _RecentLogsCard extends StatelessWidget {
  const _RecentLogsCard({required this.logs});

  final List<HealthLog> logs;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.history_rounded,
      title: 'Recent logs',
      subtitle: 'A compact timeline of your latest entries.',
      child: Column(
        children: [
          for (int i = 0; i < logs.length; i++) ...[
            _RecentLogTile(log: logs[i]),
            if (i != logs.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _RecentLogTile extends StatelessWidget {
  const _RecentLogTile({required this.log});

  final HealthLog log;

  @override
  Widget build(BuildContext context) {
    final symptoms = log.symptoms.isEmpty ? 'No symptoms' : log.symptoms.take(2).join(', ');
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _scoreTone(log.healthScore).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            log.healthScore.toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _scoreTone(log.healthScore),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDate(log.date), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Sleep ${log.sleepHours.toStringAsFixed(1)}h • Water ${log.waterGlasses} • Stress ${log.stressLevel}/10',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(symptoms, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
      ],
    );
  }
}

class _EmptyAnalyticsState extends StatelessWidget {
  const _EmptyAnalyticsState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: AppTheme.softBrandGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppTheme.accentMint,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.analytics_rounded, color: AppTheme.primaryTeal, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                'Health Statistics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a few health logs to unlock trend charts, averages, and personalized wellness focus areas.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.accentMint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: AppTheme.primaryTeal, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(22)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.05),
      ),
      child: child,
    );
  }
}

class _Averages {
  const _Averages({
    required this.score,
    required this.sleep,
    required this.water,
    required this.stress,
    required this.exercise,
  });

  final double score;
  final double sleep;
  final double water;
  final double stress;
  final double exercise;

  factory _Averages.fromLogs(List<HealthLog> logs) {
    if (logs.isEmpty) {
      return const _Averages(score: 0, sleep: 0, water: 0, stress: 0, exercise: 0);
    }
    double score = 0;
    double sleep = 0;
    double water = 0;
    double stress = 0;
    double exercise = 0;
    for (final log in logs) {
      score += log.healthScore;
      sleep += log.sleepHours;
      water += log.waterGlasses;
      stress += log.stressLevel;
      exercise += log.exerciseMinutes;
    }
    final count = logs.length;
    return _Averages(
      score: score / count,
      sleep: sleep / count,
      water: water / count,
      stress: stress / count,
      exercise: exercise / count,
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String value;
  final String suffix;
  final IconData icon;
  final Color tone;
}

class _BalanceItem {
  const _BalanceItem(this.title, this.value, this.target, this.label, this.icon);

  final String title;
  final double value;
  final double target;
  final String label;
  final IconData icon;
}

double _ratio(double value, double target) {
  if (target <= 0) return 0;
  return (value / target).clamp(0.0, 1.0);
}

Color _scoreTone(int score) {
  if (score >= 80) return AppTheme.success;
  if (score >= 60) return AppTheme.warning;
  return AppTheme.danger;
}

String _formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _shortDay(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[date.weekday - 1];
}
