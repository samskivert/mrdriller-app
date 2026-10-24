import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/screens/practice_log_screen.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/practice_log.dart';
import 'package:mrdriller/widgets/arcade.dart';
import 'package:mrdriller/widgets/rainbow_drum.dart';
import 'package:mrdriller/widgets/taiko_drum_head.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A Sunday.
final _now = DateTime(2026, 10, 4, 20, 0);

// Each drill completed takes ten minutes.
Future<void> _load(List<DateTime> drills) async {
  SharedPreferences.setMockInitialValues({
    'practiceLog.entries': jsonEncode([
      for (final at in drills)
        PracticeLogEntry(
          completedAt: at,
          drillId: data.drills.first.id,
          config: const DrillConfig(bpm: 90),
          seconds: 600,
        ).toJson(),
    ]),
  });
  await practiceLog.load();
}

Finder _tiles(String value) =>
    find.byWidgetPredicate((widget) => widget is DigitTiles && widget.value == value);

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // A day with twenty minutes of practice gets a spinning drum, which would never settle.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
    disableAnimations: true,
  );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(MaterialApp(home: PracticeLogScreen(now: _now)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty log says so', (tester) async {
    await _load([]);
    await _pump(tester, const Size(390, 844));
    expect(find.textContaining('No practice logged yet'), findsOneWidget);
  });

  testWidgets('the streak counts consecutive days up to today, and the totals add up', (
    tester,
  ) async {
    await _load([
      DateTime(2026, 10, 4, 9),
      DateTime(2026, 10, 3, 18),
      DateTime(2026, 10, 2, 7),
      // A gap on the 1st breaks the streak.
      DateTime(2026, 9, 30, 12),
    ]);
    await _pump(tester, const Size(390, 844));
    // Streak, drills, and total time, in digit tiles.
    expect(_tiles('3'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
    expect(_tiles('4'), findsOneWidget);
    expect(_tiles('40m'), findsOneWidget);
    expect(find.bySemanticsLabel('Sun Oct 4, practiced 10 minutes, today'), findsOneWidget);
    expect(find.bySemanticsLabel('Thu Oct 1'), findsOneWidget);
  });

  testWidgets("a streak that hasn't been continued today yet still counts", (tester) async {
    await _load([DateTime(2026, 10, 3, 18), DateTime(2026, 10, 2, 7)]);
    await _pump(tester, const Size(390, 844));
    expect(_tiles('2'), findsWidgets);
    expect(find.text('days'), findsOneWidget);
  });

  testWidgets("a day's drills are grouped together", (tester) async {
    await _load([DateTime(2026, 10, 4, 9), DateTime(2026, 10, 4, 9, 15), DateTime(2026, 10, 3)]);
    await _pump(tester, const Size(390, 844));
    expect(find.text('2 practices · 20m 00s'), findsOneWidget);
    expect(find.text('1 practice · 10m 00s'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('a long log lays out without errors on a $size screen', (tester) async {
      await _load([for (var i = 0; i < 30; i += 2) _now.subtract(Duration(days: i))]);
      await _pump(tester, size);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('practice tiers go up at ten and twenty minutes', () {
    expect(PracticeTier.of(null), PracticeTier.none);
    expect(PracticeTier.of(1), PracticeTier.practiced);
    expect(PracticeTier.of(599), PracticeTier.practiced);
    expect(PracticeTier.of(600), PracticeTier.tenMinutes);
    expect(PracticeTier.of(1199), PracticeTier.tenMinutes);
    expect(PracticeTier.of(1200), PracticeTier.twentyMinutes);
  });

  testWidgets('practiced days get fancier the longer the practice', (tester) async {
    final days = [for (var d = 1; d <= 3; d++) DateTime(2026, 10, d)];
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            for (final day in days)
              PracticeDayCell(
                day: day,
                today: _now,
                practice: {days[0]: 60, days[1]: 900, days[2]: 1500},
                size: 40,
              ),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Thu Oct 1, practiced 1 minute'), findsOneWidget);
    expect(find.bySemanticsLabel('Fri Oct 2, practiced 15 minutes'), findsOneWidget);
    expect(find.bySemanticsLabel('Sat Oct 3, practiced 25 minutes'), findsOneWidget);
    // A plain mitsudomoe, then one on a drum head, then the rainbow drum.
    expect(find.byType(Mitsudomoe), findsNWidgets(2));
    expect(find.byType(TaikoDrumHead), findsOneWidget);
    expect(find.byType(RainbowDrum), findsOneWidget);
    // It keeps on turning (but stops along with everything else at the end of the test).
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('time with the metronome shows up as its preset, or just Metronome', (tester) async {
    SharedPreferences.setMockInitialValues({
      'practiceLog.entries': jsonEncode([
        for (final title in [null, 'Fast'])
          PracticeLogEntry(
            completedAt: DateTime(2026, 10, 4, 9),
            drillId: metronomeId,
            config: const DrillConfig(bpm: 90),
            seconds: 120,
            title: title,
          ).toJson(),
      ]),
    });
    await practiceLog.load();
    await _pump(tester, const Size(390, 844));
    expect(find.text('2 practices · 4m 00s'), findsOneWidget);
    expect(find.textContaining('Metronome'), findsOneWidget);
    expect(find.textContaining('Fast'), findsOneWidget);
  });
}
