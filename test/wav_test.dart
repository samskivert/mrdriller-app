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
}
