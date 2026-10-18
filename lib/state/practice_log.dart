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
    _entries = [];
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

/// The local calendar day (no time of day) that [dateTime] falls on, for comparing which days
/// drills were practiced on.
DateTime practiceDay(DateTime dateTime) {
  final local = dateTime.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// How many days in a row, up to [today], have had practice (going by the [practiced] days). A
/// streak that's still alive (practice yesterday, but not yet today) counts too.
int practiceStreak(Set<DateTime> practiced, DateTime today) {
  var day = practiced.contains(today) ? today : DateTime(today.year, today.month, today.day - 1);
  var streak = 0;
  while (practiced.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// A total amount of practice, to the minute: e.g. "40m", or "1h5m".
String formatPracticeTotal(int seconds) {
  final minutes = (seconds / 60).round();
  return minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h${minutes % 60}m';
}

/// App-wide singleton, initialized once at startup (see main.dart).
final PracticeLog practiceLog = PracticeLog();
