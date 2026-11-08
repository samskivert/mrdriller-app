// Global user settings, persisted to local storage and synced through iCloud (see sync.dart).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/click_sound.dart';
import '../model/grading.dart';
import '../services/cloud_store.dart';
import 'sync.dart';

class Settings extends ChangeNotifier {
  static const _key = 'settings';
  // Where the setting was kept before settings synced.
  static const _oldShowBouncingDotKey = 'settings.showBouncingDot';

  bool _showBouncingDot = true;
  GradingDifficulty _gradingDifficulty = GradingDifficulty.normal;
  ClickSound _clickSound = ClickSound.classic;
  SharedPreferences? _prefs;
  bool _listening = false;

  bool get showBouncingDot => _showBouncingDot;

  /// How strictly hits on a drum pad are judged.
  GradingDifficulty get gradingDifficulty => _gradingDifficulty;

  /// What the metronome clicks with.
  ClickSound get clickSound => _clickSound;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    if (!_listening) {
      _listening = true;
      cloudStore.addListener((changed) {
        if (changed.contains(_key)) _sync();
      });
    }
    _sync();
  }

  void setShowBouncingDot(bool value) {
    _showBouncingDot = value;
    _save();
  }

  void setGradingDifficulty(GradingDifficulty value) {
    _gradingDifficulty = value;
    _save();
  }

  void setClickSound(ClickSound value) {
    _clickSound = value;
    _save();
  }

  // (All of them together, as they're stamped and synced as one.)
  void _save() {
    final prefs = _prefs;
    if (prefs != null) {
      saveLatest(prefs, _key, {
        'showBouncingDot': _showBouncingDot,
        'gradingDifficulty': _gradingDifficulty.name,
        'clickSound': _clickSound.name,
      });
    }
    notifyListeners();
  }

  void _sync() {
    final prefs = _prefs;
    if (prefs == null) return;
    final merged = syncDoc(prefs, _key, (local, cloud) {
      final old = prefs.get(_oldShowBouncingDotKey);
      return mergeLatest(local ?? (old is bool ? {'showBouncingDot': old} : null), cloud);
    });
    final values = Stamped.read(merged)?.v;
    final showBouncingDot = values is Map ? values['showBouncingDot'] : null;
    _showBouncingDot = showBouncingDot is bool ? showBouncingDot : true;
    final difficulty = values is Map ? values['gradingDifficulty'] : null;
    _gradingDifficulty =
        GradingDifficulty.values.asNameMap()[difficulty] ?? GradingDifficulty.normal;
    final clickSound = values is Map ? values['clickSound'] : null;
    _clickSound = ClickSound.values.asNameMap()[clickSound] ?? ClickSound.classic;
    notifyListeners();
  }
}

/// App-wide singleton, initialized once at startup (see main.dart).
final Settings settings = Settings();
