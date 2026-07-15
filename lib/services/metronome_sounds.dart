// Plays the metronome beep/boop tones during a drill.
//
// Uses two pooled AudioPlayers (one per tone) so rapid-fire ticks can restart the sample
// immediately (audioplayers reuses a single player's underlying source but `resume` after a
// `seek(Duration.zero)` gives us low-latency, overlap-safe retriggering).

import 'package:audioplayers/audioplayers.dart';

class MetronomeSounds {
  final AudioPlayer _beepPlayer = AudioPlayer();
  final AudioPlayer _boopPlayer = AudioPlayer();
  bool _ready = false;

  MetronomeSounds() {
    _beepPlayer.setReleaseMode(ReleaseMode.stop);
    _boopPlayer.setReleaseMode(ReleaseMode.stop);
    _beepPlayer.setPlayerMode(PlayerMode.lowLatency);
    _boopPlayer.setPlayerMode(PlayerMode.lowLatency);
    Future.wait([
      _beepPlayer.setSource(AssetSource('sounds/beep.wav')),
      _boopPlayer.setSource(AssetSource('sounds/boop.wav')),
    ]).then((_) => _ready = true);
  }

  void playBeep() {
    if (!_ready) return;
    _beepPlayer.seek(Duration.zero);
    _beepPlayer.resume();
  }

  void playBoop() {
    if (!_ready) return;
    _boopPlayer.seek(Duration.zero);
    _boopPlayer.resume();
  }

  /// Must be called from a user gesture (tap) handler, to unlock audio playback on browsers that
  /// require it. The iOS silent-switch bypass is instead handled once, globally, by the
  /// `AudioContextConfig(respectSilence: false)` set in `main.dart` (equivalent to the web app's
  /// `AVAudioSessionCategory.playback`).
  void resume() {
    _beepPlayer.setVolume(0);
    _beepPlayer.resume();
    Future.delayed(const Duration(milliseconds: 30), () {
      _beepPlayer.pause();
      _beepPlayer.setVolume(1);
    });
  }

  void pause() {}

  void dispose() {
    _beepPlayer.dispose();
    _boopPlayer.dispose();
  }
}
