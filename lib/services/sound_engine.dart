// Starts up the SoLoud audio engine that all of the app's sounds play through (see
// metronome_sounds.dart for why SoLoud), once, however many things need it.

import 'package:audio_session/audio_session.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

Future<void>? _starting;

/// Completes once the audio engine is up and running, starting it if it isn't already. If starting
/// it fails, the next call tries again.
Future<void> ensureSoundEngine() => _starting ??= _start().catchError((Object error) {
  _starting = null;
  throw error;
});

Future<void> _start() async {
  if (SoLoud.instance.isInitialized) return;
  // SoLoud leaves the iOS AVAudioSession entirely to the app, and the session has to be configured
  // and active *before* SoLoud starts its output unit: one started against an inactive session
  // stays silent. This is `.music()` (AVAudioSessionCategory.playback, which plays through the
  // silent switch, and music-style audio attributes on Android), except that it doesn't stop music
  // that's already playing: on iOS the metronome mixes with it, and on Android (which has no way
  // to just mix) it asks for focus that ducks it instead. On other platforms it's a no-op.
  final session = await AudioSession.instance;
  await session.configure(
    const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
    ),
  );
  if (!await session.setActive(true)) throw StateError('Audio session could not be activated');
  // A small buffer keeps output latency low and consistent -- SoLoud's default (2048 samples,
  // ~46ms at 44.1kHz) is tuned for general-purpose playback, not tight rhythmic triggering.
  await SoLoud.instance.init(bufferSize: 512, lowLatency: true);
}
