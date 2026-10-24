// Plays the metronome tool: each beat of the measure as its high tone, low tone, or silence, as
// quarter notes (or eighths, etc.) at the configured bpm, going faster every so many measures if
// it's set to.

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../state/metronome_settings.dart';
import '../state/practice_log.dart';
import 'metronome.dart';
import 'metronome_sounds.dart';

class MetronomePlayer extends ChangeNotifier {
  MetronomeConfig _config;
  final _metronome = Metronome();
  final MetronomeSounds Function() _makeSounds;
  MetronomeSounds? _sounds;
  bool _disposed = false;

  bool _playing = false;
  // The beat to play next, and the one last played (null before the first).
  int _next = 0;
  int? _beat;
  // The bpm it's playing at now, which goes up from the config's as it speeds up.
  int _bpm;
  // Measures played since it last sped up (or started).
  int _measures = 0;

  /// What to log time spent playing as (see [_logPractice]): a preset's name, or null for the
  /// metronome's main settings.
  String? practiceName;

  // Time spent playing that hasn't been logged yet, besides the current stretch of it, if it's
  // playing, since [_playingSince].
  Duration _unlogged = Duration.zero;
  DateTime? _playingSince;
  late final AppLifecycleListener _lifecycle;

  /// Plays [config] through the sounds [makeSounds] makes, when it first plays (by default, the
  /// metronome's beep and boop).
  MetronomePlayer(MetronomeConfig config, {MetronomeSounds Function()? makeSounds})
    : _config = config,
      _bpm = config.bpm,
      _makeSounds = makeSounds ?? MetronomeSounds.new {
    _metronome.onDue = _handleBeatsDue;
    // The app could be closed from the background, so log what's been played before it gets there.
    _lifecycle = AppLifecycleListener(onHide: _logPractice);
  }

  bool get playing => _playing;

  /// The beat of the measure last played, if it's playing.
  int? get beat => _playing ? _beat : null;

  /// The bpm it's playing at now (which goes up as it speeds up).
  int get bpm => _bpm;

  MetronomeConfig get config => _config;

  /// Changes the settings, taking effect from the next beat. A new bpm starts over from it, and
  /// restarts the count of measures to the next speed-up.
  set config(MetronomeConfig config) {
    final old = _config;
    _config = config;
    if (_next >= config.beats.length) _next = 0;
    if (config.bpm != old.bpm) {
      _bpm = config.bpm;
      _measures = 0;
    }
    if (_playing) _keepTime();
    notifyListeners();
  }

  /// Starts playing, from the first beat if it's just starting, or the next one if it was paused.
  Future<void> play() async {
    if (_playing) return;
    _playing = true;
    notifyListeners();
    WakelockPlus.enable();
    final sounds = _sounds ??= _makeSounds();
    await sounds.ready;
    if (_disposed || !_playing) return;
    _playingSince = clock.now();
    _playNext();
    _keepTime();
  }

  // Has the Metronome tick once per beat, at the current bpm and note. (A no-op if it already is.)
  void _keepTime() {
    // It counts sixteenth notes, so four of its ticks make a quarter note.
    _metronome.ensureRunning(bpm: _bpm, scale: 4 / _config.note.perQuarter);
  }

  void pause() {
    if (!_playing) return;
    _playing = false;
    if (_playingSince case final since?) _unlogged += clock.now().difference(since);
    _playingSince = null;
    _metronome.stop();
    _sounds?.pause();
    WakelockPlus.disable();
    notifyListeners();
  }

  void _handleBeatsDue(int due) {
    // If it's fallen behind, catch up, but only sound the latest beat.
    for (var i = 0; i < due; i++) {
      _playNext(sound: i == due - 1);
    }
  }

  void _playNext({bool sound = true}) {
    final beats = _config.beats;
    _beat = _next;
    if (sound) {
      switch (beats[_next]) {
        case BeatLevel.high:
          _sounds?.playBeep();
        case BeatLevel.low:
          _sounds?.playBoop();
        case BeatLevel.off:
          break;
      }
    }
    _next = (_next + 1) % beats.length;
    if (_next == 0 && _config.increaseEvery > 0 && ++_measures >= _config.increaseEvery) {
      _measures = 0;
      final faster = (_bpm + _config.bpmIncrease).clamp(_bpm, metronomeBpmLimits.max);
      if (faster != _bpm) {
        _bpm = faster;
        // From the next beat: the first of the next measure.
        _keepTime();
      }
    }
    notifyListeners();
  }

  // Logs the time spent playing since it was last logged to the practice log, if it adds up to a
  // minute or more (or else keeps counting it, towards the next time).
  void _logPractice() {
    final now = clock.now();
    final played =
        _unlogged + (_playingSince == null ? Duration.zero : now.difference(_playingSince!));
    if (played < const Duration(minutes: 1)) return;
    practiceLog.recordMetronome(name: practiceName, bpm: _config.bpm, seconds: played.inSeconds);
    _unlogged = Duration.zero;
    if (_playingSince != null) _playingSince = now;
  }

  @override
  void dispose() {
    _logPractice();
    _lifecycle.dispose();
    _disposed = true;
    if (_playing) WakelockPlus.disable();
    _metronome.dispose();
    _sounds?.dispose();
    super.dispose();
  }
}
