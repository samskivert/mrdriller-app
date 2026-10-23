// Per-drill and per-tool practice configuration, persisted to local storage and synced through
// iCloud (see sync.dart), where each config is a separate document whose latest change wins.

import 'package:shared_preferences/shared_preferences.dart';

import '../model/model.dart';
import 'sync.dart';

class DrillConfig {
  final int bpm;
  final int bpmIncrease;
  final int drillRepeat;
  final bool swapHands;
  // Whether to count in again (at the new tempo) when the bpm goes up for the next loop.
  final bool replayIntroOnBpmIncrease;

  const DrillConfig({
    this.bpm = 60,
    this.bpmIncrease = 0,
    this.drillRepeat = 1,
    this.swapHands = false,
    this.replayIntroOnBpmIncrease = true,
  });

  DrillConfig copyWith({
    int? bpm,
    int? bpmIncrease,
    int? drillRepeat,
    bool? swapHands,
    bool? replayIntroOnBpmIncrease,
  }) => DrillConfig(
    bpm: bpm ?? this.bpm,
    bpmIncrease: bpmIncrease ?? this.bpmIncrease,
    drillRepeat: drillRepeat ?? this.drillRepeat,
    swapHands: swapHands ?? this.swapHands,
    replayIntroOnBpmIncrease: replayIntroOnBpmIncrease ?? this.replayIntroOnBpmIncrease,
  );

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'bpmIncrease': bpmIncrease,
    'drillRepeat': drillRepeat,
    'swapHands': swapHands,
    'replayIntroOnBpmIncrease': replayIntroOnBpmIncrease,
  };

  factory DrillConfig.fromJson(Map<String, dynamic> json) => DrillConfig(
    bpm: json['bpm'] as int? ?? 60,
    bpmIncrease: json['bpmIncrease'] as int? ?? 0,
    drillRepeat: json['drillRepeat'] as int? ?? 1,
    swapHands: json['swapHands'] as bool? ?? false,
    replayIntroOnBpmIncrease: json['replayIntroOnBpmIncrease'] as bool? ?? true,
  );
}

/// How long [drill] takes to play at [config], in seconds.
double drillDuration(Drill drill, DrillConfig config) => computeDrillDuration(
  drill,
  config.bpm,
  config.bpmIncrease,
  config.drillRepeat,
  replayIntroOnBpmIncrease: config.replayIntroOnBpmIncrease,
);

Future<DrillConfig> loadDrillConfig(String drillId) async {
  final saved = _loadConfig(await SharedPreferences.getInstance(), 'config.$drillId');
  if (saved != null) {
    try {
      return DrillConfig.fromJson(saved);
    } catch (_) {
      // fall through to default
    }
  }
  return const DrillConfig();
}

Future<void> saveDrillConfig(String drillId, DrillConfig config) async {
  await saveLatest(await SharedPreferences.getInstance(), 'config.$drillId', config.toJson());
}

Map<String, dynamic>? _loadConfig(SharedPreferences prefs, String key) {
  final value = Stamped.read(syncDoc(prefs, key, mergeLatest))?.v;
  return value is Map<String, dynamic> ? value : null;
}

enum Difficulty { easy, medium, hard }

enum SectionVisibility { showAll, showListen, showRepeat, dontShow }

class PatternTrainerConfig {
  final int bpm;
  final Difficulty difficulty;
  final int numPatterns;
  final bool swapHands;
  final SectionVisibility sectionVisibility;

  const PatternTrainerConfig({
    this.bpm = 60,
    this.difficulty = Difficulty.easy,
    this.numPatterns = 5,
    this.swapHands = false,
    this.sectionVisibility = SectionVisibility.showAll,
  });

  PatternTrainerConfig copyWith({
    int? bpm,
    Difficulty? difficulty,
    int? numPatterns,
    bool? swapHands,
    SectionVisibility? sectionVisibility,
  }) => PatternTrainerConfig(
    bpm: bpm ?? this.bpm,
    difficulty: difficulty ?? this.difficulty,
    numPatterns: numPatterns ?? this.numPatterns,
    swapHands: swapHands ?? this.swapHands,
    sectionVisibility: sectionVisibility ?? this.sectionVisibility,
  );

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'difficulty': difficulty.name,
    'numPatterns': numPatterns,
    'swapHands': swapHands,
    'sectionVisibility': sectionVisibility.name,
  };

  factory PatternTrainerConfig.fromJson(Map<String, dynamic> json) => PatternTrainerConfig(
    bpm: json['bpm'] as int? ?? 60,
    difficulty: Difficulty.values.firstWhere(
      (d) => d.name == json['difficulty'],
      orElse: () => Difficulty.easy,
    ),
    numPatterns: json['numPatterns'] as int? ?? 5,
    swapHands: json['swapHands'] as bool? ?? false,
    sectionVisibility: SectionVisibility.values.firstWhere(
      (v) => v.name == json['sectionVisibility'],
      orElse: () => SectionVisibility.showAll,
    ),
  );
}

// The ranges a pattern trainer's bpm and number of patterns can be set within.
const patternTrainerBpmLimits = (min: 30, max: 120);
const patternCountLimits = (min: 1, max: 20);

/// How long a pattern trainer session at [config] takes, in seconds: a four-measure count-in,
/// then four measures to listen to and four to play back for each pattern, at four beats to the
/// measure and four notes to the beat.
double patternTrainerSeconds(PatternTrainerConfig config) {
  const notesPerMeasure = 4;
  final notes = notesPerMeasure * 4 * (1 + 2 * config.numPatterns);
  return notes * 60 / config.bpm / 4;
}

const _patternTrainerKey = 'config.pattern-trainer';

Future<PatternTrainerConfig> loadPatternTrainerConfig() async {
  final saved = _loadConfig(await SharedPreferences.getInstance(), _patternTrainerKey);
  if (saved != null) {
    try {
      return PatternTrainerConfig.fromJson(saved);
    } catch (_) {
      // fall through to default
    }
  }
  return const PatternTrainerConfig();
}

Future<void> savePatternTrainerConfig(PatternTrainerConfig config) async {
  await saveLatest(await SharedPreferences.getInstance(), _patternTrainerKey, config.toJson());
}
