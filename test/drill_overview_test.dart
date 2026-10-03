import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart';
import 'package:mrdriller/model/model.dart';
import 'package:mrdriller/widgets/arcade.dart';
import 'package:mrdriller/widgets/drill_overview_view.dart';

// Lays out [drill]'s overview on a portrait-phone-sized screen.
Future<void> _pumpOverview(WidgetTester tester, Drill drill) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: DrillOverviewView(drill: drill)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('every drill overview lays out without errors', (tester) async {
    for (final drill in drills) {
      await _pumpOverview(tester, drill);
      expect(tester.takeException(), isNull, reason: drill.id);
    }
  });

  testWidgets('a section whose measures wrap shrinks its card to the wrapped rows, not the full '
      'width (regression: Sixteens)', (tester) async {
    await _pumpOverview(tester, sixteens);

    final card = tester.getRect(find.byType(PlayfieldPanel).first);
    final wrap = tester.getRect(
      find.descendant(of: find.byType(PlayfieldPanel).first, matching: find.byType(Wrap)).first,
    );
    // Sixteens' 64-beat lines can't fit on one row at this width, so they wrap...
    expect(tester.getSize(find.byType(Wrap).first).height, greaterThan(100));
    // ...and the card hugs the wrapped rows (plus its 10px padding and 2px border on each side)
    // rather than leaving blank space beside them.
    expect(card.width, closeTo(wrap.width + 2 * (10 + 2), 1));
    expect(card.width, lessThan(402 - 20));
  });
}
