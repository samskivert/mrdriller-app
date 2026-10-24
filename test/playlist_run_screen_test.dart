import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/screens/playlist_run_screen.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/playlists.dart';
import 'package:mrdriller/widgets/drill_practice_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)];

List<PlaylistEntry> _entries() => [
  for (final drill in data.allDrills.take(5))
    PlaylistEntry(
      drillId: drill.id,
      config: const DrillConfig(bpm: 90, bpmIncrease: 5, drillRepeat: 3),
    ),
];

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in _sizes) {
    testWidgets('the intro to each drill lays out without errors on a $size screen', (
      tester,
    ) async {
      _setSize(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          home: PlaylistRunScreen(title: 'Warm Up', entries: _entries()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('STAGE 1 OF 5'), findsOneWidget);
      expect(find.text('Warm Up'), findsWidgets);

      // START NOW skips the rest of the intro.
      await tester.tap(find.bySemanticsLabel('START NOW'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DrillPracticeHost), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the results screen lays out without errors on a $size screen', (tester) async {
      _setSize(tester, size);
      await tester.pumpWidget(MaterialApp(home: PlaylistResults(entries: _entries())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final drill in data.allDrills.take(5)) {
        expect(find.text(drill.title), findsOneWidget);
      }
    });
  }

  testWidgets('DONE! goes back to where it came from', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PlaylistResults(entries: _entries()))),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('DONE!'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistResults), findsNothing);
  });
}
