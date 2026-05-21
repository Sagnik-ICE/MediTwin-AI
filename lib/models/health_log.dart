import 'dart:convert';

class HealthLog {
  HealthLog({
    required this.date,
    required this.sleepHours,
    required this.waterGlasses,
    required this.stressLevel,
    required this.mood,
    required this.exerciseMinutes,
    required this.symptoms,
    required this.foodQuality,
    required this.weight,
    required this.notes,
    required this.healthScore,
    required this.riskFlags,
    required this.insight,
  });

  final DateTime date;
  final double sleepHours;
  final int waterGlasses;
  final int stressLevel;
  final String mood;
  final int exerciseMinutes;
  final List<String> symptoms;
  final String foodQuality;
  final double weight;
  final String notes;
  final int healthScore;
  final List<String> riskFlags;
  final String insight;

  bool get hasSevereSymptoms {
    final lower = symptoms.map((s) => s.toLowerCase()).toList();
    return lower.contains('fever') || lower.contains('trouble breathing');
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'sleepHours': sleepHours,
      'waterGlasses': waterGlasses,
      'stressLevel': stressLevel,
      'mood': mood,
      'exerciseMinutes': exerciseMinutes,
      'symptoms': symptoms,
      'foodQuality': foodQuality,
      'weight': weight,
      'notes': notes,
      'healthScore': healthScore,
      'riskFlags': riskFlags,
      'insight': insight,
    };
  }

  factory HealthLog.fromMap(Map<String, dynamic> map) {
    return HealthLog(
      date: DateTime.parse(map['date'] as String),
      sleepHours: (map['sleepHours'] as num).toDouble(),
      waterGlasses: map['waterGlasses'] as int,
      stressLevel: map['stressLevel'] as int,
      mood: map['mood'] as String,
      exerciseMinutes: map['exerciseMinutes'] as int,
      symptoms: List<String>.from(map['symptoms'] as List<dynamic>),
      foodQuality: map['foodQuality'] as String,
      weight: (map['weight'] as num).toDouble(),
      notes: map['notes'] as String,
      healthScore: map['healthScore'] as int,
      riskFlags: List<String>.from(map['riskFlags'] as List<dynamic>),
      insight: map['insight'] as String,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HealthLog.fromJson(String source) =>
      HealthLog.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
