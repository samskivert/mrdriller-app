import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/wav.dart';

void main() {
  test('writes the samples as floats, with notes in a chunk after them', () {
    final bytes = encodeWav(Float32List.fromList([0, 0.5, -0.25]), 48000, notes: {'bpm': 120});
    final data = ByteData.sublistView(bytes);
    String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
    expect(tag(0), 'RIFF');
    expect(data.getUint32(4, Endian.little), bytes.length - 8);
    expect(tag(8), 'WAVE');
    expect(data.getUint16(20, Endian.little), 3);
    expect(data.getUint32(24, Endian.little), 48000);
    expect(tag(38), 'data');
    expect(data.getUint32(42, Endian.little), 12);
    expect(data.getFloat32(54, Endian.little), -0.25);
    expect(tag(58), 'json');
    final length = data.getUint32(62, Endian.little);
    expect(jsonDecode(utf8.decode(bytes.sublist(66, 66 + length))), {'bpm': 120});
  });

  test('writes markers as cue points with labels', () {
    final bytes = encodeWav(
      Float32List(100),
      48000,
      markers: [(frame: 10, label: 'click 8'), (frame: 42, label: 'hit 8 -41.2ms')],
      notes: {'bpm': 120},
    );
    final data = ByteData.sublistView(bytes);
    // Every chunk, by id.
    final chunks = <String, Uint8List>{};
    for (var at = 12; at < bytes.length;) {
      final id = String.fromCharCodes(bytes.sublist(at, at + 4));
      final size = data.getUint32(at + 4, Endian.little);
      chunks[id] = bytes.sublist(at + 8, at + 8 + size);
      at += 8 + size + size % 2;
    }
    expect(chunks.keys, ['fmt ', 'data', 'cue ', 'LIST', 'json']);
    final cue = ByteData.sublistView(chunks['cue ']!);
    expect(cue.getUint32(0, Endian.little), 2);
    // The second point's id and position (each point is 24 bytes, after the count).
    expect(cue.getUint32(4 + 24, Endian.little), 2);
    expect(cue.getUint32(4 + 24 + 20, Endian.little), 42);
    final list = chunks['LIST']!;
    expect(String.fromCharCodes(list.sublist(0, 4)), 'adtl');
    final labels = String.fromCharCodes(list).split(RegExp('labl....'));
    expect(labels.any((l) => l.contains('click 8')), isTrue);
    expect(labels.any((l) => l.contains('hit 8 -41.2ms')), isTrue);
    expect(jsonDecode(utf8.decode(chunks['json']!)), {'bpm': 120});
  });
}
