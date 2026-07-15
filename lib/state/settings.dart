// Global user settings, persisted to local storage.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  static const _showBouncingDotKey = 'settings.showBouncingDot';
  static const _replayIntroOnBpmIncreaseKey = 'settings.replayIntroOnBpmIncrease';

  bool _showBouncingDot = true;
  bool _replayIntroOnBpmIncrease = true;
  SharedPreferences? _prefs;

  bool get showBouncingDot => _showBouncingDot;
  bool get replayIntroOnBpmIncrease => _replayIntroOnBpmIncrease;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _showBouncingDot = prefs.getBool(_showBouncingDotKey) ?? true;
    _replayIntroOnBpmIncrease = prefs.getBool(_replayIntroOnBpmIncreaseKey) ?? true;
    notifyListeners();
  }

  void setShowBouncingDot(bool value) {
    _showBouncingDot = value;
    _prefs?.setBool(_showBouncingDotKey, value);
    notifyListeners();
  }

  void setReplayIntroOnBpmIncrease(bool value) {
    _replayIntroOnBpmIncrease = value;
    _prefs?.setBool(_replayIntroOnBpmIncreaseKey, value);
    notifyListeners();
  }
}

/// App-wide singleton, initialized once at startup (see main.dart).
final Settings settings = Settings();
