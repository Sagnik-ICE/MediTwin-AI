import '../models/health_log.dart';

class RiskDetectionService {
  static List<String> detectRisks(HealthLog latestLog, List<HealthLog> logs) {
    final risks = <String>[];

    if (latestLog.sleepHours < 6 && latestLog.stressLevel >= 7) {
      risks.add('Elevated stress and fatigue risk');
    }

    final lowerSymptoms = latestLog.symptoms.map((s) => s.toLowerCase()).toList();
    if (latestLog.waterGlasses < 5 && lowerSymptoms.contains('headache')) {
      risks.add('Possible dehydration-related headache pattern');
    }

    final lowActivityStreak = logs.take(3).where((log) => log.exerciseMinutes < 10).length;
    if (lowActivityStreak >= 3) {
      risks.add('Low activity pattern');
    }

    if ((latestLog.mood == 'bad' || latestLog.mood == 'very bad') && latestLog.stressLevel >= 8) {
      risks.add('Possible emotional strain pattern');
    }

    final hasWeightIncrease = logs.length >= 2 && latestLog.weight > logs[1].weight;
    if (hasWeightIncrease && latestLog.exerciseMinutes < 10 && latestLog.foodQuality == 'poor') {
      risks.add('Possible metabolic lifestyle risk');
    }

    if (latestLog.hasSevereSymptoms) {
      risks.add('Symptoms may indicate elevated health risk. Seek urgent medical help if symptoms are severe.');
    }

    return risks;
  }
}
