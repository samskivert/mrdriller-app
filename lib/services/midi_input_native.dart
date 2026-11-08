// MIDI input on iOS and Android, through flutter_midi_command (CoreMIDI and android.media.midi).
//
// Hits are judged by when the platform timestamped each message as it came in from the device, not
// when Dart got it, which can be late by however long the main thread was busy. [now] reads the
// same clock as the timestamps (see host_clock.dart), so they line up exactly.
//
// See docs/calibration.md for why the timestamps matter.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart' as fmc;

import 'host_clock.dart';
import 'midi_input.dart';

bool get isSupported => Platform.isIOS || Platform.isAndroid;

Future<MidiInput> open() async {
  if (!isSupported) {
    throw const MidiUnavailable("MIDI input isn't supported on this platform yet.");
  }
  final input = _NativeMidiInput();
  try {
    await input._start();
  } catch (e) {
    input.close();
    throw MidiUnavailable("Couldn't start MIDI: $e");
  }
  return input;
}

class _NativeMidiInput implements MidiInput {
  final _command = fmc.MidiCommand();
  final _messages = StreamController<MidiMessage>.broadcast();
  final _portsChanged = StreamController<List<MidiPort>>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _connected = <String, fmc.MidiDevice>{};
  List<MidiPort> _ports = const [];
  bool _closed = false;

  // Messages whose timestamp didn't fit when they arrived (on another clock, or none), which were
  // timed by their arrival instead: if this climbs, the platform's timestamps can't be trusted.
  int untimed = 0;

  @override
  List<MidiPort> get ports => _ports;

  @override
  Stream<List<MidiPort>> get onPortsChanged => _portsChanged.stream;

  @override
  Stream<MidiMessage> get messages => _messages.stream;

  @override
  double now() => hostClockMs();

  Future<void> _start() async {
    final packets = _command.onMidiPacketReceived;
    if (packets != null) _subscriptions.add(packets.listen(_onPacket));
    final setup = _command.onMidiSetupChanged;
    if (setup != null) _subscriptions.add(setup.listen((_) => _refresh()));
    await _refresh();
  }

  // Lists the devices, connecting to any new ones (devices plugged in over USB, or through a
  // USB-MIDI cable; not Bluetooth or virtual ones, for now).
  Future<void> _refresh() async {
    final devices = await _command.devices ?? const <fmc.MidiDevice>[];
    if (_closed) return;
    final usable = [
      for (final d in devices)
        if (d.type == fmc.MidiDeviceType.serial) d,
    ];
    for (final device in usable) {
      if (device.connected || _connected.containsKey(device.id)) continue;
      try {
        await _command.connectToDevice(device);
        _connected[device.id] = device;
      } catch (e) {
        debugPrint("Couldn't connect to MIDI device ${device.name}: $e");
      }
      if (_closed) return;
    }
    // Forget the ones that went away.
    final present = {for (final d in usable) d.id};
    _connected.removeWhere((id, _) => !present.contains(id));
    _ports = [
      for (final d in usable) MidiPort(id: d.id, name: d.name, manufacturer: '', connected: true),
    ];
    _portsChanged.add(_ports);
  }

  void _onPacket(fmc.MidiPacket packet) {
    if (_closed) return;
    final receivedAt = hostClockMs();
    var timestamp = packet.timestamp / 1e6;
    // A message stamped 0 (as some transports do), or seemingly from the future or long ago, is
    // on some other clock: time it by when it arrived instead.
    if (packet.timestamp <= 0 || timestamp > receivedAt + 1 || receivedAt - timestamp > 1000) {
      timestamp = receivedAt;
      untimed++;
    }
    _messages.add(
      MidiMessage(
        portId: packet.device.id,
        data: Uint8List.fromList(packet.data),
        timestamp: timestamp,
        receivedAt: receivedAt,
      ),
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    for (final device in _connected.values) {
      _command.disconnectDevice(device);
    }
    _connected.clear();
    _messages.close();
    _portsChanged.close();
  }
}
