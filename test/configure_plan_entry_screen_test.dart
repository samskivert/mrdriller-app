import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/screens/configure_plan_entry_screen.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/practice_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _drill = data.drills.first;

// Opens the screen on top of a stand-in for the plan screen (which it returns to when done).
Future<void> _open(WidgetTester tester, Size size, {int? editIndex, DrillConfig? config}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Start from scratch, rather than from whatever an earlier _open left on screen.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: '/daily-practice',
      routes: {
        '/daily-practice': (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConfigurePlanEntryScreen(
                  drillId: _drill.id,
                  drillTitle: _drill.title,
                  editIndex: editIndex,
                  initialConfig: config,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      },
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await practicePlan.load();
    // (Loading from empty storage doesn't clear out what a previous test left in the plan.)
    while (practicePlan.entries.isNotEmpty) {
      practicePlan.removeAt(0);
    }
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('adding and editing both lay out without errors on a $size screen', (tester) async {
      await _open(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp(r'^ADD( TO PLAN)?\b')), findsOneWidget);
      expect(find.bySemanticsLabel('CANCEL'), findsOneWidget);

      await _open(tester, size, editIndex: 0, config: const DrillConfig(bpm: 120));
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp('^SAVE')), findsOneWidget);
      expect(find.bySemanticsLabel('DELETE'), findsOneWidget);
    });
  }

  testWidgets('ADD TO PLAN adds the drill, at the config set up on the screen', (tester) async {
    await _open(tester, const Size(390, 844));
    await tester.tap(find.byTooltip('Faster'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^ADD( TO PLAN)?\b')));
    await tester.pumpAndSettle();
    expect(practicePlan.entries, hasLength(1));
    expect(practicePlan.entries.single.drillId, _drill.id);
    expect(practicePlan.entries.single.config.bpm, 61);
    expect(find.byType(ConfigurePlanEntryScreen), findsNothing);
  });

  testWidgets('DELETE removes the entry, once confirmed', (tester) async {
    practicePlan.add(PracticePlanEntry(drillId: _drill.id, config: const DrillConfig()));
    await _open(tester, const Size(390, 844), editIndex: 0, config: const DrillConfig());
    await tester.tap(find.bySemanticsLabel('DELETE'));
    await tester.pumpAndSettle();
    expect(find.text('DELETE DRILL?'), findsOneWidget);
    // The dialog's own DELETE button.
    await tester.tap(find.bySemanticsLabel('DELETE').last);
    await tester.pumpAndSettle();
    expect(practicePlan.entries, isEmpty);
    expect(find.byType(ConfigurePlanEntryScreen), findsNothing);
  });
}
