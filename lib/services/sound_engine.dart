// Starts up the SoLoud audio engine that all of the app's sounds play through (see
// metronome_sounds.dart for why SoLoud), once, however many things need it.

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

Future<void>? _starting;
// Bumped whenever the engine restarts, which discards every loaded sound.
var _generation = 0;
final _loading = <String, Future<AudioSource>>{};
final _loaded = <String, AudioSource>{};

/// Completes once the audio engine is up and running, starting it if it isn't already. If starting
/// it fails, the next call tries again.
Future<void> ensureSoundEngine() {
  if (_starting case final starting?) return starting;
  late final Future<void> starting;
  starting = _start().catchError((Object error) {
    // Unless the engine's restarted since.
    if (identical(_starting, starting)) _starting = null;
    throw error;
  });
  return _starting = starting;
}

/// Loads the sound in [asset] (starting the engine if need be), once. If loading it fails, the
/// next call tries again.
Future<AudioSource> loadSound(String asset) {
  if (_loading[asset] case final loading?) return loading;
  final generation = _generation;
  late final Future<AudioSource> loading;
  loading =
      () async {
        await ensureSoundEngine();
        final sound = await SoLoud.instance.loadAsset(asset);
        // The engine restarted while this was loading, so this sound is gone with it.
        if (generation != _generation) return loadSound(asset);
        return _loaded[asset] = sound;
      }().catchError((Object error) {
        if (identical(_loading[asset], loading)) _loading.remove(asset);
        throw error;
      });
  return _loading[asset] = loading;
}

/// The sound in [asset], if it's been loaded (see [loadSound]). Look sounds up here each time
/// they're played rather than keeping them: the engine sometimes has to restart, which replaces
/// them all.
AudioSource? loadedSound(String asset) => _loaded[asset];

var _watching = false;
var _interrupted = false;

// iOS interrupts the audio session when the app goes into the background, and doesn't always say
// when that interruption is over. SoLoud refuses to start its output device until it hears that
// the interruption ended, so after one of those, sound would stay off for good. The only way to
// clear that from here is to restart the engine, so if the app comes back with an interruption
// still unfinished, restart it and reload the sounds.
void _watchInterruptions(AudioSession session) {
  if (_watching) return;
  _watching = true;
  session.interruptionEventStream.listen((event) => _interrupted = event.begin);
  AppLifecycleListener(
    onResume: () {
      final iOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      if (iOS && _interrupted && _starting != null) _restart();
    },
  );
}

void _restart() {
  logSound('restarting after an unfinished interruption');
  _interrupted = false;
  final assets = {..._loading.keys};
  _generation++;
  _loading.clear();
  _loaded.clear();
  _starting = null;
  if (SoLoud.instance.isInitialized) SoLoud.instance.deinit();
  for (final asset in assets) {
    loadSound(asset).ignore();
  }
}

Future<void> _start() async {
  if (SoLoud.instance.isInitialized) return;
  // SoLoud leaves the iOS AVAudioSession entirely to the app, and the session has to be configured
  // and active *before* SoLoud starts its output unit: one started against an inactive session
  // stays silent. This is `.music()` (AVAudioSessionCategory.playback, which plays through the
  // silent switch, and music-style audio attributes on Android), except that it doesn't stop music
  // that's already playing: on iOS the metronome mixes with it, and on Android (which has no way
  // to just mix) it asks for focus that ducks it instead. On other platforms it's a no-op.
  final session = await AudioSession.instance;
  _watchInterruptions(session);
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

/// Logs [message] about a sound problem, outside of release builds.
void logSound(String message) {
  if (!kReleaseMode) debugPrint('[sound] $message');
}
