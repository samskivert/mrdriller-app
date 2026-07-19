// A log of completed daily practice sessions (see daily_practice_screen.dart), persisted to local
// storage. An entry is only recorded when the user reaches the end of a session and confirms it
// via the outro screen's "Log it!" button -- bailing out early logs nothing.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PracticeLogEntry {
  final DateTime completedAt;
  final int drillCount;
  final int totalSeconds;

  const PracticeLogEntry({
    required this.completedAt,
    required this.drillCount,
    required this.totalSeconds,
  });

  Map<String, dynamic> toJson() => {
    'completedAt': completedAt.toIso8601String(),
    'drillCount': drillCount,
    'totalSeconds': totalSeconds,
  };

  factory PracticeLogEntry.fromJson(Map<String, dynamic> json) => PracticeLogEntry(
    completedAt: DateTime.parse(json['completedAt'] as String),
    drillCount: json['drillCount'] as int,
    totalSeconds: json['totalSeconds'] as int,
  );
}

class PracticeLog extends ChangeNotifier {
  static const _key = 'practiceLog.entries';

  List<PracticeLogEntry> _entries = [];
  SharedPreferences? _prefs;

  /// Most recently completed session first.
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

  void _save() {
    _prefs?.setString(_key, jsonEncode([for (final e in _entries) e.toJson()]));
    notifyListeners();
  }
}

/// App-wide singleton, initialized once at startup (see main.dart).
final PracticeLog practiceLog = PracticeLog();
