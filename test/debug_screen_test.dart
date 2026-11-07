import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/main.dart';
import 'package:mrdriller/screens/debug_screen.dart';
import 'package:mrdriller/screens/playlist_run_screen.dart';
import 'package:mrdriller/widgets/arcade.dart';
import 'package:mrdriller/widgets/results_popup.dart';
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
}
