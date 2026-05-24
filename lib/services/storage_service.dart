import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder_preferences.dart';
import '../models/reminder_schedule.dart';

class StorageService {
  static const String defaultApiUrl = 'http://127.0.0.1:11434/api/chat';

  static const _themeModeKey = 'dark_mode';
  static const _apiUrlKey = 'api_url';
  static const _reminderPrefsKey = 'reminder_prefs';
  static const _reminderScheduleKey = 'reminder_schedule';

  Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeModeKey, enabled);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeModeKey) ?? false;
  }

  Future<void> setApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = url.trim();
    if (normalized.isEmpty || normalized == defaultApiUrl) {
      await prefs.remove(_apiUrlKey);
      return;
    }
    await prefs.setString(_apiUrlKey, normalized);
  }

  Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_apiUrlKey)?.trim();
    if (saved == null || saved.isEmpty) {
      return defaultApiUrl;
    }
    return saved;
  }

  Future<void> saveReminderPreferences(ReminderPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderPrefsKey, jsonEncode(preferences.toMap()));
  }

  Future<ReminderPreferences> loadReminderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reminderPrefsKey);
    if (raw == null) {
      return ReminderPreferences.defaults();
    }

    return ReminderPreferences.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveReminderSchedule(ReminderSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderScheduleKey, jsonEncode(schedule.toMap()));
  }

  Future<ReminderSchedule> loadReminderSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reminderScheduleKey);
    if (raw == null) {
      return ReminderSchedule.defaults();
    }

    return ReminderSchedule.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }
}
