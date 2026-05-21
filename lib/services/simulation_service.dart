import '../models/health_log.dart';

class SimulationService {
  static Map<String, dynamic> simulate({
    required String scenario,
    required List<HealthLog> history,
  }) {
    final latest = history.isNotEmpty ? history.first : null;
    final baseline = latest?.healthScore ?? 65;
    final normalized = scenario.toLowerCase();

    int delta = 0;
    if (normalized.contains('sleep 5') || normalized.contains('less sleep')) {
      delta -= 14;
    }
    if (normalized.contains('drink more water') || normalized.contains('hydration')) {
      delta += 8;
    }
    if (normalized.contains('exercise')) {
      delta += 7;
    }
    if (normalized.contains('reduce stress')) {
      delta += 10;
    }
    if (normalized.contains('continue this lifestyle')) {
      delta -= 3;
    }

    final day7 = (baseline + (delta * 0.5)).round().clamp(0, 100);
    final day30 = (baseline + (delta * 0.8)).round().clamp(0, 100);
    final day90 = (baseline + delta).round().clamp(0, 100);

    final risks = <String>[];
    final suggestions = <String>[];

    if (day90 < 55) {
      risks.add('Possible risk of worsening fatigue and stress patterns.');
      suggestions.add('Consider consulting a doctor to review persistent symptoms.');
    }
    if (day90 >= 55 && day90 < 75) {
      risks.add('Possible moderate lifestyle risk if current trends continue.');
      suggestions.add('Prioritize sleep consistency and hydration goals this week.');
    }
    if (day90 >= 75) {
      suggestions.add('Your lifestyle adjustments may indicate improved wellness resilience.');
    }

    suggestions.add('This is not a medical diagnosis. Use this as preventive wellness guidance only.');

    return {
      'day7': day7,
      'day30': day30,
      'day90': day90,
      'risks': risks,
      'suggestions': suggestions,
    };
  }
}
