import 'dart:convert';
import 'dart:typed_data';

/// A point in a recording, as a marker that audio editors show on the waveform: at [frame] (from
/// the start of the samples), labelled [label].
typedef WavMarker = ({int frame, String label});

/// [samples] (one channel, from -1 to 1) as a WAV file of 32-bit floats, at [sampleRate].
///
/// A WAV file is a RIFF container: a series of chunks, each a four-character ID, its length, and
/// its data, which readers skip if they don't know them. Besides the format ("fmt ") and the
/// samples ("data"), it has:
/// - with [markers], a "cue " chunk of their positions and a "LIST" chunk of type "adtl" holding a
///   "labl" (label) for each, which editors like Audacity and Logic show as markers;
/// - with [notes], those as JSON in a chunk of its own ("json"), which nothing shows, but is where
///   everything else about the recording goes.
Uint8List encodeWav(
  Float32List samples,
  int sampleRate, {
  List<WavMarker> markers = const [],
  Object? notes,
}) {
  final body = BytesBuilder(copy: false);
  void chunk(String id, Uint8List data) {
    body
      ..add(ascii.encode(id))
      ..add(_u32(data.length))
      ..add(data);
    // (Each chunk starts on an even byte.)
    if (data.length.isOdd) body.addByte(0);
  }

  // The format: IEEE floats (3), one channel, 32 bits.
  chunk(
    'fmt ',
    Uint8List.fromList([
      ..._u16(3),
      ..._u16(1),
      ..._u32(sampleRate),
      ..._u32(sampleRate * 4),
      ..._u16(4),
      ..._u16(32),
      ..._u16(0),
    ]),
  );
  final data = ByteData(samples.length * 4);
  for (final (i, s) in samples.indexed) {
    data.setFloat32(i * 4, s, Endian.little);
  }
  chunk('data', data.buffer.asUint8List());
  if (markers.isNotEmpty) {
    // Each cue point: its id, its position, the chunk it's in ("data"), that chunk's start and
    // block start (both 0 for a plain WAV), and its offset in samples.
    final cues = BytesBuilder()..add(_u32(markers.length));
    final labels = BytesBuilder()..add(ascii.encode('adtl'));
    for (final (i, marker) in markers.indexed) {
      final id = i + 1;
      cues
        ..add(_u32(id))
        ..add(_u32(marker.frame))
        ..add(ascii.encode('data'))
        ..add(_u32(0))
        ..add(_u32(0))
        ..add(_u32(marker.frame));
      final text = [...utf8.encode(marker.label), 0];
      labels
        ..add(ascii.encode('labl'))
        ..add(_u32(4 + text.length))
        ..add(_u32(id))
        ..add(text);
      if (text.length.isOdd) labels.addByte(0);
    }
    chunk('cue ', cues.takeBytes());
    chunk('LIST', labels.takeBytes());
  }
  if (notes != null) chunk('json', Uint8List.fromList(utf8.encode(jsonEncode(notes))));

  final bytes = body.takeBytes();
  return (BytesBuilder(copy: false)
        ..add(ascii.encode('RIFF'))
        ..add(_u32(4 + bytes.length))
        ..add(ascii.encode('WAVE'))
        ..add(bytes))
      .takeBytes();
}

Uint8List _u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);

Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
