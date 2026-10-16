// Starts up the SoLoud audio engine that all of the app's sounds play through (see
// metronome_sounds.dart for why SoLoud), once, however many things need it.

import 'package:audio_session/audio_session.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

Future<void>? _starting;

/// Completes once the audio engine is up and running, starting it if it isn't already.
Future<void> ensureSoundEngine() => _starting ??= _start();

Future<void> _start() async {
  if (SoLoud.instance.isInitialized) return;
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
