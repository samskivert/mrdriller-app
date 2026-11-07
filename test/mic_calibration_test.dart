import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/mic_calibration.dart';

const _rate = 48000.0;

int _frames(double ms) => (ms * _rate / 1000).round();

// A noisy recording [ms] long, quiet unless [noise] says otherwise.
Float32List _recording(double ms, {int seed = 1, double noise = 0.002}) {
  final random = math.Random(seed);
  return Float32List.fromList([
    for (var i = 0; i < _frames(ms); i++) (random.nextDouble() - 0.5) * noise,
  ]);
}

// The metronome's beep's level at [t] seconds in (see assets/sounds/update_sounds.py): ramping
// up over 2ms, holding for 35ms, then dying away.
double _beepLevel(double t) {
  if (t < 0.002) return t / 0.002;
  if (t < 0.037) return 1;
  return math.exp(-(t - 0.037) / 0.015);
}

// Adds the metronome's 800Hz beep at [at] ms (which may fall between samples).
void _addBeep(Float32List samples, double at, {double level = 0.3}) {
  final start = at * _rate / 1000;
  for (var i = start.ceil(); i < start + _frames(100) && i < samples.length; i++) {
    final t = (i - start) / _rate;
    samples[i] += level * _beepLevel(t) * math.sin(2 * math.pi * 800 * t);
  }
}

// Adds a stick's thwack (a burst of noise, dying away over 30ms) at [at] ms.
void _addThwack(Float32List samples, double at, {double level = 0.5}) {
  final random = math.Random(at.round());
  final start = _frames(at);
  for (var i = 0; i < _frames(30); i++) {
    final decay = math.exp(-i / _frames(8));
    samples[start + i] += level * decay * (random.nextDouble() * 2 - 1);
  }
}

void main() {
  group('findOnset', () {
    test('finds where a sound starts, to within a millisecond', () {
      final samples = _recording(500);
      _addBeep(samples, 200);
      final onset = findOnset(samples, 0, samples.length)!;
      expect(onset.index, closeTo(_frames(200), _frames(1)));
      expect(onset.peak, greaterThan(onset.noise * 12));
    });

    test('finds nothing in silence', () {
      expect(findOnset(_recording(500), 0, _frames(500)), isNull);
    });

    test('only looks between where it is told', () {
      final samples = _recording(500);
      _addBeep(samples, 100);
      _addThwack(samples, 300);
      expect(findOnset(samples, _frames(200), _frames(500))!.index, closeTo(_frames(300), 48));
    });
  });

  group('measureMicDelay', () {
    // Sound takes 33ms to come out of the speakers and a hit 2ms to come in over MIDI, so the
    // system delay is 35ms. The microphone takes 10ms more to record sounds, and its frames are
    // numbered from 5000 at time 0; the rough mapping from times to frames is 20ms off.
    const outMs = 33.0, midiInMs = 2.0, micInMs = 10.0, startFrame = 5000;
    double frameAt(double ms) => startFrame + (ms + 20) * _rate / 1000;

    // A recording of clicks every second from 1000ms, and hits (at [hitTimes], when the stick
    // really struck), and the MIDI timestamps of those hits.
    (Float32List, List<double>, List<double>) session(List<double> hitTimes) {
      final samples = _recording(6000);
      final clicks = <double>[1000, 2000, 3000, 4000, 5000];
      for (final click in clicks) {
        _addBeep(samples, click + outMs + micInMs);
      }
      for (final hit in hitTimes) {
        _addThwack(samples, hit + micInMs);
      }
      return (samples, clicks, [for (final hit in hitTimes) hit + midiInMs]);
    }

    test('measures the system delay, however the hits fall between the clicks', () {
      final (samples, clicks, hits) = session([1500, 2380, 3720, 4610]);
      final result = measureMicDelay(
        clicks: clicks,
        hits: hits,
        samples: samples,
        startFrame: startFrame,
        sampleRate: _rate,
        frameAt: frameAt,
      );
      expect(result.pairs, hasLength(4));
      for (final pair in result.pairs) {
        expect(pair.problem, isNull);
        expect(pair.delayMs, closeTo(outMs + midiInMs, 1));
      }
      expect(result.stats.mean, closeTo(35, 1));
      expect(result.stats.spread, lessThan(1));
    });

    test("skips hits too close to a click, as their sounds overlap, and says why", () {
      final (samples, clicks, hits) = session([1500, 2040, 2950]);
      final result = measureMicDelay(
        clicks: clicks,
        hits: hits,
        samples: samples,
        startFrame: startFrame,
        sampleRate: _rate,
        frameAt: frameAt,
      );
      expect(
        [for (final p in result.pairs) p.problem],
        [null, 'too close to a click', 'too close to a click'],
      );
      expect(result.agreeing, hasLength(1));
    });

    test("says when it didn't hear the hit or the click", () {
      final samples = _recording(6000);
      _addThwack(samples, 2500 + micInMs);
      final result = measureMicDelay(
        clicks: [1000, 2000, 3000],
        hits: [1500 + midiInMs, 2500 + midiInMs],
        samples: samples,
        startFrame: startFrame,
        sampleRate: _rate,
        frameAt: frameAt,
      );
      expect(
        [for (final p in result.pairs) p.problem],
        ["didn't hear the hit", "didn't hear the click"],
      );
    });

    test('leaves out delays that disagree with the rest', () {
      final result = MicMeasurement([
        for (final delay in [35.0, 34.5, 36.0, 80.0, 35.5])
          MicPair(clickMs: 0, hitMs: 500, delayMs: delay),
      ]);
      expect(result.agreeing, [34.5, 35.0, 35.5, 36.0]);
      expect(result.stats.mean, closeTo(35.25, 0.001));
    });
  });
}
