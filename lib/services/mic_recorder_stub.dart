import 'mic_recorder.dart';

bool get isSupported => false;

Future<MicRecorder> open() async =>
    throw const MicUnavailable("Recording the microphone isn't supported on this platform yet.");
