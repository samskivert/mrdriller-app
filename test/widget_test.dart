import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/main.dart';
import 'package:mrdriller/widgets/taiko_drum_head.dart';

void main() {
  testWidgets('Menu screen shows the title, a Drills link, and Pattern Trainer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TaikoTrainerApp());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Dokodoko Drills'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Drills\.')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Pattern Trainer\.')), findsOneWidget);
  });

  testWidgets('Tapping Drills opens a screen listing at least one drill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TaikoTrainerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Drills\.')));
    await tester.pumpAndSettle();

    expect(find.text('Drills'), findsWidgets); // header title now, plus the nav link behind it
    expect(find.text(data.allDrills.first.title), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('Menu screen lays out without errors on a $size screen', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TaikoTrainerApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // (Just "Practice" when it's half width.)
      expect(find.bySemanticsLabel(RegExp(r'^(Daily )?Practice\.')), findsOneWidget);
    });
  }

  testWidgets('in portrait, the drum shrinks so everything fits on an iPhone Pro', (tester) async {
    // An iPhone 17 Pro's screen, and its status bar and home indicator.
    tester.view.physicalSize = const Size(402, 874) * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TaikoTrainerApp());
    await tester.pumpAndSettle();
    // No scrolling needed...
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(scroll.maxScrollExtent, 0);
    // ...and no room left over either: the column fills the screen between the insets (less its
    // padding, and the bits of the insets it tucks into), which together mean
    // _TallMenu.nonHeroHeight is exactly right.
    final column = find.ancestor(of: find.byType(DrumBadge), matching: find.byType(Column)).first;
    expect(tester.getSize(column).height, moreOrLessEquals(874 - (62 - 22) - (34 - 26) - 16 - 12));
  });
}
