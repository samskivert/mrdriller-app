import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/model/model.dart';
import 'package:mrdriller/screens/drill_picker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpPicker(
  WidgetTester tester,
  Size size, {
  Future<void> Function(BuildContext, Drill)? onDrillTap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DrillPickerScreen(title: 'Drills', onDrillTap: onDrillTap ?? (_, _) async {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('the drill picker lays out without errors on a $size screen', (tester) async {
      await _pumpPicker(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text(data.drills.first.title), findsOneWidget);
      // Scroll through to the end, laying out every card along the way.
      await tester.drag(find.byType(GridView), const Offset(0, -20000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(data.drills.last.title), findsOneWidget);
    });
  }

  testWidgets("cards show each drill's saved settings, reloaded after it's been tapped", (
    tester,
  ) async {
    final first = data.drills.first;
    SharedPreferences.setMockInitialValues({
      'config.${first.id}': jsonEncode({'bpm': 90, 'bpmIncrease': 5, 'drillRepeat': 3}),
    });
    await _pumpPicker(
      tester,
      const Size(390, 844),
      onDrillTap: (context, drill) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('config.${drill.id}', jsonEncode({'bpm': 120}));
      },
    );
    expect(find.textContaining('90 BPM  ·  +5  ·  ×3'), findsOneWidget);

    await tester.tap(find.text(first.title));
    await tester.pumpAndSettle();
    expect(find.textContaining('120 BPM'), findsOneWidget);
    expect(find.textContaining('90 BPM'), findsNothing);
  });
}
