// Plays a taiko drum hit ("don", recorded from a real drum), e.g. when the menu's logo is drummed
// on.

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../model/model.dart';
import 'sound_engine.dart';

Future<AudioSource>? _loading;

Future<AudioSource> _load() => _loading ??=
    () async {
      await ensureSoundEngine();
      return SoLoud.instance.loadAsset('assets/sounds/don.mp3');
    }().catchError((Object error) {
      // Try again on the next hit.
      _loading = null;
      throw error;
    });

/// Starts loading the drum sound ahead of time, so that the first hit isn't late -- except on the
/// web, where browsers won't let audio start until the user has interacted with the page, and
/// starting the audio engine any earlier leaves it stuck silent. There, it loads on the first hit
/// instead (which is a user interaction), so just that first hit comes a little late.
void preloadTaikoDrum() {
  if (!kIsWeb) _load().ignore();
}

/// Plays a hit on the drum, panned a little towards the side of the [hand] that hit it. Quietly
/// does nothing if sound isn't available.
Future<void> hitTaikoDrum(Hand hand) async {
  try {
    final sound = await _load();
    SoLoud.instance.play(sound, pan: hand == Hand.R ? 0.25 : -0.25);
  } catch (_) {
    // No sound, but the drumming still counts.
  }
}
