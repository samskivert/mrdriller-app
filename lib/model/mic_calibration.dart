// Measures a drum pad's timing calibration with the microphone: how long the click takes to come
// out of the speakers plus how long a hit takes to come in over MIDI, without the player's own
// timing in it (which playing along can't separate out).
//
// The microphone hears both the click and the stick hitting the pad. For a click scheduled at T
// and a hit with MIDI timestamp M, whose sounds the microphone records at frames C and S:
//
//   system delay = (C - S) / sampleRate + (M - T)
//
// The microphone's own delay is in both C and S, so it cancels, and each difference is between two
// times on the same clock, so the microphone's clock never needs mapping onto the MIDI one
// (except roughly, to know where to look for each sound). When the player hits doesn't matter,
// as long as it's well clear of the clicks, so the two sounds don't overlap.

import 'dart:math' as math;
import 'dart:typed_data';

import 'timing.dart';

/// Where a sound starts in a recording (in samples), and how loud it and the background around it
/// are.
class Onset {
  final double index;
  final double peak;
  final double noise;

  const Onset(this.index, this.peak, this.noise);
}

/// The first sound standing out from the background in [samples] from [from] to [to], or null if
/// nothing does. It starts at the first sample louder than a fifth of the loudest (and well above
/// the background, which most of the stretch should be).
Onset? findOnset(Float32List samples, int from, int to) {
  from = math.max(0, from);
  to = math.min(samples.length, to);
  if (to - from < 32) return null;
  var peak = 0.0;
  final levels = Float64List(to - from);
  for (var i = from; i < to; i++) {
    final level = samples[i].abs();
    levels[i - from] = level;
    if (level > peak) peak = level;
  }
  final sorted = Float64List.fromList(levels)..sort();
  final noise = sorted[sorted.length ~/ 2];
  if (peak < 0.002 || peak < noise * 12) return null;
  final threshold = math.max(peak * 0.2, noise * 6);
  for (var i = 0; i < levels.length; i++) {
    if (levels[i] >= threshold) return Onset((from + i).toDouble(), peak, noise);
  }
  return null;
}

/// One hit, paired with the click before it, and what came of measuring them.
class MicPair {
  /// When the click was scheduled and when the hit came in, on the MIDI clock, in milliseconds.
  final double clickMs;
  final double hitMs;
  final Onset? clickOnset;
  final Onset? hitOnset;

  /// The system delay measured from them, or null if it couldn't be (see [problem]).
  final double? delayMs;
  final String? problem;

  const MicPair({
    required this.clickMs,
    required this.hitMs,
    this.clickOnset,
    this.hitOnset,
    this.delayMs,
    this.problem,
  });
}

class MicMeasurement {
  final List<MicPair> pairs;

  /// The delays that agree with each other (within [_agreementMs] of their median), which the
  /// result is taken from.
  final List<double> agreeing;

  static const _agreementMs = 10.0;

  MicMeasurement(this.pairs) : agreeing = _agreeing(pairs);

  OffsetStats get stats => OffsetStats.of(agreeing);

  static List<double> _agreeing(List<MicPair> pairs) {
    final delays = [for (final p in pairs) ?p.delayMs]..sort();
    if (delays.isEmpty) return const [];
    final median = delays[delays.length ~/ 2];
    return [
      for (final d in delays)
        if ((d - median).abs() <= _agreementMs) d,
    ];
  }
}

/// Measures the system delay from [clicks] and [hits] (on the MIDI clock, in milliseconds) and a
/// recording of them: [samples] at [sampleRate], whose first is the recorder's frame
/// [startFrame]. [frameAt] gives the recorder's frame at a time on the MIDI clock, roughly (to
/// within a few tens of milliseconds), to know where to look for each sound.
MicMeasurement measureMicDelay({
  required List<double> clicks,
  required List<double> hits,
  required Float32List samples,
  required int startFrame,
  required double sampleRate,
  required double Function(double ms) frameAt,
  double minGapMs = 150,
}) {
  int frames(double ms) => (ms * sampleRate / 1000).round();
  int indexAt(double ms) => (frameAt(ms) - startFrame).round();
  final pairs = <MicPair>[];
  for (final hit in hits) {
    final before = clicks.lastWhere((c) => c <= hit, orElse: () => double.nan);
    if (before.isNaN) continue;
    final after = clicks.firstWhere((c) => c > hit, orElse: () => double.infinity);
    if (hit - before < minGapMs || after - hit < minGapMs) {
      pairs.add(MicPair(clickMs: before, hitMs: hit, problem: 'too close to a click'));
      continue;
    }
    // The stick's sound comes in around when the hit did, give or take the devices' delays.
    final hitIndex = indexAt(hit);
    final hitOnset = findOnset(samples, hitIndex - frames(50), hitIndex + frames(150));
    if (hitOnset == null) {
      pairs.add(MicPair(clickMs: before, hitMs: hit, problem: "didn't hear the hit"));
      continue;
    }
    // The click comes out some time after it was scheduled, but before the hit's sound.
    final clickIndex = indexAt(before);
    final clickOnset = findOnset(
      samples,
      clickIndex - frames(20),
      math.min(clickIndex + frames(400), hitOnset.index.round() - frames(20)),
    );
    if (clickOnset == null) {
      pairs.add(
        MicPair(clickMs: before, hitMs: hit, hitOnset: hitOnset, problem: "didn't hear the click"),
      );
      continue;
    }
    pairs.add(
      MicPair(
        clickMs: before,
        hitMs: hit,
        clickOnset: clickOnset,
        hitOnset: hitOnset,
        delayMs: (clickOnset.index - hitOnset.index) * 1000 / sampleRate + (hit - before),
      ),
    );
  }
  return MicMeasurement(pairs);
}
