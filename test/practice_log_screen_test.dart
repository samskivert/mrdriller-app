import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/screens/practice_log_screen.dart';
import 'package:mrdriller/state/practice_log.dart';
import 'package:mrdriller/widgets/arcade.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A Sunday.
final _now = DateTime(2026, 10, 4, 20, 0);

Future<void> _load(List<DateTime> sessions) async {
  SharedPreferences.setMockInitialValues({
    'practiceLog.entries': jsonEncode([
      for (final at in sessions)
        PracticeLogEntry(completedAt: at, drillCount: 5, totalSeconds: 600).toJson(),
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
  await tester.pumpWidget(MaterialApp(home: PracticeLogScreen(now: _now)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty log says so', (tester) async {
    await _load([]);
    await _pump(tester, const Size(390, 844));
    expect(find.textContaining('No practice sessions logged yet'), findsOneWidget);
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
    // Streak, sessions, and total time, in digit tiles.
    expect(_tiles('3'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
    expect(_tiles('4'), findsOneWidget);
    expect(_tiles('40m'), findsOneWidget);
    expect(find.bySemanticsLabel('Sun Oct 4, practiced, today'), findsOneWidget);
    expect(find.bySemanticsLabel('Thu Oct 1'), findsOneWidget);
  });

  testWidgets("a streak that hasn't been continued today yet still counts", (tester) async {
    await _load([DateTime(2026, 10, 3, 18), DateTime(2026, 10, 2, 7)]);
    await _pump(tester, const Size(390, 844));
    expect(_tiles('2'), findsWidgets);
    expect(find.text('days'), findsOneWidget);
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
}
