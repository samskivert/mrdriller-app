// The user's playlists: named, ordered lists of drills, each with its own starting bpm/bpm
// increase/repeat count, persisted to local storage and synced through iCloud (see sync.dart).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/drills.dart' as data;
import 'drill_config.dart';
import 'sync.dart';

class PlaylistEntry {
  final String drillId;
  final DrillConfig config;

  const PlaylistEntry({required this.drillId, required this.config});

  Map<String, dynamic> toJson() => {'drillId': drillId, 'config': config.toJson()};

  factory PlaylistEntry.fromJson(Map<String, dynamic> json) => PlaylistEntry(
    drillId: json['drillId'] as String,
    config: DrillConfig.fromJson(json['config'] as Map<String, dynamic>),
  );
}

class Playlist {
  // Used in the playlist's URL (/playlists/<id>), and by reminders that open it.
  final String id;
  final String name;
  final List<PlaylistEntry> entries;

  const Playlist({required this.id, required this.name, this.entries = const []});

  Playlist copyWith({String? name, List<PlaylistEntry>? entries}) =>
      Playlist(id: id, name: name ?? this.name, entries: entries ?? this.entries);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'entries': [for (final e in entries) e.toJson()],
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    name: json['name'] as String,
    entries: [
      for (final item in json['entries'] as List<dynamic>)
        PlaylistEntry.fromJson(item as Map<String, dynamic>),
    ],
  );
}

/// How long it takes to play every drill in [entries], in seconds (skipping any drill that no
/// longer exists, as playing them does).
double playlistSeconds(List<PlaylistEntry> entries) {
  var total = 0.0;
  for (final entry in entries) {
    final drill = data.findDrillById(entry.drillId);
    if (drill != null) total += drillDuration(drill, entry.config);
  }
  return total;
}

// Exporting a playlist to a file, to import into another copy of the app: its name and drills,
// but not its id (an import is given a new one).

const _exportFormat = 'mrdriller-playlist';
const _exportVersion = 1;

/// A file name for [playlist]'s export: its name, less characters file systems don't allow.
String playlistExportFileName(Playlist playlist) {
  final name = playlist.name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '').trim();
  return '${name.isEmpty ? 'playlist' : name}.json';
}

/// [playlist] as the JSON of an export file.
String encodePlaylistExport(Playlist playlist) => const JsonEncoder.withIndent('  ').convert({
  'format': _exportFormat,
  'version': _exportVersion,
  'name': playlist.name,
  'entries': [for (final e in playlist.entries) e.toJson()],
});

/// A playlist read from an export file: its name, the drills in it that this copy of the app has,
/// and how many it left out because it doesn't have them (exported from a newer version, say).
typedef PlaylistImport = ({String name, List<PlaylistEntry> entries, int missing});

/// Reads an export file's [text] (see [encodePlaylistExport]), throwing a [FormatException] if
/// it isn't one.
PlaylistImport decodePlaylistExport(String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> || json['format'] != _exportFormat) {
      throw const FormatException('Not a playlist export');
    }
    final version = json['version'];
    if (version is! int || version > _exportVersion) {
      throw const FormatException('Exported by a newer version of the app');
    }
    final name = (json['name'] as String).trim();
    final all = [
      for (final item in json['entries'] as List<dynamic>)
        PlaylistEntry.fromJson(item as Map<String, dynamic>),
    ];
    final entries = [
      for (final e in all)
        if (data.findDrillById(e.drillId) != null) e,
    ];
    return (
      name: name.isEmpty ? 'Imported playlist' : name,
      entries: entries,
      missing: all.length - entries.length,
    );
  } on FormatException {
    rethrow;
  } catch (e) {
    // (A field of the wrong type, say.)
    throw FormatException('Malformed playlist export: $e');
  }
}

/// The user's playlists, synced item by item (see [SyncedList]).
class PlaylistList extends SyncedList<Playlist> {
  // Where playlists were kept before they synced: a list of them.
  static const _oldKey = 'playlists';

  PlaylistList() : super('playlists.v2');

  List<Playlist> get playlists => items;

  @override
  String idOf(Playlist item) => item.id;

  @override
  Map<String, dynamic> encode(Playlist item) => item.toJson();

  @override
  Playlist decode(Map<String, dynamic> json) => Playlist.fromJson(json);

  @override
  Object? oldDoc(SharedPreferences prefs) {
    try {
      final list = jsonDecode(prefs.getString(_oldKey) ?? 'null');
      if (list is! List) return null;
      return {
        'order': Stamped(0, [for (final p in list) p['id']]).toJson(),
        'items': {for (final p in list) p['id']: Stamped(0, p).toJson()},
      };
    } catch (_) {
      return null;
    }
  }

  /// Creates a new playlist called [name] (empty, unless given [entries]), at the end of the list.
  Playlist create(String name, {List<PlaylistEntry> entries = const []}) {
    final playlist = Playlist(id: newId(), name: name, entries: entries);
    add(playlist);
    return playlist;
  }

  void rename(String id, String name) => update(id, (p) => p.copyWith(name: name));

  void delete(String id) => remove(id);

  void addEntry(String id, PlaylistEntry entry) =>
      update(id, (p) => p.copyWith(entries: [...p.entries, entry]));

  void updateEntry(String id, int index, PlaylistEntry entry) =>
      update(id, (p) => p.copyWith(entries: [...p.entries]..[index] = entry));

  void removeEntry(String id, int index) =>
      update(id, (p) => p.copyWith(entries: [...p.entries]..removeAt(index)));

  void reorderEntries(String id, int oldIndex, int newIndex) => update(id, (p) {
    final entries = [...p.entries];
    final entry = entries.removeAt(oldIndex);
    entries.insert(newIndex, entry);
    return p.copyWith(entries: entries);
  });
}

/// App-wide singleton, initialized once at startup (see main.dart).
final PlaylistList playlists = PlaylistList();
