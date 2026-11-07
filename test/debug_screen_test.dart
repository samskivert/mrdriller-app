import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/main.dart';
import 'package:mrdriller/screens/debug_screen.dart';
import 'package:mrdriller/screens/playlist_run_screen.dart';
import 'package:mrdriller/widgets/arcade.dart';
import 'package:mrdriller/widgets/hud_controls.dart';
import 'package:mrdriller/widgets/results_popup.dart';
import 'package:mrdriller/widgets/timing_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('shows the results popup for each made-up run without errors on a $size screen', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: DrillResultsDebugScreen()));
      expect(find.text('RESULTS'), findsWidgets);
      for (final run in ['Typical', 'Great', 'Rough', 'Uncal.', 'Playlist']) {
        await tester.tap(find.text(run).first);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      // The timings' histogram.
      expect(find.byType(TimingChart), findsOneWidget);
      // A playlist's moves on by itself (with a bar draining until it does), with no buttons.
      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
      expect(find.text('CONTINUE'), findsNothing);
      expect(find.text('OK'), findsNothing);
    });
  }

  Rect popupRect(WidgetTester tester) => tester.getRect(
    find.descendant(of: find.byType(ResultsPopup), matching: find.byType(PlayfieldPanel)),
  );

  testWidgets('the results popup scales up on a big screen', (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DrillResultsDebugScreen()));
    // Laid out 380 wide, at twice the size.
    expect(popupRect(tester).width, closeTo(760, 1));
  });

  testWidgets("the results popup is laid out as wide as fits, on a phone, at its own size", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DrillResultsDebugScreen()));
    expect(popupRect(tester).width, closeTo(320 - 32, 1));
  });

  testWidgets('the results popup scales down to fit a short screen', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DrillResultsDebugScreen()));
    final rect = popupRect(tester);
    expect(rect.top, greaterThanOrEqualTo(16));
    expect(rect.bottom, lessThanOrEqualTo(390 - 16));
  });

  testWidgets('the debug menu leads to drill results and playlist results', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TaikoTrainerApp(initialRoute: '/debug'));
    await tester.pumpAndSettle();
    expect(find.byType(DebugMenuScreen), findsOneWidget);

    await tester.tap(find.text('Drill results').first);
    await tester.pumpAndSettle();
    expect(find.byType(DrillResultsDebugScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playlist results').first);
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistResults), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('shows playlist results with and without MIDI stats on a $size screen', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: PlaylistResultsDebugScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // A page over all the drills, then one for each (so they aren't also listed as cleared).
      expect(find.text('ALL DRILLS'), findsOneWidget);
      expect(find.byType(GradeCards), findsOneWidget);
      expect(find.text('CLEARED'), findsNothing);
      for (final entry in debugPlaylistEntries()) {
        await tester.ensureVisible(find.byTooltip('Next'));
        await tester.tap(find.byTooltip('Next'));
        await tester.pumpAndSettle();
        expect(find.text(data.findDrillById(entry.drillId)!.title.toUpperCase()), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.byTooltip('Previous'));
      await tester.tap(find.byTooltip('Previous'));
      await tester.pumpAndSettle();
      expect(find.byType(GradeCards), findsOneWidget);

      await tester.tap(find.byType(CandySwitch));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ALL DRILLS'), findsNothing);
      expect(find.byType(GradeCards), findsNothing);
      expect(find.text('CLEARED'), findsOneWidget);
    });
  }
}
