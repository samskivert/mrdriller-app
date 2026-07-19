// Per-drill and per-tool practice configuration, persisted to local storage.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DrillConfig {
  final int bpm;
  final int bpmIncrease;
  final int drillRepeat;
  final bool swapHands;

  const DrillConfig({
    this.bpm = 60,
    this.bpmIncrease = 0,
    this.drillRepeat = 1,
    this.swapHands = false,
  });

  DrillConfig copyWith({int? bpm, int? bpmIncrease, int? drillRepeat, bool? swapHands}) =>
      DrillConfig(
        bpm: bpm ?? this.bpm,
        bpmIncrease: bpmIncrease ?? this.bpmIncrease,
        drillRepeat: drillRepeat ?? this.drillRepeat,
        swapHands: swapHands ?? this.swapHands,
      );

  Map<String, dynamic> toJson() => {
    'bpm': bpm,
    'bpmIncrease': bpmIncrease,
    'drillRepeat': drillRepeat,
    'swapHands': swapHands,
  };

  factory DrillConfig.fromJson(Map<String, dynamic> json) => DrillConfig(
    bpm: json['bpm'] as int? ?? 60,
    bpmIncrease: json['bpmIncrease'] as int? ?? 0,
    drillRepeat: json['drillRepeat'] as int? ?? 1,
    swapHands: json['swapHands'] as bool? ?? false,
  );
}

Future<DrillConfig> loadDrillConfig(String drillId) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('config.$drillId');
  if (saved != null) {
    try {
      return DrillConfig.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {
      // fall through to default
    }
  }
  return const DrillConfig();
}

Future<void> saveDrillConfig(String drillId, DrillConfig config) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('config.$drillId', jsonEncode(config.toJson()));
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

const _patternTrainerKey = 'config.pattern-trainer';

Future<PatternTrainerConfig> loadPatternTrainerConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_patternTrainerKey);
  if (saved != null) {
    try {
      return PatternTrainerConfig.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {
      // fall through to default
    }
  }
  return const PatternTrainerConfig();
}

Future<void> savePatternTrainerConfig(PatternTrainerConfig config) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_patternTrainerKey, jsonEncode(config.toJson()));
}
