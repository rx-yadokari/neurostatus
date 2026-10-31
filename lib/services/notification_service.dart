import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_alarm_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _hourKey = 'notif_hour';
  static const _minuteKey = 'notif_minute';
  static const int _reminderNotificationId = 0;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_hourKey) ?? 20;
    final minute = prefs.getInt(_minuteKey) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);
    await ReminderAlarmService.instance.scheduleDaily(time);
  }

  /// Re-arms the daily background check (idempotent — safe to call on every
  /// app start) and clears any leftover reminder notification, including one
  /// left over from the previous (statically-scheduled) version of the app.
  Future<void> ensureScheduled() async {
    await _plugin.cancel(_reminderNotificationId);
    final time = await getReminderTime();
    await ReminderAlarmService.instance.scheduleDaily(time);
  }

  /// Shows the reminder immediately. Called from the background alarm
  /// callback only when today has no entry yet.
  Future<void> showReminderNow() async {
    await init();
    await _plugin.show(
      _reminderNotificationId,
      'Comment tu te sens aujourd\'hui ?',
      'Prends une minute pour noter ton état émotionnel.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Rappel quotidien',
          channelDescription:
              'Rappel quotidien pour noter son état émotionnel',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
