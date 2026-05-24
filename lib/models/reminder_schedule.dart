import 'package:flutter/material.dart';

class ReminderSchedule {
  const ReminderSchedule({
    required this.hydration,
    required this.sleep,
    required this.dailyLog,
    required this.stressBreak,
  });

  final TimeOfDay hydration;
  final TimeOfDay sleep;
  final TimeOfDay dailyLog;
  final TimeOfDay stressBreak;

  factory ReminderSchedule.defaults() => const ReminderSchedule(
        hydration: TimeOfDay(hour: 10, minute: 0),
        sleep: TimeOfDay(hour: 22, minute: 0),
        dailyLog: TimeOfDay(hour: 20, minute: 30),
        stressBreak: TimeOfDay(hour: 15, minute: 0),
      );

  ReminderSchedule copyWith({
    TimeOfDay? hydration,
    TimeOfDay? sleep,
    TimeOfDay? dailyLog,
    TimeOfDay? stressBreak,
  }) {
    return ReminderSchedule(
      hydration: hydration ?? this.hydration,
      sleep: sleep ?? this.sleep,
      dailyLog: dailyLog ?? this.dailyLog,
      stressBreak: stressBreak ?? this.stressBreak,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hydration': _format(hydration),
      'sleep': _format(sleep),
      'dailyLog': _format(dailyLog),
      'stressBreak': _format(stressBreak),
    };
  }

  factory ReminderSchedule.fromMap(Map<String, dynamic> map) {
    return ReminderSchedule(
      hydration: _parse((map['hydration'] as String?) ?? '10:00'),
      sleep: _parse((map['sleep'] as String?) ?? '22:00'),
      dailyLog: _parse((map['dailyLog'] as String?) ?? '20:30'),
      stressBreak: _parse((map['stressBreak'] as String?) ?? '15:00'),
    );
  }

  static String _format(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static TimeOfDay _parse(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return const TimeOfDay(hour: 9, minute: 0);
    }

    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }
}
