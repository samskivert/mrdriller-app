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

  test('scale stretches the interval (e.g. a drill with scale: 0.5 ticks twice as fast)', () {
    fakeAsync((async) {
      final due = <int>[];
      final metronome = Metronome(onDue: due.add);

      metronome.ensureRunning(bpm: 60, scale: 0.5);
      async.elapse(const Duration(milliseconds: 125));
      expect(due, [1]);

      metronome.dispose();
    });
  });

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

  test('calling ensureRunning again with the same bpm/scale does not reset the schedule', () {
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
  });

  test('changing bpm rebases the schedule to start counting from the change, not from zero', () {
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
  });

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

  test('isActive reflects whether ticks are currently being delivered', () {
    fakeAsync((async) {
      final metronome = Metronome(onDue: (_) {});
      expect(metronome.isActive, isFalse);

      metronome.ensureRunning(bpm: 60);
      expect(metronome.isActive, isTrue);

      metronome.stop();
      expect(metronome.isActive, isFalse);

      metronome.dispose();
    });
  });

  test('notifies listeners when isActive changes, but not on a same-activeness rebase', () {
    fakeAsync((async) {
      final metronome = Metronome(onDue: (_) {});
      var notifications = 0;
      metronome.addListener(() => notifications++);

      metronome.ensureRunning(bpm: 60); // false -> true
      expect(notifications, 1);

      metronome.ensureRunning(bpm: 120); // still active, just rebased
      expect(notifications, 1);

      metronome.stop(); // true -> false
      expect(notifications, 2);

      metronome.stop(); // already inactive, no-op
      expect(notifications, 2);

      metronome.dispose();
    });
  });

  test('pause() halts ticking without losing the schedule, and marks isActive false', () {
    fakeAsync((async) {
      final due = <int>[];
      final metronome = Metronome(onDue: due.add);

      metronome.ensureRunning(bpm: 60); // 250ms per beat
      async.elapse(const Duration(milliseconds: 200));
      expect(due, isEmpty);

      metronome.pause();
      expect(metronome.isActive, isFalse);
      expect(metronome.isPaused, isTrue);
      async.elapse(const Duration(seconds: 5));
      expect(due, isEmpty); // no ticks while paused, no matter how long

      metronome.dispose();
    });
  });

  test('resume() rebases from the moment of resume rather than firing a catch-up burst for the '
      'paused duration', () {
    fakeAsync((async) {
      final due = <int>[];
      final metronome = Metronome(onDue: due.add);

      metronome.ensureRunning(bpm: 60); // 250ms per beat
      async.elapse(const Duration(milliseconds: 200));
      metronome.pause();
      async.elapse(const Duration(seconds: 5)); // long pause -- would be "20 beats due" if counted

      metronome.resume();
      expect(metronome.isActive, isTrue);
      expect(metronome.isPaused, isFalse);
      async.elapse(const Duration(milliseconds: 200));
      expect(due, isEmpty); // next beat is 250ms from resume, not from the old 200ms mark
      async.elapse(const Duration(milliseconds: 50));
      expect(due, [1]);

      metronome.dispose();
    });
  });

  test('ensureRunning while paused remembers the new bpm/scale for resume without ticking', () {
    fakeAsync((async) {
      final due = <int>[];
      final metronome = Metronome(onDue: due.add);

      metronome.ensureRunning(bpm: 60);
      metronome.pause();
      metronome.ensureRunning(bpm: 120); // e.g. a bpm-increase applied while paused
      async.elapse(const Duration(seconds: 1));
      expect(due, isEmpty);

      metronome.resume();
      async.elapse(const Duration(milliseconds: 125)); // 120 bpm -> 125ms per beat
      expect(due, [1]);

      metronome.dispose();
    });
  });

  test('pause() before ensureRunning was ever called is a harmless no-op', () {
    fakeAsync((async) {
      final metronome = Metronome(onDue: (_) {});

      metronome.pause();
      expect(metronome.isPaused, isTrue);
      metronome.resume();
      expect(metronome.isPaused, isFalse);
      expect(metronome.isActive, isFalse);

      metronome.dispose();
    });
  });
}
