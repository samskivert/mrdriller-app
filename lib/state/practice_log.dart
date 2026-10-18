// A log of every drill the user has completed, persisted to local storage. A drill is recorded as
// soon as it finishes on its own (see DrillPracticeHost), however it was started: on its own, or as
// part of a playlist. Bailing out of a drill partway through records nothing.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/model.dart';
import 'drill_config.dart';

class PracticeLogEntry {
  final DateTime completedAt;
  final String drillId;
  final DrillConfig config;
  // The drill's computed duration when it was completed (not wall-clock time, so pausing doesn't
  // count), kept rather than recomputed so that changes to the drill don't rewrite history.
  final int seconds;

  const PracticeLogEntry({
    required this.completedAt,
    required this.drillId,
    required this.config,
    required this.seconds,
  });

  Map<String, dynamic> toJson() => {
    'completedAt': completedAt.toIso8601String(),
    'drillId': drillId,
    'config': config.toJson(),
    'seconds': seconds,
  };

  factory PracticeLogEntry.fromJson(Map<String, dynamic> json) => PracticeLogEntry(
    completedAt: DateTime.parse(json['completedAt'] as String),
    drillId: json['drillId'] as String,
    config: DrillConfig.fromJson(json['config'] as Map<String, dynamic>),
    seconds: json['seconds'] as int,
  );
}

class PracticeLog extends ChangeNotifier {
  static const _key = 'practiceLog.entries';

  List<PracticeLogEntry> _entries = [];
  SharedPreferences? _prefs;

  /// Most recently completed drill first.
  List<PracticeLogEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final saved = prefs.getString(_key);
    if (saved != null) {
      try {
        final list = jsonDecode(saved) as List<dynamic>;
        _entries = [
          for (final item in list) PracticeLogEntry.fromJson(item as Map<String, dynamic>),
        ];
      } catch (_) {
        _entries = [];
      }
    }
    notifyListeners();
  }

  void add(PracticeLogEntry entry) {
    _entries = [entry, ..._entries];
    _save();
  }

  /// Records that [drill] was just completed at [config].
  void recordDrill(Drill drill, DrillConfig config) => add(
    PracticeLogEntry(
      completedAt: DateTime.now(),
      drillId: drill.id,
      config: config,
      seconds: drillDuration(drill, config).round(),
    ),
  );

  void _save() {
    _prefs?.setString(_key, jsonEncode([for (final e in _entries) e.toJson()]));
    notifyListeners();
  }
}

/// App-wide singleton, initialized once at startup (see main.dart).
final PracticeLog practiceLog = PracticeLog();
