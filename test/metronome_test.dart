import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/services/metronome.dart';

void main() {
  test('ticks once per beat interval at the given bpm', () {
    fakeAsync((async) {
      final due = <int>[];
      final metronome = Metronome(onDue: due.add);

      // 60 bpm -> a quarter note every second -> a sixteenth-note "beat" every 250ms.
      metronome.ensureRunning(bpm: 60);
      async.elapse(const Duration(milliseconds: 250));
      expect(due, [1]);

      async.elapse(const Duration(milliseconds: 250));
      expect(due, [1, 1]);

      metronome.dispose();
    });
  });

  test(
    'scale stretches the interval (e.g. a drill with scale: 0.5 ticks twice as fast)',
    () {
      fakeAsync((async) {
        final due = <int>[];
        final metronome = Metronome(onDue: due.add);

        metronome.ensureRunning(bpm: 60, scale: 0.5);
        async.elapse(const Duration(milliseconds: 125));
        expect(due, [1]);

        metronome.dispose();
      });
    },
  );

  test('reports more than one beat per callback when the beat interval is faster than the poll '
      'interval, instead of firing once per beat', () {
    fakeAsync((async) {
      final due = <int>[];
      final metronome = Metronome(onDue: due.add);

      // This is the same code path a real stall (a GC pause, a slow frame) would exercise --
      // elapsed time says more than one beat is due since the last poll -- just reached here by
      // outrunning the poll interval instead of by faking a stall directly.
      // 6000 bpm -> a beat every 2.5ms, faster than the scheduler's fixed 5ms poll interval, so
      // exactly 2 beats become due between one poll and the next.
      metronome.ensureRunning(bpm: 6000);
      async.elapse(const Duration(milliseconds: 5));
      expect(due, [2]);

      async.elapse(const Duration(milliseconds: 5));
      expect(due, [2, 2]);

      metronome.dispose();
    });
  });

  test('stop() halts ticking until ensureRunning is called again', () {
    fakeAsync((async) {
      final due = <int>[];
      final metronome = Metronome(onDue: due.add);

      metronome.ensureRunning(bpm: 60);
      async.elapse(const Duration(milliseconds: 250));
      expect(due, [1]);

      metronome.stop();
      async.elapse(const Duration(seconds: 2));
      expect(due, [1]); // no new ticks while stopped

      metronome.dispose();
    });
  });

  test(
    'calling ensureRunning again with the same bpm/scale does not reset the schedule',
    () {
      fakeAsync((async) {
        final due = <int>[];
        final metronome = Metronome(onDue: due.add);

        metronome.ensureRunning(bpm: 60);
        async.elapse(const Duration(milliseconds: 200));
        // Re-affirming the same bpm (as every _afterStateChange-style call does on every tick) must
        // not push the next beat further out -- it should still land at the original 250ms mark,
        // not 250ms from this call.
        metronome.ensureRunning(bpm: 60);
        async.elapse(const Duration(milliseconds: 50));
        expect(due, [1]);

        metronome.dispose();
      });
    },
  );

  test(
    'changing bpm rebases the schedule to start counting from the change, not from zero',
    () {
      fakeAsync((async) {
        final due = <int>[];
        final metronome = Metronome(onDue: due.add);

        metronome.ensureRunning(bpm: 60); // 250ms per beat
        async.elapse(const Duration(milliseconds: 200));
        expect(due, isEmpty);

        // Speeding up mid-flight: the next beat should be 125ms from *now* (120 bpm), not measured
        // against the 200ms already elapsed under the old bpm.
        metronome.ensureRunning(bpm: 120);
        async.elapse(const Duration(milliseconds: 100));
        expect(due, isEmpty);
        async.elapse(const Duration(milliseconds: 25));
        expect(due, [1]);

        metronome.dispose();
      });
    },
  );

  test('dispose stops any further ticking', () {
    fakeAsync((async) {
      final due = <int>[];
      final metronome = Metronome(onDue: due.add);

      metronome.ensureRunning(bpm: 60);
      metronome.dispose();
      async.elapse(const Duration(seconds: 2));
      expect(due, isEmpty);
    });
  });
}
