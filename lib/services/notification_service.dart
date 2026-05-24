import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_preferences.dart';
import '../models/reminder_schedule.dart';
import '../utils/debug_logger.dart';

enum ReminderType {
  hydration,
  sleep,
  dailyLog,
  stressBreak,
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<bool> init() async {
    if (kIsWeb) {
      DebugLogger.debug('Local notifications are skipped on web.');
      return false;
    }

    if (_initialized) {
      return true;
    }

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      tzdata.initializeTimeZones();
      await _plugin.initialize(settings);

      await _requestPlatformPermissions();
      _initialized = true;
      return true;
    } catch (e, st) {
      DebugLogger.warning('Failed to initialize local notifications', e);
      DebugLogger.debug(st.toString());
      return false;
    }
  }

  Future<void> _requestPlatformPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleSimpleReminders() async {
    await showReminder(ReminderType.hydration);
  }

  Future<void> showReminder(ReminderType type) async {
    final ready = await init();
    if (!ready) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'meditwin_reminders',
        'MediTwin Reminders',
        channelDescription: 'Health, hydration, daily log, sleep, and stress break reminders.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      type.index + 1,
      _titleFor(type),
      _bodyFor(type),
      details,
    );
  }

  Future<void> scheduleDailyReminders({
    required ReminderPreferences preferences,
    required ReminderSchedule schedule,
  }) async {
    final ready = await init();
    if (!ready) return;

    await cancelAllReminderSchedules();

    if (preferences.hydration) {
      await _scheduleSingle(ReminderType.hydration, schedule.hydration);
    }
    if (preferences.sleep) {
      await _scheduleSingle(ReminderType.sleep, schedule.sleep);
    }
    if (preferences.dailyLog) {
      await _scheduleSingle(ReminderType.dailyLog, schedule.dailyLog);
    }
    if (preferences.stressBreak) {
      await _scheduleSingle(ReminderType.stressBreak, schedule.stressBreak);
    }
  }

  Future<void> cancelAllReminderSchedules() async {
    if (kIsWeb) return;

    await _plugin.cancel(_idFor(ReminderType.hydration));
    await _plugin.cancel(_idFor(ReminderType.sleep));
    await _plugin.cancel(_idFor(ReminderType.dailyLog));
    await _plugin.cancel(_idFor(ReminderType.stressBreak));
  }

  Future<void> _scheduleSingle(ReminderType type, TimeOfDay time) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'meditwin_reminders',
        'MediTwin Reminders',
        channelDescription: 'Health, hydration, daily log, sleep, and stress break reminders.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _idFor(type),
      _titleFor(type),
      _bodyFor(type),
      _nextInstanceOfTime(time.hour, time.minute),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  int _idFor(ReminderType type) {
    return type.index + 100;
  }

  String _titleFor(ReminderType type) {
    switch (type) {
      case ReminderType.hydration:
        return 'Drink Water Reminder';
      case ReminderType.sleep:
        return 'Sleep Rhythm Reminder';
      case ReminderType.dailyLog:
        return 'Daily Log Reminder';
      case ReminderType.stressBreak:
        return 'Stress Break Reminder';
    }
  }

  String _bodyFor(ReminderType type) {
    switch (type) {
      case ReminderType.hydration:
        return 'Time to drink water and maintain your wellness target.';
      case ReminderType.sleep:
        return 'Plan your sleep window for 7-9 hours of recovery.';
      case ReminderType.dailyLog:
        return 'Log today\'s health habits to update your digital twin.';
      case ReminderType.stressBreak:
        return 'Take a short breathing or stretching break.';
    }
  }
}
