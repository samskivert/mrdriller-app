import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/main.dart';
import 'package:mrdriller/state/metronome_settings.dart';
import 'package:mrdriller/widgets/arcade.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openMetronome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const TaikoTrainerApp());
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(RegExp(r'^Metronome\.')));
  await tester.pumpAndSettle();
}

Future<void> _tapLabeled(WidgetTester tester, String label) async {
  final finder = find.bySemanticsLabel(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _candy(String label) => find.widgetWithText(CandyButton, label);

CandyButton _button(WidgetTester tester, String label) =>
    tester.widget<CandyButton>(_candy(label).first);

Future<void> _tapCandy(WidgetTester tester, String label) async {
  await tester.ensureVisible(_candy(label).last);
  await tester.tap(_candy(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await metronomePresets.load();
  });

  testWidgets('beats can be added, and switched between high, low, and off', (tester) async {
    await _openMetronome(tester);
    expect(find.bySemanticsLabel(RegExp(r'^Beat \d')), findsNWidgets(4));
    await _tapLabeled(tester, 'More beats');
    expect(find.bySemanticsLabel('Beat 5, low'), findsOneWidget);
    await _tapLabeled(tester, 'Beat 1, high');
    expect(find.bySemanticsLabel('Beat 1, low'), findsOneWidget);
    await _tapLabeled(tester, 'Beat 1, low');
    expect(find.bySemanticsLabel('Beat 1, off'), findsOneWidget);
    // Kept for next time.
    final saved = await loadMetronomeConfig();
    expect(saved.beats, [
      BeatLevel.off,
      BeatLevel.low,
      BeatLevel.low,
      BeatLevel.low,
      BeatLevel.low,
    ]);
  });

  testWidgets('a new preset starts from the settings, and saves changes made to it', (
    tester,
  ) async {
    await _openMetronome(tester);
    expect(find.textContaining('No presets yet'), findsOneWidget);
    await _tapLabeled(tester, 'Faster');

    await _tapCandy(tester, 'NEW PRESET');
    await tester.enterText(find.byType(TextField), 'Warm up');
    await _tapCandy(tester, 'CREATE');

    // On the preset's own screen, with the settings it was made from.
    expect(find.text('Warm up'), findsOneWidget);
    expect(metronomePresets.presets.single.config.bpm, 101);
    expect(_button(tester, 'SAVE').onPressed, isNull);

    await _tapLabeled(tester, 'Faster');
    expect(_button(tester, 'SAVE').onPressed, isNotNull);
    // Back to how it was saved: nothing to save.
    await _tapLabeled(tester, 'Slower');
    expect(_button(tester, 'SAVE').onPressed, isNull);

    await _tapLabeled(tester, 'More beats');
    await _tapCandy(tester, 'SAVE');
    expect(_button(tester, 'SAVE').onPressed, isNull);
    expect(metronomePresets.presets.single.config.beats, hasLength(5));

    // Listed on the main screen.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Warm up'), findsOneWidget);
    expect(find.text('101 BPM · 5 beats'), findsOneWidget);
  });

  testWidgets('a preset can be renamed and deleted', (tester) async {
    metronomePresets.create('Slow', const MetronomeConfig(bpm: 60));
    await _openMetronome(tester);
    await tester.tap(find.text('Slow'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rename preset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Very slow');
    await _tapCandy(tester, 'SAVE');
    expect(metronomePresets.presets.single.name, 'Very slow');

    await _tapCandy(tester, 'DELETE');
    // Confirming it.
    await _tapCandy(tester, 'DELETE');
    expect(metronomePresets.presets, isEmpty);
    expect(find.textContaining('No presets yet'), findsOneWidget);
  });

  testWidgets('a value can be typed in', (tester) async {
    await _openMetronome(tester);
    await _tapLabeled(tester, 'BPM: 100. Tap to type a new value.');
    await tester.enterText(find.byType(TextField), '120');
    // (Through the dialog's closing animation, which still shows the text field.)
    await _tapCandy(tester, 'OK');
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('BPM: 120. Tap to type a new value.'), findsOneWidget);
    expect((await loadMetronomeConfig()).bpm, 120);
  });
}
