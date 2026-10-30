// A log of every drill the user has completed, persisted to local storage. A drill is recorded as
// soon as it finishes on its own (see DrillPracticeHost), however it was started: on its own, or as
// part of a playlist. Bailing out of a drill partway through records nothing. A minute or more of
// playing the metronome is recorded too (see MetronomePlayer), as an entry for [metronomeId].
//
// It's also synced through iCloud (see sync.dart). Entries are only ever added, so merging two
// copies of the log is just keeping every entry in either. To fit years of practice into iCloud's
// 1MB, the copy there is split up by month (in UTC), with each entry in a compact form.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/model.dart';
import '../services/cloud_store.dart';
import 'drill_config.dart';

/// The [PracticeLogEntry.drillId] of time spent playing the metronome (whose bpm is its config's).
const metronomeId = 'metronome';

class PracticeLogEntry {
  final DateTime completedAt;
  final String drillId;
  final DrillConfig config;
  // What it's called, for practice that isn't a drill: a metronome preset's name, or null for the
  // metronome's main settings.
  final String? title;
  // The drill's computed duration when it was completed (not wall-clock time, so pausing doesn't
  // count), kept rather than recomputed so that changes to the drill don't rewrite history.
  final int seconds;

  const PracticeLogEntry({
    required this.completedAt,
    required this.drillId,
    required this.config,
    required this.seconds,
    this.title,
  });

  // Which drill was completed when, which tells two copies of an entry apart from two entries.
  String get _id => '${completedAt.millisecondsSinceEpoch}:$drillId';

  // In UTC, so that the time doesn't move if the time zone changes.
  Map<String, dynamic> toJson() => {
    'completedAt': completedAt.toUtc().toIso8601String(),
    'drillId': drillId,
    'config': config.toJson(),
    'seconds': seconds,
    'title': ?title,
  };

  factory PracticeLogEntry.fromJson(Map<String, dynamic> json) => PracticeLogEntry(
    completedAt: DateTime.parse(json['completedAt'] as String),
    drillId: json['drillId'] as String,
    config: DrillConfig.fromJson(json['config'] as Map<String, dynamic>),
    seconds: json['seconds'] as int,
    title: json['title'] as String?,
  );

  // The compact form kept in iCloud, with the title (if any) on the end.
  List<Object> _toCloud() => [
    completedAt.millisecondsSinceEpoch,
    drillId,
    config.bpm,
    config.bpmIncrease,
    config.drillRepeat,
    config.swapHands ? 1 : 0,
    config.replayIntroOnBpmIncrease ? 1 : 0,
    seconds,
    ?title,
  ];

  static PracticeLogEntry _fromCloud(List<dynamic> json) => PracticeLogEntry(
    completedAt: DateTime.fromMillisecondsSinceEpoch(json[0] as int, isUtc: true),
    drillId: json[1] as String,
    config: DrillConfig(
      bpm: json[2] as int,
      bpmIncrease: json[3] as int,
      drillRepeat: json[4] as int,
      swapHands: json[5] == 1,
      replayIntroOnBpmIncrease: json[6] == 1,
    ),
    seconds: json[7] as int,
    title: json.length > 8 ? json[8] as String? : null,
  );

  // The iCloud key of the month this entry is kept under.
  String get _cloudKey {
    final utc = completedAt.toUtc();
    return '$_cloudPrefix${utc.year}-${utc.month.toString().padLeft(2, '0')}';
  }
}

const _cloudPrefix = 'practiceLog.';
final _cloudKeyPattern = RegExp(r'^practiceLog\.\d{4}-\d{2}$');

class PracticeLog extends ChangeNotifier {
  static const _key = 'practiceLog.entries';

  List<PracticeLogEntry> _entries = [];
  SharedPreferences? _prefs;
  bool _listening = false;

  /// Most recently completed drill first.
  List<PracticeLogEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    if (!_listening) {
      _listening = true;
      cloudStore.addListener((changed) {
        if (changed.any(_cloudKeyPattern.hasMatch)) _sync();
      });
    }
    _entries = [];
    var fromBeforeUtc = false;
    final saved = prefs.getString(_key);
    if (saved != null) {
      try {
        final list = jsonDecode(saved) as List<dynamic>;
        _entries = [
          for (final item in list) PracticeLogEntry.fromJson(item as Map<String, dynamic>),
        ];
        fromBeforeUtc = _entries.any((e) => !e.completedAt.isUtc);
      } catch (_) {
        _entries = [];
      }
    }
    // Pin entries saved in local time (before the log synced) to UTC before they're synced.
    if (fromBeforeUtc) _saveLocal();
    _sync();
  }

  void add(PracticeLogEntry entry) {
    _entries = [entry, ..._entries];
    _saveLocal();
    _sync();
  }

  /// Records that the metronome was just played for [seconds], starting at [bpm], with the preset
  /// called [name] (or its main settings, if null).
  void recordMetronome({String? name, required int bpm, required int seconds}) => add(
    PracticeLogEntry(
      completedAt: clock.now(),
      drillId: metronomeId,
      config: DrillConfig(bpm: bpm),
      seconds: seconds,
      title: name,
    ),
  );

  /// Records that [drill] was just completed at [config].
  void recordDrill(Drill drill, DrillConfig config) => add(
    PracticeLogEntry(
      completedAt: clock.now(),
      drillId: drill.id,
      config: config,
      seconds: drillDuration(drill, config).round(),
    ),
  );

  // Adds the entries in iCloud that are missing here, then puts any months that are missing
  // entries back in iCloud.
  void _sync() {
    final byId = {for (final e in _entries) e._id: e};
    final inCloud = <String, int>{};
    for (final key in cloudStore.keys.where(_cloudKeyPattern.hasMatch)) {
      try {
        final list = jsonDecode(cloudStore[key]!) as List<dynamic>;
        inCloud[key] = list.length;
        for (final item in list) {
          final entry = PracticeLogEntry._fromCloud(item as List<dynamic>);
          byId.putIfAbsent(entry._id, () => entry);
        }
      } catch (_) {
        // Rewrite it from what's here.
        inCloud[key] = 0;
      }
    }
    if (byId.length > _entries.length) {
      _entries = byId.values.toList()..sort((a, b) => b.completedAt.compareTo(a.completedAt));
      _saveLocal();
    }
    final months = <String, List<PracticeLogEntry>>{};
    for (final entry in _entries.reversed) {
      months.putIfAbsent(entry._cloudKey, () => []).add(entry);
    }
    // Everything in iCloud is here now too, so a month with more entries here is missing some.
    months.forEach((key, entries) {
      if (entries.length > (inCloud[key] ?? 0)) {
        cloudStore[key] = jsonEncode([for (final e in entries) e._toCloud()]);
      }
    });
    notifyListeners();
  }

  void _saveLocal() {
    _prefs?.setString(_key, jsonEncode([for (final e in _entries) e.toJson()]));
  }
}

/// The local calendar day (no time of day) that [dateTime] falls on, for comparing which days
/// drills were practiced on.
DateTime practiceDay(DateTime dateTime) {
  final local = dateTime.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// How long was spent practicing on each day (see [practiceDay]) that had any practice, in
/// seconds.
Map<DateTime, int> practiceByDay(Iterable<PracticeLogEntry> entries) {
  final byDay = <DateTime, int>{};
  for (final e in entries) {
    byDay.update(practiceDay(e.completedAt), (s) => s + e.seconds, ifAbsent: () => e.seconds);
  }
  return byDay;
}

/// How a day's practice ranks by how long it was (shown as fancier and fancier badges on the
/// practice calendars).
enum PracticeTier {
  none,
  practiced,
  tenMinutes,
  twentyMinutes;

  /// The tier for a day with [seconds] of practice (null for none at all).
  static PracticeTier of(int? seconds) => switch (seconds) {
    null => none,
    < 600 => practiced,
    < 1200 => tenMinutes,
    _ => twentyMinutes,
  };
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
