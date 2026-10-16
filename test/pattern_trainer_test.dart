import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/screens/pattern_trainer_run_screen.dart';
import 'package:mrdriller/screens/pattern_trainer_screen.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/widgets/section_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)];

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in _sizes) {
    testWidgets('the setup screen lays out without errors on a $size screen', (tester) async {
      _setSize(tester, size);
      await tester.pumpWidget(const MaterialApp(home: PatternTrainerScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the run screen lays out without errors on a $size screen', (tester) async {
      _setSize(tester, size);
      await tester.pumpWidget(
        const MaterialApp(home: PatternTrainerRunScreen(config: PatternTrainerConfig())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('GET READY'), findsOneWidget);
      expect(find.byType(SectionView), findsOneWidget);
    });
  }

  testWidgets('setup changes are saved, and the time follows them', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: PatternTrainerScreen()));
    await tester.pumpAndSettle();
    // Defaults: 60 bpm, 5 patterns -> (16 + 5 * 32) notes at a quarter second each.
    expect(find.bySemanticsLabel(RegExp('Time: 0:44')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Hard'));
    await tester.tap(find.bySemanticsLabel('Never'));
    await tester.tap(find.byTooltip('More patterns'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Time: 0:52')), findsOneWidget);

    final saved = await loadPatternTrainerConfig();
    expect(saved.difficulty, Difficulty.hard);
    expect(saved.sectionVisibility, SectionVisibility.dontShow);
    expect(saved.numPatterns, 6);
  });

  testWidgets('a hidden pattern shows a mystery panel instead', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      const MaterialApp(
        home: PatternTrainerRunScreen(
          config: PatternTrainerConfig(sectionVisibility: SectionVisibility.dontShow),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SectionView), findsNothing);
    expect(find.text('Listen closely…'), findsOneWidget);
  });
}
