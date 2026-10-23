// The metronome tool's settings: the ones on its main screen (persisted as the user changes them,
// like a drill's config), and the user's named presets of them. Both sync through iCloud (see
// sync.dart).

import 'package:shared_preferences/shared_preferences.dart';

import '../model/model.dart';
import 'sync.dart';

/// What a beat of the measure plays: the high tone, the low one, or nothing.
enum BeatLevel {
  high,
  low,
  off;

  /// The level a tap on a beat switches it to: high, then low, then off, then back around.
  BeatLevel get next => values[(index + 1) % values.length];
}

const metronomeBpmLimits = (min: 30, max: maxBpm);
const metronomeBeatLimits = (min: 2, max: 8);
const metronomeIncreaseLimits = (min: 1, max: 50);
// How many measures go by between bpm increases (zero for none).
const metronomeIncreaseEveryLimits = (min: 0, max: 32);

class MetronomeConfig {
  final int bpm;
  // One level per beat of the measure, so the measure is as many beats long as this.
  final List<BeatLevel> beats;
  final int bpmIncrease;
  // The bpm goes up by [bpmIncrease] every this many measures, or never if it's zero.
  final int increaseEvery;

  const MetronomeConfig({
    this.bpm = 100,
    this.beats = const [BeatLevel.high, BeatLevel.low, BeatLevel.low, BeatLevel.low],
    this.bpmIncrease = 5,
    this.increaseEvery = 0,
  });

  MetronomeConfig copyWith({
    int? bpm,
    List<BeatLevel>? beats,
    int? bpmIncrease,
    int? increaseEvery,
  }) => MetronomeConfig(
    bpm: bpm ?? this.bpm,
    beats: beats ?? this.beats,
    bpmIncrease: bpmIncrease ?? this.bpmIncrease,
    increaseEvery: increaseEvery ?? this.increaseEvery,
  );

  /// This config with the measure [count] beats long: cut short, or with low beats added on.
  MetronomeConfig withBeatCount(int count) => copyWith(
    beats: [for (var i = 0; i < count; i++) i < beats.length ? beats[i] : BeatLevel.low],
  );

  /// This config with beat [index] switched to the next level (see [BeatLevel.next]).
  MetronomeConfig withBeatToggled(int index) =>
      copyWith(beats: [...beats]..[index] = beats[index].next);

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'beats': [for (final b in beats) b.name],
    'bpmIncrease': bpmIncrease,
    'increaseEvery': increaseEvery,
  };

  factory MetronomeConfig.fromJson(Map<String, dynamic> json) {
    const defaults = MetronomeConfig();
    final beats = json['beats'];
    return MetronomeConfig(
      bpm: json['bpm'] as int? ?? defaults.bpm,
      beats: beats is List && beats.length >= metronomeBeatLimits.min
          ? [
              for (final b in beats.take(metronomeBeatLimits.max))
                BeatLevel.values.asNameMap()[b] ?? BeatLevel.low,
            ]
          : defaults.beats,
      bpmIncrease: json['bpmIncrease'] as int? ?? defaults.bpmIncrease,
      increaseEvery: json['increaseEvery'] as int? ?? defaults.increaseEvery,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MetronomeConfig &&
      other.bpm == bpm &&
      _listEquals(other.beats, beats) &&
      other.bpmIncrease == bpmIncrease &&
      other.increaseEvery == increaseEvery;

  @override
  int get hashCode => Object.hash(bpm, Object.hashAll(beats), bpmIncrease, increaseEvery);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const _configKey = 'config.metronome';

/// The settings on the metronome's main screen, as last left.
Future<MetronomeConfig> loadMetronomeConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = Stamped.read(syncDoc(prefs, _configKey, mergeLatest))?.v;
  if (saved is Map<String, dynamic>) {
    try {
      return MetronomeConfig.fromJson(saved);
    } catch (_) {
      // fall through to default
    }
  }
  return const MetronomeConfig();
}

Future<void> saveMetronomeConfig(MetronomeConfig config) async {
  await saveLatest(await SharedPreferences.getInstance(), _configKey, config.toJson());
}

class MetronomePreset {
  // Used in the preset's URL (/metronome/<id>).
  final String id;
  final String name;
  final MetronomeConfig config;

  const MetronomePreset({required this.id, required this.name, required this.config});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'config': config.toJson()};

  factory MetronomePreset.fromJson(Map<String, dynamic> json) => MetronomePreset(
    id: json['id'] as String,
    name: json['name'] as String,
    config: MetronomeConfig.fromJson(json['config'] as Map<String, dynamic>),
  );
}

/// The user's metronome presets, synced item by item (see [SyncedList]).
class MetronomePresetList extends SyncedList<MetronomePreset> {
  MetronomePresetList() : super('metronomePresets');

  List<MetronomePreset> get presets => items;

  @override
  String idOf(MetronomePreset item) => item.id;

  @override
  Map<String, dynamic> encode(MetronomePreset item) => item.toJson();

  @override
  MetronomePreset decode(Map<String, dynamic> json) => MetronomePreset.fromJson(json);

  /// Creates a preset called [name] with [config], at the end of the list.
  MetronomePreset create(String name, MetronomeConfig config) {
    final preset = MetronomePreset(id: newId(), name: name, config: config);
    add(preset);
    return preset;
  }

  void save(String id, MetronomeConfig config) =>
      update(id, (p) => MetronomePreset(id: p.id, name: p.name, config: config));

  void rename(String id, String name) =>
      update(id, (p) => MetronomePreset(id: p.id, name: name, config: p.config));

  void delete(String id) => remove(id);
}

/// App-wide singleton, initialized once at startup (see main.dart).
final MetronomePresetList metronomePresets = MetronomePresetList();
