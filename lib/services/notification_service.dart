import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/habit.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: initSettings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Per-habit nudges at their chosen times',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF7C4DFF),
    ),
  );

  /// Daily repeating reminder for one habit. Notification id = habit id,
  /// so each habit owns exactly one slot and can be cancelled alone.
  Future<void> scheduleHabitReminder(Habit habit) async {
    final id = habit.id;
    final minutes = habit.reminderMinutes;
    if (id == null) return;
    await _plugin.cancel(id: id);
    if (minutes == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    if (now.isAfter(scheduled)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: '${habit.identityName} is waiting ✨',
      body: 'One tap lights a star for #${habit.tagName}.',
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelHabitReminder(int habitId) =>
      _plugin.cancel(id: habitId);
}
