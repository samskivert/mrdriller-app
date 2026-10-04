import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/screens/practice_plan_screen.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/practice_plan.dart';
import 'package:mrdriller/state/reminders.dart';
import 'package:mrdriller/widgets/hud_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpPlan(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: PracticePlanScreen()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await practicePlan.load();
    await reminders.load();
    // (Loading from empty storage doesn't clear out what a previous test left behind.)
    while (practicePlan.entries.isNotEmpty) {
      practicePlan.removeAt(0);
    }
    while (reminders.entries.isNotEmpty) {
      reminders.removeAt(0);
    }
  });

  testWidgets('an empty plan shows prompts to add drills and reminders, and no START!', (
    tester,
  ) async {
    await _pumpPlan(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.byType(StartButton), findsNothing);
    expect(find.textContaining('No drills in your plan yet'), findsOneWidget);
    expect(find.text('No reminders set up yet.'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('a full plan lays out without errors on a $size screen', (tester) async {
      for (final drill in data.drills.take(4)) {
        practicePlan.add(
          PracticePlanEntry(
            drillId: drill.id,
            config: const DrillConfig(bpm: 100, bpmIncrease: 5, drillRepeat: 3, swapHands: true),
          ),
        );
      }
      reminders.add(const ReminderConfig(id: 1, hour: 7, minute: 30, days: {1, 2, 3, 4, 5}));
      reminders.add(
        const ReminderConfig(
          id: 2,
          hour: 19,
          minute: 5,
          days: {6, 7},
          message: 'A really quite long reminder message, to see how it wraps on a small phone.',
        ),
      );
      await _pumpPlan(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.byType(StartButton), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
