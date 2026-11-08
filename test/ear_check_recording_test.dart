import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/ear_check.dart';

// Real recordings of playing along (saved by SAVE RECORDING, in debug builds), through a
// MacBook's speakers and microphone, with a KAT pad played by stick, and the system delay each
// should come out at. Analyzed offline, the first's hits' sounds come 0.7ms either way from where
// their MIDI times put them, and its system delay is about 56.5ms. (A missing one is skipped.)
const _recordings = {
  'test/recordings/in-the-air-120-bpm-2026-11-07T15-05-01.wav': 56.5,
  // One with every other hit much quieter (2026-11-07T17-12-51), whose system delay came out live
  // as 56.1ms.
  'test/recordings/in-the-air-120-bpm-2026-11-07T17-12-51.wav': 56.5,
  // One where matching clicks to their templates went wrong, which they used to be placed by.
  'test/recordings/in-the-air-120-bpm-2026-11-07T17-56-50.wav': 56.5,
  // An iPhone's own speaker and microphone (with the iOS recorder's exact sample times).
  'test/recordings/in-the-air-iOS-120-bpm-2026-11-07T22-52-19.wav': 51.8,
};

({Float32List samples, int rate, Map<String, dynamic> notes}) _load(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var at = 12, rate = 0, format = 0;
  Float32List? samples;
  Map<String, dynamic>? notes;
  while (at + 8 <= bytes.length) {
    final tag = String.fromCharCodes(bytes.sublist(at, at + 4));
    final size = data.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (tag == 'fmt ') {
      format = data.getUint16(body, Endian.little);
      rate = data.getUint32(body + 4, Endian.little);
    }
    // (As saved, 32-bit floats; or, to keep the ones here small, 16-bit integers.)
    if (tag == 'data') {
      final float = format == 3;
      samples = Float32List(size ~/ (float ? 4 : 2));
      for (var i = 0; i < samples.length; i++) {
        samples[i] = float
            ? data.getFloat32(body + i * 4, Endian.little)
            : data.getInt16(body + i * 2, Endian.little) / 32768;
      }
    }
    if (tag == 'json') notes = jsonDecode(utf8.decode(bytes.sublist(body, body + size)));
    at = body + size + size % 2;
  }
  return (samples: samples!, rate: rate, notes: notes!);
}

void main() {
  for (final MapEntry(key: path, value: expectedDelay) in _recordings.entries) {
    test('hears a real recording to within a couple of milliseconds: $path', () {
      _check(path, expectedDelay);
    }, skip: File(path).existsSync() ? false : 'no recording at $path');
  }
}

void _check(String path, double expectedDelay) {
  final recording = _load(path);
  final notes = recording.notes;
  final startFrame = notes['startFrame'] as int;
  final clicks = [for (final c in notes['clicks']) (c['ms'] as num).toDouble()];
  final hits = [for (final h in notes['hits']) (h['ms'] as num).toDouble()];
  // The mapping from times to frames it was saved with (one line, through the clicks').
  final first = notes['clicks'].first, last = notes['clicks'].last;
  final perMs = (last['frame'] - first['frame']) / (last['ms'] - first['ms']);
  double frameAt(double ms) => first['frame'] + (ms - first['ms']) * perMs;
  double msAt(double frame) => first['ms'] + (frame - first['frame']) / perMs;

  final check = EarCheck(
    countIn: notes['countIn'],
    intervalMs: (notes['intervalMs'] as num).toDouble(),
    toneHz: (i) => i % notes['clicksPerBeat'] == 0 ? 800 : 400,
    sampleRate: recording.rate.toDouble(),
  );
  // As it would have heard it live: a tenth of a second more each time.
  final step = recording.rate ~/ 10;
  for (var length = step; ; length += step) {
    final samples = Float32List.sublistView(
      recording.samples,
      0,
      length.clamp(0, recording.samples.length),
    );
    final now = msAt((startFrame + samples.length).toDouble());
    check.update(
      samples: samples,
      startFrame: startFrame,
      clicks: [
        for (final c in clicks)
          if (c <= now) c,
      ],
      hits: [
        for (final h in hits)
          if (h <= now) h,
      ],
      frameAt: frameAt,
    );
    if (length >= recording.samples.length) break;
  }
  expect(check.state, EarCheckState.checking);
  final heard = check.beats.where((b) => b.hitMs != null).length;
  final midiOffsets = <int, List<double>>{
    for (final e in (notes['midiOffsets'] as Map).entries)
      int.parse(e.key): [for (final o in e.value) (o as num).toDouble()],
  };
  final delay = systemDelay(check.beats, midiOffsets);
  // Each hit's burst actually heard, not just taken to be where expected.
  final looked = check.log.where((e) => e.containsKey('hit'));
  final found = looked.where((e) => e['onset'] != null).length;
  // ignore: avoid_print
  print(
    '$path: $heard hits, $found of ${looked.length} heard; delay ${check.systemDelayMs}; '
    'per click ${delay.mean} (spread ${delay.spread}, ${delay.count})',
  );
  expect(heard, greaterThanOrEqualTo(hits.length - 4));
  expect(found, greaterThanOrEqualTo(looked.length * 0.9));
  expect(check.log.where((e) => e.containsKey('unplaced')), isEmpty);
  expect(check.systemDelayMs, closeTo(expectedDelay, 2));
  expect(delay.mean, closeTo(expectedDelay, 2));
  expect(delay.spread, lessThan(2));
}
