import 'midi_input.dart';

bool get isSupported => false;

Future<MidiInput> open() async =>
    throw const MidiUnavailable("MIDI input isn't supported on this platform yet.");
