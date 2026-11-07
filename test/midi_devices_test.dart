import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/services/midi_input.dart';
import 'package:mrdriller/state/midi_devices.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'E-MU Systems, Inc. / E-MU XMidi1X1';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // A fresh copy, loaded from what was saved.
  Future<MidiDevices> reloaded() async {
    final devices = MidiDevices();
    await devices.load();
    return devices;
  }

  test("keys a device by its manufacturer and name, as its port's id isn't stable", () {
    const port = MidiPort(
      id: 'abc123',
      name: 'E-MU XMidi1X1',
      manufacturer: 'E-MU Systems, Inc.',
      connected: true,
    );
    expect(midiDeviceKey(port), key);
    const unnamed = MidiPort(id: 'x', name: 'Pad', manufacturer: '', connected: true);
    expect(midiDeviceKey(unnamed), 'Pad');
  });

  test('maps pads to roles, and unmaps them, and saves them', () async {
    final devices = MidiDevices();
    await devices.load();
    expect(devices.roleOf(key, 48), isNull);
    devices.setRole(key, 48, PadRole.right);
    devices.setRole(key, 50, PadRole.left);
    devices.setRole(key, 52, PadRole.ignore);
    devices.setRole(key, 50, null);
    final loaded = await reloaded();
    expect(loaded.byKey(key)?.pads, {48: PadRole.right, 52: PadRole.ignore});
  });

  test("shows a device's name if it's been renamed, else its key", () async {
    final devices = MidiDevices();
    await devices.load();
    expect(devices.nameOf(key), key);
    devices.rename(key, 'KAT pad');
    expect(devices.nameOf(key), 'KAT pad');
    final loaded = await reloaded();
    expect(loaded.nameOf(key), 'KAT pad');
    // Renaming it back to its key forgets the name.
    devices.rename(key, key);
    expect(devices.byKey(key)?.name, isNull);
  });

  test('forgets a device', () async {
    final devices = MidiDevices();
    await devices.load();
    devices.setRole(key, 48, PadRole.right);
    devices.forget(key);
    expect(devices.byKey(key), isNull);
    expect(devices.all, isEmpty);
    final loaded = await reloaded();
    expect(loaded.all, isEmpty);
  });

  test('starts empty if what was saved is unreadable', () async {
    SharedPreferences.setMockInitialValues({'midi.devices': 'not json'});
    final devices = MidiDevices();
    await devices.load();
    expect(devices.all, isEmpty);
  });
}
