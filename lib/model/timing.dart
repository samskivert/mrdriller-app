import 'dart:collection';
import 'dart:math' as math;

/// A steady beat: beat `n` falls at [start] + `n` * [interval], all in milliseconds.
class BeatGrid {
  final double start;
  final double interval;

  const BeatGrid({required this.start, required this.interval});

  /// A grid of quarter notes at [bpm], from [start].
  BeatGrid.bpm({required this.start, required int bpm}) : interval = 60000 / bpm;

  double timeOf(int beat) => start + beat * interval;

  /// The beat nearest [time] (negative before the start).
  int nearestBeat(double time) => ((time - start) / interval).round();

  /// How far [time] is from its nearest beat: negative if early, positive if late.
  double offsetOf(double time) => time - timeOf(nearestBeat(time));
}

/// Summary statistics of some timing offsets, in milliseconds.
class OffsetStats {
  final int count;
  final double mean;

  /// The (population) standard deviation: how widely the offsets spread around [mean].
  final double spread;

  /// The offset furthest from zero, early or late.
  final double worst;

  const OffsetStats._(this.count, this.mean, this.spread, this.worst);

  static const empty = OffsetStats._(0, 0, 0, 0);

  factory OffsetStats.of(Iterable<double> offsets) {
    final list = offsets.toList();
    if (list.isEmpty) return empty;
    final mean = list.reduce((a, b) => a + b) / list.length;
    final variance = list.map((o) => (o - mean) * (o - mean)).reduce((a, b) => a + b) / list.length;
    final worst = list.reduce((a, b) => a.abs() >= b.abs() ? a : b);
    return OffsetStats._(list.length, mean, math.sqrt(variance), worst);
  }
}

/// Maps times on a smooth clock onto one that only advances in steps, like an audio engine's,
/// which moves on once per buffer it mixes, from paired readings of the two ([sample]).
///
/// A stepped clock reads at or behind the true time, so the pairs closest to the truth are those
/// where (stepped - smooth) is greatest. This keeps the greatest over the last [window]
/// milliseconds, so that it follows if the clocks slowly drift apart.
class ClockSync {
  final double window;

  // (smooth time, offset) pairs with decreasing offsets, so the first is the window's greatest.
  final _samples = ListQueue<(double, double)>();

  ClockSync({this.window = 2000});

  /// Records that the stepped clock read [stepped] when the smooth one read [smooth].
  void sample(double smooth, double stepped) {
    final offset = stepped - smooth;
    while (_samples.isNotEmpty && _samples.last.$2 <= offset) {
      _samples.removeLast();
    }
    _samples.add((smooth, offset));
    while (_samples.first.$1 < smooth - window) {
      _samples.removeFirst();
    }
  }

  /// Forgets every [sample], e.g. because the stepped clock stopped, and will restart from where
  /// it left off.
  void clear() => _samples.clear();

  /// How far ahead of the smooth clock the stepped one is, or null before any [sample].
  double? get offset => _samples.isEmpty ? null : _samples.first.$2;

  /// [smooth] on the stepped clock, or null before any [sample].
  double? toStepped(double smooth) {
    final offset = this.offset;
    return offset == null ? null : smooth + offset;
  }
}
