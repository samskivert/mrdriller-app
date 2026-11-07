import 'dart:typed_data';

import 'mic_recorder_stub.dart' if (dart.library.js_interop) 'mic_recorder_web.dart' as impl;

/// Thrown by [MicRecorder.open] when the microphone isn't available: unsupported, or permission
/// refused.
class MicUnavailable implements Exception {
  final String message;

  const MicUnavailable(this.message);

  @override
  String toString() => message;
}

/// Records the microphone, raw (no echo cancellation, noise suppression or gain control, which
/// would take out or smear the sounds being timed), from when it's opened until it's closed.
/// Currently only implemented on web.
abstract class MicRecorder {
  static bool get isSupported => impl.isSupported;

  /// Starts recording, which may prompt the user for permission. Throws [MicUnavailable] if it
  /// can't.
  static Future<MicRecorder> open() => impl.open();

  double get sampleRate;

  /// Everything recorded since it opened (or was last [clear]ed), up to a minute and a half, as
  /// one channel. The first sample is the recorder's frame [startFrame].
  Float32List get samples;
  int get startFrame;

  /// How loud the latest moment recorded was, from 0 to 1.
  double get level;

  void clear();

  /// The recorder's frame at [ms] on `performance.now()`'s clock (the MIDI one), roughly: within
  /// a few tens of milliseconds, as it doesn't know its input's delay.
  double frameAt(double ms);

  void close();
}
