import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/screens/configure_playlist_entry_screen.dart';
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/playlists.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _drill = data.allDrills.first;

late Playlist _playlist;

// Opens the screen on top of a stand-in for the playlist's screen (which it returns to when done).
Future<void> _open(WidgetTester tester, Size size, {int? editIndex, DrillConfig? config}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Start from scratch, rather than from whatever an earlier _open left on screen.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: '/playlists/${_playlist.id}',
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConfigurePlaylistEntryScreen(
                  playlistId: _playlist.id,
                  drillId: _drill.id,
                  drillTitle: _drill.title,
                  editIndex: editIndex,
                  initialConfig: config,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

List<PlaylistEntry> get _entries => playlists.byId(_playlist.id)!.entries;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await playlists.load();
    _playlist = playlists.create('Test');
  });

  tearDown(() => playlists.delete(_playlist.id));

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('adding and editing both lay out without errors on a $size screen', (tester) async {
      await _open(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp(r'^ADD( TO PLAYLIST)?\b')), findsOneWidget);
      expect(find.bySemanticsLabel('CANCEL'), findsOneWidget);

      await _open(tester, size, editIndex: 0, config: const DrillConfig(bpm: 120));
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp('^SAVE')), findsOneWidget);
      expect(find.bySemanticsLabel('DELETE'), findsOneWidget);
    });
  }

  testWidgets('ADD TO PLAYLIST adds the drill, at the config set up on the screen', (tester) async {
    await _open(tester, const Size(390, 844));
    await tester.tap(find.byTooltip('Faster'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^ADD( TO PLAYLIST)?\b')));
    await tester.pumpAndSettle();
    expect(_entries, hasLength(1));
    expect(_entries.single.drillId, _drill.id);
    expect(_entries.single.config.bpm, 61);
    expect(find.byType(ConfigurePlaylistEntryScreen), findsNothing);
  });

  testWidgets('DELETE removes the entry, once confirmed', (tester) async {
    playlists.addEntry(
      _playlist.id,
      PlaylistEntry(drillId: _drill.id, config: const DrillConfig()),
    );
    await _open(tester, const Size(390, 844), editIndex: 0, config: const DrillConfig());
    await tester.tap(find.bySemanticsLabel('DELETE'));
    await tester.pumpAndSettle();
    expect(find.text('DELETE DRILL?'), findsOneWidget);
    // The dialog's own DELETE button.
    await tester.tap(find.bySemanticsLabel('DELETE').last);
    await tester.pumpAndSettle();
    expect(_entries, isEmpty);
    expect(find.byType(ConfigurePlaylistEntryScreen), findsNothing);
  });
}
