// Merging the app's state in local storage with its copy in iCloud (see services/cloud_store.dart).
// Each synced document is merged when it's loaded, whenever it changes here, and whenever another
// device changes it, and the result is stored back in both places. The merges have to work however
// stale either side is: after the app's been reinstalled, local storage starts out empty (and
// iCloud's copy may not have arrived yet), and a device that hasn't run the app in a while can
// have old copies of things changed elsewhere since.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cloud_store.dart';

/// A value stamped with when it last changed, so that of two copies of it the later changed one
/// wins. A null value is a deletion, kept so that the deletion wins over older copies of the value.
class Stamped {
  // Milliseconds since the epoch. Zero for a value saved before the app synced, so that any copy
  // changed since wins over it.
  final int t;
  final Object? v;

  const Stamped(this.t, this.v);

  /// [v], changed just now: later than [previous] (the value it replaces), even if the clock says
  /// otherwise, so that it wins over it.
  Stamped.next(Stamped? previous, this.v)
    : t = max(DateTime.now().millisecondsSinceEpoch, (previous?.t ?? 0) + 1);

  Map<String, dynamic> toJson() => {'t': t, 'v': v};

  /// Reads [json] as a stamped value, or as a bare value saved before the app synced. Null if
  /// there's no value at all.
  static Stamped? read(Object? json) {
    if (json == null) return null;
    if (json is Map && json.length == 2 && json['t'] is int && json.containsKey('v')) {
      return Stamped(json['t'] as int, json['v']);
    }
    return Stamped(0, json);
  }
}

/// Whichever of [local] and [cloud] changed last, preferring the cloud's copy on a tie.
Stamped? latest(Stamped? local, Stamped? cloud) {
  if (local == null) return cloud;
  if (cloud == null) return local;
  return local.t > cloud.t ? local : cloud;
}

/// Merges two copies of a [Stamped] value (see [Stamped.read]), for [syncDoc].
Object? mergeLatest(Object? local, Object? cloud) =>
    latest(Stamped.read(local), Stamped.read(cloud))?.toJson();

/// Merges the local and cloud copies of the JSON document at [key] (either of which is null if
/// it's missing or unreadable) with [merge], stores the result in both places, and returns it. Null
/// if there's no document in either place.
Object? syncDoc(
  SharedPreferences prefs,
  String key,
  Object? Function(Object? local, Object? cloud) merge,
) {
  final localJson = prefs.getString(key);
  final cloudJson = cloudStore[key];
  final merged = merge(_decode(localJson), _decode(cloudJson));
  if (merged == null) return null;
  final json = jsonEncode(merged);
  if (json != localJson) prefs.setString(key, json);
  if (json != cloudJson) cloudStore[key] = json;
  return merged;
}

/// Stores [value] in both places at [key], as changed just now.
Future<void> saveLatest(SharedPreferences prefs, String key, Object? value) async {
  final previous = latest(
    Stamped.read(_decode(prefs.getString(key))),
    Stamped.read(_decode(cloudStore[key])),
  );
  final json = jsonEncode(Stamped.next(previous, value).toJson());
  cloudStore[key] = json;
  await prefs.setString(key, json);
}

Object? _decode(String? json) {
  if (json == null) return null;
  try {
    return jsonDecode(json);
  } catch (_) {
    return null;
  }
}

/// A list of items, each with its own id, persisted to local storage under [key] and synced
/// through iCloud item by item. It's kept as one document of each item (or a marker that it was
/// deleted, so that the deletion wins over older copies of it), stamped with when it last changed,
/// plus the order they're in, stamped with when it last changed. So changing different items on two
/// devices keeps both changes, and changing the same one keeps the later.
abstract class SyncedList<T> extends ChangeNotifier {
  final String key;

  SyncedList(this.key);

  String idOf(T item);
  Map<String, dynamic> encode(T item);
  T decode(Map<String, dynamic> json);

  /// The list as it was kept before it synced, if it was, as a document (see [_ItemsDoc]) whose
  /// stamps are all zero, so that any change since wins over it.
  Object? oldDoc(SharedPreferences prefs) => null;

  List<T> _items = [];
  SharedPreferences? _prefs;
  bool _listening = false;

  List<T> get items => List.unmodifiable(_items);

  T? byId(String id) {
    for (final item in _items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    if (!_listening) {
      _listening = true;
      cloudStore.addListener((changed) {
        if (changed.contains(key)) _sync();
      });
    }
    _items = [];
    _sync();
  }

  /// An id for a new item, that no item has yet.
  String newId() {
    var id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    while (byId(id) != null) {
      id = '${id}x';
    }
    return id;
  }

  /// Adds [item] to the end of the list.
  void add(T item) {
    _items = [..._items, item];
    _save(idOf(item), orderChanged: true);
  }

  /// Replaces the item [id] with what [update] makes of it.
  void update(String id, T Function(T item) update) {
    _items = [for (final item in _items) idOf(item) == id ? update(item) : item];
    _save(id);
  }

  void remove(String id) {
    _items = [
      for (final item in _items)
        if (idOf(item) != id) item,
    ];
    _save(id, orderChanged: true);
  }

  // Stores the change to the item [id] (and to the order, if [orderChanged]), then syncs.
  void _save(String id, {bool orderChanged = false}) {
    final prefs = _prefs;
    if (prefs == null) return notifyListeners();
    final doc = _ItemsDoc.read(_decode(prefs.getString(key)));
    final item = byId(id);
    doc.items[id] = Stamped.next(doc.items[id], item == null ? null : encode(item));
    final order = orderChanged
        ? Stamped.next(doc.order, [for (final item in _items) idOf(item)])
        : doc.order;
    prefs.setString(key, jsonEncode(_ItemsDoc(order, doc.items).toJson()));
    _sync();
  }

  void _sync() {
    final prefs = _prefs;
    if (prefs == null) return;
    final merged = syncDoc(
      prefs,
      key,
      (local, cloud) => _ItemsDoc.merge(local ?? oldDoc(prefs), cloud),
    );
    _items = _ItemsDoc.read(merged).values(decode);
    notifyListeners();
  }
}

class _ItemsDoc {
  final Stamped? order;
  final Map<String, Stamped> items;

  _ItemsDoc(this.order, this.items);

  static _ItemsDoc read(Object? json) {
    final items = <String, Stamped>{};
    if (json is Map && json['items'] is Map) {
      (json['items'] as Map).forEach((id, item) {
        final stamped = Stamped.read(item);
        if (id is String && stamped != null) items[id] = stamped;
      });
    }
    return _ItemsDoc(json is Map ? Stamped.read(json['order']) : null, items);
  }

  // Merges two copies of the document, either of which may be null.
  static Map<String, dynamic>? merge(Object? local, Object? cloud) {
    if (local == null && cloud == null) return null;
    final a = read(local), b = read(cloud);
    return _ItemsDoc(latest(a.order, b.order), {
      for (final id in {...a.items.keys, ...b.items.keys}) id: latest(a.items[id], b.items[id])!,
    }).toJson();
  }

  Map<String, dynamic> toJson() => {
    'order': order?.toJson(),
    'items': {for (final MapEntry(:key, :value) in items.entries) key: value.toJson()},
  };

  // The items that haven't been deleted (and can be read), in order.
  List<T> values<T>(T Function(Map<String, dynamic> json) decode) {
    final live = <String, T>{};
    for (final MapEntry(:key, :value) in items.entries) {
      try {
        if (value.v != null) live[key] = decode(value.v as Map<String, dynamic>);
      } catch (_) {
        // Skip it.
      }
    }
    final ids = order?.v;
    final ordered = ids is List
        ? [
            for (final id in ids)
              if (id is String) id,
          ]
        : <String>[];
    // Any that aren't in the order (added on another device whose order lost to this one's) go at
    // the end, in the order they were last changed.
    final rest = live.keys.where((id) => !ordered.contains(id)).toList()
      ..sort((a, b) => items[a]!.t.compareTo(items[b]!.t));
    return [
      for (final id in [...ordered, ...rest]) ?live[id],
    ];
  }
}
