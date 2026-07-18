import 'dart:async';

import 'package:clock/clock.dart';

/// Drives a steady beat at a given bpm (quarter notes, further scaled by an optional [scale]
/// factor passed to [ensureRunning]), calling [onDue] once elapsed time says a beat is due.
///
/// Elapsed time is measured from [clock.now()] (a monotonic-in-practice clock unaffected by GC
/// pauses or a busy isolate, and one that tests can override via `package:fake_async`'s zone --
/// see metronome_test.dart) rather than by counting how many times an internal poll happened to
/// fire. A [Timer.periodic] alone doesn't guarantee that: if the isolate is busy when one fire is
/// due, the next one still only advances the beat count by one, and the schedule quietly slides
/// later and later forever. Comparing against real elapsed time instead means a late poll just
/// notices multiple beats are newly due all at once and reports that count via [onDue], so the
/// caller can catch its own state up in a single step instead of drifting.
///
/// The poll itself runs much more often than any actual beat interval (even at max bpm and the
/// fastest known drill scale, the interval between beats doesn't go below ~30ms) -- that's what
/// keeps a late-firing poll from itself becoming a source of drift: a delayed poll only notices a
/// beat a few milliseconds late, rather than a whole beat-interval late the way waiting for one
/// big Timer.periodic tick fired once per beat would.
class Metronome {
  static const _pollInterval = Duration(milliseconds: 5);

  final void Function(int beatsDue) onDue;

  Metronome({required this.onDue});

  Timer? _pollTimer;
  DateTime? _startTime;
  int _intervalUs = 0;
  int _processed = 0;

  /// Starts ticking at [bpm] (scaled by [scale]), or re-bases the schedule if it's already running
  /// at a different bpm/scale. Rebasing starts the next beat exactly one interval from *now*,
  /// rather than measuring against elapsed time that belonged to a different interval -- which
  /// would otherwise read as a pile of beats suddenly overdue. Calling this again with the same
  /// bpm/scale while already running is a no-op, so callers can call it unconditionally on every
  /// state change without worrying about restarting an already-correct schedule.
  void ensureRunning({required int bpm, double scale = 1}) {
    final intervalUs = ((60000000 / bpm / 4) * scale).round();
    if (_pollTimer != null && intervalUs == _intervalUs) return;
    _pollTimer?.cancel();
    _intervalUs = intervalUs;
    _startTime = clock.now();
    _processed = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Stops ticking. Safe to call whether or not it's currently running.
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _startTime = null;
    _intervalUs = 0;
    _processed = 0;
  }

  void _poll() {
    final startTime = _startTime;
    if (startTime == null) return;
    final elapsedUs = clock.now().difference(startTime).inMicroseconds;
    final due = elapsedUs ~/ _intervalUs;
    final newlyDue = due - _processed;
    if (newlyDue <= 0) return;
    _processed = due;
    onDue(newlyDue);
  }

  void dispose() => stop();
}
