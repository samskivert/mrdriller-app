import 'package:fake_async/fake_async.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/services/click_scheduler.dart';
import 'package:mrdriller/services/metronome.dart';
import 'package:mrdriller/services/metronome_sounds.dart';

// An audio engine whose clock runs 5000ms ahead of the metronome's (so that a click due at t is
// scheduled at 5000 + t), advancing in 10ms buffers (or isn't running, if [running] is false), and
// which keeps track of what it scheduled and played.
class _FakeSounds implements MetronomeSounds {
  final Metronome metronome;
  bool running = true;
  final scheduled = <(Click, double)>[];
  final played = <Click>[];
  final cancelled = <SoundHandle>[];
  var _handles = 0;

  _FakeSounds(this.metronome);

  @override
  Future<void> ready = Future.value();

  @override
  Future<void> start() => ready;

  @override
  Duration? engineTime({bool running = false}) {
    if (!this.running) return null;
    final ms = 5000 + (metronome.now() / 10).floor() * 10;
    return Duration(milliseconds: ms);
  }

  @override
  SoundHandle? scheduleBeep(Duration at) => _schedule(Click.beep, at);

  @override
  SoundHandle? scheduleBoop(Duration at) => _schedule(Click.boop, at);

  SoundHandle _schedule(Click click, Duration at) {
    scheduled.add((click, at.inMicroseconds / 1000));
    return SoundHandle(++_handles);
  }

  @override
  void cancel(SoundHandle handle) => cancelled.add(handle);

  @override
  void playBeep() => played.add(Click.beep);

  @override
  void playBoop() => played.add(Click.boop);

  @override
  void pause() {}

  @override
  void dispose() {}
}

void main() {
  // Runs [body] with a metronome, fake sounds and a scheduler that asks [clicksFor] (by default,
  // a beep on every tick).
  void withScheduler(
    void Function(FakeAsync async, Metronome metronome, _FakeSounds sounds, ClickScheduler s)
    body, {
    ClicksFor? clicksFor,
  }) {
    fakeAsync((async) {
      final metronome = Metronome();
      final sounds = _FakeSounds(metronome);
      final scheduler = ClickScheduler(
        metronome: metronome,
        sounds: sounds,
        clicksFor: clicksFor ?? (_) => const [Click.beep],
      );
      // Long enough for the scheduler to have learned the engine's clock, as it would have by the
      // time anything starts playing.
      async.elapse(const Duration(milliseconds: 20));
      body(async, metronome, sounds, scheduler);
      scheduler.dispose();
      metronome.dispose();
    });
  }

  // (The metronome starts 20ms in, after the scheduler's warmed up, so a tick at t on its clock is
  // scheduled at 5000 + 20 + t on the engine's.)
  const lookahead = ClickScheduler.lookaheadMs;

  test('schedules each click ahead, at its time on the engine clock', () {
    withScheduler((async, metronome, sounds, _) {
      metronome.ensureRunning(bpm: 15); // A tick a second.
      // Not until the first tick is within the lookahead.
      async.elapse(Duration(milliseconds: (1000 - lookahead - 10).round()));
      expect(sounds.scheduled, isEmpty);
      async.elapse(const Duration(milliseconds: 20));
      expect(sounds.scheduled, [(Click.beep, 6020.0)]);
      async.elapse(const Duration(seconds: 2));
      expect(sounds.scheduled.map((s) => s.$2), [6020, 7020, 8020]);
      expect(sounds.played, isEmpty);
    });
  });

  test('asks for the clicks on each tick by how far ahead of the current one it is', () {
    final asked = <(int, int)>[];
    late Metronome m;
    withScheduler(
      (async, metronome, sounds, _) {
        m = metronome;
        metronome.ensureRunning(bpm: 300); // A tick every 50ms: lots within the lookahead.
        async.elapse(const Duration(milliseconds: 130));
        // 150ms in, the current tick is the second, and those up to the lookahead are scheduled.
        final last = ((150 + lookahead - 20) / 50).floor();
        expect(
          [for (final (current, ahead) in asked) current + ahead],
          [for (var tick = 1; tick <= last; tick++) tick],
        );
        expect(asked.first, (0, 1));
        expect(asked.last, (2, last - 2));
      },
      clicksFor: (ahead) {
        asked.add((m.ticks, ahead));
        return ahead % 2 == 0 ? const [Click.boop] : const [Click.beep, Click.boop];
      },
    );
  });

  test("stops looking ahead at a tick whose clicks can't be known yet", () {
    withScheduler((async, metronome, sounds, _) {
      metronome.ensureRunning(bpm: 300); // A tick every 50ms.
      async.elapse(const Duration(milliseconds: 20));
      expect(sounds.scheduled.map((s) => s.$2), [5070]);
      async.elapse(const Duration(milliseconds: 40));
      expect(sounds.scheduled.map((s) => s.$2), [5070, 5120]);
    }, clicksFor: (ahead) => ahead > 1 ? null : const [Click.beep]);
  });

  test('plays a tick at once if it comes due without having been scheduled', () {
    withScheduler((async, metronome, sounds, _) {
      sounds.running = false;
      metronome.ensureRunning(bpm: 15);
      async.elapse(const Duration(milliseconds: 1010));
      expect(sounds.scheduled, isEmpty);
      expect(sounds.played, [Click.beep]);
      // Once the engine's running, it schedules ahead again.
      sounds.running = true;
      async.elapse(const Duration(seconds: 1));
      expect(sounds.played, [Click.beep]);
      expect(sounds.scheduled.map((s) => s.$2), [7020]);
    });
  });

  test("resetting cancels what hasn't played, and schedules afresh", () {
    withScheduler((async, metronome, sounds, scheduler) {
      metronome.ensureRunning(bpm: 15);
      async.elapse(Duration(milliseconds: (1000 - lookahead + 100).round()));
      expect(sounds.scheduled.length, 1);
      scheduler.reset();
      expect(sounds.cancelled, [const SoundHandle(1)]);
      async.elapse(const Duration(milliseconds: 20));
      expect(sounds.scheduled.map((s) => s.$2), [6020, 6020]);
      // Nothing played twice, once it's due.
      async.elapse(Duration(milliseconds: lookahead.round()));
      expect(sounds.played, isEmpty);
    });
  });
}
