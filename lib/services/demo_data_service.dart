import '../models/chat_message.dart';
import '../models/health_log.dart';
import '../models/user_profile.dart';
import 'health_score_service.dart';
import 'risk_detection_service.dart';

class DemoDataService {
  static List<HealthLog> generateDemoLogs() {
    final now = DateTime.now();
    final seeds = <Map<String, dynamic>>[
      {
        'sleep': 5.5,
        'water': 4,
        'stress': 8,
        'mood': 'bad',
        'exercise': 5,
        'symptoms': ['Headache', 'Fatigue'],
        'food': 'poor',
        'weight': 77.0,
      },
      {
        'sleep': 6.0,
        'water': 5,
        'stress': 7,
        'mood': 'neutral',
        'exercise': 8,
        'symptoms': ['Headache'],
        'food': 'average',
        'weight': 77.2,
      },
      {
        'sleep': 6.2,
        'water': 6,
        'stress': 6,
        'mood': 'neutral',
        'exercise': 10,
        'symptoms': ['Fatigue'],
        'food': 'average',
        'weight': 77.3,
      },
      {
        'sleep': 6.8,
        'water': 7,
        'stress': 6,
        'mood': 'good',
        'exercise': 18,
        'symptoms': ['No symptoms'],
        'food': 'average',
        'weight': 77.1,
      },
      {
        'sleep': 7.1,
        'water': 8,
        'stress': 5,
        'mood': 'good',
        'exercise': 25,
        'symptoms': ['No symptoms'],
        'food': 'good',
        'weight': 76.8,
      },
      {
        'sleep': 7.3,
        'water': 8,
        'stress': 4,
        'mood': 'very good',
        'exercise': 35,
        'symptoms': ['No symptoms'],
        'food': 'good',
        'weight': 76.6,
      },
      {
        'sleep': 7.5,
        'water': 9,
        'stress': 4,
        'mood': 'very good',
        'exercise': 40,
        'symptoms': ['No symptoms'],
        'food': 'good',
        'weight': 76.4,
      },
    ];

    final result = <HealthLog>[];
    for (int i = 0; i < seeds.length; i++) {
      final seed = seeds[i];
      final score = HealthScoreService.calculateScore(
        sleepHours: seed['sleep'] as double,
        waterGlasses: seed['water'] as int,
        stressLevel: seed['stress'] as int,
        mood: seed['mood'] as String,
        exerciseMinutes: seed['exercise'] as int,
        symptoms: List<String>.from(seed['symptoms'] as List<dynamic>),
      );

      final baseLog = HealthLog(
        date: now.subtract(Duration(days: i)),
        sleepHours: seed['sleep'] as double,
        waterGlasses: seed['water'] as int,
        stressLevel: seed['stress'] as int,
        mood: seed['mood'] as String,
        exerciseMinutes: seed['exercise'] as int,
        symptoms: List<String>.from(seed['symptoms'] as List<dynamic>),
        foodQuality: seed['food'] as String,
        weight: seed['weight'] as double,
        notes: 'Demo entry for competition mode',
        healthScore: score,
        riskFlags: const [],
        insight: '',
      );

      final withRisk = HealthLog(
        date: baseLog.date,
        sleepHours: baseLog.sleepHours,
        waterGlasses: baseLog.waterGlasses,
        stressLevel: baseLog.stressLevel,
        mood: baseLog.mood,
        exerciseMinutes: baseLog.exerciseMinutes,
        symptoms: baseLog.symptoms,
        foodQuality: baseLog.foodQuality,
        weight: baseLog.weight,
        notes: baseLog.notes,
        healthScore: baseLog.healthScore,
        riskFlags: RiskDetectionService.detectRisks(baseLog, [baseLog, ...result]),
        insight: HealthScoreService.buildInsight(baseLog),
      );

      result.add(withRisk);
    }

    return result;
  }

  static List<ChatMessage> sampleChat() {
    return [
      ChatMessage(
        text: 'Hello! I am your preventive wellness assistant. This is not a medical diagnosis.',
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      ChatMessage(
        text: 'I keep getting headaches when I am stressed.',
        isUser: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
      ChatMessage(
        text: 'Your pattern may indicate stress-linked headaches and low hydration. Consider consulting a doctor if this continues.',
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    ];
  }

  static UserProfile profile() => UserProfile.empty();
}
