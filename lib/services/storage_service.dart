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
    // The app uses automatic local Ollama. Keep this method only for backward
    // compatibility with older screens/services and clear any old manual value.
    await prefs.remove(_apiUrlKey);
  }

  Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear any endpoint saved by older builds so the app always returns to
    // automatic local Ollama.
    await prefs.remove(_apiUrlKey);
    return defaultApiUrl;
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
