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

/// A stroke the drill expects to be hit at [timeMs] by [hand]. [spot] is whatever the caller
/// needs to know where it is in the drill (to show its grade there).
class ExpectedStroke {
  final double timeMs;
  final Hand hand;
  final Object spot;

  const ExpectedStroke({required this.timeMs, required this.hand, required this.spot});
}

class Grade {
  final ExpectedStroke stroke;
  final Judgement judgement;

  /// How far from the stroke's time the hit was, in milliseconds (negative if early), unless it
  /// was missed.
  final double? errorMs;

  /// Whether it was hit with the other hand than the stroke's.
  final bool wrongHand;

  const Grade({
    required this.stroke,
    required this.judgement,
    this.errorMs,
    this.wrongHand = false,
  });
}

/// The grades of a whole drill (or as much of it as was played), summed up.
class GradeSummary {
  final Map<Judgement, int> counts;
  final int wrongHands;

  /// Hits that weren't near any stroke.
  final int extras;

  /// The offsets of the strokes that were hit.
  final OffsetStats offsets;

  const GradeSummary({
    required this.counts,
    required this.wrongHands,
    required this.extras,
    required this.offsets,
  });

  int get strokes => counts.values.fold(0, (a, b) => a + b);

  int count(Judgement judgement) => counts[judgement] ?? 0;
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

  Grader({this.windowMs = 120, this.perfectMs = 25, this.goodMs = 50});

  List<Grade> get grades => List.unmodifiable(_grades);

  /// Adds a stroke to expect, after any already expected.
  void expect(ExpectedStroke stroke) => _pending.add(stroke);

  /// Grades a hit at [timeMs] (adjusted by the calibration) with [hand], against the nearest
  /// stroke expected within [windowMs] (or a stroke for [hand] nearly as near, if the nearest is
  /// for the other hand), or returns null if there isn't one (and, if [countExtra], counts it as
  /// an extra hit).
  Grade? hit(double timeMs, Hand hand, {bool countExtra = true}) {
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
    final grade = Grade(
      stroke: stroke,
      judgement: judge(error),
      errorMs: error,
      wrongHand: stroke.hand != hand,
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
    final counts = <Judgement, int>{};
    for (final grade in _grades) {
      counts.update(grade.judgement, (n) => n + 1, ifAbsent: () => 1);
    }
    return GradeSummary(
      counts: counts,
      wrongHands: _grades.where((g) => g.wrongHand).length,
      extras: _extras,
      offsets: OffsetStats.of([for (final g in _grades) ?g.errorMs]),
    );
  }
}
