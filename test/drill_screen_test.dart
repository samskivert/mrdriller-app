import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/screens/drill_screen.dart';
import 'package:mrdriller/widgets/hud_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpDrillScreen(WidgetTester tester, Size size, int drillIndex) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: DrillScreen(drill: data.drills[drillIndex])));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1024, 768)]) {
    testWidgets('every drill overview lays out without errors on a $size screen', (tester) async {
      for (var i = 0; i < data.drills.length; i++) {
        await _pumpDrillScreen(tester, size, i);
        expect(tester.takeException(), isNull, reason: data.drills[i].id);
      }
    });
  }

  testWidgets('the steppers and hands toggle change the drill config', (tester) async {
    await _pumpDrillScreen(tester, const Size(390, 844), 0);

    // Defaults: 60 bpm, +0, one loop.
    expect(find.bySemanticsLabel(RegExp(r'^BPM: 60\.')), findsOneWidget);
    await tester.tap(find.byTooltip('Faster'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^BPM: 61\.')), findsOneWidget);

    await tester.tap(find.byTooltip('More loops'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Loops: ×2\.')), findsOneWidget);

    // Already at the minimum: the decrease button is disabled.
    await tester.tap(find.byTooltip('Smaller bpm increase each loop'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^BPM up: \+0\.')), findsOneWidget);

    final hands = find.byType(HandsToggle);
    expect(tester.widget<HandsToggle>(hands).swapped, isFalse);
    await tester.tap(hands);
    await tester.pumpAndSettle();
    expect(tester.widget<HandsToggle>(hands).swapped, isTrue);
  });

  testWidgets("changes made in quick succession don't undo each other", (tester) async {
    await _pumpDrillScreen(tester, const Size(390, 844), 0);
    // No rebuild in between these taps.
    await tester.tap(find.byTooltip('Faster'));
    await tester.tap(find.byTooltip('More loops'));
    await tester.tap(find.byType(HandsToggle));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^BPM: 61\.')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Loops: ×2\.')), findsOneWidget);
    expect(tester.widget<HandsToggle>(find.byType(HandsToggle)).swapped, isTrue);
  });

  testWidgets('the count switch is saved with the drill, and ? explains it', (tester) async {
    await _pumpDrillScreen(tester, const Size(390, 844), 0);
    final drill = data.drills[0];

    final countIn = find.byType(CountInToggle);
    expect(tester.widget<CountInToggle>(countIn).value, isTrue);
    await tester.tap(find.descendant(of: countIn, matching: find.byType(CandySwitch)));
    await tester.pumpAndSettle();
    expect(tester.widget<CountInToggle>(countIn).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('config.${drill.id}')!) as Map<String, dynamic>;
    expect(saved['replayIntroOnBpmIncrease'], isFalse);

    // The explanation pops up, and tapping outside it dismisses it.
    final explanation = find.textContaining('count in again');
    await tester.tap(find.byTooltip('What does this do?'));
    await tester.pumpAndSettle();
    expect(explanation, findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(explanation, findsNothing);
  });
}
