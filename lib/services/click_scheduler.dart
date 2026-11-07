// Schedules a Metronome's clicks ahead of time on the audio engine's clock.
//
// Playing a click when a poll finds its tick due (MetronomeSounds.playBeep) makes it as late as the
// poll was, and polls are late whenever the main thread is busy (a frame, garbage collection):
// that was audible as the beat wobbling, by up to 90ms. Scheduled a little ahead with an exact
// start time on the engine's own clock, a click plays exactly on time however busy the app is
// when it's due, as long as the app isn't stalled for longer than the lookahead.

import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../model/timing.dart';
import 'metronome.dart';
import 'metronome_sounds.dart';

enum Click { beep, boop }

/// Says which clicks sound on the tick [ahead] ticks after the current one (the last delivered to
/// [Metronome.onDue]), or returns null if that can't be known yet. That's the case if its timing
/// depends on a tempo change on an earlier tick, which the metronome hasn't been told about.
typedef ClicksFor = List<Click>? Function(int ahead);

class ClickScheduler {
  /// How far ahead clicks are scheduled. The app would have to stall for longer than this for one
  /// to be late (which a busy screen in a debug build has done for a quarter of a second);
  /// anything already scheduled when the metronome pauses is cancelled.
  static const lookaheadMs = 400.0;

  // A tick that comes due without having been scheduled is played then if it's at most this late,
  // and otherwise skipped (as a late poll's catch-up would).
  static const _tooLateMs = 20.0;

  final Metronome metronome;
  final MetronomeSounds sounds;
  final ClicksFor clicksFor;

  final _sync = ClockSync();
  late final Timer _sampler;
  // Scheduled clicks that may not have played yet: when they're due, and their handles.
  final _pending = <(double, SoundHandle)>[];
  // The next tick to schedule (the ones before it having been scheduled or played).
  int _next = 1;

  /// Schedules [metronome]'s clicks, as [clicksFor] says, through [sounds], from each of its polls
  /// (replacing its [Metronome.onPoll]).
  ClickScheduler({required this.metronome, required this.sounds, required this.clicksFor}) {
    metronome.onPoll = _update;
    // Keeps the mapping onto the engine's clock warm while the metronome isn't running too, so
    // it's accurate from the first tick.
    _sampler = Timer.periodic(const Duration(milliseconds: 5), (_) => _sample());
  }

  /// Cancels any clicks scheduled that haven't played yet, to schedule afresh from the current
  /// tick: call when the metronome pauses or stops, or what's coming up changes.
  void reset() {
    for (final (_, handle) in _pending) {
      sounds.cancel(handle);
    }
    _pending.clear();
    _next = metronome.ticks + 1;
  }

  /// How far ahead of the metronome's clock the audio engine's is, in milliseconds, as best it
  /// knows, or null if it doesn't yet.
  double? get engineOffsetMs => _sync.offset;

  void dispose() {
    _sampler.cancel();
    reset();
    if (metronome.onPoll == _update) metronome.onPoll = null;
  }

  void _sample() {
    final engineTime = sounds.engineTime(running: true);
    if (engineTime == null) {
      // The engine's clock stops with its output device (which it does, for one, when paused),
      // and restarts from where it left off, so what was known of it no longer holds.
      _sync.clear();
    } else {
      _sync.sample(metronome.now(), engineTime.inMicroseconds / 1000);
    }
  }

  void _update() {
    _sample();
    final now = metronome.now();
    _pending.removeWhere((pending) => pending.$1 < now - 1000);
    final current = metronome.ticks;
    if (_next <= current) {
      // The current tick wasn't scheduled ahead (because the engine's clock wasn't known yet, or
      // the app stalled), so play it now, if it's not too late.
      final time = metronome.timeOfTick(current);
      if (time != null && time >= now - _tooLateMs) {
        for (final click in clicksFor(0) ?? const <Click>[]) {
          click == Click.beep ? sounds.playBeep() : sounds.playBoop();
        }
      }
      _next = current + 1;
    }
    while (true) {
      final time = metronome.timeOfTick(_next);
      final engineTime = _sync.toStepped(time ?? 0);
      if (time == null || engineTime == null || time > now + lookaheadMs) return;
      final clicks = clicksFor(_next - current);
      if (clicks == null) return;
      final at = Duration(microseconds: (engineTime * 1000).round());
      for (final click in clicks) {
        final handle = click == Click.beep ? sounds.scheduleBeep(at) : sounds.scheduleBoop(at);
        if (handle != null) _pending.add((time, handle));
      }
      _next++;
    }
  }
}
