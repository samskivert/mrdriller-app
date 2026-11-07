import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

/// Drives a steady beat at a given bpm (quarter notes, further scaled by an optional [scale]
/// factor passed to [ensureRunning]), calling [onDue] once elapsed time says a beat is due.
///
/// Elapsed time is measured on [now] (a steady clock unaffected by GC pauses or a busy isolate,
/// and one that tests can override via `package:fake_async`'s zone -- see metronome_test.dart)
/// rather than by counting how many times an internal poll happened to
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
///
/// Owners that schedule sounds ahead of time (see click_scheduler.dart) can also see where the
/// schedule is going: [ticks] counts the ticks delivered so far, [timeOfTick] says when a coming
/// one is due on the [now] clock, and [onPoll] is called after every poll, to look ahead from.
class Metronome extends ChangeNotifier {
  static const _pollInterval = Duration(milliseconds: 5);
  static void _noop(int beatsDue) {}

  void Function(int beatsDue) onDue;

  /// Called after every poll while running (after [onDue], if ticks were due).
  VoidCallback? onPoll;

  /// The current time in milliseconds, on the steady clock that the schedule is kept on.
  final double Function() now;

  Metronome({this.onDue = _noop}) : now = _steadyClock();

  Timer? _pollTimer;
  int _intervalUs = 0;
  // The current stretch of the schedule (since it started, changed tempo or resumed): tick
  // [_startTick] fell at [_startMs], and those after it fall every interval from there.
  double _startMs = 0;
  int _startTick = 0;
  int _ticks = 0;
  bool _paused = false;

  bool get isPaused => _paused;

  /// Whether beats are currently being delivered to [onDue] -- false once [stop] is called or
  /// while [pause]d.
  bool get isActive => _pollTimer != null;

  /// How many ticks have been delivered to [onDue] since it started (from stopped).
  int get ticks => _ticks;

  /// When [tick] (counted like [ticks]) is due, on the [now] clock, if the tempo doesn't change
  /// before then. Null unless it's running.
  double? timeOfTick(int tick) =>
      _pollTimer == null ? null : _startMs + (tick - _startTick) * _intervalUs / 1000;

  /// Starts ticking at [bpm] (scaled by [scale]), or re-bases the schedule if it's already running
  /// at a different bpm/scale. Rebasing puts the next beat one new interval after the last one
  /// (or after now, if that's already passed), rather than measuring against elapsed time that
  /// belonged to a different interval -- which would otherwise read as a pile of beats suddenly
  /// overdue. Calling this again with the same bpm/scale while already running is a no-op, so
  /// callers can call it unconditionally on every state change without worrying about restarting
  /// an already-correct schedule. While paused, this just remembers the bpm/scale to pick up on
  /// [resume] -- it doesn't start ticking.
  void ensureRunning({required int bpm, double scale = 1}) {
    final intervalUs = ((60000000 / bpm / 4) * scale).round();
    if (_paused) {
      _intervalUs = intervalUs;
      return;
    }
    if (_pollTimer != null && intervalUs == _intervalUs) return;
    final wasActive = isActive;
    final now = this.now();
    if (wasActive) {
      // Usually called as a tick is handled, when the next falls one new interval after it, just as
      // anything scheduled ahead expects.
      final lastTick = timeOfTick(_ticks)!;
      _startMs = lastTick + intervalUs / 1000 > now ? lastTick : now;
    } else {
      _startMs = now;
      _ticks = 0;
    }
    _startTick = _ticks;
    _intervalUs = intervalUs;
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => _poll());
    if (!wasActive) notifyListeners();
  }

  /// Stops ticking and forgets the schedule entirely (including any paused bpm). Safe to call
  /// whether or not it's currently running.
  void stop() {
    final wasActive = isActive;
    _pollTimer?.cancel();
    _pollTimer = null;
    _intervalUs = 0;
    _ticks = 0;
    _startTick = 0;
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
    _startMs = now();
    _startTick = _ticks;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    notifyListeners();
  }

  void _poll() {
    if (_pollTimer == null) return;
    final elapsedUs = ((now() - _startMs) * 1000).floor();
    final due = _startTick + elapsedUs ~/ _intervalUs;
    final newlyDue = due - _ticks;
    if (newlyDue > 0) {
      _ticks = due;
      onDue(newlyDue);
    }
    // (Unless onDue stopped or paused it.)
    if (_pollTimer != null) onPoll?.call();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// A steady, fine-grained clock, in milliseconds: a Stopwatch (performance.now() on web, to the
// microsecond, where DateTime.now() only has milliseconds), unless something (a test, with
// fake_async) has overridden package:clock's clock, in which case that.
double Function() _steadyClock() {
  final overridden = clock;
  if (identical(overridden, const Clock())) {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsedMicroseconds / 1000;
  }
  final start = overridden.now();
  return () => overridden.now().difference(start).inMicroseconds / 1000;
}
