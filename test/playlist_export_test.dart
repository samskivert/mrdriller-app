import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/state/drill_config.dart';
import 'package:mrdriller/state/playlists.dart';

void main() {
  final playlist = Playlist(
    id: 'abc',
    name: 'Warm: ups?',
    entries: [
      PlaylistEntry(
        drillId: data.allDrills[0].id,
        config: const DrillConfig(bpm: 90, bpmIncrease: 5, drillRepeat: 3, swapHands: true),
      ),
      PlaylistEntry(drillId: data.allDrills[1].id, config: const DrillConfig()),
    ],
  );

  test('round trips a playlist', () {
    final imported = decodePlaylistExport(encodePlaylistExport(playlist));
    expect(imported.name, 'Warm: ups?');
    expect(imported.missing, 0);
    expect(
      [for (final e in imported.entries) e.toJson()],
      [for (final e in playlist.entries) e.toJson()],
    );
  });

  test('names the file after the playlist', () {
    expect(playlistExportFileName(playlist), 'Warm ups.json');
    expect(playlistExportFileName(const Playlist(id: 'x', name: '???')), 'playlist.json');
  });

  test('leaves out drills it does not have', () {
    final json = jsonDecode(encodePlaylistExport(playlist)) as Map<String, dynamic>;
    (json['entries'] as List).add({'drillId': 'no-such-drill', 'config': <String, dynamic>{}});
    final imported = decodePlaylistExport(jsonEncode(json));
    expect(imported.entries.length, 2);
    expect(imported.missing, 1);
  });

  test('rejects files that are not playlist exports', () {
    for (final text in [
      'not json',
      '[]',
      '{"name": "x", "entries": []}',
      '{"format": "mrdriller-playlist", "version": 99, "name": "x", "entries": []}',
      '{"format": "mrdriller-playlist", "version": 1, "name": 3, "entries": []}',
      '{"format": "mrdriller-playlist", "version": 1, "name": "x", "entries": [1]}',
    ]) {
      expect(() => decodePlaylistExport(text), throwsFormatException, reason: text);
    }
  });
}
