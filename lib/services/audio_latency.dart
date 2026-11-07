import 'audio_latency_stub.dart' if (dart.library.js_interop) 'audio_latency_web.dart' as impl;

/// The browser's own estimates of the delay in sound reaching the current output device, in
/// milliseconds: [output] from its audio graph to the device (as the OS reports it), and [base] its
/// own buffering. Neither includes the audio engine's buffering (see sound_engine.dart).
typedef AudioLatency = ({double output, double base});

/// Asks the browser for its [AudioLatency] estimates, or null if it can't say (or this isn't a
/// browser). Call it from a tap: the audio it starts up to ask needs one.
Future<AudioLatency?> browserAudioLatency() => impl.browserAudioLatency();
