// The user's practice reminders -- each with a time of day, which days of the week it fires on,
// and a custom message -- persisted to local storage.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultReminderMessage = "Mr. Driller says it's time to practice!";

/// Every day of the week, in [DateTime.weekday] order (Monday = 1 .. Sunday = 7) -- the order
/// reminders' day-toggles and summaries are shown in.
const List<int> allWeekdays = [1, 2, 3, 4, 5, 6, 7];

const _weekdayAbbreviations = {
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

String weekdayAbbreviation(int weekday) => _weekdayAbbreviations[weekday]!;

class ReminderConfig {
  final int id;
  final int hour;
  final int minute;
  final Set<int> days;
  final String message;

  const ReminderConfig({
    required this.id,
    required this.hour,
    required this.minute,
    required this.days,
    this.message = defaultReminderMessage,
  });

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  ReminderConfig copyWith({int? hour, int? minute, Set<int>? days, String? message}) =>
      ReminderConfig(
        id: id,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        days: days ?? this.days,
        message: message ?? this.message,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'days': days.toList()..sort(),
    'message': message,
  };

  factory ReminderConfig.fromJson(Map<String, dynamic> json) => ReminderConfig(
    id: json['id'] as int,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    days: {for (final d in json['days'] as List<dynamic>) d as int},
    message: json['message'] as String? ?? defaultReminderMessage,
  );
}

class ReminderList extends ChangeNotifier {
  static const _key = 'reminders.entries';

  List<ReminderConfig> _entries = [];
  SharedPreferences? _prefs;

  List<ReminderConfig> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final saved = prefs.getString(_key);
    if (saved != null) {
      try {
        final list = jsonDecode(saved) as List<dynamic>;
        _entries = [for (final item in list) ReminderConfig.fromJson(item as Map<String, dynamic>)];
      } catch (_) {
        _entries = [];
      }
    }
    notifyListeners();
  }

  void add(ReminderConfig reminder) {
    _entries = [..._entries, reminder];
    _save();
  }

  void updateAt(int index, ReminderConfig reminder) {
    _entries = [..._entries];
    _entries[index] = reminder;
    _save();
  }

  void removeAt(int index) {
    _entries = [..._entries]..removeAt(index);
    _save();
  }

  void _save() {
    _prefs?.setString(_key, jsonEncode([for (final e in _entries) e.toJson()]));
    notifyListeners();
  }
}

/// App-wide singleton, initialized once at startup (see main.dart).
final ReminderList reminders = ReminderList();
