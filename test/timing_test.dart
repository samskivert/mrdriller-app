import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/timing.dart';

void main() {
  group('BeatGrid', () {
    const grid = BeatGrid(start: 1000, interval: 500);

    test('places beats at regular intervals from the start', () {
      expect(grid.timeOf(0), 1000);
      expect(grid.timeOf(3), 2500);
      expect(BeatGrid.bpm(start: 0, bpm: 120).interval, 500);
    });

    test('matches a time to the nearest beat, early or late', () {
      expect(grid.nearestBeat(1480), 1);
      expect(grid.offsetOf(1480), -20);
      expect(grid.nearestBeat(1530), 1);
      expect(grid.offsetOf(1530), 30);
      expect(grid.nearestBeat(1760), 2);
      expect(grid.offsetOf(1760), -240);
    });

    test('numbers beats before the start negatively', () {
      expect(grid.nearestBeat(600), -1);
      expect(grid.offsetOf(600), 100);
    });
  });

  group('OffsetStats', () {
    test('is all zero for no offsets', () {
      final stats = OffsetStats.of([]);
      expect(stats.count, 0);
      expect(stats.mean, 0);
      expect(stats.spread, 0);
    });

    test('summarizes offsets', () {
      final stats = OffsetStats.of([10, 20, 30, -40]);
      expect(stats.count, 4);
      expect(stats.mean, 5);
      // Deviations of 5, 15, 25 and -45: variance (25 + 225 + 625 + 2025) / 4 = 725.
      expect(stats.spread, closeTo(26.926, 0.001));
      expect(stats.worst, -40);
    });
  });

  group('ClockSync', () {
    test('knows nothing before a sample', () {
      expect(ClockSync().toStepped(100), isNull);
    });

    test('uses the reading closest to the truth: the stepped clock furthest ahead', () {
      // Offsets of 990, 997, 990 and 993: the stepped clock lags its truth by varying amounts.
      final sync = ClockSync()
        ..sample(0, 990)
        ..sample(3, 1000)
        ..sample(6, 996)
        ..sample(9, 1002);
      expect(sync.offset, 997);
      expect(sync.toStepped(100), 1097);
    });

    test('forgets readings older than its window, following drift', () {
      final sync = ClockSync(window: 100)
        ..sample(0, 1000)
        ..sample(50, 1040);
      expect(sync.offset, 1000);
      sync.sample(150, 1140);
      expect(sync.offset, 990);
    });
  });
}
