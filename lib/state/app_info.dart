// The running app's own version (from pubspec.yaml), loaded once at startup for display in the UI
// (e.g. the main menu's footer) -- see main.dart.

import 'package:package_info_plus/package_info_plus.dart';

String appVersion = '';

Future<void> loadAppInfo() async {
  final info = await PackageInfo.fromPlatform();
  appVersion = info.version;
}
