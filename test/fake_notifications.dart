// A stand-in for the OS's local notifications, which don't exist in tests (see
// flutter_test_config.dart, which installs it): it does nothing but remember what's scheduled.
// It's the Android implementation because tests run as Android, for which the plugin insists on
// one.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class FakeNotifications extends AndroidFlutterLocalNotificationsPlugin {
  /// The notifications currently scheduled, by id.
  final Map<int, ({String? body, tz.TZDateTime scheduledDate, String? payload})> scheduled = {};

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async =>
      const NotificationAppLaunchDetails(false);

  @override
  Future<bool?> requestNotificationsPermission() async => true;

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    AndroidNotificationDetails? notificationDetails,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exact,
  }) async {
    scheduled[id] = (body: body, scheduledDate: scheduledDate, payload: payload);
  }

  @override
  Future<void> cancelAll() async => scheduled.clear();
}

/// The one installed for every test.
final fakeNotifications = FakeNotifications();
