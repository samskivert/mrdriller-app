import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/click_sound.dart';
import 'package:mrdriller/model/grading.dart';
import 'package:mrdriller/screens/settings_screen.dart';
import 'package:mrdriller/state/settings.dart';
import 'package:mrdriller/widgets/hud_controls.dart';

void main() {
  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('settings lays out without errors on a $size screen, and its cards toggle', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      final before = settings.showBouncingDot;
      await tester.tap(find.text('NOTE HIGHLIGHT'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(settings.showBouncingDot, !before);
      // The switch itself toggles it too (just once, not also via the card it's on).
      await tester.tap(find.byType(CandySwitch).first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(settings.showBouncingDot, before);
      expect(tester.takeException(), isNull);

      // Picking a grading difficulty.
      final hard = find.text('Hard').first;
      await tester.ensureVisible(hard);
      await tester.tap(hard);
      await tester.pump();
      expect(settings.gradingDifficulty, GradingDifficulty.hard);
      expect(find.text('Perfect within ±15ms, good within ±30ms.'), findsOneWidget);
      settings.setGradingDifficulty(GradingDifficulty.normal);

      // Picking a click sound.
      final cowbell = find.text('Cowbell').first;
      await tester.ensureVisible(cowbell);
      await tester.tap(cowbell);
      await tester.pump(const Duration(seconds: 2));
      expect(settings.clickSound, ClickSound.cowbell);
      settings.setClickSound(ClickSound.classic);
      expect(tester.takeException(), isNull);

      // Stop the highlight preview's timer.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
