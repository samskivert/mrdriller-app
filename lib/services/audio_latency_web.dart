import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'audio_latency.dart';

Future<AudioLatency?> browserAudioLatency() async {
  final context = web.AudioContext();
  try {
    await context.resume().toDart;
    // It only knows its output latency once it's been running for a moment.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (context.state != 'running') return null;
    return (output: context.outputLatency * 1000, base: context.baseLatency * 1000);
  } catch (_) {
    return null;
  } finally {
    context.close();
  }
}
