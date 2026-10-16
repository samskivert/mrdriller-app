import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/main.dart';
import 'package:mrdriller/model/model.dart';
import 'package:mrdriller/widgets/drill_practice_view.dart';
import 'package:mrdriller/state/app_name.dart';
import 'package:mrdriller/state/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => mrDrillerUnlocked.value = false);

  test("the app's called Taiko Trainer, until the easter egg is unlocked", () {
    expect(appName(), 'Taiko Trainer');
    mrDrillerUnlocked.value = true;
    expect(appName(), 'Mr. Driller');
  });

  testWidgets('unlocking the easter egg renames the app on screen, too', (tester) async {
    await tester.pumpWidget(const TaikoTrainerApp());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Taiko Trainer'), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Taiko Trainer');

    mrDrillerUnlocked.value = true;
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Mr. Driller'), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Mr. Driller');

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mr. Driller v'), findsOneWidget);
  });

  test("a saved reminder with the old Mr. Driller default message gets the new default", () {
    ReminderConfig load(String? message) => ReminderConfig.fromJson({
      'id': 1,
      'hour': 9,
      'minute': 0,
      'days': [1],
      'message': ?message,
    });
    expect(load("Mr. Driller says it's time to practice!").message, defaultReminderMessage);
    expect(load(null).message, defaultReminderMessage);
    expect(load('Drum time!').message, 'Drum time!');
  });

  group('the secret drum pattern', () {
    final start = DateTime(2026, 10, 15, 20);
    const pattern = 'RRLRL RRLRL RRLRL RRLRL';

    // Plays [hits] (R/L, spaces ignored) a quarter second apart, from [from], and says which hits
    // completed the pattern.
    List<int> play(DrumPatternDetector detector, String hits, {DateTime? from}) {
      final hands = [
        for (final c in hits.split(''))
          if (c != ' ') c == 'R' ? Hand.R : Hand.L,
      ];
      return [
        for (var i = 0; i < hands.length; i++)
          if (detector.hit(hands[i], (from ?? start).add(Duration(milliseconds: 250 * i)))) i,
      ];
    }

    test('is the matsuri base beat, four times over', () {
      expect(secretDrumPattern.length, 20);
      expect(play(DrumPatternDetector(), pattern), [19]);
    });

    test('a wrong hit, or too long a pause, means starting over', () {
      final detector = DrumPatternDetector();
      expect(play(detector, 'RRLRL RRLRL RRLRR RRLRL'), isEmpty);
      expect(play(detector, 'RRLRL RRLRL'), isEmpty);
      // Long after: the earlier hits no longer count towards it.
      expect(play(detector, 'RRLRL RRLRL', from: start.add(const Duration(minutes: 1))), isEmpty);
    });

    test("stray hits before the pattern don't stop it counting, and it can be played again", () {
      final detector = DrumPatternDetector();
      expect(play(detector, 'LL R $pattern $pattern'), [22, 42]);
    });
  });

  testWidgets(
    'drumming the pattern on the drum artwork unlocks the easter egg, and again locks it',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TaikoTrainerApp());
      await tester.pumpAndSettle();

      Future<void> drum() async {
        final pad = tester.getRect(find.bySemanticsLabel(RegExp('taiko drum')));
        for (final hand in secretDrumPattern) {
          await tester.tapAt(
            hand == Hand.R
                ? pad.centerRight - const Offset(20, 0)
                : pad.centerLeft + const Offset(20, 0),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await drum();
      expect(find.byType(ClearCelebration), findsOneWidget);
      // Its text is drawn in a Material, so it isn't flagged with the yellow underline of text with
      // no text style.
      expect(
        find.ancestor(of: find.byType(ClearCelebration), matching: find.byType(Material)),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(ClearCelebration), findsNothing);
      expect(appName(), 'Mr. Driller');
      expect(find.bySemanticsLabel('Mr. Driller'), findsOneWidget);
      // The drum has turned into Mr. Driller.
      expect(find.bySemanticsLabel('Mr. Driller playing a taiko drum'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getBool('easterEgg.mrDriller'), isTrue);

      await drum();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(appName(), 'Taiko Trainer');
    },
  );
}
