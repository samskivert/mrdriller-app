// The audio outputs (speakers, headphones, TVs) that the user plays through, and which one is in
// use. Sound takes a different time to come out of each (Bluetooth adds 100-300ms, a TV's
// processing can add as much, even two TVs differ), so hit timing is calibrated for each one (see
// midi_devices.dart). On web the user names them and picks the current one; on iOS and Android
// they could be detected from the audio route. Persisted to local storage, but not synced: the
// same headphones have different delays on different devices.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What sort of output it is, where that's known.
enum OutputKind { builtIn, wired, bluetooth, display, other }

class AudioOutput {
  final String id;
  final String name;
  final OutputKind? kind;

  const AudioOutput({required this.id, required this.name, this.kind});

  AudioOutput withName(String name) => AudioOutput(id: id, name: name, kind: kind);

  Map<String, Object?> toJson() => {'id': id, 'name': name, if (kind != null) 'kind': kind!.name};

  static AudioOutput? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String || json['name'] is! String) return null;
    return AudioOutput(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: OutputKind.values.asNameMap()[json['kind']],
    );
  }
}

class AudioOutputs extends ChangeNotifier {
  static const _key = 'audio.outputs';
  static const _default = AudioOutput(id: 'default', name: 'This computer');

  SharedPreferences? _prefs;
  List<AudioOutput> _all = const [_default];
  String _currentId = _default.id;

  /// Every output, in the order they were added. Never empty.
  List<AudioOutput> get all => _all;

  /// The output in use now.
  AudioOutput get current => byId(_currentId) ?? _all.first;

  AudioOutput? byId(String id) {
    for (final output in _all) {
      if (output.id == id) return output;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    try {
      final json = jsonDecode(prefs.getString(_key) ?? '{}');
      if (json is Map) {
        final outputs = json['outputs'];
        final all = outputs is List ? outputs.map(AudioOutput.fromJson).nonNulls.toList() : [];
        if (all.isNotEmpty) _all = List.unmodifiable(all);
        final current = json['current'];
        if (current is String && byId(current) != null) _currentId = current;
      }
    } on FormatException {
      // Start over.
    }
    notifyListeners();
  }

  /// Adds an output called [name], and makes it the current one.
  AudioOutput add(String name) {
    final output = AudioOutput(id: 'output-${DateTime.now().microsecondsSinceEpoch}', name: name);
    _all = List.unmodifiable([..._all, output]);
    _currentId = output.id;
    _save();
    return output;
  }

  void rename(String id, String name) {
    _all = List.unmodifiable([for (final o in _all) o.id == id ? o.withName(name) : o]);
    _save();
  }

  /// Deletes the output with [id], unless it's the only one. If it was the current one, the first
  /// left becomes current.
  void delete(String id) {
    if (_all.length <= 1) return;
    _all = List.unmodifiable(_all.where((o) => o.id != id));
    if (_currentId == id) _currentId = _all.first.id;
    _save();
  }

  void select(String id) {
    if (byId(id) == null || id == _currentId) return;
    _currentId = id;
    _save();
  }

  void _save() {
    _prefs?.setString(
      _key,
      jsonEncode({
        'outputs': [for (final o in _all) o.toJson()],
        'current': _currentId,
      }),
    );
    notifyListeners();
  }
}

/// App-wide singleton, initialized once at startup (see main.dart).
final AudioOutputs audioOutputs = AudioOutputs();
