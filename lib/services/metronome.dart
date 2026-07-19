import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

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
///
/// [pause]/[resume] halt/restart delivery of ticks to [onDue] without losing the schedule's bpm --
/// unlike [stop], a paused metronome remembers what it was running at and picks back up from
/// [resume] as if it had just started fresh at that bpm (no pile of beats appears newly "due" for
/// the time spent paused). [isActive] reports whether ticks are currently being delivered (running
/// and not paused) and changes are broadcast via [ChangeNotifier] -- e.g. so something that should
/// track "is the metronome actually doing something right now" (keeping the screen awake, pausing
/// a sound engine) can just listen here instead of keeping its own copy of the playing/paused
/// bookkeeping.
class Metronome extends ChangeNotifier {
  static const _pollInterval = Duration(milliseconds: 5);
  static void _noop(int beatsDue) {}

  void Function(int beatsDue) onDue;

  Metronome({this.onDue = _noop});

  Timer? _pollTimer;
  DateTime? _startTime;
  int _intervalUs = 0;
  int _processed = 0;
  bool _paused = false;

  bool get isPaused => _paused;

  /// Whether beats are currently being delivered to [onDue] -- false once [stop] is called or
  /// while [pause]d.
  bool get isActive => _pollTimer != null;

  /// Starts ticking at [bpm] (scaled by [scale]), or re-bases the schedule if it's already running
  /// at a different bpm/scale. Rebasing starts the next beat exactly one interval from *now*,
  /// rather than measuring against elapsed time that belonged to a different interval -- which
  /// would otherwise read as a pile of beats suddenly overdue. Calling this again with the same
  /// bpm/scale while already running is a no-op, so callers can call it unconditionally on every
  /// state change without worrying about restarting an already-correct schedule. While paused,
  /// this just remembers the bpm/scale to pick up on [resume] -- it doesn't start ticking.
  void ensureRunning({required int bpm, double scale = 1}) {
    final intervalUs = ((60000000 / bpm / 4) * scale).round();
    if (_paused) {
      _intervalUs = intervalUs;
      return;
    }
    if (_pollTimer != null && intervalUs == _intervalUs) return;
    final wasActive = isActive;
    _pollTimer?.cancel();
    _intervalUs = intervalUs;
    _startTime = clock.now();
    _processed = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    if (!wasActive) notifyListeners();
  }

  /// Stops ticking and forgets the schedule entirely (including any paused bpm). Safe to call
  /// whether or not it's currently running.
  void stop() {
    final wasActive = isActive;
    _pollTimer?.cancel();
    _pollTimer = null;
    _startTime = null;
    _intervalUs = 0;
    _processed = 0;
    _paused = false;
    if (wasActive) notifyListeners();
  }

  /// Halts ticking in place -- [ensureRunning] can still be called while paused (e.g. as the drill
  /// state keeps advancing bpm across repeats), it just won't actually tick until [resume].
  void pause() {
    if (_paused) return;
    _paused = true;
    final wasActive = isActive;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (wasActive) notifyListeners();
  }

  /// Resumes ticking at whatever bpm/scale was last set (via [ensureRunning], including any that
  /// happened while paused), rebasing the schedule to start counting from now.
  void resume() {
    if (!_paused) return;
    _paused = false;
    if (_intervalUs <= 0) return; // ensureRunning was never actually called
    _startTime = clock.now();
    _processed = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    notifyListeners();
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

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
