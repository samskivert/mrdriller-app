import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'data/drills.dart' as data;
import 'screens/drill_menu_screen.dart';
import 'screens/drill_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/pattern_trainer_screen.dart';
import 'screens/practice_plan_screen.dart';
import 'screens/settings_screen.dart';
import 'state/app_info.dart';
import 'state/practice_log.dart';
import 'state/practice_plan.dart';
import 'state/reminders.dart';
import 'state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await settings.load();
  await practicePlan.load();
  await practiceLog.load();
  await reminders.load();
  await loadAppInfo();
  runApp(const MrDrillerApp());
}

class MrDrillerApp extends StatelessWidget {
  const MrDrillerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mr. Driller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E63DD)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

Route<dynamic> _onGenerateRoute(RouteSettings routeSettings) {
  final uri = Uri.parse(routeSettings.name ?? '/');
  final segments = uri.pathSegments;

  if (segments.isEmpty) {
    return MaterialPageRoute(settings: routeSettings, builder: (_) => const MenuScreen());
  }
  if (segments[0] == 'settings') {
    return MaterialPageRoute(settings: routeSettings, builder: (_) => const SettingsScreen());
  }
  if (segments[0] == 'drills') {
    return MaterialPageRoute(settings: routeSettings, builder: (_) => const DrillMenuScreen());
  }
  if (segments[0] == 'drill' && segments.length > 1) {
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
  return MaterialPageRoute(
    settings: routeSettings,
    builder: (_) => _UnknownRoute(id: routeSettings.name ?? ''),
  );
}

class _UnknownRoute extends StatelessWidget {
  final String id;

  const _UnknownRoute({required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Unknown drill or tool: $id'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('← Back'),
            ),
          ],
        ),
      ),
    );
  }
}
