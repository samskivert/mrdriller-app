// Schedules the user's practice reminders (see state/reminders.dart) as OS-level local
// notifications for the next _daysToSchedule days, using flutter_local_notifications. Everything
// previously scheduled by this app is cleared and replaced from scratch each time
// refreshScheduledReminders() runs (currently just once, at app startup -- see main.dart).
//
// No-ops entirely on web: there's no meaningful way for a browser tab to deliver a notification
// while it isn't open, so scheduling anything there would be misleading. dart:io's Platform isn't
// used anywhere in this file for the same reason -- importing it at all would break web builds.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../state/reminders.dart';

const _daysToSchedule = 7;

const _androidChannelId = 'practice_reminders';
const _androidChannelName = 'Practice Reminders';
const _androidChannelDescription = "Reminders to practice with Mr. Driller";

final _plugin = FlutterLocalNotificationsPlugin();

bool _initialized = false;

/// Cancels every notification this app has previously scheduled and schedules fresh ones for the
/// next [_daysToSchedule] days, based on the user's current reminder configuration. Safe to call
/// even if nothing has changed -- it always starts from a clean slate. Failures (e.g. permission
/// denied, an unsupported platform) are swallowed rather than thrown, since reminders are a
/// nice-to-have that shouldn't be able to prevent the app from starting up.
Future<void> refreshScheduledReminders() async {
  if (kIsWeb) return;
  // Skip entirely (including the permission prompt) until the user has actually configured a
  // reminder -- there's nothing to schedule yet, so asking now would be out of context. Once
  // we've initialized at least once, though, keep going even if the list is now empty (e.g. the
  // user just deleted their last reminder): there may be stale notifications to cancel.
  if (reminders.entries.isEmpty && !_initialized) return;
  try {
    await _ensureInitialized();
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var notificationId = 0;
    for (final reminder in reminders.entries) {
      for (var offset = 0; offset < _daysToSchedule; offset++) {
        final day = now.add(Duration(days: offset));
        if (!reminder.days.contains(day.weekday)) continue;
        final scheduledDate = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          reminder.hour,
          reminder.minute,
        );
        // Only offset==0 can land in the past (today, at an hour/minute already gone by).
        if (!scheduledDate.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: notificationId++,
          title: 'Mr. Driller',
          body: reminder.message,
          scheduledDate: scheduledDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              channelDescription: _androidChannelDescription,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  } catch (error, stackTrace) {
    debugPrint('refreshScheduledReminders failed: $error\n$stackTrace');
  }
}

Future<void> _ensureInitialized() async {
  if (_initialized) return;
  _initialized = true;

  tz.initializeTimeZones();
  final timeZone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZone.identifier));

  const androidSettings = AndroidInitializationSettings('launcher_icon');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _plugin.initialize(
    settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
}
