// Run by flutter_test before every test file in this directory (see
// https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html).

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_notifications.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // There's no native side to the app's plugins in tests: stand in for the ones that reminder
  // scheduling (services/reminder_scheduler.dart) uses, which would otherwise fail.
  FlutterLocalNotificationsPlatform.instance = fakeNotifications;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter_timezone'),
    (call) async => call.method == 'getLocalTimezone' ? 'UTC' : null,
  );
  await testMain();
}
