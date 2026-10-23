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

import 'sound_engine.dart';

const _beep = 'assets/sounds/beep.wav';
const _boop = 'assets/sounds/boop.wav';

class MetronomeSounds {
  // The engine and the two tones are loaded once, and shared (see sound_engine.dart): each
  // MetronomeSounds instance is just a cheap handle onto them, so constructing one for every
  // practice session is fine, and dispose() intentionally tears nothing down.

  /// Resolves once both tones are loaded and playable. Loading is asynchronous even for these
  /// tiny local assets -- it can never complete within the same synchronous call stack that
  /// constructs this class. A caller that fires its first tick immediately after construction (as
  /// the drill practice screen does, so the first beat lines up with the moment the screen
  /// appears) needs to await this first, or that first tick's sound has nothing loaded to play.
  late final Future<void> ready;

  MetronomeSounds() {
    ready = _load();
  }

  // If sound can't be started, this still completes (so the drill plays, silently), and the next
  // drill tries again.
  Future<void> _load() async {
    try {
      await Future.wait([loadSound(_beep), loadSound(_boop)]);
      _keepDeviceRunning(true);
    } catch (e) {
      logSound('metronome tones failed to load: $e');
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
