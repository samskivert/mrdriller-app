import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mrdriller/widgets/slide_in.dart';

// Diagnostic test for the DrillScreen top-slot animation pattern: a fresh SlideIn instance
// (mounted via a changing key) should start its slide-in animation from `begin` toward
// `Offset.zero`, rather than snapping instantly to rest.
void main() {
  testWidgets('SlideIn keyed by changing key animates the slide-in', (tester) async {
    var keyValue = 'a';
    late StateSetter setter;

    Widget slot() => SlideIn(
      key: ValueKey(keyValue),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: Text(keyValue),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setter = setState;
            return slot();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500)); // let the first entry settle at zero

    FractionalTranslation ft() =>
        tester.widget<FractionalTranslation>(find.byKey(const ValueKey('slide-in')));

    expect(ft().translation, Offset.zero, reason: 'settled state should be at rest');

    setter(() => keyValue = 'b');
    await tester
        .pump(); // first frame after key change: animation should start at `begin`, not `end`
    expect(
      ft().translation,
      const Offset(0, 1),
      reason: 'should start the slide from below, not snap to rest',
    );

    await tester.pump(const Duration(milliseconds: 200)); // halfway through the 400ms animation
    final atMid = ft().translation;
    expect(atMid.dy, greaterThan(0.0));
    expect(atMid.dy, lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 300)); // finish
    expect(ft().translation, Offset.zero, reason: 'should end at rest');
  });

  testWidgets('same-key rebuilds during the animation do not reset or truncate it', (tester) async {
    // Mirrors DrillScreen's real usage: it rebuilds on every metronome tick (every ~125-250ms),
    // and most of those rebuilds pass the SAME key (only content like the highlighted beat
    // changes) while a slide-in animation from a genuine key change is still in flight.
    var keyValue = 'a';
    var content = 'a-0';
    late StateSetter setter;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setter = setState;
            return SlideIn(
              key: ValueKey(keyValue),
              duration: const Duration(milliseconds: 400),
              child: Text(content),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    FractionalTranslation ft() =>
        tester.widget<FractionalTranslation>(find.byKey(const ValueKey('slide-in')));

    setter(() {
      keyValue = 'b';
      content = 'b-0';
    });
    await tester.pump();
    expect(ft().translation, const Offset(0, 1));

    // Simulate ~8 same-key ticks (content-only changes) spaced 40ms apart across the 400ms window.
    for (var i = 1; i <= 8; i++) {
      setter(() => content = 'b-$i');
      await tester.pump(const Duration(milliseconds: 40));
    }
    // 320ms of real time has elapsed (8 * 40ms); the animation should have progressed
    // continuously rather than being reset back to Offset(0, 1) by any of those rebuilds.
    final atNearEnd = ft().translation;
    expect(
      atNearEnd.dy,
      lessThan(0.1),
      reason: 'should be nearly settled, not reset by content-only rebuilds',
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(ft().translation, Offset.zero);
  });
}
