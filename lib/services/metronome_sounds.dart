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

typedef _Tones = ({AudioSource beep, AudioSource boop});

class MetronomeSounds {
  // The engine and the two loaded tones are process-wide singletons (SoLoud.instance itself is a
  // singleton, and re-initializing/reloading it every time a drill starts would be slow and
  // wasteful) -- each MetronomeSounds instance is just a cheap handle onto that shared state, so
  // constructing one for every practice session is fine, and dispose() intentionally tears
  // nothing down.
  static Future<_Tones>? _loading;

  AudioSource? _beepSource;
  AudioSource? _boopSource;

  /// Resolves once both tones are loaded and playable. Loading is asynchronous even for these
  /// tiny local assets -- it can never complete within the same synchronous call stack that
  /// constructs this class. A caller that fires its first tick immediately after construction (as
  /// the drill practice screen does, so the first beat lines up with the moment the screen
  /// appears) needs to await this first, or that first tick's sound has nothing loaded to play.
  late final Future<void> ready;

  MetronomeSounds() {
    ready = _load();
  }

  Future<void> _load() async {
    final tones = await (_loading ??= _initEngineAndLoad());
    _beepSource = tones.beep;
    _boopSource = tones.boop;
  }

  static Future<_Tones> _initEngineAndLoad() async {
    await ensureSoundEngine();
    final beep = await SoLoud.instance.loadAsset('assets/sounds/beep.wav');
    final boop = await SoLoud.instance.loadAsset('assets/sounds/boop.wav');
    return (beep: beep, boop: boop);
  }

  void playBeep() {
    final source = _beepSource;
    if (source != null) SoLoud.instance.play(source);
  }

  void playBoop() {
    final source = _boopSource;
    if (source != null) SoLoud.instance.play(source);
  }

  void pause() {}

  void dispose() {}
}
