// The user's practice plan: an ordered list of drills, each with its own starting bpm/bpm
// increase/repeat count, persisted to local storage.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drill_config.dart';

class PracticePlanEntry {
  final String drillId;
  final DrillConfig config;

  const PracticePlanEntry({required this.drillId, required this.config});

  Map<String, dynamic> toJson() => {'drillId': drillId, 'config': config.toJson()};

  factory PracticePlanEntry.fromJson(Map<String, dynamic> json) => PracticePlanEntry(
    drillId: json['drillId'] as String,
    config: DrillConfig.fromJson(json['config'] as Map<String, dynamic>),
  );
}

class PracticePlan extends ChangeNotifier {
  static const _key = 'practicePlan.entries';

  List<PracticePlanEntry> _entries = [];
  SharedPreferences? _prefs;

  List<PracticePlanEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final saved = prefs.getString(_key);
    if (saved != null) {
      try {
        final list = jsonDecode(saved) as List<dynamic>;
        _entries = [
          for (final item in list) PracticePlanEntry.fromJson(item as Map<String, dynamic>),
        ];
      } catch (_) {
        _entries = [];
      }
    }
    notifyListeners();
  }

  void add(PracticePlanEntry entry) {
    _entries = [..._entries, entry];
    _save();
  }

  void updateAt(int index, PracticePlanEntry entry) {
    _entries = [..._entries];
    _entries[index] = entry;
    _save();
  }

  void removeAt(int index) {
    _entries = [..._entries]..removeAt(index);
    _save();
  }

  void reorder(int oldIndex, int newIndex) {
    final updated = [..._entries];
    final entry = updated.removeAt(oldIndex);
    updated.insert(newIndex, entry);
    _entries = updated;
    _save();
  }

  void _save() {
    _prefs?.setString(_key, jsonEncode([for (final e in _entries) e.toJson()]));
    notifyListeners();
  }
}

/// App-wide singleton, initialized once at startup (see main.dart).
final PracticePlan practicePlan = PracticePlan();
