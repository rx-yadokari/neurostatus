import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';

import '../data/database.dart';
import 'notification_service.dart';

const _alarmId = 1000;

/// Runs once a day in a background isolate (no app needed in the foreground)
/// to decide whether today's reminder notification is still relevant: if an
/// entry already exists for today, it's skipped instead of shown.
@pragma('vm:entry-point')
void reminderAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  final existing = await AppDatabase.instance.entriesForDate(DateTime.now());
  if (existing.isNotEmpty) return;
  await NotificationService.instance.showReminderNow();
}

class ReminderAlarmService {
  ReminderAlarmService._();
  static final ReminderAlarmService instance = ReminderAlarmService._();

  Future<void> init() async {
    await AndroidAlarmManager.initialize();
  }

  /// Registers (or replaces) a 24h-periodic background check starting at the
  /// next occurrence of [time]. Kept inexact/wakeup, matching the precision
  /// the previous scheduled-notification approach already used.
  Future<void> scheduleDaily(TimeOfDay time) async {
    final now = DateTime.now();
    var start = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (start.isBefore(now)) {
      start = start.add(const Duration(days: 1));
    }
    await AndroidAlarmManager.periodic(
      const Duration(hours: 24),
      _alarmId,
      reminderAlarmCallback,
      startAt: start,
      exact: false,
      wakeup: true,
      // The reboot-rescheduling receiver crashes on release builds (its
      // manifest-declared component name doesn't survive R8 shrinking). Not
      // needed anyway: ensureScheduled() re-arms this on every app start.
      rescheduleOnReboot: false,
    );
  }

  Future<void> cancel() => AndroidAlarmManager.cancel(_alarmId);
}
