import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

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
    final lower = symptoms.map((s) => s.toLowerCase().trim()).toList();
    return lower.any(
      (symptom) =>
          symptom == 'fever' ||
          symptom == 'trouble breathing' ||
          symptom == 'chest pain' ||
          symptom == 'severe bleeding' ||
          symptom == 'seizure',
    );
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
      date: _dateFromValue(map['date']),
      sleepHours: _doubleFromValue(map['sleepHours']),
      waterGlasses: _intFromValue(map['waterGlasses']),
      stressLevel: _intFromValue(map['stressLevel']),
      mood: _stringFromValue(map['mood'], fallback: 'Neutral'),
      exerciseMinutes: _intFromValue(map['exerciseMinutes']),
      symptoms: _stringListFromValue(map['symptoms']),
      foodQuality: _stringFromValue(map['foodQuality'], fallback: 'Balanced'),
      weight: _doubleFromValue(map['weight']),
      notes: _stringFromValue(map['notes']),
      healthScore: _intFromValue(map['healthScore']),
      riskFlags: _stringListFromValue(map['riskFlags']),
      insight: _stringFromValue(map['insight']),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HealthLog.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return HealthLog.fromMap(decoded);
    }
    if (decoded is Map) {
      return HealthLog.fromMap(Map<String, dynamic>.from(decoded));
    }
    throw const FormatException('Invalid health log JSON');
  }

  static DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static double _doubleFromValue(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static int _intFromValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static String _stringFromValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  static List<String> _stringListFromValue(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return <String>[];
  }
}
