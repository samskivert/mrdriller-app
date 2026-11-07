// Plays the metronome tool: each beat of the measure as its high tone, low tone, or silence, as
// quarter notes (or eighths, etc.) at the configured bpm, going faster every so many measures if
// it's set to.

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../state/metronome_settings.dart';
import '../state/practice_log.dart';
import 'click_scheduler.dart';
import 'metronome.dart';
import 'metronome_sounds.dart';

class MetronomePlayer extends ChangeNotifier {
  MetronomeConfig _config;
  final _metronome = Metronome();
  final MetronomeSounds Function() _makeSounds;
  MetronomeSounds? _sounds;
  ClickScheduler? _scheduler;
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
    if (_playing) {
      _keepTime();
      // What's coming up has changed.
      _scheduler?.reset();
    }
    notifyListeners();
  }

  /// Starts playing, from the first beat if it's just starting, or the next one if it was paused.
  Future<void> play() async {
    if (_playing) return;
    _playing = true;
    notifyListeners();
    WakelockPlus.enable();
    final sounds = _sounds ??= _makeSounds();
    _scheduler ??= ClickScheduler(metronome: _metronome, sounds: sounds, clicksFor: _clicksFor);
    await sounds.start();
    if (_disposed || !_playing) return;
    _playingSince = clock.now();
    // The first beat plays at once, and the metronome's ticks (scheduled ahead) play the rest.
    _playNext(sound: true);
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
    _scheduler?.reset();
    _sounds?.pause();
    WakelockPlus.disable();
    notifyListeners();
  }

  void _handleBeatsDue(int due) {
    // (If it's fallen behind, this catches up.)
    for (var i = 0; i < due; i++) {
      _playNext();
    }
  }

  static List<Click> _clicksOf(BeatLevel level) => switch (level) {
    BeatLevel.high => const [Click.beep],
    BeatLevel.low => const [Click.boop],
    BeatLevel.off => const [],
  };

  // The clicks on the metronome's tick [ahead] ticks after the current one (see ClicksFor): the
  // beat that'll be playing then, unless it speeds up before then.
  List<Click>? _clicksFor(int ahead) {
    final beats = _config.beats;
    if (ahead == 0) return _clicksOf(beats[_beat ?? 0]);
    var measures = _measures;
    // Each tick before that one, which plays one beat, and speeds up after the last of a measure.
    for (var i = 1; i < ahead; i++) {
      final finishesMeasure = (_next + i) % beats.length == 0;
      if (finishesMeasure && _config.increaseEvery > 0 && ++measures >= _config.increaseEvery) {
        if (_faster() != _bpm) return null;
        measures = 0;
      }
    }
    return _clicksOf(beats[(_next + ahead - 1) % beats.length]);
  }

  int _faster() => (_bpm + _config.bpmIncrease).clamp(_bpm, metronomeBpmLimits.max);

  void _playNext({bool sound = false}) {
    final beats = _config.beats;
    _beat = _next;
    if (sound) {
      for (final click in _clicksOf(beats[_next])) {
        click == Click.beep ? _sounds?.playBeep() : _sounds?.playBoop();
      }
    }
    _next = (_next + 1) % beats.length;
    if (_next == 0 && _config.increaseEvery > 0 && ++_measures >= _config.increaseEvery) {
      _measures = 0;
      final faster = _faster();
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
    _scheduler?.dispose();
    _metronome.dispose();
    _sounds?.dispose();
    super.dispose();
  }
}
