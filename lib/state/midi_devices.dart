// What the app knows about MIDI devices (drum pads): the name to show for each, which hand each of
// its pads is for, and its timing calibration for each audio output (see audio_outputs.dart).
// Persisted to local storage, but not synced: calibrations only hold for the device they were
// measured on.

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

/// How a [Calibration] was measured.
enum CalibrationSource {
  /// By playing along with clicks (the timing test), which takes the player's own habit of hitting
  /// early or late into it.
  playing,

  /// With the microphone, which measures only the sound's and the hit's delays.
  microphone,
}

/// How much later than the beat a player's hits on a pad land, on average, playing along with
/// clicks from an audio output: the sound's delay in coming out, and the hit's in coming in, less
/// the player's habit of hitting early. Hits are adjusted by it before they're judged.
class Calibration {
  /// The average offset of the hits measured, in milliseconds (negative if early).
  final double offsetMs;

  /// How widely the hits measured spread around [offsetMs], and how many there were, at what
  /// tempo, and when.
  final double spreadMs;
  final int hits;
  final int bpm;
  final DateTime measured;
  final CalibrationSource source;

  const Calibration({
    required this.offsetMs,
    required this.spreadMs,
    required this.hits,
    required this.bpm,
    required this.measured,
    this.source = CalibrationSource.playing,
  });

  Map<String, Object?> toJson() => {
    'offset': offsetMs,
    'spread': spreadMs,
    'hits': hits,
    'bpm': bpm,
    'measured': measured.toIso8601String(),
    'source': source.name,
  };

  static Calibration? fromJson(Object? json) {
    if (json is! Map) return null;
    final (offset, spread, hits, bpm) = (json['offset'], json['spread'], json['hits'], json['bpm']);
    final measured = DateTime.tryParse('${json['measured']}');
    if (offset is! num || spread is! num || hits is! int || bpm is! int || measured == null) {
      return null;
    }
    return Calibration(
      offsetMs: offset.toDouble(),
      spreadMs: spread.toDouble(),
      hits: hits,
      bpm: bpm,
      measured: measured,
      source: CalibrationSource.values.asNameMap()[json['source']] ?? CalibrationSource.playing,
    );
  }
}

class MidiDeviceConfig {
  final String key;

  /// The name to show, if it's been renamed (otherwise its port's name).
  final String? name;

  /// Each mapped pad's note, and what it's for.
  final Map<int, PadRole> pads;

  /// Its calibration for each audio output that it's been calibrated for, by the output's id.
  final Map<String, Calibration> calibrations;

  /// The velocity (1-127) at or above which a hit counts as accented, if it's been set (and
  /// otherwise accents aren't graded).
  final int? accentVelocity;

  const MidiDeviceConfig({
    required this.key,
    this.name,
    this.pads = const {},
    this.calibrations = const {},
    this.accentVelocity,
  });

  // A copy with whatever's given changed (the nullable ones, by a function returning the new value).
  MidiDeviceConfig _copy({
    String? Function()? name,
    Map<int, PadRole>? pads,
    Map<String, Calibration>? calibrations,
    int? Function()? accentVelocity,
  }) => MidiDeviceConfig(
    key: key,
    name: name == null ? this.name : name(),
    pads: pads == null ? this.pads : Map.unmodifiable(pads),
    calibrations: calibrations == null ? this.calibrations : Map.unmodifiable(calibrations),
    accentVelocity: accentVelocity == null ? this.accentVelocity : accentVelocity(),
  );

  MidiDeviceConfig withName(String? name) => _copy(name: () => name);

  MidiDeviceConfig withPads(Map<int, PadRole> pads) => _copy(pads: pads);

  MidiDeviceConfig withCalibrations(Map<String, Calibration> calibrations) =>
      _copy(calibrations: calibrations);

  MidiDeviceConfig withAccentVelocity(int? velocity) => _copy(accentVelocity: () => velocity);

  Map<String, Object?> toJson() => {
    'key': key,
    if (name != null) 'name': name,
    if (accentVelocity != null) 'accentVelocity': accentVelocity,
    'pads': {for (final MapEntry(:key, :value) in pads.entries) '$key': value.name},
    'calibrations': {
      for (final MapEntry(:key, :value) in calibrations.entries) key: value.toJson(),
    },
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
    final calibrations = <String, Calibration>{};
    final calibrationsJson = json['calibrations'];
    if (calibrationsJson is Map) {
      for (final MapEntry(:key, :value) in calibrationsJson.entries) {
        final calibration = Calibration.fromJson(value);
        if (key is String && calibration != null) calibrations[key] = calibration;
      }
    }
    final accentVelocity = json['accentVelocity'];
    return MidiDeviceConfig(
      key: json['key'] as String,
      name: name is String ? name : null,
      pads: Map.unmodifiable(pads),
      calibrations: Map.unmodifiable(calibrations),
      accentVelocity: accentVelocity is int ? accentVelocity : null,
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

  /// The calibration of the device with [key] for the output with [outputId], if it has one.
  Calibration? calibrationOf(String key, String outputId) => _devices[key]?.calibrations[outputId];

  /// Sets the calibration of the device with [key] for the output with [outputId] (or with null,
  /// removes it).
  void setCalibration(String key, String outputId, Calibration? calibration) {
    _update(key, (device) {
      final calibrations = {...device.calibrations};
      if (calibration == null) {
        calibrations.remove(outputId);
      } else {
        calibrations[outputId] = calibration;
      }
      return device.withCalibrations(calibrations);
    });
  }

  /// The velocity at or above which a hit on the device with [key] counts as accented, if set.
  int? accentVelocityOf(String key) => _devices[key]?.accentVelocity;

  /// Sets the velocity at or above which a hit on the device with [key] counts as accented (or
  /// with null, stops grading accents on it).
  void setAccentVelocity(String key, int? velocity) {
    _update(key, (device) => device.withAccentVelocity(velocity?.clamp(1, 127)));
  }

  /// Removes every device's calibration for the output with [outputId], which is gone.
  void forgetOutput(String outputId) {
    var changed = false;
    for (final device in [..._devices.values]) {
      if (!device.calibrations.containsKey(outputId)) continue;
      _devices[device.key] = device.withCalibrations({...device.calibrations}..remove(outputId));
      changed = true;
    }
    if (changed) _save();
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
