import '../models/health_log.dart';

class HealthScoreService {
  static int calculateScore({
    required double sleepHours,
    required int waterGlasses,
    required int stressLevel,
    required int exerciseMinutes,
    required String mood,
    required List<String> symptoms,
  }) {
    int score = 0;

    score += _sleepScore(sleepHours);
    score += _hydrationScore(waterGlasses);
    score += _stressScore(stressLevel);
    score += _exerciseScore(exerciseMinutes);
    score += _moodScore(mood);
    score += _symptomScore(symptoms);

    return score.clamp(0, 100);
  }

  static int _sleepScore(double sleepHours) {
    if (sleepHours >= 7 && sleepHours <= 9) {
      return 25;
    }
    if ((sleepHours >= 6 && sleepHours < 7) || (sleepHours > 9 && sleepHours <= 10)) {
      return 16;
    }
    if (sleepHours < 5 || sleepHours > 10) {
      return 6;
    }
    return 12;
  }

  static int _hydrationScore(int glasses) {
    if (glasses >= 8) {
      return 20;
    }
    if (glasses >= 5) {
      return 12;
    }
    return 5;
  }

  static int _stressScore(int stress) {
    if (stress >= 1 && stress <= 3) {
      return 20;
    }
    if (stress >= 4 && stress <= 6) {
      return 12;
    }
    return 5;
  }

  static int _exerciseScore(int minutes) {
    if (minutes >= 30) {
      return 15;
    }
    if (minutes >= 10) {
      return 9;
    }
    return 4;
  }

  static int _moodScore(String mood) {
    final normalized = mood.toLowerCase();
    if (normalized == 'very good' || normalized == 'good') {
      return 10;
    }
    if (normalized == 'neutral') {
      return 6;
    }
    return 3;
  }

  static int _symptomScore(List<String> symptoms) {
    if (symptoms.isEmpty || symptoms.contains('No symptoms')) {
      return 10;
    }

    final lower = symptoms.map((e) => e.toLowerCase()).toList();
    const severe = {'trouble breathing', 'fainting', 'severe bleeding', 'seizure', 'fever'};

    if (lower.any(severe.contains)) {
      return 2;
    }
    return 6;
  }

  static String buildInsight(HealthLog log) {
    if (log.healthScore >= 80) {
      return 'Your recent habits look balanced. Keep this routine to sustain your wellness.';
    }
    if (log.healthScore >= 60) {
      return 'Your score may indicate moderate wellness. Improving sleep or hydration could help.';
    }
    return 'Your patterns may indicate increased lifestyle strain. Consider consulting a doctor if symptoms persist.';
  }
}
