// The running app's own version (from pubspec.yaml), loaded once at startup for display in the UI
// (e.g. the main menu's footer) -- see main.dart.

import 'package:package_info_plus/package_info_plus.dart';

String appVersion = '';

Future<void> loadAppInfo() async {
  final info = await PackageInfo.fromPlatform();
  appVersion = displayVersion(info.version);
}

/// [version] as users see it: without a zero patch, so 1.1.0 is 1.1 (and 1.1.1 stays 1.1.1). The
/// release scripts (appstore-publish.sh, deploy-web.sh) build with that already, but other builds
/// (`flutter run`, say) have pubspec.yaml's version, which Flutter requires to be major.minor.patch.
String displayVersion(String version) =>
    version.replaceFirstMapped(RegExp(r'^(\d+\.\d+)\.0$'), (m) => m[1]!);
