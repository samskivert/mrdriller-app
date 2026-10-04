import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/main.dart';

void main() {
  testWidgets('Menu screen shows the title, a Drills link, and Pattern Trainer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MrDrillerApp());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Mr. Driller'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Drills\.')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Pattern Trainer\.')), findsOneWidget);
  });

  testWidgets('Tapping Drills opens a screen listing at least one drill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MrDrillerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Drills\.')));
    await tester.pumpAndSettle();

    expect(find.text('Drills'), findsWidgets); // header title now, plus the nav link behind it
    expect(find.text(data.drills.first.title), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('Menu screen lays out without errors on a $size screen', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MrDrillerApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp(r'^Daily Practice\.')), findsOneWidget);
    });
  }
}
