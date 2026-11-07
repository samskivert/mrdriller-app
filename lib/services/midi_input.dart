import 'dart:async';
import 'dart:typed_data';

import 'midi_input_stub.dart' if (dart.library.js_interop) 'midi_input_web.dart' as impl;

/// A MIDI input device (e.g. a USB-MIDI cable, or a pad plugged in over USB).
class MidiPort {
  final String id;
  final String name;
  final String manufacturer;
  final bool connected;

  const MidiPort({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.connected,
  });
}

/// One message from a MIDI input.
class MidiMessage {
  final String portId;
  final Uint8List data;

  /// When the platform timestamped the message as it arrived from the device, in milliseconds on
  /// the clock of [MidiInput.now]. This is the time to judge a hit by.
  final double timestamp;

  /// When our code got the message, on the same clock. The gap between this and [timestamp] is
  /// how long the message waited for the (busy) main thread.
  final double receivedAt;

  const MidiMessage({
    required this.portId,
    required this.data,
    required this.timestamp,
    required this.receivedAt,
  });

  int get status => data.isEmpty ? 0 : data[0];
  int get command => status & 0xF0;

  /// The message's channel, 1-16 (as MIDI devices number them).
  int get channel => (status & 0x0F) + 1;

  int get data1 => data.length > 1 ? data[1] : 0;
  int get data2 => data.length > 2 ? data[2] : 0;

  /// A note on with velocity 0 is, by convention, a note off.
  bool get isNoteOn => command == 0x90 && data2 > 0;
  bool get isNoteOff => command == 0x80 || (command == 0x90 && data2 == 0);
  int get note => data1;
  int get velocity => data2;
}

/// Thrown by [MidiInput.open] when MIDI isn't available: unsupported, or permission refused.
class MidiUnavailable implements Exception {
  final String message;

  const MidiUnavailable(this.message);

  @override
  String toString() => message;
}

/// Access to the device's MIDI inputs, delivering the messages from all of them. Currently only
/// implemented on web (through Web MIDI); elsewhere [isSupported] is false.
abstract class MidiInput {
  /// Whether this platform can do MIDI input at all.
  static bool get isSupported => impl.isSupported;

  /// Gets access to MIDI input, which may prompt the user for permission. Throws
  /// [MidiUnavailable] if it can't.
  static Future<MidiInput> open() => impl.open();

  /// The inputs, connected or not, in the platform's order.
  List<MidiPort> get ports;

  /// Fires with the new [ports] when a device is connected or disconnected.
  Stream<List<MidiPort>> get onPortsChanged;

  /// Messages from every input.
  Stream<MidiMessage> get messages;

  /// The current time on the clock that messages are timestamped with, in milliseconds.
  double now();

  /// Stops listening to the inputs and closes the streams.
  void close();
}
