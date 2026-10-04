import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/widgets/drill_practice_view.dart';

void main() {
  for (final text in const ['ALL CLEAR!', 'DRILL CLEAR!']) {
    for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1024, 768)]) {
      testWidgets('the $text celebration plays out without errors and fits on a $size screen', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 2600),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ClearCelebration(
              text: text,
              animation: controller,
              start: Offset(size.width / 2, size.height * 0.9),
              textSize: 36,
            ),
          ),
        );

        controller.forward();
        // (A little past its 2.6s, so it's finished.)
        for (var i = 0; i < 28; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
        }

        // Once settled in the middle, the text is big (well beyond its starting size), and entirely
        // on screen.
        final rect = tester.getRect(find.textContaining('CLEAR!').last);
        expect(rect.height, greaterThan(36));
        expect((Offset.zero & size).contains(rect.topLeft), isTrue, reason: '$rect');
        expect((Offset.zero & size).contains(rect.bottomRight), isTrue, reason: '$rect');
      });
    }
  }
}
