import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/main.dart';
import 'package:mrdriller/screens/drill_screen.dart';
import 'package:mrdriller/screens/unknown_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('the unknown page lays out without errors on a $size screen', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: UnknownScreen(path: '/drills/a-really-long-mistyped-drill-name')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Lost underground!'), findsOneWidget);
    });
  }

  testWidgets('MENU goes back to the main menu, clearing the history', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/nowhere'),
            child: const Text('the menu'),
          ),
        },
        onUnknownRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => UnknownScreen(path: settings.name ?? ''),
        ),
      ),
    );
    await tester.tap(find.text('the menu'));
    await tester.pumpAndSettle();
    expect(find.text("There's no drill or tool at /nowhere."), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('MENU'));
    await tester.pumpAndSettle();
    expect(find.text('the menu'), findsOneWidget);
    expect(find.byType(UnknownScreen), findsNothing);
  });

  group('launched with a deep link', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> launch(WidgetTester tester, String link) async {
      tester.platformDispatcher.defaultRouteNameTestValue = link;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      await tester.pumpWidget(const TaikoTrainerApp());
      await tester.pumpAndSettle();
    }

    testWidgets('to a drill, opens it (with the drills list behind it)', (tester) async {
      await launch(tester, '/drills/${data.allDrills.first.id}');
      expect(find.byType(DrillScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text(data.allDrills.first.title), findsOneWidget);
    });

    testWidgets("to a drill that doesn't exist, shows the unknown page", (tester) async {
      await launch(tester, '/drills/nope');
      expect(find.text("There's no drill or tool at /drills/nope."), findsOneWidget);
    });

    testWidgets("to a page that doesn't exist, shows the unknown page", (tester) async {
      await launch(tester, '/nowhere/at/all');
      expect(find.byType(UnknownScreen), findsOneWidget);
    });
  });
}
