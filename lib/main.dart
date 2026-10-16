import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'data/drills.dart' as data;
import 'screens/drill_menu_screen.dart';
import 'screens/drill_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/pattern_trainer_screen.dart';
import 'screens/practice_plan_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/unknown_screen.dart';
import 'services/reminder_scheduler.dart';
import 'services/screen_cutout.dart';
import 'state/app_info.dart';
import 'state/app_name.dart';
import 'state/practice_log.dart';
import 'state/practice_plan.dart';
import 'state/reminders.dart';
import 'state/settings.dart';
import 'util/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await settings.load();
  await practicePlan.load();
  await practiceLog.load();
  await reminders.load();
  await loadAppInfo();
  await loadAppName();
  initScreenCutout();
  // Not awaited -- this involves a native plugin round-trip and (on iOS/Android) a permission
  // prompt, neither of which should delay the app's first frame.
  unawaited(refreshScheduledReminders());
  runApp(const TaikoTrainerApp());
}

class TaikoTrainerApp extends StatelessWidget {
  const TaikoTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilt if the app's name changes (see app_name.dart), for the window/tab title.
    return ListenableBuilder(listenable: mrDrillerUnlocked, builder: (context, _) => _app());
  }

  Widget _app() {
    return MaterialApp(
      title: appName(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E63DD)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        // Bundled (see assets/fonts), including the app's Japanese glyphs, so that web doesn't
        // have to lazily download a fallback font for them (showing tofu until it arrives).
        fontFamily: AppFonts.body,
      ),
      initialRoute: '/',
      onGenerateRoute: _onGenerateRoute,
      onGenerateInitialRoutes: _onGenerateInitialRoutes,
      onUnknownRoute: _unknownRoute,
    );
  }
}

Route<dynamic> _unknownRoute(RouteSettings settings) => MaterialPageRoute(
  settings: settings,
  builder: (_) => UnknownScreen(path: settings.name ?? ''),
);

// The back stack for a deep link the app is launched with (e.g. /drills/paradiddle): the menu,
// then each prefix of the path that's a route of its own (/drills), then the route itself. Unlike
// Flutter's default (which quietly falls back to just the menu), a link to something that doesn't
// exist (e.g. a mistyped drill) ends on the unknown page, saying so.
List<Route<dynamic>> _onGenerateInitialRoutes(String initialRoute) {
  final routes = [_onGenerateRoute(const RouteSettings(name: '/'))!];
  final segments = Uri.parse(initialRoute).pathSegments.where((s) => s.isNotEmpty).toList();
  for (var i = 1; i <= segments.length; i++) {
    final name = '/${segments.take(i).join('/')}';
    final route = _onGenerateRoute(RouteSettings(name: name));
    if (route != null) {
      routes.add(route);
    } else if (i == segments.length) {
      routes.add(_unknownRoute(RouteSettings(name: initialRoute)));
    }
  }
  return routes;
}

// Returns null for unknown routes (handled by onUnknownRoute), so that _onGenerateInitialRoutes can
// tell which prefixes of a deep link are routes of their own.
Route<dynamic>? _onGenerateRoute(RouteSettings routeSettings) {
  final uri = Uri.parse(routeSettings.name ?? '/');
  final segments = uri.pathSegments;

  if (segments.isEmpty) {
    return MaterialPageRoute(settings: routeSettings, builder: (_) => const MenuScreen());
  }
  if (segments[0] == 'settings') {
    return MaterialPageRoute(settings: routeSettings, builder: (_) => const SettingsScreen());
  }
  if (segments[0] == 'drills' && segments.length == 1) {
    return MaterialPageRoute(settings: routeSettings, builder: (_) => const DrillMenuScreen());
  }
  if (segments[0] == 'drills' && segments.length > 1) {
    final drill = data.findDrillById(segments[1]);
    if (drill != null) {
      return MaterialPageRoute(
        settings: routeSettings,
        builder: (_) => DrillScreen(drill: drill),
      );
    }
  }
  if (segments[0] == 'daily-practice') {
    return MaterialPageRoute(settings: routeSettings, builder: (_) => const PracticePlanScreen());
  }
  if (segments[0] == 'tool' && segments.length > 1) {
    final id = segments[1];
    if (id == 'pattern-trainer') {
      return MaterialPageRoute(
        settings: routeSettings,
        builder: (_) => const PatternTrainerScreen(),
      );
    }
  }
  return null;
}
