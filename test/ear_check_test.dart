import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/ear_check.dart';
import 'package:mrdriller/widgets/calibration_grid.dart';
import 'package:mrdriller/widgets/ear_raster.dart';

const _rate = 48000.0;
int _frames(double ms) => (ms * _rate / 1000).round();

double _hz(int index) => index.isEven ? 800 : 400;

// The metronome's click's level at [t] seconds in: ramping up over 2ms, holding for 35ms, then
// dying away.
double _clickLevel(double t) {
  if (t < 0.002) return t / 0.002;
  if (t < 0.037) return 1;
  return math.exp(-(t - 0.037) / 0.015);
}

void _addClick(Float32List samples, double atMs, double hz, {double level = 0.2}) {
  final start = atMs * _rate / 1000;
  for (var i = start.ceil(); i < start + _frames(100) && i < samples.length; i++) {
    final t = (i - start) / _rate;
    samples[i] += level * _clickLevel(t) * math.sin(2 * math.pi * hz * t);
  }
}

void _addThwack(Float32List samples, double atMs, math.Random random, {double ringMs = 8}) {
  final start = _frames(atMs);
  for (var i = 0; i < _frames(ringMs * 6) && start + i < samples.length; i++) {
    samples[start + i] += 0.5 * math.exp(-i / _frames(ringMs)) * (random.nextDouble() * 2 - 1);
  }
}

// A session at 120 bpm, two clicks a beat (every 250ms) from 1000ms: the clicks come out [delay]
// ms after they're scheduled, and the microphone records sounds 10ms after they're made, at frames
// numbered from 0 at time 0. The player listens to the 8-click count-in, then plays each click
// [lead] ms (by index) from when they hear it (or not, if null). A hit comes in over MIDI 3ms after it's made. The
// rough mapping from times to frames is 20ms out.
({Float32List samples, List<double> clicks, List<double> hits}) _session(
  int clickCount,
  double? Function(int index)? lead, {
  bool clicksAudible = true,
  double delay = 40,
  double noise = 0.002,
  double clickLevel = 0.2,
  double? boopLevel,
  double micDelay = 10,
  double ringMs = 8,
}) {
  final random = math.Random(3);
  final samples = Float32List.fromList([
    for (var i = 0; i < _frames(1000.0 + clickCount * 250 + 500); i++)
      (random.nextDouble() - 0.5) * noise,
  ]);
  final clicks = [for (var i = 0; i < clickCount; i++) 1000.0 + i * 250];
  final hits = <double>[];
  for (final (i, scheduled) in clicks.indexed) {
    final heard = scheduled + delay;
    if (clicksAudible) {
      final level = i.isOdd ? (boopLevel ?? clickLevel) : clickLevel;
      _addClick(samples, heard + micDelay, _hz(i), level: level);
    }
    final ahead = i >= 8 ? lead?.call(i) : null;
    if (ahead != null) {
      final made = heard + ahead;
      _addThwack(samples, made + micDelay, random, ringMs: ringMs);
      hits.add(made + 3);
    }
  }
  return (samples: samples, clicks: clicks, hits: hits);
}

double _frameAt(double ms) => (ms + 20) * _rate / 1000;

EarCheck _check() => EarCheck(countIn: 8, intervalMs: 250, toneHz: _hz, sampleRate: _rate);

void main() {
  test('hears how far ahead of the clicks the hits were', () {
    final random = math.Random(9);
    final session = _session(40, (_) => -45 + (random.nextDouble() * 2 - 1) * 10);
    final check = _check();
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    expect(check.state, EarCheckState.checking);
    // Every click after the count-in, found in the recording, with its hit.
    expect(check.beats, hasLength(32));
    expect(check.beats.every((b) => b.clickMatched), isTrue);
    expect(check.beats.every((b) => b.hitMs != null && b.hitHeard), isTrue);
    expect(check.countInHeard, {0, 1, 2, 3, 4, 5, 6, 7});
    expect(check.stats.mean, closeTo(-45, 1.5));
    // Its shapes: the click at the middle, and the hit about 45ms (18 steps) before it.
    final beat = check.beats.first;
    expect(beat.tone.length, EarCheck.bins);
    final hitPeak = beat.hit.indexOf(1.0);
    expect(hitPeak, inInclusiveRange(EarCheck.bins ~/ 2 - 22, EarCheck.bins ~/ 2 - 14));
  });

  test('finds a click even right under a hit', () {
    // Hits a few milliseconds from their clicks, either way, so their sounds overlap.
    final session = _session(24, (i) => i.isEven ? -3 : 4);
    final check = _check();
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    expect(check.beats, hasLength(16));
    for (final beat in check.beats) {
      // (Not matched, with the hit on top of it, but predicted from the clean ones.)
      expect(beat.clickMatched, isFalse);
      expect(beat.hitMs, closeTo(beat.index.isEven ? -3 : 4, 1.5));
    }
  });

  test('checks clicks as their stretch of the recording comes in', () {
    final session = _session(20, (_) => -30);
    final check = _check();
    // Only the count-in so far: still listening.
    final countInOnly = Float32List.sublistView(session.samples, 0, _frames(2700));
    check.update(
      samples: countInOnly,
      startFrame: 0,
      clicks: session.clicks.sublist(0, 8),
      hits: const [],
      frameAt: _frameAt,
    );
    expect(check.state, EarCheckState.listening);
    // Then a few more clicks.
    final more = Float32List.sublistView(session.samples, 0, _frames(4800));
    expect(
      check.update(
        samples: more,
        startFrame: 0,
        clicks: session.clicks,
        hits: session.hits,
        frameAt: _frameAt,
      ),
      isTrue,
    );
    final soFar = check.beats.length;
    expect(soFar, inInclusiveRange(4, 9));
    // And the rest.
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    expect(check.beats, hasLength(12));
    expect(check.stats.mean, closeTo(-30, 1.5));
  });

  test("says when it can't hear the clicks", () {
    final session = _session(16, (_) => -30, clicksAudible: false);
    final check = _check();
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    expect(check.state, EarCheckState.cantHear);
    expect(check.beats, isEmpty);
  });

  test("leaves a click without a hit when the player doesn't play it", () {
    final session = _session(16, (i) => i == 10 ? null : -20);
    final check = _check();
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    final missed = check.beats.firstWhere((b) => b.index == 10);
    expect(missed.hitMs, isNull);
    expect(check.beats.where((b) => b.hitMs != null), hasLength(7));
  });

  testWidgets('draws the beats it heard', (tester) async {
    final session = _session(24, (i) => i == 12 ? null : -40);
    final check = _check()
      ..update(
        samples: session.samples,
        startFrame: 0,
        clicks: session.clicks,
        hits: session.hits,
        frameAt: _frameAt,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: EarRaster(beats: check.beats.reversed.take(12).toList()),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(EarRaster), findsOneWidget);
  });

  test('finds the clicks however long they take to come out (up to half a second)', () {
    final session = _session(24, (_) => -35, delay: 300);
    final check = _check();
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    expect(check.state, EarCheckState.checking);
    expect(check.stats.mean, closeTo(-35, 1.5));
    expect(check.diagnosis, contains('8 of 8 clicks lined up'));
  });

  test('finds faint clicks in a noisy room by their tones', () {
    // Clicks barely louder overall than the room's noise.
    final session = _session(24, (_) => -35, noise: 0.03, clickLevel: 0.025);
    final check = _check();
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    expect(check.diagnosis, contains('8 of 8 clicks lined up'));
    expect(check.state, EarCheckState.checking);
    // (Where a click this faint starts can only be told to within a couple of milliseconds,
    // its rise half lost in the noise.)
    expect(check.stats.mean, closeTo(-35, 3));
  });

  test('finds low clicks played much more quietly than high ones, as small speakers do', () {
    final session = _session(24, (_) => -35, noise: 0.01, boopLevel: 0.02);
    final check = _check();
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    expect(check.diagnosis, contains('8 of 8 clicks lined up'));
    expect(check.state, EarCheckState.checking);
    expect(check.stats.mean, closeTo(-35, 2));
  });

  test("works with only the high clicks heard, as through headphones held to the mic", () {
    final session = _session(32, (_) => -40, boopLevel: 0);
    final check = _check();
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    expect(check.state, EarCheckState.checking);
    expect(check.countInHeard, {0, 2, 4, 6});
    expect(check.beats.where((b) => b.hitMs != null), hasLength(24));
    expect(check.stats.mean, closeTo(-40, 1.5));
    expect(check.diagnosis, contains('4 of 8 clicks lined up'));
  });

  test("finds hits however far off the MIDI times map, and however long they ring", () {
    // The microphone records 150ms after the sounds are made, which the rough mapping doesn't know
    // about, and the hits ring on for a while, as a pad in a room does.
    final session = _session(32, (_) => -50, micDelay: 150, ringMs: 30);
    final check = _check();
    check.update(
      samples: session.samples,
      startFrame: 0,
      clicks: session.clicks,
      hits: session.hits,
      frameAt: _frameAt,
    );
    expect(check.state, EarCheckState.checking);
    expect(check.beats.where((b) => b.hitMs != null), hasLength(24));
    expect(check.stats.mean, closeTo(-50, 2));
  });

  test("measures the system's delay from the MIDI hits and the hits heard", () {
    final random = math.Random(5);
    final session = _session(40, (_) => -45 + (random.nextDouble() * 2 - 1) * 10);
    final check = _check()
      ..update(
        samples: session.samples,
        startFrame: 0,
        clicks: session.clicks,
        hits: session.hits,
        frameAt: _frameAt,
      );
    // Each hit's offset from the click it was on, by MIDI, with a double trigger on one click and
    // a stray hit on another, which shouldn't count.
    final midiOffsets = <int, List<double>>{};
    for (final hit in session.hits) {
      final index = ((hit - 1000) / 250).round();
      (midiOffsets[index] ??= []).add(hit - session.clicks[index]);
    }
    midiOffsets[12]!.add(midiOffsets[12]!.first + 20);
    midiOffsets[20] = [90];
    final delay = systemDelay(check.beats, midiOffsets);
    // The clicks come out 40ms late, and the hits arrive 3ms after they're made.
    expect(delay.mean, closeTo(43, 1.5));
    expect(delay.count, inInclusiveRange(30, 32));
  });

  testWidgets('draws a calibration grid of every kind of click', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: CalibrationGrid(
              countIn: 8,
              current: 12,
              cells: [
                ...[
                  for (var i = 0; i < 7; i++) const CalibrationCell(CalibrationCellKind.clickHeard),
                ],
                const CalibrationCell(CalibrationCellKind.clickNotHeard),
                const CalibrationCell(CalibrationCellKind.hitHeard, -45),
                const CalibrationCell(CalibrationCellKind.hitNotHeard, 10),
                const CalibrationCell(CalibrationCellKind.missed),
                const CalibrationCell(CalibrationCellKind.hitHeard, -200),
                ...[for (var i = 0; i < 60; i++) CalibrationCell.pending],
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // A row for the count-in and one for every eight clicks played.
    expect(tester.getSize(find.byType(CalibrationGrid)).height, greaterThan(9 * 22));
  });
}
