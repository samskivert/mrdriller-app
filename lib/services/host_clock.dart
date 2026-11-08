// The clock that MIDI messages and microphone samples are timestamped on, on iOS and Android (only
// imported on platforms with dart:io; on web, everything's on performance.now()):
//
// - iOS: CoreMIDI and AVAudioEngine stamp with mach_absolute_time, which is CLOCK_UPTIME_RAW,
//   read here through FFI. (Not Dart's own monotonic clock, CLOCK_MONOTONIC_RAW, which keeps
//   counting while the device sleeps, so drifts away from it by every sleep.)
// - Android: android.media.midi and AudioRecord's timestamps use System.nanoTime(), which is
//   CLOCK_MONOTONIC, the same clock as Dart's own monotonic one, which Timeline.now reads (in
//   microseconds).

import 'dart:developer' show Timeline;
import 'dart:ffi';
import 'dart:io' show Platform;

typedef _ClockNative = Uint64 Function(Int32 clock);
typedef _ClockDart = int Function(int clock);
const _clockUptimeRaw = 8;
final _clockGettimeNsec = Platform.isIOS
    ? DynamicLibrary.process().lookupFunction<_ClockNative, _ClockDart>('clock_gettime_nsec_np')
    : null;

/// The current time on the host clock (see above), in milliseconds.
double hostClockMs() {
  final clock = _clockGettimeNsec;
  return clock != null ? clock(_clockUptimeRaw) / 1e6 : Timeline.now / 1000;
}
