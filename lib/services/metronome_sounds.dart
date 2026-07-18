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

import 'package:audio_session/audio_session.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

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
    if (!SoLoud.instance.isInitialized) {
      // A small buffer keeps output latency low and consistent -- SoLoud's default (2048 samples,
      // ~46ms at 44.1kHz) is tuned for general-purpose playback, not tight rhythmic triggering.
      await SoLoud.instance.init(bufferSize: 512, lowLatency: true);
      // SoLoud's own iOS session-category setup (deep in its vendored miniaudio backend) doesn't
      // reliably land on a category that ignores the mute switch -- it depends on which of a few
      // internal init paths it happens to take, and in practice we saw it land on one that
      // respects the switch. Configuring the shared AVAudioSession ourselves, *after* SoLoud's own
      // init has already run, makes this the last word on the matter: `.music()` sets
      // AVAudioSessionCategory.playback, which (like AudioContextConfig(respectSilence: false) in
      // the old audioplayers setup) plays through the silent switch. This also gives Android
      // proper music-style audio focus/attributes; on other platforms it's a no-op.
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    }
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
