// Schedules the user's practice reminders (see state/reminders.dart) as OS-level local
// notifications for the next _daysToSchedule days, using flutter_local_notifications. Everything
// previously scheduled by this app is cleared and replaced from scratch each time
// refreshScheduledReminders() runs (at app startup -- see main.dart -- and whenever the reminders
// change).
//
// A reminder linked to a playlist deep-links to it: its notification's payload is the playlist's
// route, which the app opens when the notification is tapped (see notificationLaunchRoute() and
// onNotificationRoute).
//
// No-ops entirely on web: there's no meaningful way for a browser tab to deliver a notification
// while it isn't open, so scheduling anything there would be misleading. dart:io's Platform isn't
// used anywhere in this file for the same reason -- importing it at all would break web builds.

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../state/app_name.dart';
import '../state/reminders.dart';

const _daysToSchedule = 7;

const _androidChannelId = 'practice_reminders';
const _androidChannelName = 'Practice Reminders';
const _androidChannelDescription = "Reminders to practice your taiko drills";

final _plugin = FlutterLocalNotificationsPlugin();

bool _pluginInitialized = false;
bool _initialized = false;

/// Called with a tapped notification's route (e.g. `/playlists/<id>`) when it's tapped while the app
/// is running. (When a tap launches the app, see [notificationLaunchRoute] instead.)
void Function(String route)? onNotificationRoute;

/// The route of the notification whose tap launched the app, if it was launched that way.
Future<String?> notificationLaunchRoute() async {
  if (kIsWeb) return null;
  // Nothing could have been scheduled without a reminder, and initializing the plugin is a native
  // round-trip that'd hold up the app's first frame for nothing.
  if (reminders.entries.isEmpty) return null;
  try {
    await _ensurePluginInitialized();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  } catch (error, stackTrace) {
    debugPrint('notificationLaunchRoute failed: $error\n$stackTrace');
    return null;
  }
}

/// The route a reminder's notification opens when tapped, if any.
String? _reminderRoute(ReminderConfig reminder) =>
    reminder.playlistId == null ? null : '/playlists/${reminder.playlistId}';

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
          title: appName(),
          body: reminder.message,
          scheduledDate: scheduledDate,
          payload: _reminderRoute(reminder),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              channelDescription: _androidChannelDescription,
              // The app's pink, for the icon (and accents) wherever Android shows it in color.
              color: Color(0xFFF0457A),
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

  await _ensurePluginInitialized();

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

// Just the plugin itself, without asking for permission, which is all that's needed to find out
// whether a notification launched the app.
Future<void> _ensurePluginInitialized() async {
  if (_pluginInitialized) return;
  _pluginInitialized = true;

  // The status bar icon: Android draws notification icons as a single-color silhouette, so it's
  // the mitsudomoe in white (rendered by tool/generate_icons_test.dart), not the full-color app
  // icon. See also res/raw/keep.xml, which stops release builds from stripping it out.
  const androidSettings = AndroidInitializationSettings('ic_notification');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _plugin.initialize(
    settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    onDidReceiveNotificationResponse: (response) {
      final route = response.payload;
      if (route != null) onNotificationRoute?.call(route);
    },
  );
}
