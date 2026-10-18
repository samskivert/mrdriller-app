import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/main.dart';
import 'package:mrdriller/screens/playlist_run_screen.dart';
import 'package:mrdriller/screens/playlist_screen.dart';
import 'package:mrdriller/screens/playlists_screen.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/playlists.dart';
import 'package:mrdriller/state/practice_log.dart';
import 'package:mrdriller/state/reminders.dart';
import 'package:mrdriller/widgets/drill_practice_host.dart';
import 'package:mrdriller/widgets/drill_practice_view.dart';
import 'package:mrdriller/widgets/hud_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)];

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Playlist _fullPlaylist() {
  final playlist = playlists.create('Warm Up');
  for (final drill in data.drills.take(4)) {
    playlists.addEntry(
      playlist.id,
      PlaylistEntry(
        drillId: drill.id,
        config: const DrillConfig(bpm: 100, bpmIncrease: 5, drillRepeat: 3, swapHands: true),
      ),
    );
  }
  return playlists.byId(playlist.id)!;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await playlists.load();
    await reminders.load();
    await practiceLog.load();
    // (Loading from empty storage doesn't clear out what a previous test left behind.)
    for (final p in playlists.playlists) {
      playlists.delete(p.id);
    }
    while (reminders.entries.isNotEmpty) {
      reminders.removeAt(0);
    }
  });

  testWidgets('no playlists shows a prompt to make one', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('No playlists yet'), findsOneWidget);
  });

  testWidgets('NEW PLAYLIST asks for a name, then opens the new playlist', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(const TaikoTrainerApp(initialRoute: '/playlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('NEW PLAYLIST'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Morning Set ');
    await tester.tap(find.bySemanticsLabel('CREATE'));
    await tester.pumpAndSettle();
    expect(playlists.playlists.single.name, 'Morning Set');
    expect(find.byType(PlaylistScreen), findsOneWidget);
    expect(find.textContaining('No drills in this playlist yet'), findsOneWidget);
    // And it's in the list behind it.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Set'), findsOneWidget);
  });

  for (final size in _sizes) {
    testWidgets('a full playlist lays out without errors on a $size screen', (tester) async {
      _setSize(tester, size);
      final playlist = _fullPlaylist();
      await tester.pumpWidget(MaterialApp(home: PlaylistScreen(playlistId: playlist.id)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(StartButton), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^SHUFFLE')), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the playlists list lays out without errors on a $size screen', (tester) async {
      _setSize(tester, size);
      _fullPlaylist();
      playlists.create('An empty playlist with a long name that has to be cut off somewhere');
      await tester.pumpWidget(const MaterialApp(home: PlaylistsScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No drills yet'), findsOneWidget);
    });
  }

  testWidgets('PLAY runs the drills in order, and SHUFFLE runs all of them', (tester) async {
    _setSize(tester, const Size(390, 844));
    final playlist = _fullPlaylist();
    await tester.pumpWidget(MaterialApp(home: PlaylistScreen(playlistId: playlist.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp('^PLAY')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    var run = tester.widget<PlaylistRunScreen>(find.byType(PlaylistRunScreen));
    expect(run.title, 'Warm Up');
    expect(run.entries.map((e) => e.drillId).toList(), [
      for (final e in playlist.entries) e.drillId,
    ]);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp('^SHUFFLE')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    run = tester.widget<PlaylistRunScreen>(find.byType(PlaylistRunScreen));
    expect(
      run.entries.map((e) => e.drillId).toSet(),
      playlist.entries.map((e) => e.drillId).toSet(),
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
  });

  testWidgets('renaming and deleting a playlist', (tester) async {
    _setSize(tester, const Size(390, 844));
    final playlist = _fullPlaylist();
    reminders.add(ReminderConfig(id: 1, hour: 9, minute: 0, days: {1}, playlistId: playlist.id));
    await tester.pumpWidget(TaikoTrainerApp(initialRoute: '/playlists/${playlist.id}'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rename playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cool Down');
    await tester.tap(find.bySemanticsLabel('SAVE'));
    await tester.pumpAndSettle();
    expect(playlists.byId(playlist.id)!.name, 'Cool Down');
    expect(find.text('Cool Down'), findsOneWidget);

    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('DELETE PLAYLIST'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('DELETE').last);
    await tester.pumpAndSettle();
    expect(playlists.playlists, isEmpty);
    expect(find.byType(PlaylistsScreen), findsOneWidget);
    // The reminder that opened it now just opens the app.
    expect(reminders.entries.single.playlistId, isNull);
  });

  testWidgets("a link to a playlist that doesn't exist ends on the unknown page", (tester) async {
    await tester.pumpWidget(const TaikoTrainerApp(initialRoute: '/playlists/nope'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistScreen), findsNothing);
    expect(find.textContaining('/playlists/nope'), findsWidgets);
  });

  testWidgets('a drill played to the end is recorded in the practice log', (tester) async {
    _setSize(tester, const Size(390, 844));
    final drill = data.drills.first;
    const config = DrillConfig(bpm: 200);
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DrillPracticeHost(
          title: drill.title,
          drill: drill,
          config: config,
          onDone: () => done = true,
        ),
      ),
    );
    await tester.pump();
    // (The drill itself can't play to the end in a test, since its sounds never finish loading, so
    // this skips to it finishing.)
    tester.widget<DrillPracticeView>(find.byType(DrillPracticeView)).onDone();
    expect(done, isTrue);
    expect(practiceLog.entries.first.drillId, drill.id);
    expect(practiceLog.entries.first.config.bpm, 200);
    expect(practiceLog.entries.first.seconds, drillDuration(drill, config).round());
  });
}
