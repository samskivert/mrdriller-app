// Grades a player's hits (from a MIDI pad) against the strokes a drill expects: matches each hit
// to a stroke, and judges how close to it the hit was, and whether it was with the right hand.

import 'model.dart';
import 'timing.dart';

/// How a stroke went.
enum Judgement {
  perfect('Perfect'),
  good('Good'),
  early('Early'),
  late('Late'),
  miss('Missed');

  final String label;

  const Judgement(this.label);
}

/// How strictly hits are judged: how close to its stroke a hit has to be to be perfect, or good.
enum GradingDifficulty {
  easy('Easy', 35, 70),
  normal('Normal', 25, 50),
  hard('Hard', 15, 30),
  expert('Expert', 10, 20);

  final String label;
  final double perfectMs;
  final double goodMs;

  const GradingDifficulty(this.label, this.perfectMs, this.goodMs);
}

/// A stroke the drill expects to be hit at [timeMs] by [hand], [accent]ed or not. [spot] is
/// whatever the caller needs to know where it is in the drill (to show its grade there).
class ExpectedStroke {
  final double timeMs;
  final Hand hand;
  final bool accent;
  final Object spot;

  const ExpectedStroke({
    required this.timeMs,
    required this.hand,
    this.accent = false,
    required this.spot,
  });
}

class Grade {
  final ExpectedStroke stroke;
  final Judgement judgement;

  /// How far from the stroke's time the hit was, in milliseconds (negative if early), unless it
  /// was missed.
  final double? errorMs;

  /// Whether it was hit with the other hand than the stroke's.
  final bool wrongHand;

  /// Whether it was hit softly though accented, or hard though not (if accents were graded).
  final bool wrongAccent;

  const Grade({
    required this.stroke,
    required this.judgement,
    this.errorMs,
    this.wrongHand = false,
    this.wrongAccent = false,
  });
}

/// The grades of a whole drill (or as much of it as was played), summed up.
class GradeSummary {
  final Map<Judgement, int> counts;
  final int wrongHands;

  /// Whether accents were graded (which needs the pad's accent velocity), and how many strokes
  /// were hit with the wrong accent.
  final bool accentsGraded;
  final int wrongAccents;

  /// Hits that weren't near any stroke.
  final int extras;

  /// The offsets of the strokes that were hit, summed up, and each (in milliseconds, negative if
  /// early), if known.
  final OffsetStats offsets;
  final List<double> errors;

  /// How close to their strokes hits had to be to be perfect, or good.
  final double perfectMs;
  final double goodMs;

  const GradeSummary({
    required this.counts,
    required this.wrongHands,
    this.accentsGraded = false,
    this.wrongAccents = 0,
    required this.extras,
    required this.offsets,
    this.errors = const [],
    this.perfectMs = 25,
    this.goodMs = 50,
  });

  int get strokes => counts.values.fold(0, (a, b) => a + b);

  int count(Judgement judgement) => counts[judgement] ?? 0;

  /// All of [summaries] (e.g. of each drill in a playlist) together. (Judged as strictly as the
  /// first was.)
  factory GradeSummary.combine(Iterable<GradeSummary> summaries) {
    final counts = <Judgement, int>{};
    for (final summary in summaries) {
      for (final MapEntry(:key, :value) in summary.counts.entries) {
        counts.update(key, (n) => n + value, ifAbsent: () => value);
      }
    }
    return GradeSummary(
      counts: counts,
      wrongHands: summaries.fold(0, (n, s) => n + s.wrongHands),
      accentsGraded: summaries.any((s) => s.accentsGraded),
      wrongAccents: summaries.fold(0, (n, s) => n + s.wrongAccents),
      extras: summaries.fold(0, (n, s) => n + s.extras),
      offsets: OffsetStats.combine(summaries.map((s) => s.offsets)),
      errors: [for (final s in summaries) ...s.errors],
      perfectMs: summaries.firstOrNull?.perfectMs ?? 25,
      goodMs: summaries.firstOrNull?.goodMs ?? 50,
    );
  }
}

/// How a drill went, graded: its [summary], and whether the drum pad wasn't calibrated for the
/// audio output in use (so its timings include the sound's delay).
class GradedRun {
  final GradeSummary summary;
  final bool uncalibrated;

  const GradedRun(this.summary, {this.uncalibrated = false});
}

class Grader {
  /// How far from a stroke's time a hit can be and still count as hitting it.
  final double windowMs;

  /// How close to its time a hit has to be to be perfect, or good.
  final double perfectMs;
  final double goodMs;

  // The strokes expected that haven't been hit or missed yet, in time order.
  final _pending = <ExpectedStroke>[];
  final _grades = <Grade>[];
  var _extras = 0;
  var _accentsGraded = false;

  Grader({this.windowMs = 120, this.perfectMs = 25, this.goodMs = 50});

  /// A grader judging as strictly as [difficulty] says.
  Grader.at(GradingDifficulty difficulty, {this.windowMs = 120})
    : perfectMs = difficulty.perfectMs,
      goodMs = difficulty.goodMs;

  List<Grade> get grades => List.unmodifiable(_grades);

  /// Adds a stroke to expect, after any already expected.
  void expect(ExpectedStroke stroke) => _pending.add(stroke);

  /// Grades a hit at [timeMs] (adjusted by the calibration) with [hand], against the nearest
  /// stroke expected within [windowMs] (or a stroke for [hand] nearly as near, if the nearest is
  /// for the other hand), or returns null if there isn't one (and, if [countExtra], counts it as
  /// an extra hit). If whether it was [accented] is known, that's graded too.
  Grade? hit(double timeMs, Hand hand, {bool? accented, bool countExtra = true}) {
    ExpectedStroke? nearest;
    ExpectedStroke? nearestSameHand;
    for (final stroke in _pending) {
      final distance = (stroke.timeMs - timeMs).abs();
      if (distance > windowMs) continue;
      if (nearest == null || distance < (nearest.timeMs - timeMs).abs()) nearest = stroke;
      if (stroke.hand == hand &&
          (nearestSameHand == null || distance < (nearestSameHand.timeMs - timeMs).abs())) {
        nearestSameHand = stroke;
      }
    }
    if (nearest == null) {
      if (countExtra) _extras++;
      return null;
    }
    // Played with the right hand but a little off is likelier than with the wrong one.
    final stroke = nearestSameHand != null && (nearestSameHand.timeMs - timeMs).abs() <= goodMs
        ? nearestSameHand
        : nearest;
    _pending.remove(stroke);
    final error = timeMs - stroke.timeMs;
    if (accented != null) _accentsGraded = true;
    final grade = Grade(
      stroke: stroke,
      judgement: judge(error),
      errorMs: error,
      wrongHand: stroke.hand != hand,
      wrongAccent: accented != null && accented != stroke.accent,
    );
    _grades.add(grade);
    return grade;
  }

  Judgement judge(double errorMs) {
    if (errorMs.abs() <= perfectMs) return Judgement.perfect;
    if (errorMs.abs() <= goodMs) return Judgement.good;
    return errorMs < 0 ? Judgement.early : Judgement.late;
  }

  /// Misses the strokes whose window has passed by [nowMs] without being hit, and returns their
  /// grades.
  List<Grade> expire(double nowMs) {
    final missed = <Grade>[];
    while (_pending.isNotEmpty && _pending.first.timeMs < nowMs - windowMs) {
      missed.add(Grade(stroke: _pending.removeAt(0), judgement: Judgement.miss));
    }
    _grades.addAll(missed);
    return missed;
  }

  /// Forgets the strokes expected that haven't been hit or missed yet (e.g. on pausing, after
  /// which they'll come at other times), without missing them.
  void forgetPending() => _pending.clear();

  GradeSummary get summary {
    final errors = List<double>.unmodifiable([for (final g in _grades) ?g.errorMs]);
    final counts = <Judgement, int>{};
    for (final grade in _grades) {
      counts.update(grade.judgement, (n) => n + 1, ifAbsent: () => 1);
    }
    return GradeSummary(
      counts: counts,
      wrongHands: _grades.where((g) => g.wrongHand).length,
      accentsGraded: _accentsGraded,
      wrongAccents: _grades.where((g) => g.wrongAccent).length,
      extras: _extras,
      offsets: OffsetStats.of(errors),
      errors: errors,
      perfectMs: perfectMs,
      goodMs: goodMs,
    );
  }
}

/// The velocity (1-127) that best splits [velocities] (a mix of soft and loud hits) into two groups:
/// hits at or above it count as accented. It's the split that makes the two groups' velocities
/// each as close together as can be (Otsu's method). Null if there aren't enough to tell, or
/// they're all much the same.
int? accentVelocityFor(List<int> velocities) {
  if (velocities.length < 4) return null;
  final sorted = [...velocities]..sort();
  if (sorted.last - sorted.first < 10) return null;
  int? best;
  var bestSpread = double.infinity;
  for (var split = sorted.first + 1; split <= sorted.last; split++) {
    final soft = sorted.where((v) => v < split).toList();
    final loud = sorted.where((v) => v >= split).toList();
    if (soft.isEmpty || loud.isEmpty) continue;
    double variance(List<int> group) {
      final mean = group.reduce((a, b) => a + b) / group.length;
      return group.fold(0.0, (sum, v) => sum + (v - mean) * (v - mean));
    }

    // (How spread out the two groups are, in all.)
    final spread = variance(soft) + variance(loud);
    if (spread < bestSpread) {
      bestSpread = spread;
      best = split;
    }
  }
  // Halfway across the gap between the groups, rather than at the loud group's quietest.
  if (best == null) return null;
  final softest = sorted.where((v) => v >= best!).first;
  final loudestSoft = sorted.where((v) => v < best!).last;
  return ((softest + loudestSoft + 1) / 2).floor();
}
