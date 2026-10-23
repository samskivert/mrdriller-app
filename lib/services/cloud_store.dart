// The user's iCloud key-value store (NSUbiquitousKeyValueStore, see ios/Runner/AppDelegate.swift),
// where the app keeps a copy of everything that would hurt to lose. Unlike local storage, it
// outlives the app being deleted, and it syncs between the user's devices. It only exists on iOS
// (Android's auto backup of local storage covers the first part there); everywhere else it's
// always empty and ignores writes. Values are JSON strings, which the state classes merge with
// their local copies (see lib/state/sync.dart).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CloudStore {
  static const _channel = MethodChannel('mrdriller/cloud');

  bool _enabled = false;
  Map<String, String> _values = {};
  final _listeners = <void Function(Set<String> changed)>[];

  /// Reads what's in the store, and starts listening for changes made on other devices.
  Future<void> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _enabled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await _refresh();
    });
    await _refresh();
  }

  Iterable<String> get keys => _values.keys;

  String? operator [](String key) => _values[key];

  void operator []=(String key, String value) {
    if (!_enabled || _values[key] == value) return;
    _values[key] = value;
    _channel.invokeMethod<void>('set', {'key': key, 'value': value}).ignore();
  }

  /// Calls [listener] with the keys that changed whenever another device (or iCloud's first sync
  /// after the app is installed) changes the store.
  void addListener(void Function(Set<String> changed) listener) => _listeners.add(listener);

  Future<void> _refresh() async {
    try {
      _replace(await _channel.invokeMapMethod<String, String>('getAll') ?? {});
    } catch (_) {
      // Keep what we have.
    }
  }

  void _replace(Map<String, String> values) {
    final changed = {
      for (final key in {..._values.keys, ...values.keys})
        if (_values[key] != values[key]) key,
    };
    _values = Map.of(values);
    if (changed.isEmpty) return;
    for (final listener in [..._listeners]) {
      listener(changed);
    }
  }

  /// Turns the store on with [values] in it (on any platform, with no native side), as though
  /// another device had just changed it to them.
  @visibleForTesting
  void debugSetValues(Map<String, String> values) {
    _enabled = true;
    _replace(values);
  }

  /// Empties the store and turns it back off.
  @visibleForTesting
  void debugReset() {
    _values = {};
    _enabled = false;
  }
}

/// App-wide singleton, loaded at startup (see main.dart) before the state that syncs through it.
final CloudStore cloudStore = CloudStore();
