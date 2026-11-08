// Plays the metronome beep/boop tones during a drill.
//
// Built on SoLoud (via flutter_soloud) rather than audioplayers. audioplayers' `resume()`/`seek()`
// calls cross Flutter's platform channel to reach the native media player (AVAudioPlayer/
// SoundPool/etc.) asynchronously, and that round trip's own jitter was audible as erratic
// metronome timing -- no amount of Dart-side scheduling precision can fix a delay that happens
// after the call already left Dart. SoLoud's `play()` is a direct, synchronous call straight into
// the native engine (flutter_soloud is FFI-based, not platform-channel-based), which removes that
// source of jitter entirely. It still isn't true sample-accurate scheduling (there's no API here
// to say "play at exactly this future time", only "play now"), but "now" arrives with far less
// delay and far less variance than it did through audioplayers.

import 'package:flutter_soloud/flutter_soloud.dart';

import '../model/click_sound.dart';
import '../state/settings.dart';
import 'sound_engine.dart';

class MetronomeSounds {
  /// What it clicks with: the "beep" is its high sound and the "boop" its low one.
  final ClickSound sound;
  String get _beep => sound.high;
  String get _boop => sound.low;

  // The engine and the two tones are loaded once, and shared (see sound_engine.dart): each
  // MetronomeSounds instance is just a cheap handle onto them, so constructing one for every
  // practice session is fine, and dispose() intentionally tears nothing down.

  /// Resolves once both tones are loaded and playable. Loading is asynchronous even for these
  /// tiny local assets -- it can never complete within the same synchronous call stack that
  /// constructs this class. Callers should await [start] rather than this, though.
  late final Future<void> ready;

  /// Clicks with [sound], or the one chosen in the settings.
  MetronomeSounds({ClickSound? sound}) : sound = sound ?? settings.clickSound {
    ready = _load();
  }

  // If sound can't be started, this still completes (so the drill plays, silently), and the next
  // drill tries again.
  Future<void> _load() async {
    try {
      await Future.wait([loadSound(_beep), loadSound(_boop)]);
    } catch (e) {
      logSound('metronome tones failed to load: $e');
    }
  }

  /// Gets ready to play: resolves once the tones are loaded *and* the audio output device is
  /// running. Await this before the first beat (and before resuming after [pause]). SoLoud stops
  /// its device when nothing has played for a while, and if the first beat is what starts it
  /// again, that beat (and often the next couple) comes out late while the device spins up, which
  /// was audible as a stuttering start to every drill. Starting it ahead of time avoids that.
  Future<void> start() async {
    await ready;
    if (_disposed || !SoLoud.instance.isInitialized) return;
    _keepDeviceRunning(true);
    try {
      await SoLoud.instance.startAudioDevice();
    } catch (e) {
      logSound('audio device failed to start: $e');
    }
  }

  void playBeep() => _play(_beep);

  void playBoop() => _play(_boop);

  void _play(String asset) {
    final sound = loadedSound(asset);
    if (sound == null) return logSound('$asset not loaded');
    _keepDeviceRunning(true);
    SoLoud.instance.play(sound);
  }

  /// The audio engine's clock, which [scheduleBeep] and [scheduleBoop] schedule against, or null if
  /// sound isn't working. It only advances while the output device runs (see [start]), and then
  /// in steps, at the start of each buffer that it mixes.
  ///
  /// With [running], also null unless the output device is running, as the clock is stopped
  /// otherwise.
  Duration? engineTime({bool running = false}) {
    final soloud = SoLoud.instance;
    if (!soloud.isInitialized) return null;
    if (running && soloud.getAudioDeviceState() != AudioDeviceState.started) return null;
    return soloud.getEngineTime();
  }

  /// Plays the beep at [at] on the engine's clock (see [engineTime]), exactly, however busy the
  /// app happens to be then. Unlike [playBeep], which plays at the start of whichever buffer is
  /// mixed next after the app gets around to calling it. Returns a handle that [cancel] takes.
  SoundHandle? scheduleBeep(Duration at) => _schedule(_beep, at);

  SoundHandle? scheduleBoop(Duration at) => _schedule(_boop, at);

  SoundHandle? _schedule(String asset, Duration at) {
    final sound = loadedSound(asset);
    if (sound == null) {
      logSound('$asset not loaded');
      return null;
    }
    _keepDeviceRunning(true);
    return SoLoud.instance.playScheduled(sound, at);
  }

  /// Stops a sound from [scheduleBeep] or [scheduleBoop], if it hasn't played yet.
  void cancel(SoundHandle handle) {
    if (!SoLoud.instance.isInitialized) return;
    SoLoud.instance.stop(handle).catchError((Object e) => logSound('stop failed: $e'));
  }

  /// Called whenever the metronome stops (paused, or done).
  void pause() => _keepDeviceRunning(false);

  void dispose() {
    _disposed = true;
    _keepDeviceRunning(false);
  }

  // SoLoud normally stops its output device once nothing has played for half a second, and starts
  // it again for the next sound, which at slow tempos would mean restarting it (and risking a late
  // start) for every beat. So while any metronome is running, keep the device running too.
  static const _defaultIdleTimeout = Duration(milliseconds: 500);
  static var _running = 0;
  bool _keepingDeviceRunning = false;
  bool _disposed = false;

  void _keepDeviceRunning(bool keep) {
    if (keep == _keepingDeviceRunning || (keep && _disposed)) return;
    _keepingDeviceRunning = keep;
    _running += keep ? 1 : -1;
    SoLoud.instance.setAudioDeviceIdleTimeout(_running > 0 ? null : _defaultIdleTimeout);
  }
}
