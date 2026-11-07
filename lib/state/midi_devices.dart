// What the app knows about MIDI devices (drum pads): the name to show for each, and which hand
// each of its pads is for. Persisted to local storage, but not synced: the timing calibrations
// that will join it here only hold for the device they were measured on.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/midi_input.dart';

/// What hitting a pad (a MIDI note) counts as.
enum PadRole {
  right('Right'),
  left('Left'),
  ignore('Ignore');

  final String label;

  const PadRole(this.label);
}

/// The key a device's settings are kept under: its name, as ports' ids aren't stable from one
/// session to the next.
String midiDeviceKey(MidiPort port) =>
    port.manufacturer.isEmpty ? port.name : '${port.manufacturer} / ${port.name}';

class MidiDeviceConfig {
  final String key;

  /// The name to show, if it's been renamed (otherwise its port's name).
  final String? name;

  /// Each mapped pad's note, and what it's for.
  final Map<int, PadRole> pads;

  const MidiDeviceConfig({required this.key, this.name, this.pads = const {}});

  MidiDeviceConfig withName(String? name) => MidiDeviceConfig(key: key, name: name, pads: pads);

  MidiDeviceConfig withPads(Map<int, PadRole> pads) =>
      MidiDeviceConfig(key: key, name: name, pads: Map.unmodifiable(pads));

  Map<String, Object?> toJson() => {
    'key': key,
    if (name != null) 'name': name,
    'pads': {for (final MapEntry(:key, :value) in pads.entries) '$key': value.name},
  };

  static MidiDeviceConfig? fromJson(Object? json) {
    if (json is! Map || json['key'] is! String) return null;
    final name = json['name'];
    final pads = <int, PadRole>{};
    final padsJson = json['pads'];
    if (padsJson is Map) {
      for (final MapEntry(:key, :value) in padsJson.entries) {
        final note = int.tryParse('$key');
        final role = PadRole.values.asNameMap()[value];
        if (note != null && role != null) pads[note] = role;
      }
    }
    return MidiDeviceConfig(
      key: json['key'] as String,
      name: name is String ? name : null,
      pads: Map.unmodifiable(pads),
    );
  }
}

class MidiDevices extends ChangeNotifier {
  static const _key = 'midi.devices';

  SharedPreferences? _prefs;
  final _devices = <String, MidiDeviceConfig>{};

  /// Every device with settings saved, in the order they were first saved.
  Iterable<MidiDeviceConfig> get all => _devices.values;

  MidiDeviceConfig? byKey(String key) => _devices[key];

  /// The name to show for the device with [key].
  String nameOf(String key) => _devices[key]?.name ?? key;

  /// What hitting [note] on the device with [key] counts as, if it's been mapped.
  PadRole? roleOf(String key, int note) => _devices[key]?.pads[note];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _devices.clear();
    try {
      final json = jsonDecode(prefs.getString(_key) ?? '[]');
      if (json is List) {
        for (final device in json.map(MidiDeviceConfig.fromJson).nonNulls) {
          _devices[device.key] = device;
        }
      }
    } on FormatException {
      // Start over.
    }
    notifyListeners();
  }

  /// Renames the device with [key] (or with null, back to its port's name).
  void rename(String key, String? name) {
    _update(key, (device) => device.withName(name == key ? null : name));
  }

  /// Maps [note] on the device with [key] to [role] (or with null, unmaps it).
  void setRole(String key, int note, PadRole? role) {
    _update(key, (device) {
      final pads = {...device.pads};
      if (role == null) {
        pads.remove(note);
      } else {
        pads[note] = role;
      }
      return device.withPads(pads);
    });
  }

  /// Forgets everything saved about the device with [key].
  void forget(String key) {
    if (_devices.remove(key) != null) _save();
  }

  void _update(String key, MidiDeviceConfig Function(MidiDeviceConfig) change) {
    _devices[key] = change(_devices[key] ?? MidiDeviceConfig(key: key));
    _save();
  }

  void _save() {
    _prefs?.setString(_key, jsonEncode([for (final device in _devices.values) device.toJson()]));
    notifyListeners();
  }
}

/// App-wide singleton, initialized once at startup (see main.dart).
final MidiDevices midiDevices = MidiDevices();
