import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/model/model.dart';
import 'package:mrdriller/screens/drill_picker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpPicker(
  WidgetTester tester,
  Size size, {
  void Function(BuildContext, Drill)? onDrillTap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DrillPickerScreen(title: 'Drills', onDrillTap: onDrillTap ?? (_, _) {}),
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
      expect(find.text(data.drills.first.first.title), findsOneWidget);
      // Scroll through to the end, laying out every card along the way.
      await tester.scrollUntilVisible(find.text(data.drills.last.first.title), 300);
      expect(tester.takeException(), isNull);
      expect(find.text(data.drills.last.first.title), findsOneWidget);
    });
  }

  testWidgets('tapping a variation picks that variation', (tester) async {
    final group = data.drills.firstWhere((g) => g.length > 1);
    final picked = <Drill>[];
    await _pumpPicker(tester, const Size(390, 844), onDrillTap: (_, drill) => picked.add(drill));
    await tester.scrollUntilVisible(find.text(group[1].title), 200);
    await tester.tap(find.text(group[1].title));
    await tester.tap(find.text(group[0].title));
    expect(picked, [group[1], group[0]]);
  });
}
