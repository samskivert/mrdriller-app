// The user's playlists: named, ordered lists of drills, each with its own starting bpm/bpm
// increase/repeat count, persisted to local storage and synced through iCloud (see sync.dart).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/drills.dart' as data;
import '../services/cloud_store.dart';
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

/// Merges two copies of the playlists document (see [PlaylistList]), either of which may be null.
Map<String, dynamic>? mergePlaylistDocs(Object? local, Object? cloud) {
  if (local == null && cloud == null) return null;
  final a = _PlaylistDoc.read(local), b = _PlaylistDoc.read(cloud);
  return _PlaylistDoc(latest(a.order, b.order), {
    for (final id in {...a.items.keys, ...b.items.keys}) id: latest(a.items[id], b.items[id])!,
  }).toJson();
}

class _PlaylistDoc {
  final Stamped? order;
  final Map<String, Stamped> items;

  _PlaylistDoc(this.order, this.items);

  static _PlaylistDoc read(Object? json) {
    final items = <String, Stamped>{};
    if (json is Map && json['items'] is Map) {
      (json['items'] as Map).forEach((id, item) {
        final stamped = Stamped.read(item);
        if (id is String && stamped != null) items[id] = stamped;
      });
    }
    return _PlaylistDoc(json is Map ? Stamped.read(json['order']) : null, items);
  }

  Map<String, dynamic> toJson() => {
    'order': order?.toJson(),
    'items': {for (final MapEntry(:key, :value) in items.entries) key: value.toJson()},
  };

  List<Playlist> get playlists {
    final live = <String, Playlist>{};
    for (final MapEntry(:key, :value) in items.entries) {
      try {
        if (value.v != null) live[key] = Playlist.fromJson(value.v as Map<String, dynamic>);
      } catch (_) {
        // Skip it.
      }
    }
    final order = orderIds;
    // Any that aren't in the order (made on another device whose order lost to this one's) go at
    // the end, in the order they were last changed.
    final rest = live.keys.where((id) => !order.contains(id)).toList()
      ..sort((a, b) => items[a]!.t.compareTo(items[b]!.t));
    return [
      for (final id in [...order, ...rest]) ?live[id],
    ];
  }

  List<String> get orderIds {
    final ids = order?.v;
    return ids is List
        ? [
            for (final id in ids)
              if (id is String) id,
          ]
        : [];
  }
}

// Kept as one document of each playlist (or a marker that it was deleted, so that the deletion
// wins over older copies of it), stamped with when it last changed, plus the order they're in,
// stamped with when it last changed. So editing different playlists on two devices keeps both
// edits, and editing the same one keeps the later.
class PlaylistList extends ChangeNotifier {
  static const _key = 'playlists.v2';
  // Where playlists were kept before they synced: a list of them.
  static const _oldKey = 'playlists';

  List<Playlist> _playlists = [];
  SharedPreferences? _prefs;
  bool _listening = false;

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
    if (!_listening) {
      _listening = true;
      cloudStore.addListener((changed) {
        if (changed.contains(_key)) _sync();
      });
    }
    _playlists = [];
    _sync();
  }

  /// Creates a new, empty playlist called [name], at the end of the list.
  Playlist create(String name) {
    var id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    while (byId(id) != null) {
      id = '${id}x';
    }
    final playlist = Playlist(id: id, name: name);
    _playlists = [..._playlists, playlist];
    _save(id, orderChanged: true);
    return playlist;
  }

  void rename(String id, String name) => _update(id, (p) => p.copyWith(name: name));

  void delete(String id) {
    _playlists = [
      for (final p in _playlists)
        if (p.id != id) p,
    ];
    _save(id, orderChanged: true);
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
    _save(id);
  }

  // Stores the change to the playlist [id] (and to the order, if [orderChanged]), then syncs.
  void _save(String id, {bool orderChanged = false}) {
    final prefs = _prefs;
    if (prefs == null) return notifyListeners();
    final doc = _PlaylistDoc.read(_localDoc(prefs));
    doc.items[id] = Stamped.next(doc.items[id], byId(id)?.toJson());
    final order = orderChanged
        ? Stamped.next(doc.order, [for (final p in _playlists) p.id])
        : doc.order;
    prefs.setString(_key, jsonEncode(_PlaylistDoc(order, doc.items).toJson()));
    _sync();
  }

  void _sync() {
    final prefs = _prefs;
    if (prefs == null) return;
    final merged = syncDoc(
      prefs,
      _key,
      (local, cloud) => mergePlaylistDocs(local ?? _oldDoc(prefs), cloud),
    );
    _playlists = _PlaylistDoc.read(merged).playlists;
    notifyListeners();
  }

  Object? _localDoc(SharedPreferences prefs) {
    try {
      return jsonDecode(prefs.getString(_key) ?? 'null');
    } catch (_) {
      return null;
    }
  }

  // The playlists as they were kept before they synced, which count as older than any change
  // since.
  static Object? _oldDoc(SharedPreferences prefs) {
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
}

/// App-wide singleton, initialized once at startup (see main.dart).
final PlaylistList playlists = PlaylistList();
