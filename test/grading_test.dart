import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/grading.dart';
import 'package:mrdriller/model/model.dart';
import 'package:mrdriller/model/timing.dart';

// A stroke expected at [ms] with [hand], whose spot is its time.
ExpectedStroke _stroke(double ms, Hand hand) => ExpectedStroke(timeMs: ms, hand: hand, spot: ms);

void main() {
  test('judges hits by how close they are to their strokes', () {
    final grader = Grader();
    for (final ms in <double>[0, 200, 400, 600, 800]) {
      grader.expect(_stroke(ms, Hand.R));
    }
    expect(grader.hit(10, Hand.R)?.judgement, Judgement.perfect);
    expect(grader.hit(160, Hand.R)?.judgement, Judgement.good);
    expect(grader.hit(330, Hand.R)?.judgement, Judgement.early);
    final late = grader.hit(690, Hand.R)!;
    expect(late.judgement, Judgement.late);
    expect(late.errorMs, 90);
    expect(late.stroke.spot, 600);
  });

  test('matches each stroke once, and counts hits near none as extras', () {
    final grader = Grader()..expect(_stroke(0, Hand.R));
    expect(grader.hit(5, Hand.R)?.stroke.spot, 0);
    // A second hit on the same stroke, and one far from any.
    expect(grader.hit(15, Hand.R), isNull);
    expect(grader.hit(500, Hand.R), isNull);
    expect(grader.summary.extras, 2);
  });

  test('misses strokes whose window passes without a hit', () {
    final grader = Grader()
      ..expect(_stroke(0, Hand.R))
      ..expect(_stroke(100, Hand.L));
    expect(grader.expire(110), isEmpty);
    final missed = grader.expire(121);
    expect(missed.map((g) => (g.stroke.spot, g.judgement)), [(0, Judgement.miss)]);
    // Once missed, it can't be hit.
    expect(grader.hit(130, Hand.R)?.stroke.spot, 100);
  });

  test('says when a stroke is hit with the wrong hand', () {
    final grader = Grader()..expect(_stroke(0, Hand.R));
    final grade = grader.hit(3, Hand.L)!;
    expect(grade.wrongHand, isTrue);
    expect(grade.judgement, Judgement.perfect);
  });

  test("takes a stroke for the hit's hand that's nearly as near over the other hand's", () {
    // Alternating strokes 40ms apart: a right-hand hit at 25 is nearer the left's stroke, but
    // within good of the right's, so it's the right's.
    final grader = Grader()
      ..expect(_stroke(0, Hand.R))
      ..expect(_stroke(40, Hand.L));
    final grade = grader.hit(25, Hand.R)!;
    expect(grade.stroke.spot, 0);
    expect(grade.wrongHand, isFalse);
    // But not when the hit's hand's stroke is too far off.
    final grader2 = Grader()
      ..expect(_stroke(0, Hand.R))
      ..expect(_stroke(100, Hand.L));
    final grade2 = grader2.hit(95, Hand.R)!;
    expect(grade2.stroke.spot, 100);
    expect(grade2.wrongHand, isTrue);
  });

  test('forgets pending strokes without missing them', () {
    final grader = Grader()..expect(_stroke(0, Hand.R));
    grader.forgetPending();
    expect(grader.expire(1000), isEmpty);
    expect(grader.summary.strokes, 0);
  });

  test('sums up the grades', () {
    final grader = Grader();
    for (final ms in <double>[0, 200, 400, 600]) {
      grader.expect(_stroke(ms, Hand.R));
    }
    grader
      ..hit(-10, Hand.R)
      ..hit(230, Hand.L)
      ..hit(1000, Hand.R)
      ..expire(2000);
    final summary = grader.summary;
    expect(summary.strokes, 4);
    expect(summary.count(Judgement.perfect), 1);
    expect(summary.count(Judgement.good), 1);
    expect(summary.count(Judgement.miss), 2);
    expect(summary.wrongHands, 1);
    expect(summary.extras, 1);
    expect(summary.offsets.mean, 10);
    // Each hit's offset, to chart, and how strictly they were judged.
    expect(summary.errors, [-10, 30]);
    expect(summary.goodMs, 50);
  });

  test('combines summaries', () {
    GradeSummary summary(Map<Judgement, int> counts, int wrong, int extras, List<double> offsets) =>
        GradeSummary(
          counts: counts,
          wrongHands: wrong,
          extras: extras,
          offsets: OffsetStats.of(offsets),
          errors: offsets,
        );
    final combined = GradeSummary.combine([
      summary({Judgement.perfect: 3, Judgement.miss: 1}, 1, 0, [0, 10, -10]),
      summary({Judgement.perfect: 1, Judgement.late: 2}, 0, 2, [5, 60, 70]),
    ]);
    expect(combined.count(Judgement.perfect), 4);
    expect(combined.count(Judgement.late), 2);
    expect(combined.count(Judgement.miss), 1);
    expect(combined.wrongHands, 1);
    expect(combined.extras, 2);
    expect(combined.offsets.mean, closeTo(OffsetStats.of([0, 10, -10, 5, 60, 70]).mean, 1e-9));
    expect(combined.errors, [0, 10, -10, 5, 60, 70]);
  });

  test('grades accents when told whether hits were accented', () {
    final grader = Grader()
      ..expect(const ExpectedStroke(timeMs: 0, hand: Hand.R, accent: true, spot: 0))
      ..expect(const ExpectedStroke(timeMs: 200, hand: Hand.L, spot: 200))
      ..expect(const ExpectedStroke(timeMs: 400, hand: Hand.R, accent: true, spot: 400));
    expect(grader.hit(0, Hand.R, accented: false)?.wrongAccent, isTrue);
    expect(grader.hit(200, Hand.L, accented: true)?.wrongAccent, isTrue);
    final right = grader.hit(400, Hand.R, accented: true)!;
    expect(right.wrongAccent, isFalse);
    expect(right.judgement, Judgement.perfect);
    final summary = grader.summary;
    expect(summary.accentsGraded, isTrue);
    expect(summary.wrongAccents, 2);
  });

  test("doesn't grade accents when it isn't told whether hits were accented", () {
    final grader = Grader()
      ..expect(const ExpectedStroke(timeMs: 0, hand: Hand.R, accent: true, spot: 0));
    expect(grader.hit(0, Hand.R)?.wrongAccent, isFalse);
    expect(grader.summary.accentsGraded, isFalse);
  });

  test('combines accent grades', () {
    final combined = GradeSummary.combine([
      GradeSummary(counts: const {}, wrongHands: 0, extras: 0, offsets: OffsetStats.empty),
      GradeSummary(
        counts: const {},
        wrongHands: 0,
        accentsGraded: true,
        wrongAccents: 3,
        extras: 0,
        offsets: OffsetStats.empty,
      ),
    ]);
    expect(combined.accentsGraded, isTrue);
    expect(combined.wrongAccents, 3);
  });

  group('accentVelocityFor', () {
    test('splits soft and loud hits halfway across the gap between them', () {
      expect(accentVelocityFor([40, 45, 38, 50, 100, 110, 96, 105]), 73);
    });

    test("needs enough hits, that aren't all alike", () {
      expect(accentVelocityFor([40, 100, 45]), isNull);
      expect(accentVelocityFor([60, 62, 64, 61, 63]), isNull);
    });

    test('copes with uneven groups', () {
      final split = accentVelocityFor([30, 32, 35, 31, 33, 34, 90])!;
      expect(split, greaterThan(35));
      expect(split, lessThanOrEqualTo(90));
    });
  });

  test('judges more or less strictly by difficulty', () {
    Judgement judge(GradingDifficulty d, double errorMs) => Grader.at(d).judge(errorMs);
    expect(judge(GradingDifficulty.easy, 30), Judgement.perfect);
    expect(judge(GradingDifficulty.normal, 30), Judgement.good);
    expect(judge(GradingDifficulty.hard, 20), Judgement.good);
    expect(judge(GradingDifficulty.hard, -35), Judgement.early);
    expect(judge(GradingDifficulty.expert, 9), Judgement.perfect);
    expect(judge(GradingDifficulty.expert, 25), Judgement.late);
    // The window a hit can match a stroke within is the same at every difficulty.
    expect(
      Grader.at(GradingDifficulty.expert).windowMs,
      Grader.at(GradingDifficulty.easy).windowMs,
    );
  });
}
