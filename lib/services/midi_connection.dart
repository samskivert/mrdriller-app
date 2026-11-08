// The app's one connection to MIDI input, shared by every screen that uses it, and kept open once
// made. (Opening a second MidiInput closes the first; see midi_input_web.dart.)

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'midi_input.dart';

enum MidiStatus { unsupported, disconnected, connecting, connected, failed }

class MidiConnection extends ChangeNotifier {
  MidiInput? _input;
  MidiStatus _status = MidiInput.isSupported ? MidiStatus.disconnected : MidiStatus.unsupported;
  String? _error;
  List<MidiPort> _ports = const [];
  final _messages = StreamController<MidiMessage>.broadcast();

  MidiStatus get status => _status;

  /// Why MIDI can't be used here (when [status] is unsupported), and where it can.
  String get unsupportedMessage => kIsWeb
      // (Safari, on Mac and iOS, doesn't do Web MIDI, nor any browser on iOS, which all use
      // Safari's engine.)
      ? "This browser doesn't support MIDI devices. Try Chrome, Edge or Firefox, or the iPhone "
            'app.'
      : "MIDI devices aren't supported on this device yet.";

  /// Why connecting failed, if it did.
  String? get error => _error;

  /// The MIDI inputs, connected or not, once connected.
  List<MidiPort> get ports => _ports;

  /// Messages from every input. Can be listened to before connecting.
  Stream<MidiMessage> get messages => _messages.stream;

  /// The current time on the clock that messages are timestamped with, in milliseconds (or 0
  /// before connecting).
  double now() => _input?.now() ?? 0;

  /// The port with [id], if there is one.
  MidiPort? portById(String id) {
    for (final port in _ports) {
      if (port.id == id) return port;
    }
    return null;
  }

  /// Connects to MIDI input, if it isn't already (or connecting), which may prompt for
  /// permission.
  Future<void> connect() async {
    if (_status == MidiStatus.unsupported ||
        _status == MidiStatus.connecting ||
        _status == MidiStatus.connected) {
      return;
    }
    _status = MidiStatus.connecting;
    _error = null;
    notifyListeners();
    try {
      final input = await MidiInput.open();
      // (Turned off again while it was connecting.)
      if (_status != MidiStatus.connecting) return input.close();
      _input = input;
      _ports = input.ports;
      input.onPortsChanged.listen((ports) {
        _ports = ports;
        notifyListeners();
      });
      input.messages.listen(_messages.add);
      _status = MidiStatus.connected;
    } on MidiUnavailable catch (e) {
      if (_status != MidiStatus.connecting) return;
      _error = e.message;
      _status = MidiStatus.failed;
    }
    notifyListeners();
  }

  /// Stops using MIDI input, until [connect] is called again.
  void disconnect() {
    _input?.close();
    _input = null;
    _ports = const [];
    _error = null;
    if (_status != MidiStatus.unsupported) _status = MidiStatus.disconnected;
    notifyListeners();
  }
}

/// App-wide singleton.
final MidiConnection midi = MidiConnection();
