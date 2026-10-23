import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/screens/daily_practice_screen.dart';
import 'package:mrdriller/screens/practice_log_screen.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/playlists.dart';
import 'package:mrdriller/state/practice_log.dart';
import 'package:mrdriller/state/reminders.dart';
import 'package:mrdriller/widgets/arcade.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A Wednesday.
final _now = DateTime(2026, 10, 14, 20, 0);

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // A day with twenty minutes of practice gets a spinning drum, which would never settle.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
    disableAnimations: true,
  );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(MaterialApp(home: DailyPracticeScreen(now: _now)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await practiceLog.load();
    await reminders.load();
    await playlists.load();
    // (Loading from empty storage doesn't clear out what a previous test left behind.)
    while (reminders.entries.isNotEmpty) {
      reminders.removeAt(0);
    }
    for (final p in playlists.playlists) {
      playlists.delete(p.id);
    }
  });

  testWidgets('no reminders shows a prompt to add one', (tester) async {
    await _pump(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('No reminders set up yet'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('a few reminders lay out without errors on a $size screen', (tester) async {
      final playlist = playlists.create('A playlist with a rather long name, to see it wrap');
      reminders.add(
        ReminderConfig(id: 1, hour: 7, minute: 30, days: {1, 2, 3, 4, 5}, playlistId: playlist.id),
      );
      reminders.add(
        const ReminderConfig(
          id: 2,
          hour: 19,
          minute: 5,
          days: {6, 7},
          message: 'A really quite long reminder message, to see how it wraps on a small phone.',
        ),
      );
      await _pump(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text(playlist.name), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("this week's summary counts just this week's drills", (tester) async {
    for (final at in [
      // Last week's Sunday: part of the streak, but not this week.
      DateTime(2026, 10, 11, 9),
      DateTime(2026, 10, 12, 9),
      DateTime(2026, 10, 13, 9),
      DateTime(2026, 10, 13, 9, 30),
    ]) {
      practiceLog.add(
        PracticeLogEntry(
          completedAt: at,
          drillId: data.drills.first.id,
          config: const DrillConfig(),
          seconds: 300,
        ),
      );
    }
    await _pump(tester, const Size(390, 844));
    Finder tiles(String value) =>
        find.byWidgetPredicate((widget) => widget is DigitTiles && widget.value == value);
    expect(tiles('3'), findsNWidgets(2)); // A three-day streak, and three drills this week.
    expect(tiles('15m'), findsOneWidget);
    expect(find.bySemanticsLabel('Mon Oct 12, practiced 5 minutes'), findsOneWidget);
    expect(find.bySemanticsLabel('Wed Oct 14, today'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('PRACTICE LOG'));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeLogScreen), findsOneWidget);
  });
}
