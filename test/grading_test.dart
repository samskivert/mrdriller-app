import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/grading.dart';
import 'package:mrdriller/model/model.dart';

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
  });
}
