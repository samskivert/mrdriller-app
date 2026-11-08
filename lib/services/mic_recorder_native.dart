// Recording the microphone on iOS, through the app's own native recorder (MicRecorder in
// ios/Runner/AppDelegate.swift): every buffer comes with its sample position and the host time it
// was recorded at, on the same clock as MIDI messages (see host_clock.dart), so [frameAt] maps
// times to frames exactly, rather than estimating it. (Android isn't done yet; its AudioRecord can
// give the same, through getTimestamp with TIMEBASE_MONOTONIC.)

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'host_clock.dart';
import 'mic_recorder.dart';

bool get isSupported => Platform.isIOS;

const _methods = MethodChannel('mrdriller/mic');
const _samples = EventChannel('mrdriller/mic/samples');

Future<MicRecorder> open() async {
  if (!isSupported) {
    throw const MicUnavailable("Recording the microphone isn't supported on this device yet.");
  }
  final Map<Object?, Object?>? info;
  try {
    info = await _methods.invokeMapMethod<Object?, Object?>('open');
  } on PlatformException catch (e) {
    throw MicUnavailable(e.message ?? "Couldn't record the microphone.");
  }
  final rate = info?['sampleRate'];
  if (rate is! num || rate <= 0) {
    _methods.invokeMethod<void>('close').ignore();
    throw const MicUnavailable("Couldn't record the microphone: it has no sample rate.");
  }
  return _NativeMicRecorder(rate.toDouble());
}

class _NativeMicRecorder implements MicRecorder {
  static const _maxSeconds = 90;

  @override
  final double sampleRate;
  StreamSubscription<Object?>? _subscription;
  // What's been recorded, in a buffer that's doubled in size whenever it fills.
  var _buffer = Float32List(1 << 16);
  int _length = 0;
  int? _startFrame;
  double _level = 0;
  bool _closed = false;
  // For each of the latest buffers, the frame it would have been at host time 0 (its frame less
  // its host time in frames): the same for every buffer, give or take rounding, as the samples
  // and the host clock keep step. [frameAt] goes by their median.
  final _offsets = <double>[];
  final _arrivals = <({double ms, double clockMs, int frame})>[];

  _NativeMicRecorder(this.sampleRate) {
    _subscription = _samples.receiveBroadcastStream().listen(_receive);
  }

  @override
  List<({double ms, double clockMs, int frame})> get arrivals => List.unmodifiable(_arrivals);

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

  void _receive(Object? event) {
    if (_closed || event is! Map) return;
    final frame = event['frame'], hostNs = event['hostNs'], chunk = event['samples'];
    if (frame is! int || hostNs is! int || chunk is! Float32List) return;
    final hostMs = hostNs / 1e6;
    _offsets.add(frame - hostMs * sampleRate / 1000);
    if (_offsets.length > 32) _offsets.removeAt(0);
    _level = chunk.fold(0.0, (peak, s) => math.max(peak, s.abs()));
    final start = _startFrame ??= frame;
    if (_length >= _maxSeconds * sampleRate) return;
    // If any frames were skipped, fill them with silence, so each sample stays at its frame.
    final gap = frame - (start + _length);
    if (gap > 0) {
      _append(Float32List(gap));
    } else if (gap < 0) {
      return;
    }
    _append(chunk);
    _arrivals.add((ms: hostClockMs(), clockMs: hostMs, frame: frame + chunk.length));
  }

  @override
  void clear() {
    _length = 0;
    _startFrame = null;
    _arrivals.clear();
  }

  @override
  double frameAt(double ms) {
    if (_offsets.isEmpty) return ms * sampleRate / 1000;
    final sorted = [..._offsets]..sort();
    return ms * sampleRate / 1000 + sorted[sorted.length ~/ 2];
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _subscription?.cancel();
    _methods.invokeMethod<void>('close').ignore();
  }
}
