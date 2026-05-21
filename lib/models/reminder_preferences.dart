class ReminderPreferences {
  const ReminderPreferences({
    required this.hydration,
    required this.sleep,
    required this.dailyLog,
    required this.stressBreak,
  });

  final bool hydration;
  final bool sleep;
  final bool dailyLog;
  final bool stressBreak;

  factory ReminderPreferences.defaults() => const ReminderPreferences(
        hydration: true,
        sleep: true,
        dailyLog: true,
        stressBreak: true,
      );

  ReminderPreferences copyWith({
    bool? hydration,
    bool? sleep,
    bool? dailyLog,
    bool? stressBreak,
  }) {
    return ReminderPreferences(
      hydration: hydration ?? this.hydration,
      sleep: sleep ?? this.sleep,
      dailyLog: dailyLog ?? this.dailyLog,
      stressBreak: stressBreak ?? this.stressBreak,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hydration': hydration,
      'sleep': sleep,
      'dailyLog': dailyLog,
      'stressBreak': stressBreak,
    };
  }

  factory ReminderPreferences.fromMap(Map<String, dynamic> map) {
    return ReminderPreferences(
      hydration: (map['hydration'] as bool?) ?? true,
      sleep: (map['sleep'] as bool?) ?? true,
      dailyLog: (map['dailyLog'] as bool?) ?? true,
      stressBreak: (map['stressBreak'] as bool?) ?? true,
    );
  }
}
