import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/screens/daily_practice_screen.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/practice_log.dart';
import 'package:mrdriller/state/practice_plan.dart';
import 'package:mrdriller/widgets/drill_practice_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)];

List<PracticePlanEntry> _plan() => [
  for (final drill in data.drills.take(5))
    PracticePlanEntry(
      drillId: drill.id,
      config: const DrillConfig(bpm: 90, bpmIncrease: 5, drillRepeat: 3),
    ),
];

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await practicePlan.load();
    await practiceLog.load();
    // (Loading from empty storage doesn't clear out what a previous test left in the plan.)
    while (practicePlan.entries.isNotEmpty) {
      practicePlan.removeAt(0);
    }
  });

  for (final size in _sizes) {
    testWidgets('the intro to each drill lays out without errors on a $size screen', (
      tester,
    ) async {
      _setSize(tester, size);
      for (final entry in _plan()) {
        practicePlan.add(entry);
      }
      await tester.pumpWidget(const MaterialApp(home: DailyPracticeScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('STAGE 1 OF 5'), findsOneWidget);

      // START NOW skips the rest of the intro.
      await tester.tap(find.bySemanticsLabel('START NOW'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DrillPracticeHost), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the results screen lays out without errors on a $size screen', (tester) async {
      _setSize(tester, size);
      await tester.pumpWidget(MaterialApp(home: PracticeResults(entries: _plan())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final drill in data.drills.take(5)) {
        expect(find.text(drill.title), findsOneWidget);
      }
    });
  }

  testWidgets('LOG IT! logs the session', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PracticeResults(entries: _plan()))),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('LOG IT!'));
    await tester.pumpAndSettle();
    expect(practiceLog.entries, hasLength(1));
    expect(practiceLog.entries.single.drillCount, 5);
    // And it's back where it came from.
    expect(find.byType(PracticeResults), findsNothing);
  });
}
