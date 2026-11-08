import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../model/timing.dart';
import 'mic_recorder.dart';

bool get isSupported =>
    web.window.navigator.has('mediaDevices') && web.window.has('AudioWorkletNode');

// Passes the microphone's samples back from the audio thread, a couple of thousand at a time,
// numbered by their frame on the audio context's clock.
const _worklet = '''
class DokodokoRecorder extends AudioWorkletProcessor {
  constructor() {
    super();
    this.buffer = new Float32Array(2048);
    this.length = 0;
    this.start = 0;
  }
  process(inputs) {
    const channel = inputs[0] && inputs[0][0];
    if (channel) {
      if (this.length === 0) this.start = currentFrame;
      this.buffer.set(channel, this.length);
      this.length += channel.length;
      if (this.length + channel.length > this.buffer.length) {
        this.port.postMessage({frame: this.start, samples: this.buffer.slice(0, this.length)});
        this.length = 0;
      }
    }
    return true;
  }
}
registerProcessor('dokodoko-recorder', DokodokoRecorder);
''';

// Where an open recorder leaves a function to close it, outlasting a hot restart (see
// midi_input_web.dart).
const _closeKey = '_dokodokoCloseMicRecorder';

Future<MicRecorder> open() async {
  if (!isSupported) throw const MicUnavailable("This browser can't record the microphone.");
  try {
    globalContext.getProperty<JSFunction?>(_closeKey.toJS)?.callAsFunction();
  } catch (_) {
    // It's the previous run's code; if it can't clean up, we carry on regardless.
  }
  final context = web.AudioContext();
  web.MediaStream? stream;
  try {
    final constraints =
        {
              'audio': {
                'echoCancellation': false,
                'noiseSuppression': false,
                'autoGainControl': false,
              },
            }.jsify()!
            as web.MediaStreamConstraints;
    stream = await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
    final blob = web.Blob([_worklet.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript'));
    final url = web.URL.createObjectURL(blob);
    await context.audioWorklet.addModule(url).toDart;
    web.URL.revokeObjectURL(url);
    final source = context.createMediaStreamSource(stream);
    final node = web.AudioWorkletNode(context, 'dokodoko-recorder');
    // The recorder has to lead somewhere to be run, so lead it to silence.
    final silence = context.createGain()..gain.value = 0;
    source.connect(node);
    node.connect(silence);
    silence.connect(context.destination);
    await context.resume().toDart;
    final recorder = _WebMicRecorder(context, stream, node);
    globalContext.setProperty(_closeKey.toJS, recorder.close.toJS);
    return recorder;
  } catch (e) {
    _stop(stream);
    context.close();
    if (e is MicUnavailable) rethrow;
    throw MicUnavailable("Couldn't record the microphone: $e");
  }
}

void _stop(web.MediaStream? stream) {
  for (final track in stream?.getTracks().toDart ?? const <web.MediaStreamTrack>[]) {
    track.stop();
  }
}

class _WebMicRecorder implements MicRecorder {
  static const _maxSeconds = 90;

  final web.AudioContext _context;
  final web.MediaStream _stream;
  final web.AudioWorkletNode _node;
  // What's been recorded, in a buffer that's doubled in size whenever it fills.
  var _buffer = Float32List(1 << 16);
  int _length = 0;
  int? _startFrame;
  double _level = 0;
  bool _closed = false;
  // Its processing clock (in milliseconds) against performance.now(), as the processing clock
  // only moves on a block at a time: so a time maps to the same frame whenever it's asked.
  final _clock = ClockSync(window: 5000);
  final _arrivals = <({double ms, double clockMs, int frame})>[];

  @override
  List<({double ms, double clockMs, int frame})> get arrivals => List.unmodifiable(_arrivals);

  void _sampleClock() => _clock.sample(web.window.performance.now(), _context.currentTime * 1000);

  _WebMicRecorder(this._context, this._stream, this._node) {
    _node.port.onmessage = ((web.MessageEvent event) => _receive(event.data as JSObject)).toJS;
  }

  @override
  double get sampleRate => _context.sampleRate;

  @override
  int get startFrame => _startFrame ?? 0;

  @override
  double get level => _level;

  // (A view of the buffer, not a copy, as it's read often while recording.)
  @override
  Float32List get samples => Float32List.sublistView(_buffer, 0, _length);

  void _append(Float32List chunk) {
    if (_length + chunk.length > _buffer.length) {
      var size = _buffer.length;
      while (_length + chunk.length > size) {
        size *= 2;
      }
      _buffer = Float32List(size)..setRange(0, _length, _buffer);
    }
    _buffer.setRange(_length, _length + chunk.length, chunk);
    _length += chunk.length;
  }

  void _receive(JSObject data) {
    _sampleClock();
    final frame = (data.getProperty<JSNumber>('frame'.toJS)).toDartInt;
    final chunk = data.getProperty<JSFloat32Array>('samples'.toJS).toDart;
    _level = chunk.fold(0.0, (peak, s) => math.max(peak, s.abs()));
    final start = _startFrame ??= frame;
    if (_length >= _maxSeconds * sampleRate) return;
    // If the audio thread skipped any frames, fill them with silence, so each sample stays at
    // its frame.
    final gap = frame - (start + _length);
    if (gap > 0) {
      _append(Float32List(gap));
    } else if (gap < 0) {
      return;
    }
    _append(chunk);
    _arrivals.add((
      ms: web.window.performance.now(),
      clockMs: _context.currentTime * 1000,
      frame: frame + chunk.length,
    ));
  }

  @override
  void clear() {
    _length = 0;
    _startFrame = null;
    _arrivals.clear();
  }

  @override
  double frameAt(double ms) {
    // By its processing clock, which numbers the frames recorded, read alongside
    // performance.now(). (Not getOutputTimestamp(), which is about what it outputs, and as it
    // outputs only silence, can report a stale position, mapping times to before the recording.)
    // Smoothed (see _clock), as read directly it's off by up to a block, differently each time.
    _sampleClock();
    return _clock.toStepped(ms)! / 1000 * sampleRate;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _node.port.onmessage = null;
    _stop(_stream);
    _context.close();
  }
}
