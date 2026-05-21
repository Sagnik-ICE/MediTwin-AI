import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/glass_card.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Insights')),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final logs = appState.logs.take(7).toList().reversed.toList();
          if (logs.isEmpty) {
            return const Center(child: Text('Add a few health logs to see insights here.'));
          }

          final score = _adherenceScore(logs);
          final sleepAvg = logs.map((e) => e.sleepHours).reduce((a, b) => a + b) / logs.length;
          final stressAvg = logs.map((e) => e.stressLevel).reduce((a, b) => a + b) / logs.length;
          final exerciseAvg = logs.map((e) => e.exerciseMinutes).reduce((a, b) => a + b) / logs.length;
          final waterAvg = logs.map((e) => e.waterGlasses).reduce((a, b) => a + b) / logs.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Health insights', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _metricTile(context, 'Health score', '${score.toStringAsFixed(0)}%'),
                        _metricTile(context, 'Sleep avg', '${sleepAvg.toStringAsFixed(1)} h'),
                        _metricTile(context, 'Stress avg', '${stressAvg.toStringAsFixed(1)}/10'),
                        _metricTile(context, 'Water avg', '${waterAvg.toStringAsFixed(1)} glasses'),
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
                    Text('What to focus on', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Exercise: ${exerciseAvg.toStringAsFixed(0)} min')),
                        Chip(label: Text(_insightLine(sleepAvg, stressAvg))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _chartCard(context, '7-day score trend', _spots(logs.map((e) => e.healthScore.toDouble()).toList())),
              const SizedBox(height: 14),
              _barChartCard(context, 'Daily behavior mix', logs),
              const SizedBox(height: 14),
              _radarCard(context, 'Wellness balance', sleepAvg, waterAvg, stressAvg, exerciseAvg),
            ],
          );
        },
      ),
    );
  }

  Widget _metricTile(BuildContext context, String title, String value) {
    return SizedBox(
      width: 160,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
      ),
    );
  }

  Widget _chartCard(BuildContext context, String title, List<FlSpot> spots) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).dividerColor.withValues(alpha: 0.10), strokeWidth: 1),
                  ),
                  lineTouchData: LineTouchData(enabled: true),
                  minY: 0,
                  maxY: 100,
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 4,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barChartCard(BuildContext context, String title, List<dynamic> logs) {
    final bars = logs.asMap().entries.map((entry) {
      final idx = entry.key.toDouble();
      final log = entry.value;
      final score = log.healthScore.toDouble();
      return BarChartGroupData(
        x: idx.toInt(),
        barRods: [
          BarChartRodData(toY: score, width: 12, borderRadius: BorderRadius.circular(6), color: Theme.of(context).colorScheme.secondary),
        ],
      );
    }).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: bars,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radarCard(BuildContext context, String title, double sleepAvg, double waterAvg, double stressAvg, double exerciseAvg) {
    final sleep = (sleepAvg / 8).clamp(0.0, 1.0) * 100;
    final water = (waterAvg / 8).clamp(0.0, 1.0) * 100;
    final stress = ((10 - stressAvg) / 10).clamp(0.0, 1.0) * 100;
    final exercise = (exerciseAvg / 45).clamp(0.0, 1.0) * 100;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                radarTouchData: RadarTouchData(enabled: true),
                dataSets: [
                  RadarDataSet(
                    fillColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
                    borderColor: Theme.of(context).colorScheme.primary,
                    entryRadius: 2,
                    dataEntries: [
                      RadarEntry(value: sleep),
                      RadarEntry(value: water),
                      RadarEntry(value: stress),
                      RadarEntry(value: exercise),
                    ],
                  ),
                ],
                tickCount: 4,
                radarBorderData: const BorderSide(color: Colors.transparent),
                gridBorderData: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
                titleTextStyle: Theme.of(context).textTheme.labelMedium!,
                getTitle: (index, angle) {
                  const labels = ['Sleep', 'Water', 'Stress', 'Exercise'];
                  return RadarChartTitle(text: labels[index], angle: angle);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _spots(List<double> values) {
    return values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
  }



  String _insightLine(double sleepAvg, double stressAvg) {
    if (sleepAvg < 7) {
      return 'Sleep is the main improvement area right now.';
    }
    if (stressAvg > 6) {
      return 'Stress looks elevated. A shorter routine and more breaks may help.';
    }
    return 'Your recent pattern looks steady. Keep the current routine going.';
  }

  double _adherenceScore(List<dynamic> logs) {
    if (logs.isEmpty) {
      return 0;
    }

    double total = 0;
    for (final log in logs) {
      final sleep = log.sleepHours >= 7 ? 1.0 : (log.sleepHours / 7).clamp(0.0, 1.0);
      final water = (log.waterGlasses / 8).clamp(0.0, 1.0);
      final exercise = (log.exerciseMinutes / 30).clamp(0.0, 1.0);
      final stress = ((10 - log.stressLevel) / 10).clamp(0.0, 1.0);
      total += (sleep + water + exercise + stress) / 4;
    }

    return (total / logs.length) * 100;
  }
}
