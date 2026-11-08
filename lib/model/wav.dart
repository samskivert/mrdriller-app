import 'dart:convert';
import 'dart:typed_data';

/// [samples] (one channel, from -1 to 1) as a WAV file of 32-bit floats, at [sampleRate], with
/// [notes], if given, as JSON in a chunk of its own ("json", after the samples), which players
/// skip over.
Uint8List encodeWav(Float32List samples, int sampleRate, {Object? notes}) {
  final json = notes == null ? null : utf8.encode(jsonEncode(notes));
  final jsonChunk = json == null ? 0 : 8 + json.length + json.length % 2;
  final dataBytes = samples.length * 4;
  final out = ByteData(12 + 26 + 8 + dataBytes + jsonChunk);
  var at = 0;
  void tag(String id) {
    for (final c in id.codeUnits) {
      out.setUint8(at++, c);
    }
  }

  void u32(int v) {
    out.setUint32(at, v, Endian.little);
    at += 4;
  }

  void u16(int v) {
    out.setUint16(at, v, Endian.little);
    at += 2;
  }

  tag('RIFF');
  u32(out.lengthInBytes - 8);
  tag('WAVE');
  // The format: IEEE floats (3), one channel, 32 bits.
  tag('fmt ');
  u32(18);
  u16(3);
  u16(1);
  u32(sampleRate);
  u32(sampleRate * 4);
  u16(4);
  u16(32);
  u16(0);
  tag('data');
  u32(dataBytes);
  for (final s in samples) {
    out.setFloat32(at, s, Endian.little);
    at += 4;
  }
  if (json != null) {
    tag('json');
    u32(json.length);
    for (final b in json) {
      out.setUint8(at++, b);
    }
  }
  return out.buffer.asUint8List();
}
