// The app's name, as shown everywhere in the app. It's "Taiko Trainer" -- but a secret easter egg
// (drumming the matsuri base beat on the menu's logo, see [DrumPatternDetector]) unlocks its
// original name, "Mr. Driller", after the Namco game whose look inspired it.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/model.dart';

const _key = 'easterEgg.mrDriller';

/// Whether the Mr. Driller easter egg has been unlocked. Anything that shows [appName] should
/// rebuild when this changes.
final ValueNotifier<bool> mrDrillerUnlocked = ValueNotifier(false);

/// The app's name: "Taiko Trainer", or "Mr. Driller" once [mrDrillerUnlocked].
String appName() => mrDrillerUnlocked.value ? 'Mr. Driller' : 'Taiko Trainer';

/// Restores whether the easter egg was unlocked last time. Call once at startup.
Future<void> loadAppName() async {
  final prefs = await SharedPreferences.getInstance();
  mrDrillerUnlocked.value = prefs.getBool(_key) ?? false;
}

/// Unlocks (or locks back up) the easter egg, remembering that for next time.
Future<void> setMrDrillerUnlocked(bool unlocked) async {
  mrDrillerUnlocked.value = unlocked;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_key, unlocked);
}

/// The secret drum pattern: the matsuri base beat, four times over.
final List<Hand> secretDrumPattern = [
  for (var i = 0; i < 4; i++) ...[Hand.R, Hand.R, Hand.L, Hand.R, Hand.L],
];

/// Watches a series of drum hits for [pattern], played through with no pause between hits longer
/// than [maxGap] (a longer pause starts over).
class DrumPatternDetector {
  final List<Hand> pattern;
  final Duration maxGap;

  DrumPatternDetector({List<Hand>? pattern, this.maxGap = const Duration(milliseconds: 1500)})
    : pattern = pattern ?? secretDrumPattern;

  final List<Hand> _hits = [];
  DateTime? _lastHit;

  /// Records a hit by [hand] at [at], and says whether it completed the pattern (which then starts
  /// over).
  bool hit(Hand hand, DateTime at) {
    final last = _lastHit;
    if (last != null && at.difference(last) > maxGap) _hits.clear();
    _lastHit = at;
    _hits.add(hand);
    if (_hits.length > pattern.length) _hits.removeAt(0);
    if (_hits.length == pattern.length && listEquals(_hits, pattern)) {
      _hits.clear();
      return true;
    }
    return false;
  }
}
