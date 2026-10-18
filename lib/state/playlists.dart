// The user's playlists: named, ordered lists of drills, each with its own starting bpm/bpm
// increase/repeat count, persisted to local storage.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/drills.dart' as data;
import 'drill_config.dart';

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

class PlaylistList extends ChangeNotifier {
  static const _key = 'playlists';

  List<Playlist> _playlists = [];
  SharedPreferences? _prefs;

  List<Playlist> get playlists => List.unmodifiable(_playlists);

  Playlist? byId(String id) {
    for (final playlist in _playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final saved = prefs.getString(_key);
    if (saved != null) {
      try {
        final list = jsonDecode(saved) as List<dynamic>;
        _playlists = [for (final item in list) Playlist.fromJson(item as Map<String, dynamic>)];
      } catch (_) {
        _playlists = [];
      }
    }
    notifyListeners();
  }

  /// Creates a new, empty playlist called [name], at the end of the list.
  Playlist create(String name) {
    var id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    while (byId(id) != null) {
      id = '${id}x';
    }
    final playlist = Playlist(id: id, name: name);
    _playlists = [..._playlists, playlist];
    _save();
    return playlist;
  }

  void rename(String id, String name) => _update(id, (p) => p.copyWith(name: name));

  void delete(String id) {
    _playlists = [
      for (final p in _playlists)
        if (p.id != id) p,
    ];
    _save();
  }

  void addEntry(String id, PlaylistEntry entry) =>
      _update(id, (p) => p.copyWith(entries: [...p.entries, entry]));

  void updateEntry(String id, int index, PlaylistEntry entry) =>
      _update(id, (p) => p.copyWith(entries: [...p.entries]..[index] = entry));

  void removeEntry(String id, int index) =>
      _update(id, (p) => p.copyWith(entries: [...p.entries]..removeAt(index)));

  void reorderEntries(String id, int oldIndex, int newIndex) => _update(id, (p) {
    final entries = [...p.entries];
    final entry = entries.removeAt(oldIndex);
    entries.insert(newIndex, entry);
    return p.copyWith(entries: entries);
  });

  void _update(String id, Playlist Function(Playlist playlist) update) {
    _playlists = [for (final p in _playlists) p.id == id ? update(p) : p];
    _save();
  }

  void _save() {
    _prefs?.setString(_key, jsonEncode([for (final p in _playlists) p.toJson()]));
    notifyListeners();
  }
}

/// App-wide singleton, initialized once at startup (see main.dart).
final PlaylistList playlists = PlaylistList();
