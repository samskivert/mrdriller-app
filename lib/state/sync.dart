// Merging the app's state in local storage with its copy in iCloud (see services/cloud_store.dart).
// Each synced document is merged when it's loaded, whenever it changes here, and whenever another
// device changes it, and the result is stored back in both places. The merges have to work however
// stale either side is: after the app's been reinstalled, local storage starts out empty (and
// iCloud's copy may not have arrived yet), and a device that hasn't run the app in a while can
// have old copies of things changed elsewhere since.

import 'dart:convert';
import 'dart:math';

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
